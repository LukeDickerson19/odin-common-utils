// package logging_util

// import win "core:sys/windows"

// // This will only exist on Windows builds
// get_os_specific_memory :: proc() -> (u64, bool) {
// 	pmc: win.PROCESS_MEMORY_COUNTERS
// 	pmc.cb = size_of(win.PROCESS_MEMORY_COUNTERS)
// 	handle := win.GetCurrentProcess()
// 	if win.K32GetProcessMemoryInfo(handle, &pmc, pmc.cb) {
// 		return u64(pmc.WorkingSetSize), true
// 	}
// 	return 0, false
// }

package logging_util

import win "core:sys/windows"

// --- manually declare missing types ---
PROCESS_MEMORY_COUNTERS :: struct {
    cb                : u32,
    PageFaultCount    : u32,
    PeakWorkingSetSize: usize,
    WorkingSetSize    : usize,
    QuotaPeakPagedPoolUsage : usize,
    QuotaPagedPoolUsage     : usize,
    QuotaPeakNonPagedPoolUsage: usize,
    QuotaNonPagedPoolUsage    : usize,
    PagefileUsage     : usize,
    PeakPagefileUsage : usize,
}

// --- file-scope foreign import ---
foreign import stdcall K32GetProcessMemoryInfo :: proc(
    Process: win.HANDLE,
    ppsmemCounters: ^PROCESS_MEMORY_COUNTERS,
    cb: win.DWORD,
) -> win.BOOL

// --- actual code ---
get_os_specific_memory :: proc() -> (u64, bool) {
    pmc: PROCESS_MEMORY_COUNTERS
    pmc.cb = size_of(PROCESS_MEMORY_COUNTERS)
    handle := win.GetCurrentProcess()
    if K32GetProcessMemoryInfo(handle, &pmc, pmc.cb) {
        return u64(pmc.WorkingSetSize), true
    }
    return 0, false
}
