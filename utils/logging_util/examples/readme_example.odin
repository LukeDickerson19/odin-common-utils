package readme_example

import "core:fmt"
import "logging_util" // Assuming your logic is in a folder/package named logging

// global variable so you don't need to pass it to each function using it
logger: ^logging_util.Log

main :: proc() {

    // init any non default log settings
	// see src/logging_util/logging_util.odin's Log struct for all settings
	logger = logging_util.init_log(
		output_to_logfile = true,
		filepath = "log.txt",
		clear_old_log = true,
		output_to_console = true,
		prepend_datetime_fmt = "%Y-%m-%d %H:%M:%S.%f %Z",
		timezone = "local",
		prepend_memory_usage = true,
	)
	// close the log to free memory at the end of the scope
	defer logging_util.close_log(logger)

    // log messages with different indent levels
	logger->print("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", i=0)
	logger->print("bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", i=1)
	logger->print("cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc", i=2)
	
	// // 2. Multiline string
	// logger.print("indented\nmulti\nline\nstring", {indent = 3})

	// // 3. Formatting (Replaces your FMT macro)
	// // tprintf uses a thread-local temporary buffer, very similar to your stack-allocated macro
	// logger.print(fmt.tprintf("formatted string: %d %c %s", 7, 'f', "hellooo"), {indent = 1})

	// // 4. New lines (ns/ne)
	// logger.print("new line before log message", {indent = 1, new_line_start = true})
	// logger.print("new line after log message",  {indent = 1, new_line_end = true})

	// // 5. Prepend Datetime
	// logger.prepend_datetime_fmt = "%Y-%m-%d %H:%M:%S.%f %Z"; // other available formats: https://www.tutorialspoint.com/c_standard_library/c_function_strftime.htm

	// logger.timezone = "local"
	// logger.print("multiline\nmessage\nwith\nprepend_datetime_fmt")

	// // 6. Prepend Memory Usage
	// logger.prepend_datetime_fmt = ""
	// logger.prepend_memory_usage = true
	// logger.print("multiline\nmessage\nwith\nprepend_memory_usage")

	// // 7. Mixing everything
	// logger.prepend_datetime_fmt = "%Y-%m-%d %H:%M:%S"
	// logger.print("message", {indent = 0})
	// logger.print("with",    {indent = 1})
	// logger.print("both",    {indent = 1})
	// logger.print("and",     {indent = 2})
	// logger.print("indents", {indent = 3})
}
