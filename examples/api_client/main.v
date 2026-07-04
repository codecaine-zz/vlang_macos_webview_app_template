import ttytm.webview { Event }
import net.http
import time

struct HttpResponse {
	status_code int
	status_msg  string
	headers     string
	body        string
	time_ms     i64
}

fn quit_app(e &Event) string {
	exit(0)
	return ''
}

fn send_request(e &Event) HttpResponse {
	url_raw := e.get_arg[string](0) or { '' }
	method_raw := e.get_arg[string](1) or { 'GET' }
	headers_raw := e.get_arg[string](2) or { '' }
	body_raw := e.get_arg[string](3) or { '' }

	mut url := url_raw.trim_space()
	if !url.starts_with('http://') && !url.starts_with('https://') {
		url = 'https://' + url
	}

	method := match method_raw.to_upper() {
		'POST' { http.Method.post }
		'PUT' { http.Method.put }
		'DELETE' { http.Method.delete }
		'PATCH' { http.Method.patch }
		else { http.Method.get }
	}

	mut req := http.Request{
		url: url
		method: method
		data: body_raw
	}

	// Parse custom headers
	header_lines := headers_raw.split_into_lines()
	for line in header_lines {
		parts := line.split(':')
		if parts.len >= 2 {
			key := parts[0].trim_space()
			val := parts[1..].join(':').trim_space()
			if key.len > 0 {
				req.add_custom_header(key, val) or { continue }
			}
		}
	}

	start_time := time.ticks()
	resp := req.do() or {
		return HttpResponse{
			status_code: 0
			status_msg: 'Request Failed'
			body: 'Error: Failed to perform HTTP request. Detail: ${err.msg()}'
			time_ms: time.ticks() - start_time
		}
	}
	end_time := time.ticks()

	return HttpResponse{
		status_code: resp.status_code
		status_msg: resp.status_msg
		headers: resp.header.str()
		body: resp.body
		time_ms: end_time - start_time
	}
}

fn main() {
	html := $embed_file('@DIR/index.html').to_string()

	mut w := webview.create(debug: true)
	w.bind('quitApp', quit_app)
	w.bind('sendRequest', send_request)

	w.set_title('API Client & Playground')
	w.set_size(1100, 750, .@none)
	w.set_html(html)
	w.run()
}
