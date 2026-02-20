package full_example

import logging_util "../src/odin"

import "core:fmt"
import "core:time"
import "core:os/os2"
import "base:runtime"
import "core:path/filepath"
import "core:encoding/json"
import "core:thread"

// global variable so you don't need to pass it to each function using it
log: ^logging_util.Log
f := logging_util.f // convenience procedure for string formatting
LOGGING_ENABLED :: true // toggle logging entirely for ALL log structs

project_root_dir: string


main :: proc() {
    set_project_root_dir()

    // init any non default log settings
    // see src/logging_util.odin's Log struct for all settings
    log = logging_util.init(
        enabled=LOGGING_ENABLED,
        output_to_logfile = true,
        filepath = filepath.join({ project_root_dir, "log", "full_example_log.txt" }),
        clear_old_log = true,
        output_to_console = true,
    )
    // close the log to free memory at the end of the scope
    defer {
        logging_util.close(log, verbose=true, i=0, ns=true)
        fmt.println("log closed\n")
    }

    test_print();
    test_print_json();
    test_overwrite_prev_msg(_i=1);
    test_thread_safety(_i=1);

}

set_project_root_dir :: proc() {
    exe_path, err := os2.get_executable_path(runtime.heap_allocator())
    if err != os2.ERROR_NONE {
        fmt.eprintf("Failed to get exe path: %v\n", err)
        return
    }
    exe_path = filepath.clean(exe_path)
    exe_dir  := filepath.dir(exe_path)
    project_root_dir = filepath.dir(exe_dir)
    // fmt.printf("exe_path:         %s\n", exe_path)
    // fmt.printf("exe_dir:          %s\n", exe_dir)
    fmt.printf("\nproject_root_dir: %s\n\n", project_root_dir)
}

test_print :: proc() {
    log->print("\ntest_print():")

    // test num_indents and multi line indentation
    log->print("a", i=0)
    log->print("b", i=1)
    log->print("c", i=2)
    log->print("d", i=3)
    log->print("e", i=4)
    log->print("indented\nmulti\nline\nstring", i=5)

    // test formatted string
    log->print(f("formatted string: %d %r %s", 7, 'f', "hellooo"), i=1);

    // test new line start
    log->print("new line start = true, draw line = false", i=1, ns=true)
    log->print("new line start = true, draw line = true", i=1, ns=true, d=true)
    log->print("new line start = false", i=1, ns=false)

    // test new line end
    log->print("new line end = true, draw line = false", i=1, ne=true)
    log->print("new line end = true, draw line = true", i=1, ne=true, d=true)
    log->print("new line end = false", i=1, ne=false)

    // test return values
    console_msg, logfile_msg: string
    log->print("test print return value", i=2, console_msg=&console_msg, logfile_msg=&logfile_msg, oc=false, of=false)
    fmt.print(console_msg); // if theres indents, it was preserved
    fmt.print(logfile_msg);
    delete(console_msg);
    delete(logfile_msg);
    log->print("test multiline\nprint return\nvalue", i=3, console_msg=&console_msg, logfile_msg=&logfile_msg, oc=false, of=false);
    fmt.print(console_msg); // if theres indents, it was preserved
    fmt.print(logfile_msg);
    delete(console_msg);
    delete(logfile_msg);

    // test prepend datetime
    /* datetime formats are based on strftime:
            https://man7.org/linux/man-pages/man3/strftime.3.html
            plus %f format for microseconds like in python:
            https://strftime.org/
    */
    log2 := logging_util.init(
        enabled=LOGGING_ENABLED,
        output_to_console=true,
        output_to_logfile=false,
        prepend_datetime_fmt="%y-%m-%d %H:%M:%S.%f %Z", // available formats: https://www.tutorialspoint.com/c_standard_library/c_function_strftime.htm
    )
    log2->print("testing single line prepend_datetime_fmt", ns=true)
    log2->print("testing\nmulti\nline\nprepend_datetime_fmt", i=1)
    log2->print("testing single line indented prepend_datetime_fmt", i=2)
    logging_util.close(log2)

    // test prepend memory usage
    log3 := logging_util.init(
        enabled=LOGGING_ENABLED,
        output_to_console=true,
        output_to_logfile=false,
        prepend_memory_usage=true,
    )
    log3->print("testing single line prepend_memory_usage", ns=true)
    log3->print("testing\nmulti\nline\nprepend_memory_usage", i=1)
    log3->print("testing single line indented prepend_memory_usage", i=2)
    logging_util.close(log3)

    // test prepend elapsed time since log start time
    log4 := logging_util.init(
        enabled=LOGGING_ENABLED,
        output_to_console=true,
        output_to_logfile=false,
        prepend_elapsed_time=true,
    )
    log4->print("testing single line prepend_elapsed_time", ns=true)
    log4->print("testing\nmulti\nline\nprepend_elapsed_time", i=1)
    log4->print("testing single line indented prepend_elapsed_time", i=2)
    log4->set_start_time()
    log4->print("testing reset start time", i=1)
    logging_util.close(log4)

    // test prepend all info
    log5 := logging_util.init(
        enabled=LOGGING_ENABLED,
        output_to_console=true,
        output_to_logfile=false,
        prepend_datetime_fmt="%y-%m-%d %H:%M:%S.%f %Z",
        // timezone="local",
        timezone="UTC",
        prepend_elapsed_time=true,
        prepend_memory_usage=true,
    )
    log5->print("testing single line prepend all info", ns=true)
    log5->print("testing\nmulti\nline\nprepend\nall\ninfo", i=1)
    log5->print("testing single line indented prepend all info", i=2)
    logging_util.close(log5)

}

test_print_json :: proc() {
    log->print("\ntest_print_json():")

    // Create example struct instance
    User :: struct {
        username:   string,
        settings_theme: string,
        send_email_notifications: bool,
        emails: []string,
    }
    u := User{
        username = "Username1234",
        settings_theme = "dark",
        send_email_notifications = true,
        emails = {"first.last@gmail.com", "embarrasing.highschool.email.address@yahoo.com"},
    }

    // Convert struct to JSON string
    // sources:
    // https://pkg.odin-lang.org/core/encoding/json/#marshal
    // https://pkg.odin-lang.org/core/encoding/json/#Marshal_Options
    json_bytes, err := json.marshal(u, { pretty=true, use_spaces=true, spaces=4 })
    if err != nil {
        fmt.eprintf("Failed to marshal (aka convert) JSON to string: %v\n", err)
        return
    }
    json_str := string(json_bytes)

    // log it
    log->print("created json string:", i=1)
    log->print(json_str, i=2)

    // create json file
    json_filepath := filepath.join({ project_root_dir, "examples", "example.json" })
    flags: os2.File_Flags = { .Write, .Create, .Trunc }
    // open(): https://pkg.odin-lang.org/core/os/#open
    // flags: https://pkg.odin-lang.org/core/os/#File_Flag
    // permissions: https://pkg.odin-lang.org/core/os/#Permissions_Default_File
    f, e := os2.open(json_filepath, flags, os2.Permissions_Default_File)
    if e != nil {
        fmt.eprintf("Failed to create json file: %v\n", e)
        return
    }
    
    // write to json file
    // https://pkg.odin-lang.org/core/os/#write_string
    _, e = os2.write_string(f, json_str)
    if e != nil {
        fmt.eprintf("Failed to write to json file: %v\n", e)
        return
    }

    // Clean up heap-allocated bytes
    delete(json_bytes)
    json_bytes = nil
    // don't delete json_str, its a shallow copy of json_bytes

    // read from json file
    // https://pkg.odin-lang.org/core/os/#read_entire_file_from_path
    json_bytes2, e2 := os2.read_entire_file_from_path(
        json_filepath,
        context.allocator, // use default heap
    )
    if e2 != nil {
        fmt.eprintf("Failed to read from json file: %v\n", e)
        return
    }
    json_str2 := string(json_bytes2)

    // log it again
    log->print("wrote json string to file, deleted it, and read it back in:", i=1)
    log->print(json_str2, i=2)
    delete(json_bytes2)
    json_bytes2 = nil

}

test_overwrite_prev_msg :: proc(_i:u8=0) {
	log->print("\ntest_overwrite_prev_msg():", i=_i-1)

	sleep_time := time.Millisecond * 500

	// new text has more lines
	log->print("a", i=_i)
	if LOGGING_ENABLED do time.sleep(sleep_time)
	log->print("b\nb", i=_i, overwrite_prev_msg=true)
	if LOGGING_ENABLED do time.sleep(sleep_time)
	log->print("c\nc\nc", i=_i, overwrite_prev_msg=true)
	if LOGGING_ENABLED do time.sleep(sleep_time)
	log->print("", i=0, overwrite_prev_msg=true)
	if LOGGING_ENABLED do time.sleep(sleep_time)

	// new text has less lines
	log->print("a\na\na", i=_i, overwrite_prev_msg=true)
	if LOGGING_ENABLED do time.sleep(sleep_time)
	log->print("b\nb", i=_i, overwrite_prev_msg=true)
	if LOGGING_ENABLED do time.sleep(sleep_time)
	log->print("c", i=_i, overwrite_prev_msg=true)
	if LOGGING_ENABLED do time.sleep(sleep_time)
	log->print("", i=0, end="", overwrite_prev_msg=true)
	if LOGGING_ENABLED do time.sleep(sleep_time)

	// new text has shorter lines
	log->print("aaa", i=_i, overwrite_prev_msg=true)
	if LOGGING_ENABLED do time.sleep(sleep_time)
	log->print("bb", i=_i, overwrite_prev_msg=true)
	if LOGGING_ENABLED do time.sleep(sleep_time)
	log->print("c", i=_i, overwrite_prev_msg=true)
	if LOGGING_ENABLED do time.sleep(sleep_time)
	log->print("", i=0, overwrite_prev_msg=true)
	if LOGGING_ENABLED do time.sleep(sleep_time)

	// new text has longer lines
	log->print("a", i=_i, overwrite_prev_msg=true)
	if LOGGING_ENABLED do time.sleep(sleep_time)
	log->print("bb", i=_i, overwrite_prev_msg=true)
	if LOGGING_ENABLED do time.sleep(sleep_time)
	log->print("ccc", i=_i, overwrite_prev_msg=true)
	if LOGGING_ENABLED do time.sleep(sleep_time)
	log->print("", i=_i-1, d=true, overwrite_prev_msg=true)
	if LOGGING_ENABLED do time.sleep(sleep_time)

	// verify regular log->print() works after overwrite_prev_msg
	log->print("a", i=_i)
	log->print("b", i=_i+1)
	log->print("c", i=_i+2)
	log->print("d", i=_i+3)
	log->print("e", i=_i+4)
	log->print("indented\nmulti\nline\nstring", i=_i+6)

	// verify overwrite_prev_msg works after regular log->print()
	log->print("test overwrite prev msg", i=_i, overwrite_prev_msg=true)
	if LOGGING_ENABLED do time.sleep(4*sleep_time)
	log->print("after regular print()", i=_i, overwrite_prev_msg=true)
	if LOGGING_ENABLED do time.sleep(4*sleep_time)
	log->print("", i=0, end="", overwrite_prev_msg=true)
	if LOGGING_ENABLED do time.sleep(2*sleep_time)

	log->print("test regular print() after overwrite_prev_msg", i=_i, ne=true)
	if LOGGING_ENABLED do time.sleep(4*sleep_time)

	log->print(f("log file with final test_overwrite_prev_msg output at:\n%s", log.filepath), i=_i)
	log->print(f("console indent  = \"%s\"", log.console_indent), i=_i+1)
	log->print(f("log file indent = \"%s\"", log.logfile_indent), i=_i+1, ne=true)
    if LOGGING_ENABLED do time.sleep(6*sleep_time)

}

// Global Variables
THREAD_COUNT :: 4
ITERATIONS   :: 20
Thread_Data :: struct {
    _i: u8, // pass log->print() optional args to thread if calling function wants to pass them down to the thread
    // add more fields if needed ...
}

thread_print_loop :: proc(t: ^thread.Thread) {

    // get thread data
    thread_id := t.user_index // use user_index to double as the thread id (0..3)
    _i := u8(uintptr(t.user_args[0])) // rawptr -> uintptr -> int -> u8
    thread_data := cast(^Thread_Data)t.user_args[1]
    _i = thread_data._i

    for i in 0..<ITERATIONS {
        log->print(f("thread %d iteration %d", thread_id, i), i=_i)
    }
}

test_thread_safety :: proc(_i: u8 = 0) -> (ok: bool) {
    log->print("thread_safety_test():", i=_i-1, ns=true)
    log.prepend_elapsed_time = true
    log.prepend_memory_usage = true
	sleep_time := time.Millisecond * 500
    if LOGGING_ENABLED do time.sleep(3*sleep_time)
    log->set_start_time()

    threads: [THREAD_COUNT]^thread.Thread

    // Create and start test threads
    for &t, i in threads {
        
        t = thread.create(thread_print_loop)

        // pass args to a thread with t.user_args
        t.user_args[0] = rawptr(uintptr(_i)) // u8 -> uintptr -> rawptr

        // you can also pass arbitrary data via a struct pointer to the thread with:
        // Option A: allocate on heap (if thread data must outlive creation)
        data := new(Thread_Data)
        data^ = Thread_Data{_i=_i}
        t.user_args[1] = data
        // Option B: stack / local (if thread starts immediately and you join later)
        // data: Thread_Data = {i}
        // t.user_args[1] = data // NOTE: &data must stay alive until thread finishes!

        if t == nil {
            fmt.eprintf("Failed to create thread %d\n", i)
            return false
        }
        t.user_index = i // pass thread id via user_index
        /*
            "user_index: int,
                // User-supplied array of arguments, that will be available to the thread,
                // once it is started. Should be set after the thread has been created,
                // but before it is started."

            - https://pkg.odin-lang.org/core/thread/
        */
        thread.start(t) // start immediately (non-blocking function)
    }

    // block the main thread and join the test threads
    // back into main thread when they're done
    for &t, idx in threads {
        thread.join(t)
        // Free the Thread_Data we allocated for this thread
        data := cast(^Thread_Data)t.user_args[1]
        if data != nil {
            free(data)
            t.user_args[1] = nil  // optional: clear pointer to avoid confusion
        }
        thread.destroy(t)
    }

    log->print(f("test passes if all %d x %d thread/iteration combinations were printed (order does\'t matter)", THREAD_COUNT, ITERATIONS), i=_i, ns=true)
	log->print(f("test complete, log file at:\n%s", log.filepath), i=_i-1, ne=true)
    return true
}
