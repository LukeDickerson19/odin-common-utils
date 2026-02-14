package logging_util

import "core:os"
import "core:strings"
import "core:strconv"

import "core:fmt"

get_os_specific_memory :: proc() -> (u64, bool) {

	// Read file into a buffer. Statm is tiny, so 1024 bytes is plenty.
	fd, err := os.open("/proc/self/statm")
	if err != os.ERROR_NONE do return 0, false
	defer os.close(fd)
	buf: [1024]byte
	n, read_err := os.read(fd, buf[:])
	if read_err != os.ERROR_NONE || n == 0 do return 0, false

	// Convert only the bytes we actually read to a string
	data_str := string(buf[:n])
	fields := strings.fields(data_str)	
	if len(fields) < 2 do return 0, false

	// Parse RSS (second field)
	val, ok := strconv.parse_int(fields[1])
	if !ok do return 0, false
	rss_pages := u64(val)
	page_size := u64(os.get_page_size())
	return rss_pages * page_size, true
}
