#ifndef C_BINDINGS_H
#define C_BINDINGS_H

#include <stdint.h>  // Required for int64_t, int32_t
#include <stddef.h>  // Required for size_t

//////////////// current time functions ////////////////



/* get_current_unix_time() retrieves the current Unix time with microsecond precision
    - unix_seconds:  output pointer for seconds since Unix epoch (1970-01-01 00:00:00 UTC)
    - microseconds:  output pointer for microseconds component (0–999999)
*/
int get_current_unix_time(
    int64_t *unix_seconds,
    int32_t *microseconds
);


/* format_datetime_str() returns the current datetime as a formatted string (supports microsecond level resolution with "%f" format)
    - timezone: "local" or "UTC", defaults to UTC
    - format:   datetime formats are based on strftime:
            https://man7.org/linux/man-pages/man3/strftime.3.html
            plus %f format for microseconds like in python:
            https://strftime.org/
*/
int format_datetime_str(
    int64_t unix_seconds,
    int32_t microseconds,
    const char *timezone,
    const char *format,
    char *out,
    size_t datetime_str_capacity
);


/* get_elapsed_time() computes elapsed time between two timestamps with microsecond precision
    - start_sec / start_usec: starting time (seconds + microseconds)
    - end_sec / end_usec:     ending time (seconds + microseconds)
    - elapsed_sec:            output pointer for elapsed seconds
    - elapsed_usec:           output pointer for remaining microseconds (0–999999)
*/
int get_elapsed_time(
    int64_t start_sec,
    int32_t start_usec,
    int64_t end_sec,
    int32_t end_usec,
    int32_t *elapsed_sec,
    int32_t *elapsed_usec
);


/* format_elapsed_time() formats elapsed time as HH:MM:SS.ffffff
    - elapsed_sec:  elapsed seconds
    - elapsed_usec: elapsed microseconds
    - elapsed_time_str: output buffer for formatted string
    - elapsed_time_str_cap: capacity of output buffer
*/
int format_elapsed_time(
    int32_t elapsed_sec,
    int32_t elapsed_usec,
    char *elapsed_time_str,
    size_t elapsed_time_str_cap
);


//////////////// memory usage functions ////////////////

int get_process_memory_usage(char *buf, size_t buf_cap);

////////////////////////////////////////////////////////

#endif // C_BINDINGS_H

