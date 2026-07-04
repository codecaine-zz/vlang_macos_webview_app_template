import ttytm.webview { Event }
import os

struct SystemStats {
mut:
	cpu_user   f64
	cpu_sys    f64
	cpu_idle   f64
	mem_used   f64
	mem_unused f64
	disk_size  string
	disk_used  string
	disk_avail string
	disk_cap   string
	hostname   string
	uptime     string
}

struct ProcessInfo {
	pid  int
	cpu  f64
	mem  f64
	comm string
}

fn quit_app(e &Event) string {
	exit(0)
	return ''
}

// Binds system stats fetching
fn get_sys_info(_ &Event) SystemStats {
	mut stats := SystemStats{
		hostname: os.hostname() or { 'localhost' }
	}

	// 1. Uptime
	uptime_res := os.execute('uptime')
	if uptime_res.exit_code == 0 {
		stats.uptime = uptime_res.output.trim_space()
	}

	// 2. CPU and Memory via top
	top_res := os.execute('top -l 1 -n 0')
	if top_res.exit_code == 0 {
		lines := top_res.output.split_into_lines()
		for line in lines {
			trimmed := line.trim_space()
			if trimmed.starts_with('CPU usage:') {
				// Format: CPU usage: 3.12% user, 8.0% sys, 88.86% idle
				parts := trimmed.replace('CPU usage:', '').split(',')
				for part in parts {
					p := part.trim_space()
					if p.ends_with('user') {
						val := p.replace('% user', '').trim_space()
						stats.cpu_user = val.f64()
					} else if p.ends_with('sys') {
						val := p.replace('% sys', '').trim_space()
						stats.cpu_sys = val.f64()
					} else if p.ends_with('idle') {
						val := p.replace('% idle', '').trim_space()
						stats.cpu_idle = val.f64()
					}
				}
			} else if trimmed.starts_with('PhysMem:') {
				// Format: PhysMem: 33G used (2815M wired, 485M compressor), 14G unused.
				// Or: PhysMem: 33,5G used (2815M wired), 14,2G unused.
				mut clean_line := trimmed.replace('PhysMem:', '')
				for clean_line.contains('(') && clean_line.contains(')') {
					start_idx := clean_line.index('(') or { break }
					end_idx := clean_line.index(')') or { break }
					if start_idx < end_idx {
						clean_line = clean_line[0..start_idx] + clean_line[end_idx+1..]
					} else {
						break
					}
				}
				
				parts := clean_line.split(',')
				for part in parts {
					p := part.trim_space()
					if p.contains('unused') {
						val_str := p.replace('unused', '').trim_right('.').trim_space().replace(',', '.')
						mut val := val_str.replace('G', '').replace('M', '').f64()
						if val_str.contains('G') {
							val *= 1024
						}
						stats.mem_unused = val
					} else if p.contains('used') {
						val_str := p.replace('used', '').trim_space().replace(',', '.')
						mut val := val_str.replace('G', '').replace('M', '').f64()
						if val_str.contains('G') {
							val *= 1024
						}
						stats.mem_used = val
					}
				}
			}
		}
	}

	// 3. Disk Space via df -h
	df_res := os.execute('df -h /')
	if df_res.exit_code == 0 {
		lines := df_res.output.split_into_lines()
		if lines.len >= 2 {
			// Second line contains values
			fields := lines[1].split(' ').filter(it.trim_space().len > 0)
			if fields.len >= 5 {
				stats.disk_size = fields[1]
				stats.disk_used = fields[2]
				stats.disk_avail = fields[3]
				stats.disk_cap = fields[4]
			}
		}
	}

	return stats
}

// Binds top processes fetching
fn get_processes(_ &Event) []ProcessInfo {
	mut procs := []ProcessInfo{}
	// Run ps command to get top CPU processes
	ps_res := os.execute('ps -eo pid,pcpu,pmem,comm -r')
	if ps_res.exit_code == 0 {
		lines := ps_res.output.split_into_lines()
		// Skip header line
		for i := 1; i < lines.len; i++ {
			if procs.len >= 15 {
				break
			}
			line := lines[i].trim_space()
			if line.len == 0 {
				continue
			}
			fields := line.split(' ').filter(it.trim_space().len > 0)
			if fields.len >= 4 {
				pid := fields[0].int()
				cpu := fields[1].f64()
				mem := fields[2].f64()
				comm := fields[3..].join(' ')
				procs << ProcessInfo{
					pid: pid
					cpu: cpu
					mem: mem
					comm: comm
				}
			}
		}
	}
	return procs
}

// Binds ping capability
fn ping_host(e &Event) string {
	host := e.get_arg[string](0) or { '8.8.8.8' }
	
	// Sanitize input to prevent command injection
	mut clean_host := ''
	for c in host {
		if c.is_alnum() || c == `.` || c == `-` {
			clean_host += c.ascii_str()
		}
	}
	if clean_host == '' {
		return 'Invalid host'
	}

	ping_res := os.execute('ping -c 3 -t 3 ${clean_host}')
	if ping_res.exit_code == 0 {
		return ping_res.output
	}
	return 'Ping failed:\n' + ping_res.output
}

fn main() {
	html := $embed_file('@DIR/index.html').to_string()

	mut w := webview.create(debug: true)
	w.bind('quitApp', quit_app)
	w.bind('getSysInfo', get_sys_info)
	w.bind('getProcesses', get_processes)
	w.bind('pingHost', ping_host)

	w.set_title('System Monitor & Dashboard')
	w.set_size(1100, 750, .@none)
	w.set_html(html)
	w.run()
}
