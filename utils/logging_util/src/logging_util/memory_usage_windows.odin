package logging_util

import win "core:sys/windows"

// This will only exist on Windows builds
get_os_specific_memory :: proc() -> (u64, bool) {
	pmc: win.PROCESS_MEMORY_COUNTERS
	pmc.cb = size_of(win.PROCESS_MEMORY_COUNTERS)
	handle := win.GetCurrentProcess()
	if win.K32GetProcessMemoryInfo(handle, &pmc, pmc.cb) {
		return u64(pmc.WorkingSetSize), true
	}
	return 0, false
}
