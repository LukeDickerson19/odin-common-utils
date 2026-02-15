package test_all_features

import "core:fmt"
import "core:time"
import "core:os"
import "core:path/filepath"

import logging_util "../src"


// global variable so you don't need to pass it to each function using it
log: ^logging_util.Log

// Build path relative to executable or working directory
project_root_dir: string



main :: proc() {
    set_project_root_dir()

    // init any non default log settings
    // see src/logging_util.odin's Log struct for all settings
    log = logging_util.init_log(
        output_to_logfile = true,
        filepath = filepath.join({ project_root_dir, "log", "log.txt" }),
        clear_old_log = true,
        output_to_console = true,
    )
    // close the log to free memory at the end of the scope
    defer logging_util.close_log(log)

    test_print();
    // test_print_json();
    // test_overwrite_prev_msg();

}

set_project_root_dir :: proc() {
    exe_path := os.args[0]  // First arg is executable path
    exe_dir := filepath.dir(exe_path)
    project_root_dir = filepath.dir(exe_dir)
    fmt.printf("project_root_dir: %s\n", project_root_dir)
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

    // test new line start
    log->print("new line start = true, draw line = false", i=1, ns=true)
    log->print("new line start = true, draw line = true", i=1, ns=true, d=true)
    log->print("new line start = false", i=1, ns=false)

    // test new line end
    log->print("new line end = true, draw line = false", i=1, ne=true)
    log->print("new line end = true, draw line = true", i=1, ne=true, d=true)
    log->print("new line end = false", i=1, ne=false)

    // // test return values
    // console_str, logfile_str: string
    // log->print("test print return value", i=2, console_str=&console_str, logfile_str=&logfile_str, oc=false, of=false);
    // fmt.println(console_str); // if theres indents, it was preserved
    // fmt.println(logfile_str);
    // free(console_str);
    // free(logfile_str);
    // log->print("test multiline\nprint return\nvalue", i=3, console_str=&console_str, logfile_str=&logfile_str, oc=false, of=false);
    // fmt.println(console_str); // if theres indents, it was preserved
    // fmt.println(logfile_str);
    // free(console_str);
    // free(logfile_str);

    // test prepend datetime
    log2 := logging_util.init_log(
        output_to_console=true,
        output_to_logfile=false,
        prepend_datetime_fmt="%y-%m-%d %H:%M:%S.%f %Z", // available formats: https://www.tutorialspoint.com/c_standard_library/c_function_strftime.htm
    )
    log2->print("testing single line prepend_datetime_fmt", ns=true)
    log2->print("testing\nmulti\nline\nprepend_datetime_fmt", i=1)
    log2->print("testing single line indented prepend_datetime_fmt", i=2)
    logging_util.close_log(log2)

    // test prepend memory usage
    log3 := logging_util.init_log(
        output_to_console=true,
        output_to_logfile=false,
        prepend_memory_usage=true,
    )
    log3->print("testing single line prepend_memory_usage", ns=true)
    log3->print("testing\nmulti\nline\nprepend_memory_usage", i=1)
    log3->print("testing single line indented prepend_memory_usage", i=2)
    logging_util.close_log(log3)

    // test both prepend datetime and memory usage
    log4 := logging_util.init_log(
        output_to_console=true,
        output_to_logfile=false,
        prepend_datetime_fmt="%y-%m-%d %H:%M:%S.%f %Z",
        prepend_memory_usage=true,
    )
    log4->print("testing single line prepend_datetime_fmt and prepend_memory_usage", ns=true)
    log4->print("testing\nmulti\nline\nprepend_datetime_fmt\nand\nprepend_memory_usage", i=1)
    log4->print("testing single line indented prepend_datetime_fmt and prepend_memory_usage", i=2)
    logging_util.close_log(log4)

}

test_print_json :: proc() {
    
}

test_overwrite_prev_msg :: proc() {

}


/*

def test_print_dct():
	log.print('\ntest_print_dct():')
	dct0 = {'a' : 1, 'b' : 2, 'c' : 3}
	log.print_dct(dct0, i=1, ne=true)


def test_overwrite_prev_print():
	log.print('\ntest_overwrite_prev_print():')

	sleep_time = 0.5 # seconds
	i = 1

	# new text has shorter lines
	log.print('aaaa', i=i, overwrite_prev_print=false)
	time.sleep(sleep_time)
	log.print('bbb', i=i, overwrite_prev_print=true)
	time.sleep(sleep_time)
	log.print('cc', i=i, overwrite_prev_print=true)
	time.sleep(sleep_time)
	log.print('d', i=i, overwrite_prev_print=true)
	time.sleep(sleep_time)
	log.print('', i=0, overwrite_prev_print=true)
	time.sleep(sleep_time)

	# new text has longer lines
	log.print('a', i=i, overwrite_prev_print=true)
	time.sleep(sleep_time)
	log.print('bb', i=i, overwrite_prev_print=true)
	time.sleep(sleep_time)
	log.print('ccc', i=i, overwrite_prev_print=true)
	time.sleep(sleep_time)
	log.print('dddd', i=i, overwrite_prev_print=true)
	time.sleep(sleep_time)
	log.print('', i=0, overwrite_prev_print=true)
	time.sleep(sleep_time)

	# new text has more lines
	log.print('a', i=i, overwrite_prev_print=true)
	time.sleep(sleep_time)
	log.print('b\nb', i=i, overwrite_prev_print=true)
	time.sleep(sleep_time)
	log.print('c\nc\nc', i=i, overwrite_prev_print=true)
	time.sleep(sleep_time)
	log.print('d\nd\nd\nd', i=i, overwrite_prev_print=true)
	time.sleep(sleep_time)
	log.print('', i=0, overwrite_prev_print=true)
	time.sleep(sleep_time)

	# new text has less lines
	log.print('a\na\na\na', i=i, overwrite_prev_print=true)
	time.sleep(sleep_time)
	log.print('b\nb\nb', i=i, overwrite_prev_print=true)
	time.sleep(sleep_time)
	log.print('c\nc', i=i, overwrite_prev_print=true)
	time.sleep(sleep_time)
	log.print('d', i=i, overwrite_prev_print=true)
	time.sleep(sleep_time)
	log.print('', i=0, end='', overwrite_prev_print=true)
	time.sleep(sleep_time)

	# verify regular log.print() works after overwrite_prev_print
	log.print('a', i=0)
	log.print('b', i=1)
	log.print('c', i=2)
	log.print('d', i=3)
	log.print('e', i=4)
	log.print('indented\nmulti\nline\nstring', i=5)

	# verify overwrite_prev_print works after regular log.print()
	log.print('test', i=i, overwrite_prev_print=true)
	time.sleep(3*sleep_time)
	log.print('overwrite_prev_print', i=i, overwrite_prev_print=true)
	time.sleep(3*sleep_time)
	log.print('after', i=i, overwrite_prev_print=true)
	time.sleep(3*sleep_time)
	log.print('regular print()', i=i, overwrite_prev_print=true)
	time.sleep(3*sleep_time)
	log.print('', i=0, end='', overwrite_prev_print=true)
	time.sleep(3*sleep_time)

	log.print('test regular print() after overwrite_prev_print', i=i, ne=true)


*/