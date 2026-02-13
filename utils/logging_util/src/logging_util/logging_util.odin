package logging

import "core:fmt"
import "core:os"
import "core:strings"
import "core:time"
import "core:time/timezone"
import "core:sync"
import "core:mem"
import "core:c"

LOGGING_ENABLED :: true // toggle logging entirely

Log :: struct {

    filepath:              string,       // path to the log file
    console_stream:        os.Handle,    // stream to print console output to (e.g., stdout, stderr)
    file_handle:           os.Handle,    // tbd
    clear_old_log:         bool,         // flag to clear the log file or not
    output_to_console:     bool,         // flag to print to the console or not
    output_to_logfile:     bool,         // flag to print to the log file or not
    console_indent:        string,       // what an indent looks like in the console
    logfile_indent:        string,       // what an indent looks like in the log file
    prepend_datetime_fmt:  string,       // format specifying datetime to prepend to each line printed
    timezone:              string,       // timezone to use if prepend_datetime_fmt is not an empty string
    prepend_memory_usage:  bool,         // prepend the memory used and allocated to the program using the logging util

    max_indents:           int,          // max number of indents the user can indent a log message
    max_message_chars:     u32,          // max number of characters per message, tested w/ value: 500
    max_line_chars:        u32,          // max number of characters per line (must be less than MAX_MESSAGE_CHARS), tested w/ value: 150

    prev_console_message:  string,       // variables used for overwrite_prev_msg
	prev_logfile_start:    i64,
	prev_logfile_end:      i64,

    mutex:                 sync.Mutex,   // thread safety mutex

    // pointer to print procedure
    print: proc(
        this:               ^Log,                // you can call print() via log->print("message") because 'this' is a pointer to the Log struct
        msg:                string,              // message to print
        i:                  int         = 0,     // number of indents to put in front of the string, defaults to 0
        ns:                 bool        = false, // print a new line in before the string, defaults to false
        ne:                 bool        = false, // print a new line in after the string, defaults to false
        oc:                 Maybe(bool) = nil,   // output to console, defaults to nil, which uses the Log struct's output_to_console bool
        of:                 Maybe(bool) = nil,   // output to logfile, defaults to nil, which uses the Log struct's output_to_logfile bool
        d:                  bool        = false, // draw a line on the blank line before or after the string, defaults to false
        overwrite_prev_msg: bool        = false, // overwrite previous printed message in console and logfile
        end:                string      = "\n",  // last character(s) to print at the end of the string, defaults to "\n"
    ) -> (
        console_str: string, // pointer to string printed to console
        logfile_str: string, // pointer to string printed to logfile
        ok: bool,            // success flag
    )

}

init_log :: proc(
    filepath:             string    = "",
	console_stream:       os.Handle = 0, // 0 to os.stdout in init
	file_handle:          os.Handle = 0, // 0 to file at filepath in init
    output_to_logfile:    bool      = true,
    clear_old_log:        bool      = true,
    output_to_console:    bool      = true,
	console_indent:       string    = "|   ",
	logfile_indent:       string    = "    ",
    prepend_datetime_fmt: string    = "",
	timezone:             string    = "UTC",
	max_indents:          int       = 10,
	max_message_chars:    u32       = 10000,
	max_line_chars:       u32       = 1000,
) -> ^Log {

	// set log struct members based on arguments, defaults, and available procedures
    log := new(Log)
    log.filepath = filepath
    log.output_to_console = output_to_console
    log.output_to_logfile = output_to_logfile
    log.clear_old_log = clear_old_log
    log.console_indent = console_indent
    log.logfile_indent = logfile_indent
    log.timezone = timezone
    log.prepend_datetime_fmt = prepend_datetime_fmt
    log.max_indents = max_indents
    log.max_message_chars = max_message_chars
    log.max_line_chars = max_line_chars

    log.print = print
	
	// return early if logging is disable
	if !LOGGING_ENABLED do return log;

	// handle runtime-only values like os.stdout that can't be defaulted to in the proc args
	switch console_stream {
		case 0:
			log.console_stream = os.stdout
		case os.stdout, os.stderr:
			// It's already a valid standard stream, keep as is
			log.console_stream = console_stream
		case:
			// Any other handle is considered invalid for the 'console'
			// so fail silently by disabling console output
			log.output_to_console = false
	}

	// only allow output to logfile if a valid filepath is provided
	// create logfile if it doesn't exist, and clear it if user specified to do so
	if log.filepath != "" {
		mode: int = os.O_WRONLY | os.O_CREATE
		if log.clear_old_log do mode |= os.O_TRUNC
		else do mode |= os.O_APPEND
		// os.O_WRONLY opens the file in write-only mode. You can't read from the file in this mode
		// os.O_CREATE create the file if it does not already exist
		// os.O_TRUNC  if the file exists, erase everything inside it 
		handle, err := os.open(log.filepath, mode, 0o644)
		if err == os.ERROR_NONE {
			log.file_handle = handle
		} else {
			// set output_to_logfile to false if file open fails
			log.output_to_logfile = false
			return log
		}
	} else {
		log.output_to_logfile = false
	}

    // fix weird timezone bug in C:
    // replace "%Z" with hardcoded "UTC" if
    // "%Z" substring in prepend_datetime_fmt and timezone = "UTC"
    if strings.contains(log.prepend_datetime_fmt, "%Z") && log.timezone == "UTC" {
        new_fmt: string; was_alloc: bool
        new_fmt, was_alloc = strings.replace_all(log.prepend_datetime_fmt, "%Z", "UTC")
        // https://pkg.odin-lang.org/core/strings/#replace_all
        // https://pkg.odin-lang.org/core/strings/#replace <-- more info in docs for replace
        if was_alloc {
            log.prepend_datetime_fmt = strings.clone(new_fmt)
            delete(new_fmt)
        } else {
            log.prepend_datetime_fmt = new_fmt
        }
    }
	
    return log
}

close_log :: proc(
	log: ^Log
) {
	if log == nil do return
	if log.file_handle != 0 {
		os.close(log.file_handle)
	}
    delete(log.prepend_datetime_fmt)
	delete(log.prev_console_message)
	free(log)
}

print :: proc(
	this:               ^Log,                // you can call print() via log.print("message") because 'this' is a pointer to the Log struct
	msg:                string,              // message to print
    i:                  int         = 0,     // number of indents to put in front of the string, defaults to 0
    ns:                 bool        = false, // print a new line in before the string, defaults to false
    ne:                 bool        = false, // print a new line in after the string, defaults to false
    oc:                 Maybe(bool) = nil,   // output to console, defaults to nil, which uses the Log struct's output_to_console bool
    of:                 Maybe(bool) = nil,   // output to logfile, defaults to nil, which uses the Log struct's output_to_logfile bool
    d:                  bool        = false, // draw a line on the blank line before or after the string, defaults to false
    overwrite_prev_msg: bool        = false, // overwrite previous printed message in console and logfile
    end:                string      = "\n",  // last character(s) to print at the end of the string, defaults to "\n"
) -> (
	console_str: string, // pointer to string printed to console
	logfile_str: string, // pointer to string printed to logfile
	ok: bool,            // success flag
) {
    if !LOGGING_ENABLED do return
    
	// lock mutex for thread safety, and defer unlock to the end of the procedure
    sync.lock(&this.mutex)
    defer sync.unlock(&this.mutex)

    // Validate arguments
	if this == nil {
		fmt.eprintln("ERROR: must pass a Log struct pointer")
        return "", "", false
	}

    // Print to console
	output_to_console: bool = (oc == nil) ? this.output_to_console : oc.(bool)
    console_str = ""
	if output_to_console {

        // Move cursor up and clear previous string if user set overwrite_prev_msg to true
        if overwrite_prev_msg && this.prev_console_message != "" {
            console_clear_previous_message(this)
        }

		// Format console string
		console_str, ok = get_formatted_message(this, msg, this.console_indent, i, ns, ne, d, end)
		if !ok {
			fmt.eprintln("ERROR: failed to format console string")
            return "", "", false
        }



	}

    // Print to log file
	output_to_logfile: bool = (of == nil) ? this.output_to_logfile : of.(bool)
    logfile_str = ""
	if output_to_logfile {
    }

    return console_str, logfile_str, true
}

@(private)
console_clear_previous_message :: proc(log: ^Log) {
	line_count := strings.count(log.prev_console_message, "\n")
	seq := "\033[F\033[K" // cursor up + clear line
	for _ in 0..<line_count {
		os.write_string(log.console_stream, seq)
		os.flush(log.console_stream) // flush for immediate effect
	}
}

@(private)
get_formatted_message :: proc(
	log:           ^Log,
	msg:           string,
	indent:        string,
	num_indents:   int,
	newline_start: bool,
	newline_end:   bool,
	draw:          bool,
	end:           string,
) -> (
	formatted_message: string, // pointer to string printed to console
	ok: bool,                  // success flag
) {

    // Validate user input arguments
	if num_indents < 0 || num_indents > log.max_indents {
		fmt.eprintln("ERROR: num indents, i, must be between 0 and log.max_indents of %d (inclusive), or log.max_indents must be increased in its initialization", log.max_indents)
		return "", false
	}

    // indent buffers
	total_indent1: string = strings.repeat(indent, num_indents)
	total_indent2: string = strings.repeat(indent, num_indents + 1)
	total_indent3: string = draw ? total_indent2 : total_indent1

	// Prepend info buffers and variables
	formatted_message = "" // this will hold the final formatted message with prepended info and indents, ready to be printed to console or logfile
	div_mark: rune = '-'
	mock_indent: string = " "
	p0: string = "" // p0 = mock indents (if info is prepended to each line, mock indents are tiny indents before the prepended info)
	p: string = ""; // p = prepended info text
	prepend_stuff: bool = log.prepend_datetime_fmt != "" || log.prepend_memory_usage
	if prepend_stuff {

		// Prepend datetime in specified format
		if log.prepend_datetime_fmt != "" {
            datetime_str: string; ok: bool
            datetime_str, ok = get_formatted_current_time(
                log.timezone,
                log.prepend_datetime_fmt
            )
            if !ok {
                fmt.eprintln("ERROR: failed to get current time for prepending")
                return "", false // TODO: set msg to error msg + msg
            }
            fmt.println("datetime_str:", datetime_str)
			// datetime_str, ok = current_time_formatted(log.timezone, log.prepend_datetime_fmt)
            // // datetime_str, ok = current_time_formatted(log.timezone, log.prepend_datetime_fmt)
			// if !ok {
            //     fmt.eprintln("ERROR: failed to get current time for prepending")
            //     return msg, false // TODO: set msg to error msg + msg
			// }
		}

		// // Prepend memory usage
		// if log.prepend_memory_usage {
		// 	// Example using global stats; you can implement a function to get actual memory usage if you want
		// 	mem_usage_str := fmt.sprintf("%v", mem.Kilobyte * 1024) 
		// 	if log.prepend_datetime_fmt != "" {
		// 		p = fmt.sprintf("%s%c  %17s", p, div_mark, mem_usage_str)
		// 	} else {
		// 		p = fmt.sprintf("%17s", mem_usage_str)
		// 	}
		// }

		// // fill p0 memory with mock indents + div_mark
		// p0 = strings.repeat(mock_indent, num_indents) + fmt.sprintf("%c ", div_mark)
	}

    return "", false

}

// binding odin to c: https://odin-lang.org/news/binding-to-c/
when ODIN_OS == .Windows do foreign import current_time_formatted "current_time_formatted.lib"
when ODIN_OS == .Linux   do foreign import current_time_formatted "current_time_formatted.a"
foreign current_time_formatted {
    get_current_time :: proc(
        timezone: cstring,
        datetime_str: cstring,
        datetime_str_capacity: c.size_t,
        format: cstring,
    )-> c.int ---
}

// Utility to get formatted time via C
get_formatted_current_time :: proc(
    timezone: string,
    format:   string,
    buf_size: int = 128,
) -> (
    datetime_str: string,
    ok: bool
) {

    // Allocate buffer for C to write into (+1 for null terminator)
    buf := make([]byte, buf_size + 1)
    defer delete(buf) // free the buffer memory when this function returns
    mem.zero_slice(buf) // Zero out the buffer (good hygiene, though C will null-terminate)

    // Call C function
    rc: c.int = get_current_time(
        cstring(raw_data(timezone)),
        cstring(raw_data(buf)),
        c.size_t(buf_size),
        cstring(raw_data(format)),
    )
    if rc != 0 {
        fmt.eprintf("get_current_time failed with code %d\n", rc)
        return "ERROR: failed to get formatted time", false
    }

    // Return the formatted cstring cast to string
    // NOTE: string(my_cstring) is "O(N) time as it will scan the memory, looking for the null terminator, in order to determine the length of the string" - https://odin-lang.org/news/binding-to-c/
    datetime_str = string(buf)
    return datetime_str, true
}


// current_time_formatted returns the current time as a formatted string.
//
// - timezone: IANA timezone name (e.g. "America/Phoenix", "UTC", "Europe/London")
//             If empty -> uses system local time.
// - format:   Go-style reference time format (uses "2006-01-02 15:04:05" as reference)
//             If empty -> defaults to "2006-01-02 15:04:05 MST" (human readable)
//             Common presets: time.RFC3339, time.ANSIC, time.Kitchen, etc.
//
// Returns: the formatted time string (or empty on error)

// EXMAPLE USAGE:
// fmt.println("Local (default):", current_time_formatted("", ""))
// fmt.println("UTC (RFC3339):", current_time_formatted("UTC", time.RFC3339))
// fmt.println("Phoenix (custom):", current_time_formatted("America/Phoenix", "2006-01-02 15:04:05 MST"))
// fmt.println("Tokyo (kitchen):", current_time_formatted("Asia/Tokyo", time.Kitchen))


/*

@(private)
current_time_formatted :: proc(
    timezone: string,
    format: string
) -> (
	formatted_time: string, // formatted string of current time in specified timezone
	ok: bool,               // success flag
) {

    // Get current UTC time
    t: time.Time = time.now()
    unix_nanoseconds: i64 = time.time_to_unix_nano(t)

    // // Convert to desired timezone
    // if timezone != "UTC" {
    //     loc := time.load_location(timezone)
    //     t = time.time_in_location(t, loc)
    // }

    // Format and return the time
    builder := strings.Builder{}
    strings.builder_init(&builder)
    defer strings.builder_destroy(&builder)
    err := time.format_to_writer(&builder, t, format)
    if err != nil {
        fmt.eprintf("Format error: %v\n", err)
        return "Error formatting time", false
    }
    return strings.to_string(builder), true
}



@(private)
current_time_formatted :: proc(
    timezone: string,
    format: string
) -> (
	formatted_time: string, // formatted string of current time in specified timezone
	ok: bool,               // success flag
) {

    // Load timezone if provided
    loc: ^time.Location = nil
    if timezone != "local" {
        loaded_loc, ok := time.load_location(timezone)
        if ok {
            loc = loaded_loc
        } else {
            // Fallback to local if timezone fails
            fmt.eprintf("Warning: timezone '{}' not found, using local time\n", timezone)
        }
    }

    // Get current time and convert to desired timezone (or local if no valid tz)
    t: time.Time = time.now()
    
    loc != nil ? time.time_in_location(time.now(), loc) : time.now_local()

    // Format the time
    builder := strings.Builder{}
    strings.builder_init(&builder)
    defer strings.builder_destroy(&builder)
    time.format_to_writer(&builder, t, format)

    return strings.to_string(builder), true
}

@(private)
current_time_formatted :: proc(
    timezone: string,
    format: string
) -> (
	formatted_time: string, // formatted string of current time in specified timezone
	ok: bool,               // success flag
) {

    // Get current time
    t: time.Time = time.now() // UTC timezone

    // Load timezone
    t2: time.Time = time.now_local() // UTC timezone

    loc := time.local_location()
    if timezone != "local" {
        loaded, ok := time.load_location(timezone)
        if ok {
            loc = loaded
        } else {
            // Fallback to local if timezone fails
            fmt.eprintf("Warning: timezone '{}' not found, using local time: '{}'\n", timezone, loc.name)
        }
    }

    // Convert to desired timezone
    t = time.time_in_location(t, loc)    

    // Format the time
    builder := strings.Builder{}
    strings.builder_init(&builder)
    defer strings.builder_destroy(&builder)
    err := time.format_to_writer(&builder, t, format)
    if err != nil {
        fmt.eprintf("Format error: %v\n", err)
        return "Error formatting time", false
    }

    return strings.to_string(builder), true
}
*/
