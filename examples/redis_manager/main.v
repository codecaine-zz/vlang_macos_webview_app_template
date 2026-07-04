import ttytm.webview { Event }
import xiusin.vredis
import json

struct KeyDetail {
	key   string @[json: 'key']
	value string @[json: 'value']
	@type string @[json: 'type']
	ttl   int    @[json: 'ttl']
}

fn quit_app(e &Event) string {
	exit(0)
	return ''
}

fn get_redis_client() !&vredis.Redis {
	return vredis.new_client(
		host: '127.0.0.1'
		port: 6379
		db: 0
	)!
}

fn web_check_connection(e &Event) string {
	mut client := get_redis_client() or {
		return '{"error": "Could not connect to Redis server on 127.0.0.1:6379"}'
	}
	defer { client.close() or {} }

	is_ok := client.ping() or { false }
	if is_ok {
		return '{"status": "connected"}'
	}
	return '{"error": "Ping failed. Redis server did not respond."}'
}

fn web_list_keys(e &Event) string {
	pattern := e.get_arg[string](0) or { '*' }
	
	mut client := get_redis_client() or {
		return '{"error": "Could not connect to Redis server on 127.0.0.1:6379"}'
	}
	defer { client.close() or {} }

	keys := client.keys(pattern) or {
		return '{"error": "Failed to retrieve keys from Redis"}'
	}

	return json.encode(keys)
}

fn web_get_key_detail(e &Event) string {
	key := e.get_arg[string](0) or { '' }
	if key == '' {
		return '{"error": "Key name is empty"}'
	}

	mut client := get_redis_client() or {
		return '{"error": "Could not connect to Redis server on 127.0.0.1:6379"}'
	}
	defer { client.close() or {} }

	t := client.@type(key) or { 'none' }
	ttl := client.ttl(key) or { -1 }

	mut val := ''
	if t == 'string' {
		val = client.get(key) or { '' }
	} else if t == 'none' {
		return '{"error": "Key does not exist"}'
	} else {
		val = '[Unsupported Type: ${t}]'
	}

	detail := KeyDetail{
		key:   key
		value: val
		@type: t
		ttl:   ttl
	}

	return json.encode(detail)
}

fn web_save_key(e &Event) string {
	key := e.get_arg[string](0) or { '' }
	val := e.get_arg[string](1) or { '' }
	ttl_str := e.get_arg[string](2) or { '-1' }
	ttl := ttl_str.int()

	if key.trim_space() == '' {
		return '{"error": "Key name cannot be empty"}'
	}

	mut client := get_redis_client() or {
		return '{"error": "Could not connect to Redis server on 127.0.0.1:6379"}'
	}
	defer { client.close() or {} }

	client.set(key, val) or {
		return '{"error": "Failed to set key value"}'
	}

	if ttl > 0 {
		client.expire(key, ttl) or {}
	} else if ttl == -1 {
		// Remove expiration (persist)
		client.persist(key) or {}
	}

	return '{"success": true}'
}

fn web_delete_key(e &Event) string {
	key := e.get_arg[string](0) or { '' }
	if key == '' {
		return '{"error": "Key name is empty"}'
	}

	mut client := get_redis_client() or {
		return '{"error": "Could not connect to Redis server on 127.0.0.1:6379"}'
	}
	defer { client.close() or {} }

	client.del(key) or {
		return '{"error": "Failed to delete key: ${err}"}'
	}

	return '{"success": true}'
}

fn main() {
	html := $embed_file('@DIR/index.html').to_string()

	mut w := webview.create(debug: true)
	w.bind('quitApp', quit_app)
	w.bind('checkConnection', web_check_connection)
	w.bind('listKeys', web_list_keys)
	w.bind('getKeyDetail', web_get_key_detail)
	w.bind('saveKey', web_save_key)
	w.bind('deleteKey', web_delete_key)

	w.set_title('Redis CRUD Manager')
	w.set_size(1000, 700, .@none)
	w.set_html(html)
	w.run()
}
