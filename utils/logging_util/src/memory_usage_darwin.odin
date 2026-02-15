package logging_util

import "core:sys/unix"

// Raw Mach task info definitions since they aren't fully in core:sys/darwin yet
// These match the C headers for task_basic_info
TASK_BASIC_INFO :: 5
task_basic_info_data_t :: struct {
	suspend_count:  i32,
	virtual_size:   uint,
	resident_size:  uint, // This is what we want
	user_time:      [2]i32, // time_value_t
	system_time:    [2]i32, // time_value_t
	policy:         i32,
}

// macOS specific procedure
get_os_specific_memory :: proc() -> (u64, bool) {
	info: task_basic_info_data_t
	count := u32(size_of(info) / size_of(u32)) // count is in 32-bit words
	
	// mach_task_self() on macOS is always a specific constant (port 1)
	MACH_PORT_NULL :: 0
	mach_task_self :: 1 

	// Calling the system's task_info via unix syscall or linked lib
	// Using resident_size to match your C implementation
	err := unix.task_info(mach_task_self, TASK_BASIC_INFO, &info, &count)
	
	if err == 0 {
		return u64(info.resident_size), true
	}
	
	return 0, false
}
