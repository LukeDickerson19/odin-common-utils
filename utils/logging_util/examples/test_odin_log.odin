package main

import "core:os"
import "core:log"

foo :: proc() {
    log.debug("inside foo")
}

bar :: proc() {
    log.info("inside bar")
    foo()
}



main :: proc() {

    // Console logger (with colors)
    console_opts := log.Options{
        .Level,
        .Terminal_Color,
        .Short_File_Path,
        .Line,
        .Procedure,
    } | log.Full_Timestamp_Opts

    console_logger := log.create_console_logger(
        log.Level.Debug,
        console_opts,
    )

    // Delete the log file if it already exists
    filename := "odin_log.txt" // sudo chmod 777 odin_log.txt
    _ = os.remove(filename)  // ignore error if file doesn't exist

    // Open a log file
    file := os.open(
        filename,
        os.O_CREATE | os.O_WRONLY | os.O_TRUNC,
    ) or_else panic("failed to open log file")

    defer os.close(file)

    // File logger (no colors, same metadata)
    file_logger := log.create_file_logger(
        file,
        log.Level.Debug,
        log.Default_File_Logger_Opts,
    )

    // Combine them
    combined := log.create_multi_logger(
        console_logger,
        file_logger,
    )

    // Install globally
    context.logger = combined

    log.info("starting program")
    bar()
    log.warn("something looks off")
    log.error("something went wrong")
}