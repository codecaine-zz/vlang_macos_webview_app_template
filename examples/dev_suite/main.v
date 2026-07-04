import ttytm.webview { Event }
import os
import json
import math

// Structs for JSON Store
struct TodoItem {
	id    int    @[json: 'id']
	title string @[json: 'title']
mut:
	done bool   @[json: 'done']
}

struct TodoStore {
mut:
	items []TodoItem @[json: 'items']
}

// Stats holds the computed statistical properties of a dataset.
struct Stats {
	count    int    @[json: 'count']
	min      f64    @[json: 'min']
	max      f64    @[json: 'max']
	sum      f64    @[json: 'sum']
	mean     f64    @[json: 'mean']
	median   f64    @[json: 'median']
	variance f64    @[json: 'variance']
	std_dev  f64    @[json: 'std_dev']
}

fn quit_app(e &Event) string {
	exit(0)
	return ''
}

// ==========================================
// STRING UTILITIES (Chapter 14)
// ==========================================

fn web_reverse_string(e &Event) string {
	s := e.get_arg[string](0) or { '' }
	runes := s.runes()
	mut rev_runes := []rune{cap: runes.len}
	for i := runes.len - 1; i >= 0; i-- {
		rev_runes << runes[i]
	}
	return rev_runes.string()
}

fn web_title_case(e &Event) string {
	s := e.get_arg[string](0) or { '' }
	words := s.split(' ')
	mut titled_words := []string{cap: words.len}
	for word in words {
		if word.len == 0 {
			titled_words << ''
			continue
		}
		titled_words << word.capitalize()
	}
	return titled_words.join(' ')
}

fn web_is_palindrome(e &Event) string {
	s := e.get_arg[string](0) or { '' }
	mut clean_chars := []rune{}
	for r in s.to_lower().runes() {
		if (r >= `a` && r <= `z`) || (r >= `0` && r <= `9`) {
			clean_chars << r
		}
	}

	for i in 0 .. clean_chars.len / 2 {
		if clean_chars[i] != clean_chars[clean_chars.len - 1 - i] {
			return 'false'
		}
	}
	return 'true'
}

fn web_truncate(e &Event) string {
	s := e.get_arg[string](0) or { '' }
	limit_str := e.get_arg[string](1) or { '20' }
	limit := limit_str.int()
	runes := s.runes()
	if runes.len <= limit {
		return s
	}
	return runes[0..limit].string() + '...'
}

fn web_slugify(e &Event) string {
	s := e.get_arg[string](0) or { '' }
	mut res := []rune{}
	mut last_was_dash := false

	for r in s.to_lower().runes() {
		if (r >= `a` && r <= `z`) || (r >= `0` && r <= `9`) {
			res << r
			last_was_dash = false
		} else if r == ` ` || r == `-` || r == `_` {
			if !last_was_dash && res.len > 0 {
				res << `-`
				last_was_dash = true
			}
		}
	}

	mut slug := res.string()
	if slug.ends_with('-') {
		slug = slug[0..slug.len - 1]
	}
	return slug
}

// ==========================================
// MATH & STATISTICS UTILITIES (Chapter 14)
// ==========================================

fn web_calculate_stats(e &Event) string {
	raw_str := e.get_arg[string](0) or { '' }
	parts := raw_str.split(',')
	mut numbers := []f64{}
	for p in parts {
		trimmed := p.trim_space()
		if trimmed.len > 0 {
			numbers << trimmed.f64()
		}
	}

	if numbers.len == 0 {
		return '{"error": "Empty dataset"}'
	}

	mut sum := 0.0
	mut min := numbers[0]
	mut max := numbers[0]

	for val in numbers {
		sum += val
		if val < min {
			min = val
		}
		if val > max {
			max = val
		}
	}

	mean := sum / numbers.len

	mut sorted := numbers.clone()
	sorted.sort()

	mut median := 0.0
	mid := sorted.len / 2
	if sorted.len % 2 == 0 {
		median = (sorted[mid - 1] + sorted[mid]) / 2.0
	} else {
		median = sorted[mid]
	}

	mut variance_sum := 0.0
	for val in numbers {
		diff := val - mean
		variance_sum += diff * diff
	}
	variance := variance_sum / numbers.len
	std_dev := math.sqrt(variance)

	stats := Stats{
		count:    numbers.len
		min:      min
		max:      max
		sum:      sum
		mean:     mean
		median:   median
		variance: variance
		std_dev:  std_dev
	}

	return json.encode(stats)
}

fn web_factorial(e &Event) string {
	n_str := e.get_arg[string](0) or { '0' }
	n := n_str.int()
	if n < 0 {
		return 'Error: Factorial is not defined for negative numbers.'
	}
	if n > 20 {
		return 'Error: Factorial of ${n} overflows 64-bit unsigned integer (max input is 20).'
	}
	mut result := u64(1)
	for i in 2 .. n + 1 {
		result *= u64(i)
	}
	return result.str()
}

fn web_fibonacci(e &Event) string {
	n_str := e.get_arg[string](0) or { '0' }
	n := n_str.int()
	if n < 0 {
		return 'Error: Count must be non-negative.'
	}
	if n > 93 {
		return 'Error: Fibonacci sequence beyond 93 overflows 64-bit integer limit.'
	}
	if n == 0 {
		return '[]'
	}
	if n == 1 {
		return '[0]'
	}
	mut sequence := []u64{cap: n}
	sequence << u64(0)
	sequence << u64(1)
	for i in 2 .. n {
		sequence << sequence[i - 1] + sequence[i - 2]
	}
	
	// Convert elements to strings to avoid potential overflow formatting in JS
	mut strs := []string{}
	for f in sequence {
		strs << f.str()
	}
	return json.encode(strs)
}

fn web_is_prime(e &Event) string {
	n_str := e.get_arg[string](0) or { '0' }
	n := n_str.int()
	if n <= 1 {
		return 'false'
	}
	if n <= 3 {
		return 'true'
	}
	if n % 2 == 0 || n % 3 == 0 {
		return 'false'
	}
	mut i := 5
	for i * i <= n {
		if n % i == 0 || n % (i + 2) == 0 {
			return 'false'
		}
		i += 6
	}
	return 'true'
}

fn web_gcd(e &Event) string {
	a_str := e.get_arg[string](0) or { '0' }
	b_str := e.get_arg[string](1) or { '0' }
	a := a_str.int()
	b := b_str.int()
	mut x := math.abs(a)
	mut y := math.abs(b)
	for y != 0 {
		temp := y
		y = x % y
		x = temp
	}
	return x.str()
}

fn web_lcm(e &Event) string {
	a_str := e.get_arg[string](0) or { '0' }
	b_str := e.get_arg[string](1) or { '0' }
	a := a_str.int()
	b := b_str.int()
	if a == 0 || b == 0 {
		return '0'
	}
	// Calculate GCD first
	mut x := math.abs(a)
	mut y := math.abs(b)
	for y != 0 {
		temp := y
		y = x % y
		x = temp
	}
	res := (math.abs(a) * math.abs(b)) / x
	return res.str()
}

// ==========================================
// JSON DATABASE FILE STORE (Chapter 14)
// ==========================================

fn get_db_path() string {
	// Persist todos.json inside same folder as the source code
	return os.join_path(os.dir(@FILE), 'dev_todos.json')
}

fn load_todos_from_disk() TodoStore {
	path := get_db_path()
	if !os.exists(path) {
		return TodoStore{}
	}
	raw := os.read_file(path) or { return TodoStore{} }
	return json.decode(TodoStore, raw) or { TodoStore{} }
}

fn save_todos_to_disk(store TodoStore) {
	path := get_db_path()
	data := json.encode(store)
	os.write_file(path, data) or {}
}

fn web_load_todos(_ &Event) string {
	store := load_todos_from_disk()
	return json.encode(store.items)
}

fn web_add_todo(e &Event) string {
	title := e.get_arg[string](0) or { '' }
	if title.trim_space() == '' {
		return web_load_todos(e)
	}

	mut store := load_todos_from_disk()
	
	// Resolve next ID
	mut max_id := 0
	for item in store.items {
		if item.id > max_id {
			max_id = item.id
		}
	}

	new_item := TodoItem{
		id:    max_id + 1
		title: title
		done:  false
	}
	store.items << new_item
	save_todos_to_disk(store)

	return json.encode(store.items)
}

fn web_toggle_todo(e &Event) string {
	id_str := e.get_arg[string](0) or { '0' }
	id := id_str.int()
	mut store := load_todos_from_disk()
	for i, item in store.items {
		if item.id == id {
			store.items[i].done = !item.done
			break
		}
	}
	save_todos_to_disk(store)
	return json.encode(store.items)
}

fn web_delete_todo(e &Event) string {
	id_str := e.get_arg[string](0) or { '0' }
	id := id_str.int()
	mut store := load_todos_from_disk()
	mut new_items := []TodoItem{}
	for item in store.items {
		if item.id != id {
			new_items << item
		}
	}
	store.items = new_items
	save_todos_to_disk(store)
	return json.encode(store.items)
}

fn main() {
	html := $embed_file('@DIR/index.html').to_string()

	mut w := webview.create(debug: true)
	w.bind('quitApp', quit_app)
	
	// Strings binds
	w.bind('reverseString', web_reverse_string)
	w.bind('titleCase', web_title_case)
	w.bind('isPalindrome', web_is_palindrome)
	w.bind('truncateText', web_truncate)
	w.bind('slugifyText', web_slugify)

	// Math binds
	w.bind('calculateStats', web_calculate_stats)
	w.bind('factorial', web_factorial)
	w.bind('fibonacci', web_fibonacci)
	w.bind('isPrime', web_is_prime)
	w.bind('gcd', web_gcd)
	w.bind('lcm', web_lcm)

	// Database binds
	w.bind('loadTodos', web_load_todos)
	w.bind('addTodo', web_add_todo)
	w.bind('toggleTodo', web_toggle_todo)
	w.bind('deleteTodo', web_delete_todo)

	w.set_title('Developer Utility Suite')
	w.set_size(1150, 780, .@none)
	w.set_html(html)
	w.run()
}
