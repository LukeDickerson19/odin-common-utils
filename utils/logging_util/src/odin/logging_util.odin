package logging_util

import "core:fmt"
// TODO: update when odin lang finishes its core:os update:
// https://odin-lang.org/news/moving-towards-a-new-core-os/
// https://pkg.odin-lang.org/core/os
import "core:os/os2"
import "core:io"
import "core:strings"
import "core:time"
import "core:time/timezone"
import "core:sync"
import "core:mem"
import "core:c"
import "core:math"
import "core:strconv" // used for high performance casting in get_process_memory_usage()
import "core:slice"



Log :: struct {

    /////////////////////////////////////// Struct Members ///////////////////////////////////////

    enabled:                 bool,       // toggle logging entirely

    output_to_logfile:       bool,       // flag to print to the log file or not
    filepath:                string,     // path to the log file
    file:                    ^os2.File,  // pointer logfile os2.File struct
    logfile_indent:          string,     // what an indent looks like in the log file

    output_to_console:       bool,       // flag to print to the console or not
    console:                 ^os2.File,  // pointer console os2.File struct (e.g., stdout, stderr)
    console_indent:          string,     // what an indent looks like in the console

    prepend_datetime_fmt:    string,     // format specifying the datetime to prepend to each line printed
    timezone:                string,     // timezone to use if prepend_datetime_fmt is not an empty string
    prepend_elapsed_time:    bool,       // flag to prepend the time elapsed since the the Log's start_time
    unix_start_time:         i64,        // unix start time used for prepending elapsed time, defaults to time when init() is called
    start_time_microseconds: i32,        // microsecond component of start time used for prepending time elapsed
    prepend_memory_usage:    bool,       // prepend the memory used and allocated to the program using the logging util
    max_indents:             u8,         // max number of indents the user can indent a log message // NOTE: max_indents effects mini indents when prepending time or memory info, keep it as small as you think the max number of indents you the user will use.
    max_message_chars:       u32,        // max number of characters per message, tested w/ value: 500
    max_line_chars:          u32,        // max number of characters per line (must be less than MAX_MESSAGE_CHARS), tested w/ value: 150

    prev_console_message:    string,     // variables used for overwrite_prev_msg
    logfile_last_offset:     i64,        // byte offset where last log message started (defaults to 0)

    mutex:                   sync.Mutex, // thread safety mutex

    /////////////////////// Procedure Pointers (aka OOP class functions) //////////////////////////

    // NOTE: all procedures must also be declared or defined in init(), or in general upon struct creation

    // main print() procedure
    print: proc(
        log:                ^Log,                // you can call print() via log->print("message") because 'log' is a pointer to the Log struct
        msg:                string,              // message to print
        i:                  u8          = 0,     // number of indents to put in front of the string, defaults to 0
        ns:                 bool        = false, // print a new line in before the string, defaults to false
        ne:                 bool        = false, // print a new line in after the string, defaults to false
        oc:                 Maybe(bool) = nil,   // output to console, defaults to nil, which uses the Log struct's output_to_console bool
        of:                 Maybe(bool) = nil,   // output to logfile, defaults to nil, which uses the Log struct's output_to_logfile bool
        d:                  bool        = false, // draw a line on the blank line before or after the string, defaults to false
        overwrite_prev_msg: bool        = false, // overwrite previous printed message in console and logfile
        end:                string      = "\n",  // last character(s) to print at the end of the string, defaults to "\n"
        console_msg:        ^string     = nil,   // pointer to string printed to console, so user can use console_msg outside log->print()
        logfile_msg:        ^string     = nil,   // pointer to string printed to logfile, so user can use logfile_msg outside log->print()
    ) -> (
        ok: bool,                                // success flag
    ),

    // test: proc(log: ^Log) // see example test() of declaring a procedure inside init()

    // set/update prepend_datetime_fmt for future log messages to be printed
    set_prepend_datetime_fmt: proc(
        log: ^Log,
        new_prepend_datetime_fmt: string
    ),

    // set/update timezone for future log messages to be printed
    set_timezone: proc(
        log: ^Log,
        new_timezone: string
    ),

    // update the start time for elapsed time prepend info to a specific time with tuple
    // (unix time in seconds, microseconds), or to the current time with the default nil value
    set_start_time: proc(
        log: ^Log,
        unix_start_time: i64 = 0,
        microseconds: i32 = 0,
    ),

    ///////////////////////////////////////////////////////////////////////////////////////////////
    
}


init :: proc(
    enabled:                 bool      = true,
    output_to_logfile:       bool      = true,
    filepath:                string    = "",
    clear_old_log:           bool      = true, // flag to clear the log file or not
	logfile_indent:          string    = "    ",
    output_to_console:       bool      = true,
	console:                 ^os2.File = {}, // {} maps to os2.stdout
	console_indent:          string    = "|   ",
    prepend_datetime_fmt:    string    = "",
	timezone:                string    = "UTC",
    prepend_elapsed_time:    bool      = false,
    unix_start_time:         i64       = 0, // if unix_start_time == 0, use current time, else use unix_start_time
    start_time_microseconds: i32       = 0, // if unix_start_time == 0, use current time, else use start_time_microseconds
    prepend_memory_usage:    bool      = false,
	max_indents:             u8        = 10,
	max_message_chars:       u32       = 10000,
	max_line_chars:          u32       = 1000,
) -> ^Log {

    // Init log struct
    log := new(Log)

    // map all public procedures of this log struct instance to the log arg of init() so you can call them via "->" syntax, example: "log->print("message")"
    // NOTE: removing these mappings makes calling the procedures with "log->" cause a seg fault, thats why its before "if !log.enabled ..."
    log.print = print
    log.set_prepend_datetime_fmt = set_prepend_datetime_fmt
    log.set_timezone = set_timezone
    log.set_start_time = set_start_time
    // // example of declaring a procedure inside init()
    // log.test = proc(log: ^Log) {
    //     fmt.println("test")
    // }
    // log->test()

    // Return early if logging is disable
    log.enabled = enabled
    if !log.enabled do return log;

    // Init all struct members:

    // Only allow output to logfile if a valid filepath is provided
    // create logfile if it doesn't exist, and clear it if user specified to do so
    if filepath != "" {
        flags: os2.File_Flags = { .Write, .Create }
        if clear_old_log do flags += { .Trunc }
        else do flags += { .Append }
        // flags source: https://pkg.odin-lang.org/core/os/#File_Flag
        f, err := os2.open(filepath, flags, os2.Permissions_Default_File)
        // permissions source: https://pkg.odin-lang.org/core/os/#Permissions_Default_File
        if err != os2.ERROR_NONE {
            // so just set output_to_logfile to false if file open fails to not crash the program
            fmt.eprintf("LOG ERROR: failed to create log file: %v\n", err)
            log.output_to_logfile = false
            log.filepath = ""
            log.file = nil
        } else {
            log.output_to_logfile = output_to_logfile
            log.filepath = filepath
            log.file = f
        }
    } else {
        log.output_to_logfile = false
    }
    log.logfile_indent = logfile_indent

    // Map 0 to os2.stdout. Odin doesn't allow runtime-only values like os2.stdout as default paramater values
    c: ^os2.File = console == {} ? os2.stdout : console
    if !slice.contains([]^os2.File{os2.stdout, os2.stderr}, c) {
        // Any other handle is considered invalid for the 'console'
        // so just disable console output to not crash the program
        fmt.eprintln("LOG ERROR: invalid console handle")
        log.console = nil
        log.output_to_console = false
    } else {
        log.console = c
        log.output_to_console = output_to_console
    }
    log.console_indent = console_indent

    // Set prepend info flags and data
    set_prepend_datetime_fmt_and_timezone(log, prepend_datetime_fmt, timezone)
    set_start_time(log, unix_start_time=unix_start_time, microseconds=start_time_microseconds)
    log.prepend_elapsed_time = prepend_elapsed_time
    log.prepend_memory_usage = prepend_memory_usage

    // Set message length maximums
    log.max_indents = max_indents
    log.max_message_chars = max_message_chars
    log.max_line_chars = max_line_chars

    // Init variables used for print() arg overwrite_prev_msg
    log.prev_console_message = ""
    log.logfile_last_offset = 0

    return log
}


close :: proc(
	log: ^Log,
    verbose: bool = false,
    i:                  u8          = 0,
    ns:                 bool        = false,
    ne:                 bool        = false,
    oc:                 Maybe(bool) = nil,
    of:                 Maybe(bool) = nil,
    d:                  bool        = false,
    overwrite_prev_msg: bool        = false,
    end:                string      = "\n",
    console_msg:        ^string     = nil,
    logfile_msg:        ^string     = nil,
) {
	if log == nil {
        fmt.println("No log to close, log == nil")   
        return
    }
    if verbose {
        log->print(
            f("closing log:\n%s", log.filepath),
            i=i, ns=ns, ne=ne, oc=oc, of=of, d=d,
            overwrite_prev_msg=overwrite_prev_msg, end=end,
            console_msg=console_msg, logfile_msg=logfile_msg,
        )
    }
    blacklist := []^os2.File{nil, os2.stdout, os2.stderr} // don't close these files
    if !slice.contains(blacklist, log.file) do os2.close(log.file)
    delete(log.prepend_datetime_fmt)
    delete(log.prev_console_message)
	free(log)
}


print :: proc(
    log:                ^Log,                // you can call print() via log->print("message") because 'log' is a pointer to the Log struct
    msg:                string,              // message to print 
    i:                  u8          = 0,     // number of indents to put in front of the string, defaults to 0
    ns:                 bool        = false, // print a new line in before the string, defaults to false
    ne:                 bool        = false, // print a new line in after the string, defaults to false
    oc:                 Maybe(bool) = nil,   // output to console, defaults to nil, which uses the Log struct's output_to_console bool
    of:                 Maybe(bool) = nil,   // output to logfile, defaults to nil, which uses the Log struct's output_to_logfile bool
    d:                  bool        = false, // draw a line on the blank line before or after the string, defaults to false
    overwrite_prev_msg: bool        = false, // overwrite previous printed message in console and logfile
    end:                string      = "\n",  // last character(s) to print at the end of the string, defaults to "\n"
    console_msg:        ^string     = nil,   // pointer to string printed to console, so user can use console_msg outside log->print()
    logfile_msg:        ^string     = nil,   // pointer to string printed to logfile, so user can use logfile_msg outside log->print()
) -> bool { // success flag
    if !log.enabled do return true
    
    // lock mutex for thread safety, and defer unlock to the end of this procedure
    sync.lock(&log.mutex)
    defer sync.unlock(&log.mutex)

    // Validate arguments
    if log == nil {
        fmt.eprintln("LOG ERROR: must pass a Log struct pointer")
        return false
    }

    // Get formatted string(s) for console and/or log file
    output_to_console: bool = (oc == nil) ? log.output_to_console : oc.(bool)
    output_to_logfile: bool = (of == nil) ? log.output_to_logfile : of.(bool)

    console_str, logfile_str, ok := get_formatted_messages(
        log, msg,
        output_to_console || console_msg != nil, // create console output if its to be printed or returned
        output_to_logfile || logfile_msg != nil, // create logfile output if its to be printed or returned
        i, ns, ne, d, end
    )
    if !ok {
        fmt.eprintln("LOG ERROR: failed to format message")
        return false
    }

    // Print to console
    if output_to_console {

        // Move cursor up and clear previous string if user set overwrite_prev_msg to true
        if overwrite_prev_msg && log.prev_console_message != "" {
            console_clear_previous_message(log)
        }

        // Print message to console
        os2.write_string(log.console, console_str)
        // fmt.fprint takes a file handle and variadic args, and prints them without appending a new line character

        // Update previous message tracking
        delete(log.prev_console_message) // Free old string
        log.prev_console_message = strings.clone(console_str)  // Store new string

    }

    // Print to log file
    if output_to_logfile {
        bytes := transmute([]byte)logfile_str // strings are UTF-8 already -> zero-copy // TODO: i thought strings were made of runes which were not UTF-8? verify this

        if overwrite_prev_msg && log.logfile_last_offset != 0 {

            // Seek back to start of previous message
            if _, err := os2.seek(log.file, log.logfile_last_offset, io.Seek_From.Start); err != nil {
                fmt.eprintf("LOG ERROR: logfile overwrite seek failed: %v\n", err)
                return false
            }

            // Overwrite previous message with new message
            if _, err := os2.write(log.file, bytes); err != nil {
                fmt.eprintf("LOG ERROR: logfile overwrite write failed: %v\n", err)
                return false
            }

            // Truncate file to end of new message (discards anything beyond)
            new_end := log.logfile_last_offset + i64(len(bytes))
            if err := os2.truncate(log.file, new_end); err != nil {
                fmt.eprintf("LOG ERROR: logfile overwrite truncate failed: %v\n", err)
                return false
            }

            // Force any data sitting in your program's internal output buffer to be sent to the underlying file (or device) immediately, instead of waiting for the buffer to fill up naturally.
            if err := os2.flush(log.file); err != nil {
                fmt.eprintf("LOG ERROR: logfile overwrite flush failed: %v\n", err)
                return false
            }

        } else {

            // Normal append mode
            offset, err := os2.seek(log.file, 0, io.Seek_From.Current)
            if err != nil {
                fmt.eprintf("LOG ERROR: logfile append seek failed: %v\n", err)
                return false
            }
            if _, err := os2.write(log.file, bytes); err != nil {
                fmt.eprintf("LOG ERROR: logfile append write failed: %v\n", err)
                return false
            }
            if err := os2.flush(log.file); err != nil {
                fmt.eprintf("LOG ERROR: logfile append flush failed: %v\n", err)
                return false
            }
            log.logfile_last_offset = offset
        }
    }

    // free message strings if user did not pass pointer(s)
    // to capture one or both of them
    if console_msg != nil do console_msg^ = console_str; else do delete(console_str)
    if logfile_msg != nil do logfile_msg^ = logfile_str; else do delete(logfile_str)

    return true
}


f :: proc(
    msg: string,    // message to format
    fmt_args: ..any // string format variadic parameters https://odin-lang.org/docs/overview/#variadic-parameters
) -> string {
    return fmt.tprintf(msg, ..fmt_args)
}


// Update/set prepend datetime format
set_prepend_datetime_fmt :: proc(
    log: ^Log,
    new_prepend_datetime_fmt: string,
) {
    set_prepend_datetime_fmt_and_timezone(
        log,
        new_prepend_datetime_fmt,
        log.timezone
    )
}


// Update/set timezone
set_timezone :: proc(
    log: ^Log,
    new_timezone: string,
) {
    set_prepend_datetime_fmt_and_timezone(
        log,
        log.prepend_datetime_fmt,
        new_timezone
    )
}


// Update/set the start time for elapsed time prepend info to a specific time with tuple
// (unix time in seconds, microseconds), or to the current time with the default 0 value
// for unix_start_time.
set_start_time :: proc(log: ^Log, unix_start_time: i64 = 0, microseconds: i32 = 0) {
    if unix_start_time == 0 {
        start_sec: i64
        start_usec: i32
        rc: c.int = get_time_now_us(&start_sec, &start_usec)
        if rc != 0 {
            fmt.eprintf("LOG ERROR: init() call to FFI C function get_time_now_us() failed with return code %d\n", rc)
            start_sec = 0
            start_usec = 0
        }
        log.unix_start_time = start_sec
        log.start_time_microseconds = start_usec
    } else {
        log.unix_start_time = unix_start_time
        log.start_time_microseconds = microseconds
    }
}


@(private)
console_clear_previous_message :: proc(log: ^Log) {
    line_count := strings.count(log.prev_console_message, "\n")
    seq := "\033[F\033[K" // cursor up + clear line
    for _ in 0..<line_count {
        os2.write_string(log.console, seq)
        os2.flush(log.console) // flush for immediate effect
    }
}


@(private)
get_formatted_messages :: proc(
    log:                   ^Log,
    msg:                   string,
    create_console_output: bool,
    create_logfile_output: bool,
    num_indents:           u8,
    newline_start:         bool,
    newline_end:           bool,
    draw:                  bool,
    end:                   string,
) -> (
    formatted_console_msg: string, // pointer to string printed to console
    formatted_logfile_msg: string, // pointer to string printed to console
    ok: bool,                      // success flag
) {

    // Validate user input arguments
    if num_indents < 0 || num_indents > log.max_indents {
        fmt.eprintln("LOG ERROR: num indents, i, must be between 0 and log.max_indents of %d (inclusive), or log.max_indents must be increased in its initialization", log.max_indents)
        return "", "", false
    }

    // Prepend info buffers and variables
    p: strings.Builder // p = prepended info text
    p0: strings.Builder // p0 = mini indents: If info is prepended to each line, mini indents are tiny indents before the prepended info. They exist so VS Code's code folding feature continues to work when there's prepended info, and the prepended info remains veritically alligned.
    strings.builder_init(&p, context.temp_allocator)
    strings.builder_init(&p0, context.temp_allocator)
    defer strings.builder_destroy(&p)
    defer strings.builder_destroy(&p0)
    div_mark: rune = '-'
    mini_indent: rune = ' '
    prepend_stuff: bool = log.prepend_datetime_fmt != "" || log.prepend_elapsed_time || log.prepend_memory_usage
    if prepend_stuff {

        // Create prepended info strings
        for _ in 0..<num_indents do strings.write_rune(&p0, mini_indent)
        remaining_indents := log.max_indents + 1 - num_indents
        for _ in 0..<remaining_indents do strings.write_rune(&p, mini_indent)

        // Prepend datetime in specified format
        if log.prepend_datetime_fmt != "" {
            datetime_str, ok := get_formatted_current_time(
                log.timezone,
                log.prepend_datetime_fmt
            )
            if !ok {
                fmt.eprintln("LOG ERROR: failed to get current time for prepending")
                datetime_str = "LOG ERROR: failed to get current time"
            }
            // fmt.println("datetime_str:", datetime_str)
            strings.write_string(&p, datetime_str)
            strings.write_string(&p, "  ")
        }

        // Prepend elapsed time since log's start time in HH:MM:SS.ffffff format
        if log.prepend_elapsed_time {
            elapsed_time_str, ok := get_formatted_elapsed_time(log)
            if !ok {
                fmt.eprintln("LOG ERROR: failed to get elapsed time for prepending")
                elapsed_time_str = "LOG ERROR: failed to get elapsed time"
            }
            // fmt.println("elapsed_time_str:", elapsed_time_str)
            if log.prepend_datetime_fmt != "" {
                strings.write_rune(&p, div_mark)
                strings.write_string(&p, "  ")
            }
            strings.write_string(&p, elapsed_time_str)
            strings.write_string(&p, "  ")
        }

        // Prepend memory usage
        if log.prepend_memory_usage {
            // Example using global stats; you can implement a function to get actual memory usage if you want
            mem_usage_str, ok := get_process_memory_usage()
            if !ok {
                fmt.eprintln("LOG ERROR: failed to get memory usage for prepending")
                mem_usage_str = "LOG ERROR failed to get memory usage"
            }
            // fmt.println("mem_usage_str:", mem_usage_str)
            if log.prepend_datetime_fmt != "" || log.prepend_elapsed_time {
                strings.write_rune(&p, div_mark)
                strings.write_string(&p, "  ")
            }
            strings.write_string(&p, fmt.tprintf("%17s", mem_usage_str))
        }

        strings.write_rune(&p, div_mark)
        strings.write_string(&p, "  ")
    }
    // blank_p is the same as p but w/ prepend info removed, only marks remain
    blank_info := strings.repeat(" ",
        (prepend_stuff ? strings.builder_len(p) - 3 : 0),
        context.temp_allocator)
    blank_p := fmt.tprintf("%s%r%s%r  ", strings.to_string(p0), div_mark, blank_info, div_mark)
    // fmt.tprintf uses the temp allocator and can be used since p is local to this procedure
    // source: https://pkg.odin-lang.org/core/fmt/#tprintf
    
    // Build the final formatted message
    Output_Target :: struct {
        location:      string, // "console" or "logfile"
        indent:        string,
        create_output: bool,
    }
    targets := [2]Output_Target {
        { "console", log.console_indent, create_console_output },
        { "logfile", log.logfile_indent, create_logfile_output },
    }
    formatted_console_msg = "" // default - empty string if output_to_console = false
    formatted_logfile_msg = "" // default - empty string if output_to_logfile = false
    total_indent1, total_indent2, total_indent3: string
    for target in targets {
        if !target.create_output do continue

        fm: strings.Builder // formatted message
        strings.builder_init(&fm, context.temp_allocator)
        defer strings.builder_destroy(&fm)
        total_indent1 = strings.repeat(target.indent, int(num_indents))
        total_indent2 = strings.repeat(target.indent, int(num_indents) + 1)
        total_indent3 = draw ? total_indent2 : total_indent1

        if newline_start {
            if prepend_stuff do strings.write_string(&fm, blank_p)
            strings.write_string(&fm, total_indent3)
            strings.write_rune(&fm, '\n')
        }

        lines := strings.split(msg, "\n", context.temp_allocator)
        for line, idx in lines {
            empty_line := line == ""
            if prepend_stuff {
                if empty_line {
                    strings.write_string(&fm, blank_p)
                } else {
                    strings.write_string(&fm, strings.to_string(p0))
                    strings.write_rune(&fm, div_mark)
                    strings.write_string(&fm, strings.to_string(p))
                }
            }
            strings.write_string(&fm, empty_line ? total_indent3 : total_indent1)
            strings.write_string(&fm, line)
            strings.write_string(&fm, end)
        }

        if newline_end {
            if prepend_stuff do strings.write_string(&fm, blank_p)
            strings.write_string(&fm, total_indent3)
            strings.write_rune(&fm, '\n')
        }

        switch target.location {
            case "console":
                formatted_console_msg = strings.clone(strings.to_string(fm))
            case "logfile":
                formatted_logfile_msg = strings.clone(strings.to_string(fm))
        }
    }

    return formatted_console_msg, formatted_logfile_msg, true
}


// Used C bindings for get_formatted_current_time() and get_formatted_elapsed_time() because I failed to get the local time in odin, only UTC. Also setting the timezone seems to require the UTC offset, which gets complicated because of daylights saving time. Also I couldn't find a way to format it via a user provided format string. see odin time package docs: https://pkg.odin-lang.org/core/time
// binding odin to c: https://odin-lang.org/news/binding-to-c/
when ODIN_OS == .Windows do foreign import current_time_info "./../c/current_time_info.lib" // path relative to this files parent dir
when ODIN_OS == .Linux   do foreign import current_time_info "./../c/current_time_info.a"
when ODIN_OS == .Darwin  do foreign import current_time_info "./../c/current_time_info.a"
foreign current_time_info {

    get_time_now_us :: proc(
        unix_seconds: ^c.int64_t,
        microseconds: ^c.int32_t,
    ) -> c.int ---

    format_time_us :: proc(
        unix_seconds: c.int64_t,
        microseconds: c.int32_t,
        timezone: cstring,
        format: cstring,
        out: cstring,
        out_cap: c.size_t,
    ) -> c.int ---

    elapsed_us_since :: proc(
        start_sec: c.int64_t,
        start_usec: c.int32_t,
        out_sec: ^c.int32_t,
        out_usec: ^c.int32_t,
    ) -> c.int ---

    format_elapsed_us :: proc(
        elapsed_sec: c.int32_t,
        elapsed_usec: c.int32_t,
        out: cstring,
        out_cap: c.size_t,
    ) -> c.int ---
}


/* get_formatted_current_time() returns the current datetime as a formatted string

    - timezone: "local" or "UTC", defaults to UTC
    - format:   format to display datetime in
                based on strftime. available formats: https://man7.org/linux/man-pages/man3/strftime.3.html
                i added %f format for microseconds like python has: https://strftime.org/

    Returns: the formatted datetime string (or empty on error) */
@(private)
get_formatted_current_time :: proc(
    timezone:    string,
    format:      string,
    buffer_size: int = 128,
) -> (
    string,
    bool,
) {

    // get current time in seconds + microseconds
    unix_sec: i64
    micro_sec: i32
    rc: c.int = get_time_now_us(&unix_sec, &micro_sec)
    if rc != 0 {
        fmt.eprintf("LOG ERROR: get_formatted_current_time() call to FFI C function get_time_now_us() failed with return code %d\n", rc)
        return "", false
    }

    // allocate empty cstring of buffer_size
    buffer, err := mem.alloc(buffer_size)
    if err != nil {
        fmt.eprintf("LOG ERROR: datetime cstring allocation failed: %v\n", err)
        return "", false
    }
    datetime_cstr := cstring(buffer)
    defer mem.free(buffer)

    // format the time string
    rc = format_time_us(
        unix_sec,
        micro_sec,
        cstring(raw_data(timezone)),
        cstring(raw_data(format)),
        datetime_cstr,
        c.size_t(buffer_size)
    )
    if rc != 0 {
        fmt.eprintf("LOG ERROR: get_formatted_current_time() call to FFI C function format_time_us() failed with return code %d\n", rc)
        return "", false
    }

    return string(datetime_cstr), true
}


/* get_formatted_elapsed_time returns the elapsed time since the log's start time

    Returns: formatted string "HH:MM:SS.ffffff" and success flag */
@(private)
get_formatted_elapsed_time :: proc(
    log: ^Log,
    buffer_size: int = 32,
) -> (
    string,
    bool
) {
    if log == nil do return "", false

    elapsed_sec:  i32 // elapsed seconds since log.start_sec
    elapsed_usec: i32 // elapsed microseconds since log.start_usec

    // compute elapsed time since start_sec/start_usec
    rc: c.int = elapsed_us_since(
        log.unix_start_time,
        log.start_time_microseconds,
        &elapsed_sec,
        &elapsed_usec
    )
    if rc != 0 {
        fmt.eprintf("LOG ERROR: get_formatted_elapsed_time() call to FFI C function elapsed_us_since() failed with return code %d\n", rc)
        return "", false
    }

    // allocate empty cstring of buffer_size
    buffer, err := mem.alloc(buffer_size)
    if err != nil {
        fmt.eprintf("LOG ERROR: elapsed time cstring allocation failed: %v\n", err)
        return "", false
    }
    elapsed_time_cstr := cstring(buffer)
    defer mem.free(buffer)

    // format elapsed time as HH:MM:SS.ffffff
    rc = format_elapsed_us(
        elapsed_sec,
        elapsed_usec,
        elapsed_time_cstr,
        c.size_t(buffer_size),
    )
    if rc != 0 {
        fmt.eprintf("LOG ERROR: get_formatted_elapsed_time() call to FFI C function format_elapsed_us() failed with return code %d\n", rc)
        return "", false
    }

    return string(elapsed_time_cstr), true
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


@(private)
set_prepend_datetime_fmt_and_timezone :: proc(
    log: ^Log,
    new_prepend_datetime_fmt: string,
    new_timezone: string,
) {
    // fix weird timezone bug in C:
    // replace "%Z" with hardcoded "UTC" if
    // "%Z" substring in prepend_datetime_fmt and timezone = "UTC"

    // Set/update timezone
    log.timezone = new_timezone

    // Remember old value so we can delete it safely later
    old_fmt := log.prepend_datetime_fmt
    defer delete(old_fmt)

    // Handle %Z -> "UTC" replacement
    if strings.contains(new_prepend_datetime_fmt, "%Z") && log.timezone == "UTC" {
        new_fmt, allocated := strings.replace_all(new_prepend_datetime_fmt, "%Z", "UTC")
        // https://pkg.odin-lang.org/core/strings/#replace_all
        // https://pkg.odin-lang.org/core/strings/#replace <-- more info in docs for replace

        // Set the final version (new_fmt owns the memory if allocated)
        if allocated {
            log.prepend_datetime_fmt = new_fmt
        } else {
            log.prepend_datetime_fmt = strings.clone(new_fmt)
        }
    } else {
        log.prepend_datetime_fmt = strings.clone(new_prepend_datetime_fmt)
    }
}


