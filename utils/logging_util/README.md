# logging-util

#### DESCRIPTION

> Thread-safe logging util written in Odin (and C FFI) supporting hierarchical indentation for log messages — useful for navigating logs in editors that support code folding.
> 
> Features:
> - Arbitrary indentation levels per log call (via optional int argument)
> - Handles indentation for multi-line messages
> - Microsecond datetime, time elapsed, and memory-usage prefixes (vertically aligned without breaking indentation!)
> - Overwrite the previously printed log message (via optional bool argument)
> - Output to console, log file, or both
> - Thread-safety (using single global mutex)
> 
> Traditional log levels (INFO, ERROR, etc.) are currently not yet implemented.
> This util is a rewrite of a previous [C logging util](https://github.com/LukeDickerson19/c-common-utils/tree/master/utils/log_utils), and [Python logging util](https://github.com/LukeDickerson19/python-common-utils/tree/master/utils/logging).
> 
> Tested on:
> - Linux   (on Manjaro v25.0.10, x86_64 using gcc)
> - Windows (on Windows 11, x86_64 using MSVC)

#### USAGE
Below is a quick example usage - the examples/full_example.odin file shows how to use this util's features more thoroughly.
```
package readme_example

import "core:fmt"
import logging_util "../src/odin"

// global variable so you don't need to pass it to each function using it
log: ^logging_util.Log
f := logging_util.f // convenience procedure for string formatting
LOGGING_ENABLED :: true // toggle logging entirely for ALL log structs

main :: proc() {

    // init any non default log settings
	// see src/logging_util/logging_util.odin's Log struct for all settings
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
	log->print(f("formatted string: %d %c %s", 7, 'f', "hellooo"), i=1)
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

```

#### EXAMPLE OUTPUT
```
[luke@luke log]$ 
[luke@luke log]$ 
[luke@luke log]$ ./../build/readme_example 
a
|   b
|   |   c
|   |   |   indented
|   |   |   multi
|   |   |   line
|   |   |   string
|   formatted string: 7 f hellooo
|   
|   new line before log message
|   new line after log message
|   
|   new line after log message
|   
-           2026-02-19 17:11:54.873428 UTC  -  multiline
-           2026-02-19 17:11:54.873428 UTC  -  message
-           2026-02-19 17:11:54.873428 UTC  -  with
-           2026-02-19 17:11:54.873428 UTC  -  prepend_datetime_fmt
-               1.9766 MiB used  -  multiline
-               1.9766 MiB used  -  message
-               1.9766 MiB used  -  with
-               1.9766 MiB used  -  prepend_memory_usage
-           2026-02-19 17:11:54.886666 PST  -      2.2305 MiB used  -  message
 -          2026-02-19 17:11:54.893605 PST  -      2.2305 MiB used  -  |   with
 -          2026-02-19 17:11:54.900624 PST  -      2.2344 MiB used  -  |   both
  -         2026-02-19 17:11:54.907748 PST  -      2.2344 MiB used  -  |   |   and
   -        2026-02-19 17:11:54.914979 PST  -      2.2344 MiB used  -  |   |   |   indents
[luke@luke log]$ 
[luke@luke log]$ 
[luke@luke log]$ 
[luke@luke log]$ 

```
