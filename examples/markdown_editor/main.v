import ttytm.webview { Event }
import os

struct FileItem {
	name   string
	path   string
	is_dir bool
	size   i64
}

fn quit_app(e &Event) string {
	exit(0)
	return ''
}

fn get_home_directory(_ &Event) string {
	return os.home_dir()
}

fn get_parent_directory(e &Event) string {
	path := e.get_arg[string](0) or { return os.home_dir() }
	// Return the directory component of path
	return os.dir(path)
}

fn list_directory(e &Event) []FileItem {
	path := e.get_arg[string](0) or { os.home_dir() }
	
	mut raw_items := os.ls(path) or { return []FileItem{} }
	
	mut dirs := []FileItem{}
	mut files := []FileItem{}
	
	for item in raw_items {
		// Ignore hidden files/dirs starting with dot to keep view clean
		if item.starts_with('.') && item != '.git' {
			continue
		}
		
		full_path := os.join_path(path, item)
		is_dir := os.is_dir(full_path)
		
		mut size := i64(0)
		if !is_dir {
			size = os.file_size(full_path)
		}
		
		f_item := FileItem{
			name: item
			path: full_path
			is_dir: is_dir
			size: size
		}
		
		if is_dir {
			dirs << f_item
		} else {
			// Only show text/md files for editing in this markdown app
			if item.ends_with('.md') || item.ends_with('.txt') || item.ends_with('.json') || item.ends_with('.html') || item.ends_with('.css') || item.ends_with('.js') || item.ends_with('.v') || item.ends_with('.vsh') {
				files << f_item
			}
		}
	}
	
	// Sort lists alphabetically
	dirs.sort(a.name.to_lower() < b.name.to_lower())
	files.sort(a.name.to_lower() < b.name.to_lower())
	
	mut sorted := []FileItem{}
	for d in dirs {
		sorted << d
	}
	for f in files {
		sorted << f
	}
	
	return sorted
}

fn read_local_file(e &Event) string {
	path := e.get_arg[string](0) or { return '' }
	content := os.read_file(path) or { return 'Error reading file: ${err.msg()}' }
	return content
}

fn write_local_file(e &Event) string {
	path := e.get_arg[string](0) or { return 'Error: No path provided' }
	content := e.get_arg[string](1) or { '' }
	os.write_file(path, content) or { return 'Error saving file: ${err.msg()}' }
	return 'Success'
}

fn main() {
	html := $embed_file('@DIR/index.html').to_string()

	mut w := webview.create(debug: true)
	w.bind('quitApp', quit_app)
	w.bind('getHomeDirectory', get_home_directory)
	w.bind('getParentDirectory', get_parent_directory)
	w.bind('listDirectory', list_directory)
	w.bind('readLocalFile', read_local_file)
	w.bind('writeLocalFile', write_local_file)

	w.set_title('Markdown Live Editor')
	w.set_size(1200, 800, .@none)
	w.set_html(html)
	w.run()
}
