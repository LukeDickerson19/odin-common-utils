package logging_util

import win "core:sys/windows"

enable_ansi :: proc() {
	handle := win.GetStdHandle(win.STD_OUTPUT_HANDLE)
	mode: win.DWORD
	if win.GetConsoleMode(handle, &mode) {
		// ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004
		win.SetConsoleMode(handle, mode | 0x0004)
	}
}
