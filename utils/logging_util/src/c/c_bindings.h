#ifndef C_BINDINGS_H
#define C_BINDINGS_H

// NOTE: This header is technically unnecessary for Odin code to call these
// C functions because Odin calls them by linking directly to the library.
// It would only be needed if C/C++ code wanted to call them.

#include <stdint.h>  // Required for int64_t, int32_t
#include <stddef.h>  // Required for size_t

//////////////// current time functions ////////////////

int get_time_now_us(int64_t *unix_seconds, int32_t *microseconds);

int format_time_us(int64_t unix_seconds, int32_t microseconds,
                   const char *timezone, const char *format,
                   char *out, size_t out_cap);

int elapsed_us_since(int64_t start_sec, int32_t start_usec,
                     int32_t *out_sec, int32_t *out_usec);

int format_elapsed_us(int32_t elapsed_sec, int32_t elapsed_usec,
                      char *out, size_t out_cap);

//////////////// memory usage functions ////////////////

int get_process_memory_usage(char *buf, size_t buf_cap);

char* get_memory_str(size_t bytes);

////////////////////////////////////////////////////////

#endif // C_BINDINGS_H

