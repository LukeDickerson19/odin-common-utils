package logging_util

import "core:fmt"
import "core:os"
import "core:strings"
import "core:time"
import "core:time/timezone"
import "core:sync"
import "core:mem"
import "core:c"
import "core:math"
import "core:strconv" // used for high performance casting in get_process_memory_usage()
import "core:slice"

LOGGING_ENABLED :: true // toggle logging entirely

Log :: struct {

    filepath:              string,       // path to the log file
    file_stream:           os.Handle,    // stream to print logfile output to
    output_to_logfile:     bool,         // flag to print to the log file or not
    logfile_indent:        string,       // what an indent looks like in the log file

    console_stream:        os.Handle,    // stream to print console output to (e.g., stdout, stderr)
    output_to_console:     bool,         // flag to print to the console or not
    console_indent:        string,       // what an indent looks like in the console

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
        log:                ^Log,                // you can call print() via log->print("message") because 'log' is a pointer to the Log struct
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
    clear_old_log:        bool      = true, // flag to clear the log file or not
    output_to_logfile:    bool      = true,
	logfile_indent:       string    = "    ",
	console_stream:       os.Handle = 0, // 0 maps to os.stdout
    output_to_console:    bool      = true,
	console_indent:       string    = "|   ",
    prepend_datetime_fmt: string    = "",
	timezone:             string    = "UTC",
    prepend_memory_usage: bool      = false,
	max_indents:          int       = 10,
	max_message_chars:    u32       = 10000,
	max_line_chars:       u32       = 1000,
) -> ^Log {

	// Set log struct members based on arguments, defaults, and available procedures
    log := new(Log)
	
	// Return early if logging is disable
	if !LOGGING_ENABLED do return log;

	// only allow output to logfile if a valid filepath is provided
	// create logfile if it doesn't exist, and clear it if user specified to do so
	if log.filepath != "" {
		mode: int = os.O_WRONLY | os.O_CREATE
		if clear_old_log do mode |= os.O_TRUNC
		else do mode |= os.O_APPEND
		// os.O_WRONLY opens the file in write-only mode. You can't read from the file in this mode
		// os.O_CREATE create the file if it does not already exist
		// os.O_TRUNC  if the file exists, erase everything inside it 
		handle, err := os.open(log.filepath, mode, 0o644)
		if err != os.ERROR_NONE {
            // so just set output_to_logfile to false if file open fails to not crash the program
            fmt.eprintln("LOG ERROR: failed to create logfile: %s", err)
            log.filepath = ""
            log.file_stream = 0
			log.output_to_logfile = false
		} else {
            log.filepath = filepath
            log.file_stream = handle
            log.output_to_logfile = true
        }
    } else {
		log.output_to_logfile = false
	}
    log.logfile_indent = logfile_indent

	// Map 0 to os.stdout. Odin doesn't allow runtime-only values like os.stdout as default paramater values
    stream: os.Handle = console_stream == 0 ? os.stdout : console_stream
    if !slice.contains([]os.Handle{os.stdout, os.stderr}, stream) {
        // Any other handle is considered invalid for the 'console'
        // so just disable console output to not crash the program
        fmt.eprintln("LOG ERROR: invalid console stream")
        log.console_stream = 0
        log.output_to_console = false
    } else {
        log.console_stream = stream
        log.output_to_console = output_to_console
    }
    log.console_indent = console_indent

    // fix weird timezone bug in C:
    // replace "%Z" with hardcoded "UTC" if
    // "%Z" substring in prepend_datetime_fmt and timezone = "UTC"
    log.prepend_datetime_fmt = strings.clone(prepend_datetime_fmt) // clone prepend_datetime_fmt so the Log owns it
    if strings.contains(log.prepend_datetime_fmt, "%Z") && log.timezone == "UTC" {
        new_fmt: string; was_allocation: bool
        new_fmt, was_allocation = strings.replace_all(log.prepend_datetime_fmt, "%Z", "UTC")
        // https://pkg.odin-lang.org/core/strings/#replace_all
        // https://pkg.odin-lang.org/core/strings/#replace <-- more info in docs for replace
        delete(log.prepend_datetime_fmt) // free the previous version
        log.prepend_datetime_fmt = strings.clone(new_fmt) // clone the new version
        if was_allocation do delete(new_fmt) // delete the new_fmt string
    }
    log.timezone = timezone
    log.prepend_memory_usage = prepend_memory_usage

    // assign message maximums
    log.max_indents = max_indents
    log.max_message_chars = max_message_chars
    log.max_line_chars = max_line_chars

    // map this log struct instance to the first arg of the print procedure so you can call it via log->print("message")
    // NOTE: removing this makes calling the procedures with "log->" cause a seg fault
    log.print = print
	
    return log
}

close_log :: proc(
	log: ^Log
) {
	if log == nil do return
	if log.file_stream != 0 {
		os.close(log.file_stream)
	}
    delete(log.prepend_datetime_fmt)
	delete(log.prev_console_message)
	free(log)
}

print :: proc(
	log:                ^Log,                // you can call print() via log->print("message") because 'log' is a pointer to the Log struct
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
    sync.lock(&log.mutex)
    defer sync.unlock(&log.mutex)

    // Validate arguments
	if log == nil {
		fmt.eprintln("LOG ERROR: must pass a Log struct pointer")
        return "", "", false
	}

    // Print to console
	output_to_console: bool = (oc == nil) ? log.output_to_console : oc.(bool)
    console_str = ""
	if output_to_console {

        // Move cursor up and clear previous string if user set overwrite_prev_msg to true
        if overwrite_prev_msg && log.prev_console_message != "" {
            console_clear_previous_message(log)
        }

		// Format console string
		console_str, ok = get_formatted_message(log, msg, log.console_indent, i, ns, ne, d, end)
		if !ok {
			fmt.eprintln("LOG ERROR: failed to format console string")
            return "", "", false
        }

        // Print message to console
        fmt.fprint(log.console_stream, console_str)
        // fmt.fprint takes a file handle and variadic args, and prints them without appending a new line character

        // Update previous message tracking
        delete(log.prev_console_message)  // Free old string
        log.prev_console_message = strings.clone(console_str)  // Store new string

	}

    // TODO: try to find a way to reuse get formatted string? probably make it take a list of indent types and return a list?, should be easy!

    // Print to log file
	output_to_logfile: bool = (of == nil) ? log.output_to_logfile : of.(bool)
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
        fmt.eprintln("LOG ERROR: num indents, i, must be between 0 and log.max_indents of %d (inclusive), or log.max_indents must be increased in its initialization", log.max_indents)
        return "", false
    }

    // indent buffers
    total_indent1: string = strings.repeat(indent, num_indents)
    total_indent2: string = strings.repeat(indent, num_indents + 1)
    total_indent3: string = draw ? total_indent2 : total_indent1

    // Prepend info buffers and variables
    p: string = "" // p = prepended info text
    p0: string = "" // p0 = mock indents: If info is prepended to each line, mock indents are tiny indents before the prepended info. They exist so VS Code's code folding feature continues to work when there's prepended info, and the prepended info remains veritically alligned.
    div_mark: rune = '-'
    mock_indent: string = " "
    prepend_stuff: bool = log.prepend_datetime_fmt != "" || log.prepend_memory_usage
    if prepend_stuff {

        // Prepend datetime in specified format
        if log.prepend_datetime_fmt != "" {
            datetime_str, ok := get_formatted_current_time(
                log.timezone,
                log.prepend_datetime_fmt
            )
            if !ok {
                fmt.eprintln("LOG ERROR: failed to get current time for prepending")
                return "", false // TODO: set msg to error msg + msg
            }
            // fmt.println("datetime_str:", datetime_str)
            p = fmt.tprintf("%s  ", datetime_str) // fmt.tprintf uses the tmep allocator and can be used since p is local to this procedure
        }

        // Prepend memory usage
        if log.prepend_memory_usage {
            // Example using global stats; you can implement a function to get actual memory usage if you want
            mem_usage_str, ok := get_process_memory_usage()
            // fmt.println("mem_usage_str:", mem_usage_str)
            if log.prepend_datetime_fmt != "" {
                p = fmt.tprintf("%s%c  ", p, div_mark)
            }
            p = fmt.tprintf("%s%17s", p, mem_usage_str)
        }

        // Create prepended info strings
        p0 = strings.repeat(mock_indent, num_indents)
        p = fmt.tprintf("%s%s%r  ",
            strings.repeat(" ", log.max_indents + 1 - (len(mock_indent) * num_indents)),
            p,
            div_mark,
        )
    }
    // blank_p is the same as p but w/ prepend info removed, only marks remain
    blank_p: string = fmt.tprintf("%s%r%s%c  ",
        p0,
        div_mark,
        strings.repeat(" ", len(p) - 3),
        div_mark,
    )

    // Start building final formatted message
    sb: strings.Builder
    strings.builder_init(&sb, context.temp_allocator)
    defer strings.builder_destroy(&sb)

    if newline_start {
        if prepend_stuff do strings.write_string(&sb, blank_p)
        strings.write_string(&sb, total_indent3)
        strings.write_string(&sb, end)
    }
    
    lines := strings.split(msg, "\n", context.temp_allocator)
    defer delete(lines)
    for line, idx in lines {
        empty_line := line == ""

        if prepend_stuff {
            if empty_line {
                // empty line → use blank alignment helper
                strings.write_string(&sb, blank_p)
            } else {
                // non-empty → mock indent + divider + space
                strings.write_string(&sb, p0)
                strings.write_rune (&sb, div_mark)
                strings.write_string(&sb, p)
            }
        }
        strings.write_string(&sb, empty_line ? total_indent3 : total_indent1)
        strings.write_string(&sb, line)
        strings.write_string(&sb, end)
    }

    if newline_end {
        if prepend_stuff do strings.write_string(&sb, blank_p)
        strings.write_string(&sb, total_indent3)
        strings.write_string(&sb, end)
    }

    formatted_message = strings.to_string(sb)
    return formatted_message, true

}

// get_formatted_current_time returns the current datetime as a formatted string
//
// - timezone: "local" or "UTC", defaults to UTC
// - format:   format to display datetime in
//             based on strftime. available formats: https://www.tutorialspoint.com/c_standard_library/c_function_strftime.htm
//
// Returns: the formatted datetime string (or empty on error)
@(private)
get_formatted_current_time :: proc(
    timezone:    string,
    format:      string,
    buffer_size: int = 128,
) -> (
    string,
    bool,
) {

    // allocate empty cstring of buffer_size
    buffer, err := mem.alloc(buffer_size)
    if err != nil {
        fmt.eprintf("datetime cstring allocation failed: %v\n", err)
        return "", false
    }
    datetime_cstr := cstring(buffer)
    defer mem.free(buffer)

    rc: c.int = get_current_time(
        cstring(raw_data(timezone)),
        datetime_cstr,
        c.size_t(buffer_size),
        cstring(raw_data(format)),
    )
    if rc != 0 {
        fmt.eprintf("get_current_time failed → %d\n", rc)
        return "", false
    }

    return string(datetime_cstr), true
}
// used a c binding for get_formatted_current_time() because I failed to get the local time in odin, only UTC. Also setting the timezone seems to require the UTC offset, which gets complicated because of daylights saving time. Also I couldn't find a way to format it via a user provided format string. see odin time package docs: https://pkg.odin-lang.org/core/time
when ODIN_OS == .Windows do foreign import current_time_formatted "current_time_formatted.lib"
when ODIN_OS == .Linux   do foreign import current_time_formatted "current_time_formatted.a"
// binding odin to c: https://odin-lang.org/news/binding-to-c/
foreign current_time_formatted {
    get_current_time :: proc(
        timezone: cstring,
        datetime_str: cstring,
        datetime_str_capacity: c.size_t,
        format: cstring,
    )-> c.int ---
}


@(private)
get_process_memory_usage :: proc() -> (string, bool) {
    bytes, ok := get_os_specific_memory() // Compiler finds this in the suffixed files
    if !ok do return "Memory read error  ", false

    mem_str := get_memory_str(bytes)
    return fmt.tprintf("%14s used  ", mem_str), true
}

@(private)
get_memory_str :: proc(bytes: u64) -> string {
	units     := [?]string{"bytes", "KiB", "MiB", "GiB", "TiB", "PiB", "EiB", "ZiB", "YiB"}
	b         := f64(bytes)
	unit_idx  := 0

	// Scale the value down
	for b >= 1024 && unit_idx < len(units) - 1 {
		b /= 1024.0
		unit_idx += 1
	}

	if unit_idx == 0 {
		if bytes == 1 {
			return "1 byte"
		}
		return fmt.tprintf("%d bytes", bytes)
	}

	// %.4f matches your C snprintf precisely
	return fmt.tprintf("%.4f %s", b, units[unit_idx])
}

