#include <time.h>          // time_t, struct tm, time(), localtime_r(), gmtime_r(), strftime(), gettimeofday()
#include <stdio.h>         // fprintf(), snprintf()
#include <string.h>        // strcmp(), strstr(), memcpy(), strncat(), strlen()
#include <stdlib.h>        // malloc(), free(), setenv()
#include <stdint.h>        // int64_t, int32_t
#ifdef _WIN32
    #include <windows.h>   // FILETIME, GetSystemTimePreciseAsFileTime()
    #include <psapi.h> // for PROCESS_MEMORY_COUNTERS and GetProcessMemoryInfo
// #elif defined(__APPLE__)
//     #include <mach/mach.h>
// #elif defined(__linux__) || defined(__ANDROID__)
//     #include <unistd.h>
#else
    #include <sys/time.h>  // struct timeval, gettimeofday()
    #include <unistd.h>        // usleep()
#endif


//////////////// current time functions ////////////////

// get_time_now_us() gets the current unix time with microsecond precision
int get_time_now_us(
    int64_t *unix_seconds,
    int32_t *microseconds
) {
    if (!unix_seconds || !microseconds) return -1;

    #ifdef _WIN32
        FILETIME ft;
        ULARGE_INTEGER uli;
        GetSystemTimePreciseAsFileTime(&ft); // Windows 8+ (high precision)
        uli.LowPart  = ft.dwLowDateTime;
        uli.HighPart = ft.dwHighDateTime;
        uint64_t t100ns = uli.QuadPart; // 100ns since Jan 1, 1601. 100 ns ticks are the highest resolution windows provides
        uint64_t us = (t100ns - 116444736000000000ULL) / 10; // Convert to the unix epoch (seconds since 1970-01-01 00:00:00 UTC)
        *unix_seconds = (int64_t)(us / 1000000ULL);
        *microseconds = (int32_t)(us % 1000000ULL);
    #else
        struct timeval tv;
        if (gettimeofday(&tv, NULL) != 0) // gettimeofday() -> unix seconds since 1970 new years
            return -2;

        *unix_seconds = (int64_t)tv.tv_sec; 
        *microseconds = (int32_t)tv.tv_usec; 
    #endif

    return 0;
}

/* format_time_us() returns the current datetime as a formatted string (supports microsecond level resolution with "%f" format)
    - timezone: "local" or "UTC", defaults to UTC
    - format:   datettime formats are based on strftime:
            https://man7.org/linux/man-pages/man3/strftime.3.html
            plus %f format for microseconds like in python:
            https://strftime.org/
    */
int format_time_us(
    int64_t unix_seconds,
    int32_t microseconds,
    const char *timezone,   // "UTC" | "local"
    const char *format,
    char *out,
    size_t datetime_str_capacity
) {
    if (!format || !out) return -1;

    // get current datetime in local or UTC timezone
    struct tm tm_info;
    time_t sec = (time_t)unix_seconds;
    if (!timezone || strcmp(timezone, "UTC") == 0) {
        #ifdef _WIN32
            if (gmtime_s(&tm_info, &sec) != 0) return -2;
        #else
            if (!gmtime_r(&sec, &tm_info)) return -2;
        #endif
    } else if (strcmp(timezone, "local") == 0) {
        #ifdef _WIN32
            if (localtime_s(&tm_info, &sec) != 0) return -3;
        #else
            if (!localtime_r(&sec, &tm_info)) return -3;
        #endif
    } else {
        fprintf(stderr, "Invalid timezone: \"%s\", valid options: \"UTC\", \"local\"\n", timezone);
        return -4;
    }

    // format time into string with microsecond resolution
    const char *us_ptr = strstr(format, "%f");
    char *expanded_fmt = malloc(datetime_str_capacity);
    if (!expanded_fmt) return -5;
    if (!us_ptr) {
        snprintf(expanded_fmt, datetime_str_capacity, "%s", format);
    } else {
        // replace possible "%f" in string format with micro_seconds (b/c strftime can't handle microseconds)
        char us_str[7];
        snprintf(us_str, sizeof(us_str), "%06d", microseconds);
        size_t prefix_len = us_ptr - format;
        size_t suffix_len = strlen(us_ptr + 2); // skip "%f"
        size_t total_len  = prefix_len + 6 + suffix_len + 1;
        if (total_len > datetime_str_capacity) {
            free(expanded_fmt);
            return -6; // Buffer too small
        }
        memcpy(expanded_fmt, format, prefix_len); // Copy prefix
        memcpy(expanded_fmt + prefix_len, us_str, 6); // Insert zero padded micro seconds
        memcpy(expanded_fmt + prefix_len + 6, us_ptr + 2, suffix_len); // Copy suffix
        expanded_fmt[total_len - 1] = '\0'; // Null-terminate
    }
    strftime(out, datetime_str_capacity, expanded_fmt, &tm_info);
    free(expanded_fmt);
    return 0;
}

// Elapsed time since start (seconds and microseconds)
int elapsed_us_since(
    int64_t start_sec,
    int32_t start_usec,
    int32_t *out_sec,
    int32_t *out_usec
) {
    if (!out_sec || !out_usec) return -1;

    int64_t now_sec;
    int32_t now_usec;

    if (get_time_now_us(&now_sec, &now_usec) != 0)
        return -2;

    int32_t sec  = (int32_t)(now_sec - start_sec);
    int32_t usec = now_usec - start_usec;

    // handle microsecond underflow
    if (usec < 0) {
        usec += 1000000;
        sec  -= 1;
    }

    *out_sec  = sec;
    *out_usec = usec;
    return 0;
}

// Format elapsed time with format HH:MM:SS.ffffff
int format_elapsed_us(
    int32_t elapsed_sec,
    int32_t elapsed_usec,
    char *out,
    size_t out_cap
) {
    if (!out || out_cap < 16) return -1;
    if (elapsed_usec < 0 || elapsed_usec >= 1000000) return -2;

    int hours   =  elapsed_sec / 3600;
    int minutes = (elapsed_sec % 3600) / 60;
    int seconds =  elapsed_sec % 60;

    // formatted so HH can exceed 24 for long durations
    int n = snprintf(
        out,
        out_cap,
        "%02d:%02d:%02d.%06d",
        hours, minutes, seconds, elapsed_usec
    );

    // Size out of bounds
    if (n < 0 || (size_t)n >= out_cap) return -3;

    return 0;
}

/* TEST:
// build: gcc c_bindings.c -o test_current_time_info.o
// run:   ./test_current_time_info.o
int main(void) {

    // set start time for testing elapsed time
    int64_t start_sec;
    int32_t start_usec;
    if (get_time_now_us(&start_sec, &start_usec) != 0) {
        fprintf(stderr, "get_time_now_us failed\n");
        return 1;
    }

    // format current time
    const char *datetime_fmt = "%Y-%m-%d %H:%M:%S.%f %Z";
    const char *timezone = "UTC";
    // const char *timezone = "local";
    char datetime_str[128];
    if (format_time_us(
            start_sec,
            start_usec,
            timezone,
            datetime_fmt,
            datetime_str,
            sizeof(datetime_str)
        ) != 0) {
        fprintf(stderr, "format_time_us failed\n");
        return 1;
    }
    printf("Current time: %s\n", datetime_str);

    // simulate some work
    #ifdef _WIN32
        Sleep(1234); // milliseconds
    #else
        usleep(1234000); // microseconds
    #endif

    // compute elapsed time
    int32_t elapsed_sec;
    int32_t elapsed_usec;
    if (elapsed_us_since(
            start_sec,
            start_usec,
            &elapsed_sec,
            &elapsed_usec
        ) != 0) {
        fprintf(stderr, "elapsed_us_since failed\n");
        return 1;
    }

    // format elapsed duration
    char elapsed_str[32];
    if (format_elapsed_us(
            elapsed_sec,
            elapsed_usec,
            elapsed_str,
            sizeof(elapsed_str)
        ) != 0) {
        fprintf(stderr, "format_elapsed_us failed\n");
        return 1;
    }
    printf("Elapsed time: %s\n", elapsed_str);

    return 0;
}
*/


//////////////// memory usage functions ////////////////

int get_process_memory_usage(char *buf, size_t buf_cap) {
    if (!buf || buf_cap == 0)
        return -1;
    size_t bytes = 0;

    #if defined(_WIN32)
        PROCESS_MEMORY_COUNTERS pmc;
        if (!GetProcessMemoryInfo(GetCurrentProcess(), &pmc, sizeof(pmc)))
            goto fail;
        bytes = (size_t)pmc.WorkingSetSize;

    #elif defined(__APPLE__)
        mach_task_basic_info info;
        mach_msg_type_number_t count = MACH_TASK_BASIC_INFO_COUNT;
        if (task_info(
                mach_task_self(),
                MACH_TASK_BASIC_INFO,
                (task_info_t)&info,
                &count
            ) != KERN_SUCCESS)
            goto fail;
        bytes = (size_t)info.resident_size;

    #elif defined(__linux__) || defined(__ANDROID__)
        long rss_pages = 0;
        FILE *f = fopen("/proc/self/statm", "r");
        if (!f)
            goto fail;
        if (fscanf(f, "%*s %ld", &rss_pages) != 1) {
            fclose(f);
            goto fail;
        }
        fclose(f);
        long page_size = sysconf(_SC_PAGESIZE);
        if (page_size <= 0)
            goto fail;
        bytes = (size_t)rss_pages * (size_t)page_size;

    #else
        goto fail;

    #endif

    snprintf(buf, buf_cap, "%14s used  ", _get_memory_str(bytes));
    return 0;

    fail:
    snprintf(buf, buf_cap, "%s", "Memory read error  ");
    return -1;
}

char* get_memory_str(size_t bytes) {
    // converts the int number of bytes to a string with appropriate units
    static char buffer[64];
    const char* units[] = {"bytes", "KiB", "MiB", "GiB", "TiB", "PiB", "EiB", "ZiB", "YiB"};
    const int num_units = sizeof(units) / sizeof(units[0]);
    double b = (double)bytes;
    int index = 0;
    while (b >= 1024 && index < num_units - 1) {
        b /= 1024.0;
        index++;
    }
    if (index == 0) {
        if (bytes == 1) {
            snprintf(buffer, sizeof(buffer), "1 byte");
        } else {
            snprintf(buffer, sizeof(buffer), "%zu bytes", bytes);
        }
    } else {
        snprintf(buffer, sizeof(buffer), "%.4f %s", b, units[index]);
    }
    return buffer;
}

////////////////////////////////////////////////////////

///* TEST:
// build: gcc c_bindings.c -o test_memory_usage_info.o
// run:   ./test_memory_usage_info.o
int main(void) {
   char buf[64];

    // Initial memory usage
    if (get_process_memory_usage(buf, sizeof(buf)) == 0) {
        printf("Initial memory: %s\n", buf);
    } else {
        printf("Memory read error\n");
    }

    // Allocate some memory
    printf("Allocating 50 MB...\n");
    char *data = malloc(50 * 1024 * 1024);
    if (!data) {
        printf("Allocation failed\n");
        return 1;
    }
    memset(data, 0, 50 * 1024 * 1024); // touch memory so OS actually allocates

        // Memory usage after allocation
    if (get_process_memory_usage(buf, sizeof(buf)) == 0) {
        printf("After allocation: %s\n", buf);
    } else {
        printf("Memory read error\n");
    }

    // Free memory
    free(data);

    // Memory usage after free
    if (get_process_memory_usage(buf, sizeof(buf)) == 0) {
        printf("After free: %s\n", buf);
    } else {
        printf("Memory read error\n");
    }
}
//*/