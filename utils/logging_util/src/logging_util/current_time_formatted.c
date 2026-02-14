#include <time.h>          // time_t, struct tm, time(), localtime_r(), gmtime_r(), strftime(), gettimeofday()
#include <stdio.h>         // fprintf(), snprintf()
#include <string.h>        // strcmp(), strstr(), memcpy(), strncat(), strlen()
#include <stdlib.h>        // malloc(), free(), setenv()
#ifdef _WIN32
    #include <windows.h>   // FILETIME, GetSystemTimePreciseAsFileTime()
#else
    #include <sys/time.h>  // struct timeval, gettimeofday()
#endif

int get_current_time(const char* timezone, char *datetime_str, size_t datetime_str_capacity, char *format) {

    // get current time down to microsecond precision
    struct tm tm_info;
    time_t now;
    int micro_seconds;
    #ifdef _WIN32
        FILETIME ft;
        ULARGE_INTEGER uli;
        GetSystemTimePreciseAsFileTime(&ft); // Windows 8+ (high precision)
        uli.LowPart  = ft.dwLowDateTime;
        uli.HighPart = ft.dwHighDateTime;
        uint64_t t100ns = uli.QuadPart; // FILETIME = 100ns since Jan 1, 1601
        uint64_t us = (t100ns - 116444736000000000ULL) / 10; // Convert to Unix epoch
        now = (time_t)(us / 1000000);
        micro_seconds = (int)(us % 1000000);
    #else
        struct timeval tv;
        if (gettimeofday(&tv, NULL) != 0)
            return -2;
        now = tv.tv_sec;
        micro_seconds = tv.tv_usec;
    #endif

    // get current time in local or UTC timezone
    if (!timezone || strcmp(timezone, "UTC") == 0) {
        #ifdef _WIN32
            if (gmtime_s(&tm_info, &now) != 0) return -2;
        #else
            if (gmtime_r(&now, &tm_info) == NULL) return -2;
        #endif
    } else if (strcmp(timezone, "local") == 0) {
        #ifdef _WIN32
            if (localtime_s(&tm_info, &now) != 0) return -2;
        #else
            if (localtime_r(&now, &tm_info) == NULL) return -2;
        #endif
    } else {
        fprintf(stderr, "Invalid timezone: \"%s\", valid options: \"UTC\", \"local\"\n", timezone);
        return -3;
    }

    // format string of current time
    char *us_ptr = strstr(format, "%f");
    char *format2 = malloc(datetime_str_capacity);
    if (!format2) return -4;
    if (!us_ptr) {
        snprintf(format2, datetime_str_capacity, "%s", format);
    } else {
        // replace possible "%f" in string format with micro_seconds (b/c strftime can't handle microseconds)
        char us_str[7]; // 6 digits + null terminator
        snprintf(us_str, sizeof(us_str), "%06d", micro_seconds);
        size_t prefix_len = us_ptr - format;
        size_t suffix_len = strlen(us_ptr + 2); // skip "%f"
        size_t new_size = prefix_len + 6 + suffix_len + 1;
        if (new_size > datetime_str_capacity) return -4; // Buffer too small
        memcpy(format2, format, prefix_len); // Copy prefix
        memcpy(format2 + prefix_len, us_str, 6); // Insert zero padded micro seconds
        memcpy(format2 + prefix_len + 6, us_ptr + 2, suffix_len); // Copy suffix
        format2[new_size - 1] = '\0'; // Null-terminate
    }
    strftime(datetime_str, datetime_str_capacity, format2, &tm_info);
    free(format2);
    return 0;
}
/*
// TEST
// build: gcc current_time_formatted.c -o test_current_time_formatted
// run: ./test_current_time_formatted
int main() {
    char *prepend_datetime_fmt = "%Y-%m-%d %H:%M:%S.%f %Z";
    // char *timezone = "local";
    char *timezone = "UTC";
    char datetime_str[128];
    get_current_time(
        timezone,
        datetime_str,
        sizeof(datetime_str),
        prepend_datetime_fmt
    );
    printf("%s\n", datetime_str);
    return 0;
}
*/



