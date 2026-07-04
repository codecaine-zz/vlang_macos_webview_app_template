import flag
import os

struct IconSize {
	name string
	size int
}

fn get_vmod_value(content string, key string) string {
	lines := content.split_into_lines()
	for line in lines {
		trimmed := line.trim_space()
		if trimmed.starts_with(key) {
			parts := trimmed.split(':')
			if parts.len >= 2 {
				val := parts[1].trim_space()
				return val.trim_left('\'"').trim_right('\',"')
			}
		}
	}
	return ''
}

fn format_app_name(raw string) string {
	mut result := []string{}
	mut cleaned := ''
	for c in raw {
		if c in [`-`, `_`, ` `] {
			cleaned += ' '
		} else {
			cleaned += c.ascii_str()
		}
	}
	for word in cleaned.split(' ') {
		if word.len > 0 {
			result << word[0..1].to_upper() + word[1..]
		}
	}
	return result.join(' ')
}

fn main() {
	mut fp := flag.new_flag_parser(os.args)
	fp.application('build')
	fp.version('1.0.0')
	fp.description('macOS App Bundle Builder for V Webview applications')
	fp.skip_executable()

	icon := fp.string('icon', `i`, '', 'Path to input PNG icon')
	name := fp.string('name', `n`, '', 'App display name')
	identifier := fp.string('identifier', `d`, '', 'Bundle identifier')
	app_version := fp.string('version', `v`, '', 'App version')
	out := fp.string('out', `o`, 'dist', 'Output folder')
	help := fp.bool('help', `h`, false, 'Show help message')

	additional_args := fp.finalize() or {
		println('Error: ${err}')
		println(fp.usage())
		return
	}

	if help {
		println(fp.usage())
		return
	}

	// 1. Resolve target entry file
	entry_file := if additional_args.len > 0 { additional_args[0] } else { 'main.v' }
	if !os.exists(entry_file) {
		eprintln('❌ Entry file not found: ${entry_file}')
		exit(1)
	}

	// 2. Read v.mod metadata
	vmod_content := os.read_file('v.mod') or { '' }
	pkg_name := get_vmod_value(vmod_content, 'name')
	pkg_version := get_vmod_value(vmod_content, 'version')

	// 3. Resolve App Name and Executable
	folder_name := os.base(os.getwd())
	mut raw_app_name := if name != '' {
		name
	} else if pkg_name != '' {
		pkg_name
	} else {
		folder_name
	}
	if raw_app_name == '' {
		raw_app_name = 'WebviewApp'
	}

	// Clean app name for executable (alphanumeric only)
	mut app_exe := ''
	for c in raw_app_name {
		if c.is_alnum() {
			app_exe += c.ascii_str()
		}
	}
	if app_exe == '' {
		app_exe = 'WebviewApp'
	}

	// Format display name
	app_display_name := format_app_name(raw_app_name)

	// 4. Resolve metadata values
	clean_id_name := app_exe.to_lower()
	bundle_id_val := if identifier != '' { identifier } else { 'com.webview.${clean_id_name}' }
	version_val := if app_version != '' {
		app_version
	} else if pkg_version != '' {
		pkg_version
	} else {
		'1.0.0'
	}
	out_folder := os.real_path(out)

	// 5. Resolve Icon Source
	mut icon_source := ''
	mut icon_search_paths := []string{}
	if icon != '' {
		icon_search_paths << os.real_path(icon)
	}
	icon_search_paths << os.join_path(os.getwd(), 'resources', 'icon.png')
	icon_search_paths << os.join_path(os.getwd(), 'icon.png')

	for path in icon_search_paths {
		if os.exists(path) {
			icon_source = path
			break
		}
	}

	if icon_source == '' {
		eprintln('❌ No icon source found! Please provide a PNG icon.')
		exit(1)
	}

	println('🚀 Starting macOS .app packaging...')
	println('  Entry point:   ${entry_file}')
	println('  App Name:      ${app_display_name}')
	println('  Executable:    ${app_exe}')
	println('  Bundle ID:     ${bundle_id_val}')
	println('  Version:       ${version_val}')
	println('  Icon Source:   ${icon_source}')
	println('  Output Path:   ${out_folder}')

	// 6. Setup directories
	app_dir := os.join_path(out_folder, '${app_display_name}.app')
	contents_dir := os.join_path(app_dir, 'Contents')
	macos_dir := os.join_path(contents_dir, 'MacOS')
	resources_dir := os.join_path(contents_dir, 'Resources')
	iconset_dir := os.join_path(out_folder, '${app_exe}_icon.iconset')

	if os.exists(app_dir) {
		println('🧹 Cleaning old app bundle at ${app_display_name}.app...')
		os.rmdir_all(app_dir) or {
			eprintln('❌ Failed to clean old app directory: ${err}')
			exit(1)
		}
	}

	os.mkdir_all(macos_dir) or {
		eprintln('❌ Failed to create MacOS folder: ${err}')
		exit(1)
	}
	os.mkdir_all(resources_dir) or {
		eprintln('❌ Failed to create Resources folder: ${err}')
		exit(1)
	}
	os.mkdir_all(iconset_dir) or {
		eprintln('❌ Failed to create temporary iconset folder: ${err}')
		exit(1)
	}

	// 7. Compile the V project into the MacOS folder
	println('📦 Compiling project into a standalone binary...')
	binary_path := os.join_path(macos_dir, app_exe)

	// Execute v compilation
	compile_cmd := 'v -prod -o ${os.quoted_path(binary_path)} ${os.quoted_path(entry_file)}'
	println('  Running: ${compile_cmd}')
	res := os.execute(compile_cmd)
	if res.exit_code != 0 {
		eprintln('❌ Compilation failed:')
		eprintln(res.output)
		exit(1)
	}

	// Ensure binary is executable
	os.execute('chmod +x ${os.quoted_path(binary_path)}')

	// 8. Generate macOS .icns file
	println('🎨 Processing and packaging the app icon...')
	icon_sizes := [
		IconSize{
			name: 'icon_16x16.png'
			size: 16
		},
		IconSize{
			name: 'icon_16x16@2x.png'
			size: 32
		},
		IconSize{
			name: 'icon_32x32.png'
			size: 32
		},
		IconSize{
			name: 'icon_32x32@2x.png'
			size: 64
		},
		IconSize{
			name: 'icon_128x128.png'
			size: 128
		},
		IconSize{
			name: 'icon_128x128@2x.png'
			size: 256
		},
		IconSize{
			name: 'icon_256x256.png'
			size: 256
		},
		IconSize{
			name: 'icon_256x256@2x.png'
			size: 512
		},
		IconSize{
			name: 'icon_512x512.png'
			size: 512
		},
		IconSize{
			name: 'icon_512x512@2x.png'
			size: 1024
		},
	]

	for icon_size in icon_sizes {
		out_path := os.join_path(iconset_dir, icon_size.name)
		sips_cmd := 'sips -s format png -z ${icon_size.size} ${icon_size.size} ${os.quoted_path(icon_source)} --out ${os.quoted_path(out_path)}'
		sips_res := os.execute(sips_cmd)
		if sips_res.exit_code != 0 {
			eprintln('❌ sips failed for size ${icon_size.size}: ${sips_res.output}')
			exit(1)
		}
	}

	icns_path := os.join_path(resources_dir, 'AppIcon.icns')
	iconutil_cmd := 'iconutil -c icns ${os.quoted_path(iconset_dir)} -o ${os.quoted_path(icns_path)}'
	iconutil_res := os.execute(iconutil_cmd)
	if iconutil_res.exit_code != 0 {
		eprintln('❌ iconutil failed: ${iconutil_res.output}')
		exit(1)
	}

	// Clean up temporary iconset
	println('🧹 Cleaning up temporary iconset...')
	os.rmdir_all(iconset_dir) or { eprintln('⚠️ Failed to clean up temporary iconset: ${err}') }

	// 9. Generate Info.plist
	println('📝 Generating Info.plist...')
	plist_content := '<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.txt">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>English</string>
    <key>CFBundleExecutable</key>
    <string>${app_exe}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>${bundle_id_val}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${app_display_name}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${version_val}</string>
    <key>CFBundleSignature</key>
    <string>\?\?\?\?</string>
    <key>CFBundleVersion</key>
    <string>${version_val}</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
'

	plist_path := os.join_path(contents_dir, 'Info.plist')
	os.write_file(plist_path, plist_content) or {
		eprintln('❌ Failed to write Info.plist: ${err}')
		exit(1)
	}

	println('🔐 Signing the app bundle for macOS...')
	sign_res := os.execute('codesign --force --deep --sign - ${os.quoted_path(app_dir)}')
	if sign_res.exit_code != 0 {
		eprintln('❌ codesign failed: ${sign_res.output}')
		exit(1)
	}

	clear_attr_res := os.execute('xattr -cr ${os.quoted_path(app_dir)}')
	if clear_attr_res.exit_code != 0 {
		eprintln('⚠️ Failed to clear quarantine attributes: ${clear_attr_res.output}')
	}

	println('\n🎉 Success! macOS app bundle built at: ${app_dir}')
}
