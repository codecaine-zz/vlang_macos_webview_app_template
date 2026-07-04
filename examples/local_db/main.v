import ttytm.webview { Event }
import db.sqlite
import os
import json

// Structs for SQLite DB mapping
struct User {
	id    int    @[json: 'id']
	name  string @[json: 'name']
	email string @[json: 'email']
	age   int    @[json: 'age']
}

// Structs for JSON Store mapping
struct Product {
	id    int     @[json: 'id']
	name  string  @[json: 'name']
	price f64     @[json: 'price']
	stock int     @[json: 'stock']
}

struct ProductStore {
mut:
	products []Product @[json: 'products']
}

fn quit_app(e &Event) string {
	exit(0)
	return ''
}

// ==========================================
// SQLite Database Helpers
// ==========================================

fn get_sqlite_path() string {
	return os.join_path(os.dir(@FILE), 'users.db')
}

fn get_sqlite_db() !sqlite.DB {
	path := get_sqlite_path()
	mut db := sqlite.connect(path)!
	db.exec('CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, email TEXT UNIQUE, age INTEGER);') or {
		return error('Could not initialize users schema: ${err}')
	}
	return db
}

fn web_sqlite_get_users(e &Event) string {
	mut db := get_sqlite_db() or { return '{"error": "${err}"}' }
	defer { db.close() or {} }

	rows := db.exec('SELECT id, name, email, age FROM users ORDER BY id;') or {
		return '{"error": "Failed to fetch users: ${err}"}'
	}

	mut users := []User{}
	for row in rows {
		users << User{
			id:    row.vals[0].int()
			name:  row.vals[1]
			email: row.vals[2]
			age:   row.vals[3].int()
		}
	}
	return json.encode(users)
}

fn web_sqlite_add_user(e &Event) string {
	name := e.get_arg[string](0) or { '' }
	email := e.get_arg[string](1) or { '' }
	age_str := e.get_arg[string](2) or { '0' }
	age := age_str.int()

	if name.trim_space() == '' || email.trim_space() == '' {
		return '{"error": "Name and Email are required fields"}'
	}

	mut db := get_sqlite_db() or { return '{"error": "${err}"}' }
	defer { db.close() or {} }

	// Use parameterized inputs to protect against SQL injections (textbook lesson)
	db.exec_param_many('INSERT INTO users (name, email, age) VALUES (?, ?, ?);', [
		name,
		email,
		age.str(),
	]) or { return '{"error": "Insert failed: ${err}"}' }

	return web_sqlite_get_users(e)
}

fn web_sqlite_update_user(e &Event) string {
	id_str := e.get_arg[string](0) or { '0' }
	id := id_str.int()
	name := e.get_arg[string](1) or { '' }
	email := e.get_arg[string](2) or { '' }
	age_str := e.get_arg[string](3) or { '0' }
	age := age_str.int()

	if id <= 0 || name.trim_space() == '' || email.trim_space() == '' {
		return '{"error": "Invalid user parameters"}'
	}

	mut db := get_sqlite_db() or { return '{"error": "${err}"}' }
	defer { db.close() or {} }

	db.exec_param_many('UPDATE users SET name = ?, email = ?, age = ? WHERE id = ?;', [
		name,
		email,
		age.str(),
		id.str(),
	]) or { return '{"error": "Update failed: ${err}"}' }

	return web_sqlite_get_users(e)
}

fn web_sqlite_delete_user(e &Event) string {
	id_str := e.get_arg[string](0) or { '0' }
	id := id_str.int()
	if id <= 0 {
		return '{"error": "Invalid user ID"}'
	}

	mut db := get_sqlite_db() or { return '{"error": "${err}"}' }
	defer { db.close() or {} }

	db.exec_param_many('DELETE FROM users WHERE id = ?;', [id.str()]) or {
		return '{"error": "Delete failed: ${err}"}'
	}

	return web_sqlite_get_users(e)
}

// ==========================================
// JSON File Store Helpers
// ==========================================

fn get_json_path() string {
	return os.join_path(os.dir(@FILE), 'products.json')
}

fn load_products_store() ProductStore {
	path := get_json_path()
	if !os.exists(path) {
		return ProductStore{}
	}
	raw := os.read_file(path) or { return ProductStore{} }
	return json.decode(ProductStore, raw) or { ProductStore{} }
}

fn save_products_store(store ProductStore) {
	path := get_json_path()
	data := json.encode(store)
	os.write_file(path, data) or {}
}

fn web_json_get_products(e &Event) string {
	store := load_products_store()
	return json.encode(store.products)
}

fn web_json_add_product(e &Event) string {
	name := e.get_arg[string](0) or { '' }
	price_str := e.get_arg[string](1) or { '0.0' }
	price := price_str.f64()
	stock_str := e.get_arg[string](2) or { '0' }
	stock := stock_str.int()

	if name.trim_space() == '' {
		return '{"error": "Product name is required"}'
	}

	mut store := load_products_store()
	
	mut max_id := 0
	for p in store.products {
		if p.id > max_id {
			max_id = p.id
		}
	}

	new_product := Product{
		id:    max_id + 1
		name:  name
		price: price
		stock: stock
	}

	store.products << new_product
	save_products_store(store)

	return json.encode(store.products)
}

fn web_json_update_product(e &Event) string {
	id_str := e.get_arg[string](0) or { '0' }
	id := id_str.int()
	name := e.get_arg[string](1) or { '' }
	price_str := e.get_arg[string](2) or { '0.0' }
	price := price_str.f64()
	stock_str := e.get_arg[string](3) or { '0' }
	stock := stock_str.int()

	if id <= 0 || name.trim_space() == '' {
		return '{"error": "Invalid product parameters"}'
	}

	mut store := load_products_store()
	mut updated := false
	for i, p in store.products {
		if p.id == id {
			store.products[i] = Product{
				id:    id
				name:  name
				price: price
				stock: stock
			}
			updated = true
			break
		}
	}

	if !updated {
		return '{"error": "Product not found"}'
	}

	save_products_store(store)
	return json.encode(store.products)
}

fn web_json_delete_product(e &Event) string {
	id_str := e.get_arg[string](0) or { '0' }
	id := id_str.int()
	if id <= 0 {
		return '{"error": "Invalid product ID"}'
	}

	mut store := load_products_store()
	mut new_products := []Product{}
	for p in store.products {
		if p.id != id {
			new_products << p
		}
	}

	store.products = new_products
	save_products_store(store)

	return json.encode(store.products)
}

fn main() {
	html := $embed_file('@DIR/index.html').to_string()

	mut w := webview.create(debug: true)
	w.bind('quitApp', quit_app)
	
	// SQLite binds
	w.bind('sqliteGetUsers', web_sqlite_get_users)
	w.bind('sqliteAddUser', web_sqlite_add_user)
	w.bind('sqliteUpdateUser', web_sqlite_update_user)
	w.bind('sqliteDeleteUser', web_sqlite_delete_user)

	// JSON binds
	w.bind('jsonGetProducts', web_json_get_products)
	w.bind('jsonAddProduct', web_json_add_product)
	w.bind('jsonUpdateProduct', web_json_update_product)
	w.bind('jsonDeleteProduct', web_json_delete_product)

	w.set_title('Local DB Manager')
	w.set_size(1100, 750, .@none)
	w.set_html(html)
	w.run()
}
