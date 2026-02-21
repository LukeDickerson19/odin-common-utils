package readme_example

import "core:fmt"
import logging_util "../src/odin"

// global variable so you don't need to pass it to each function using it
log: ^logging_util.Log
LOGGING_ENABLED :: true // toggle logging entirely for ALL log structs

main :: proc() {

    // init any non default log settings
	// for all settings, see the Log struct in: src/odin/logging_util.odin
	log = logging_util.init(
		enabled=LOGGING_ENABLED,
		output_to_logfile = true,
		filepath = "readme_example_log.txt",
		clear_old_log = true,
		output_to_console = true,
	)
	// close the log to free memory at the end of the scope
	defer logging_util.close(log)

    // log messages with different indent levels
	log->print("a", i=0)
	log->print("b", i=1)
	log->print("c", i=2)
	log->print("indented\nmulti\nline\nstring", i=3)
	log->print("formatted string: %d %r %s", 7, 'f', "hellooo", i=1)
	log->print("new line before log message", i=1, ns=true) // ns = newline start
	log->print("new line after log message", i=1, ne=true) // ne = newline end
	log->print("new line after log message\n", i=1)

	// prepend datetime and memory usage
	log->set_prepend_datetime_fmt("%Y-%m-%d %H:%M:%S.%f %Z")
	/* datetime formats are based on strftime:
		https://man7.org/linux/man-pages/man3/strftime.3.html
		plus %f format for microseconds like in python:
		https://strftime.org/
    */
	log->set_timezone("local") // valid options: "UTC", "local"
	log->print("multiline\nmessage\nwith\nprepend_datetime_fmt")
	log->set_prepend_datetime_fmt("") // turn off prepending datetime
    log.prepend_memory_usage = true
	log->print("multiline\nmessage\nwith\nprepend_memory_usage")
	log->set_prepend_datetime_fmt("%Y-%m-%d %H:%M:%S.%f %Z")
	log->print("message", i=0);
	log->print("with", i=1);
	log->print("both", i=1);
	log->print("and", i=2);
	log->print("indents", i=3);

}
