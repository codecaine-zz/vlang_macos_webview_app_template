import ttytm.webview

fn quit_app(e &webview.Event) string {
	exit(0)
	return ''
}

fn main() {
	html := $embed_file('@DIR/index.html').to_string()

	mut w := webview.create(debug: true)
	w.bind('quitApp', quit_app)
	w.set_title('Fluid Galaxy Simulation')
	w.set_size(1200, 800, .@none)
	w.set_html(html)
	w.run()
}
