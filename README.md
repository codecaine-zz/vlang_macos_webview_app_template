# V Webview macOS Packaging Template

A pure V template demonstrating how to build and package standalone, native macOS `.app` desktop applications with custom icons using [ttytm.webview](https://github.com/ttytm/webview).

This template features zero JavaScript runtime dependencies (like Bun or Node) for the packaging/build process. The build tool is written directly in V (`build.vsh`), leveraging macOS native tools (`sips` and `iconutil`).

## Features

- **Embed Frontend**: Keep your HTML/CSS/JS code in a separate `index.html` file, and embed it directly into the compiled V binary using V's `$embed_file`.
- **Pure V Builder**: A CLI tool (`build.vsh`) written in V to structure, compile, and package your V project into a fully styled macOS app bundle (`.app`).
- **101 Apple-Style Premium Icons**: A curated collection of futuristic glassmorphism app icons in the `resources/` folder, ready to be applied.

---

## Getting Started

### Prerequisites

Make sure you have:

1. The **V compiler** installed and added to your `PATH`.
2. The `ttytm.webview` library installed:
   ```bash
   v install ttytm.webview
   ```

### Running Locally (Development)

To run the webview application directly in development mode:

```bash
v run main.v
```

---

## Compiling & Packaging as a macOS App

To build and bundle the project into a native macOS app bundle, use the pure V builder script `build.vsh`.

### 1. Default Build

To compile `main.v` with release optimization (`-prod`) and bundle it as a macOS application using the default app name and the default wave app icon:

```bash
v run build.vsh
```

This compiles your V code and creates:

```
dist/Vlang Macos Webview App Template.app
```

### 2. Custom App Packaging

You can build the app with a custom name, a custom icon from the template suite, and a custom bundle ID:

```bash
v run build.vsh [entry_file.v] --name "My custom App" --icon resources/developer.png --identifier "com.example.myapp"
```

#### CLI Options:

- `-i, --icon <path>`: Path to a PNG icon. Defaults to `resources/icon.png` or `icon.png`.
- `-n, --name <name>`: Custom display name for the `.app` bundle.
- `-d, --identifier <id>`: CFBundleIdentifier (e.g., `com.example.myapp`).
- `-v, --version <version>`: App version (defaults to version in `v.mod`, or `1.0.0`).
- `-o, --out <dir>`: Output folder (defaults to `dist`).
- `-h, --help`: Show help message.

---

## Running the Built macOS App

Once built, you can run the application bundle by:

1. Double-clicking the `.app` bundle in Finder (located in the `dist/` directory).
2. Running it from your terminal:
   ```bash
   open "dist/Vlang Macos Webview App Template.app"
   ```

---

## 🧰 Additional Production-Ready Example Apps

The workspace now includes two new standard-library-based utilities that are more suited to day-to-day operations than the earlier demos:

- [examples/file_organizer](examples/file_organizer) for safely organizing files into category folders with dry-run support and collision-safe moves.
- [examples/log_analyzer](examples/log_analyzer) for parsing structured log lines, counting severity levels, and summarizing sources from a log file.

Both examples ship with tests and can be run directly with V from the repository root.

## 🎨 Premium Apple-Style Icon Templates

This project includes **101 premium, futuristic Apple-style glassmorphism icons** located in the [resources/](file:///Users/codecaine/vlang_macos_webview_app_template/resources) directory.

These icons feature a sleek chamfered titanium rim, dark obsidian frosted glass tile, and a neon radial background glow—ideal for matching the design language of Apple Vision Pro or macOS Sequoia.

### Examples of Building with Different Icons:

```bash
# Build an IDE app using the Developer icon
v run build.vsh --name "Code Studio" --icon resources/developer.png

# Build a database tool using the Database Admin icon
v run build.vsh --name "DB Browser" --icon resources/database_admin.png

# Build a task planner using the Kanban Board icon
v run build.vsh --name "Task Board" --icon resources/kanban_board.png
```

Check the [resources/](file:///Users/codecaine/vlang_macos_webview_app_template/resources) folder for the full catalog of available categories (e.g. `ai_chat.png`, `database.png`, `git_client.png`, `password_manager.png`, `terminal.png`, etc.).
