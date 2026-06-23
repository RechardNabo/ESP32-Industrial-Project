#!/usr/bin/env python3
"""
embed_web_assets.py — Build modular web UI into PROGMEM header for ESP32.

Workflow:
  1. Concatenate src/js/*.js       → data/web/app.js
  2. Concatenate src/css/*.css      → data/web/style.css
  3. Assemble src/html/*.html       → data/web/index.html
  4. Read all files in data/web/    → web_ui_assets.h (PROGMEM C header)

Usage:
    python3 embed_web_assets.py [--build-only | --header-only] [data_dir] [output_header]

    --build-only    Only concatenate source files into data/web/ (skip header generation)
    --header-only   Only generate the header from existing data/web/ (skip concatenation)
    (default)       Do both: build then generate header

Source layout:
    data/web/src/js/     → JavaScript modules (concatenated in order)
    data/web/src/css/    → CSS modules (concatenated in order)
    data/web/src/html/   → HTML partials (assembled into full page)
"""

import os
import sys
import glob
import mimetypes

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DEFAULT_DATA_DIR = os.path.join(SCRIPT_DIR, "data", "web")
DEFAULT_SRC_DIR = os.path.join(SCRIPT_DIR, "data", "web", "src")
DEFAULT_OUTPUT = os.path.join(SCRIPT_DIR, "web_ui_assets.h")

# JS modules — load order matters
JS_MODULES = [
    "state.js",      # Global state variables (must be first)
    "utils.js",      # Utility functions
    "charts.js",     # Chart rendering
    "tabs.js",       # Tab switching
    "alive.js",      # Device alive detection
    "dashboard.js",  # Dashboard / Device Manager tab logic
    "config.js",     # Configuration tab logic
    "modbus.js",     # Modbus RTU/TCP protocol tab
    "bacnet.js",     # BACnet MS/TP protocol tab
    "snmp.js",       # SNMP protocol tab
    "matrix.js",     # Analysis Matrix tab logic
    "ota.js",        # OTA unlock/countdown logic
    "flash.js",      # Firmware upload logic
    "refresh.js",    # Data polling orchestration
    "init.js",       # Bootstrap and DOM ready (must be last)
]

# CSS modules — load order matters
CSS_MODULES = [
    "base.css",        # Reset, variables, global styles
    "layout.css",      # Header, nav, tabs, cards
    "dashboard.css",   # Dashboard grid and metrics
    "components.css",   # Badges, inputs, buttons, gauges, toast, etc.
]

# HTML partials — assembly order
HTML_PARTIALS = [
    "head.html",
    "header.html",
    "nav.html",
    "tab-dashboard.html",
    "tab-devicemanager.html",
    "tab-config.html",
    "tab-modbus.html",
    "tab-bacnet.html",
    "tab-snmp.html",
    "tab-matrix.html",
    "tab-charts.html",
    "tab-ota.html",
]

# MIME type overrides
MIME_OVERRIDES = {
    ".js": "application/javascript",
    ".css": "text/css",
    ".html": "text/html",
}

# ---------------------------------------------------------------------------
# Build: concatenate source modules into production files
# ---------------------------------------------------------------------------

def _section_comment(filename, ext):
    """Return a language-appropriate section comment for the file type."""
    if ext == ".css":
        return f"/* === {filename} === */"
    if ext == ".html":
        return f"<!-- === {filename} === -->"
    # JS and others — // comment is fine
    return f"// === {filename} ==="


def concat_files(src_dir, subdir, module_list, output_path, separator="\n"):
    """Concatenate a list of source files into a single output file."""
    ext = os.path.splitext(module_list[0])[1] if module_list else ""
    parts = []
    for filename in module_list:
        filepath = os.path.join(src_dir, subdir, filename)
        if not os.path.isfile(filepath):
            print(f"  WARNING: source file not found: {filepath}", file=sys.stderr)
            continue
        with open(filepath, "r", encoding="utf-8") as f:
            content = f.read().rstrip()
        # Add a file header comment for traceability (language-appropriate)
        header = _section_comment(filename, ext)
        parts.append(f"{header}\n{content}")

    combined = separator.join(parts) + "\n"
    with open(output_path, "w", encoding="utf-8") as f:
        f.write(combined)
    return len(combined)


def build_css(src_dir, output_dir):
    """Concatenate CSS modules into data/web/style.css."""
    output_path = os.path.join(output_dir, "style.css")
    size = concat_files(src_dir, "css", CSS_MODULES, output_path, separator="\n\n")
    print(f"  Built style.css: {size} bytes ({len(CSS_MODULES)} modules)")
    return size


def build_js(src_dir, output_dir):
    """Concatenate JS modules into data/web/app.js."""
    output_path = os.path.join(output_dir, "app.js")
    size = concat_files(src_dir, "js", JS_MODULES, output_path, separator="\n\n")
    print(f"  Built app.js: {size} bytes ({len(JS_MODULES)} modules)")
    return size


def build_html(src_dir, output_dir):
    """Assemble HTML partials into data/web/index.html."""
    parts = []
    for filename in HTML_PARTIALS:
        filepath = os.path.join(src_dir, "html", filename)
        if not os.path.isfile(filepath):
            print(f"  WARNING: partial not found: {filepath}", file=sys.stderr)
            continue
        with open(filepath, "r", encoding="utf-8") as f:
            content = f.read().strip()
        parts.append(content)

    # Assemble full HTML page
    head_content = parts[0] if len(parts) > 0 else ""
    body_parts = parts[1:] if len(parts) > 1 else []
    body_joined = "\n\n".join(body_parts)

    html = '<!DOCTYPE html>\n<html lang="en">\n<head>\n' + head_content + '\n</head>\n<body style="margin:0;padding:0">\n\n' + body_joined + '\n\n<script src="/app.js"></script>\n</body>\n</html>\n'
    output_path = os.path.join(output_dir, "index.html")
    with open(output_path, "w", encoding="utf-8") as f:
        f.write(html)
    print(f"  Built index.html: {len(html)} bytes ({len(HTML_PARTIALS)} partials)")
    return len(html)


def build_all(src_dir=None, data_dir=None):
    """Build all production files from source modules."""
    src_dir = src_dir or DEFAULT_SRC_DIR
    data_dir = data_dir or DEFAULT_DATA_DIR

    if not os.path.isdir(src_dir):
        print(f"Error: source directory not found: {src_dir}", file=sys.stderr)
        sys.exit(1)

    os.makedirs(data_dir, exist_ok=True)

    print("Building web assets from source modules...")
    total = 0
    total += build_js(src_dir, data_dir)
    total += build_css(src_dir, data_dir)
    total += build_html(src_dir, data_dir)
    print(f"  Total: {total} bytes")
    return total


# ---------------------------------------------------------------------------
# Header: generate PROGMEM C header from production files
# ---------------------------------------------------------------------------

def var_name(filename):
    """Convert filename to a C identifier (e.g., 'app.js' → 'app_js_HTML')."""
    base, ext = os.path.splitext(filename)
    return f"{base}_{ext[1:]}_HTML"


def delim_name(filename):
    """Short delimiter for C++ raw string literal."""
    short_map = {
        "app.js": "APPJS",
        "index.html": "IDXHTML",
        "style.css": "STYLECSS",
    }
    return short_map.get(filename, filename.replace(".", "_").replace("-", "_")[:12].upper())


def mime_type(filename):
    """Return the MIME type for a filename."""
    _, ext = os.path.splitext(filename)
    return MIME_OVERRIDES.get(ext, mimetypes.guess_type(filename)[0] or "application/octet-stream")


def generate_header(data_dir=None, output=None):
    """Generate web_ui_assets.h from the production files in data/web/."""
    data_dir = data_dir or DEFAULT_DATA_DIR
    output = output or DEFAULT_OUTPUT

    if not os.path.isdir(data_dir):
        print(f"Error: data directory not found: {data_dir}", file=sys.stderr)
        sys.exit(1)

    # Collect production files (only top-level web assets, skip dotfiles)
    files = sorted([
        f for f in os.listdir(data_dir)
        if os.path.isfile(os.path.join(data_dir, f)) and not f.startswith(".")
    ])

    if not files:
        print("Error: no files found in data directory", file=sys.stderr)
        sys.exit(1)

    # Read each file
    assets = []
    for filename in files:
        filepath = os.path.join(data_dir, filename)
        with open(filepath, "rb") as f:
            content = f.read()
        assets.append((filename, content))

    # Generate header
    lines = []
    lines.append("/**")
    lines.append(" * @file web_ui_assets.h")
    lines.append(" * @brief Auto-generated PROGMEM web assets for the ESP32 Device Manager UI.")
    lines.append(" *")
    lines.append(" * DO NOT EDIT — this file is generated by embed_web_assets.py.")
    lines.append(" * Re-run the script after modifying any file in data/web/src/.")
    lines.append(" *")
    lines.append(" * Source modules (data/web/src/):")
    for subdir in ["js", "css", "html"]:
        src_subdir = os.path.join(data_dir, "src", subdir)
        if os.path.isdir(src_subdir):
            for sf in sorted(os.listdir(src_subdir)):
                if os.path.isfile(os.path.join(src_subdir, sf)):
                    lines.append(f" *   src/{subdir}/{sf}")
    lines.append(" *")
    lines.append(" * Production files (data/web/):")
    for filename, content in assets:
        lines.append(f" *   {filename} ({len(content)} bytes)")
    lines.append(" */")
    lines.append("")
    lines.append("#ifndef WEB_UI_ASSETS_H")
    lines.append("#define WEB_UI_ASSETS_H")
    lines.append("")
    lines.append("#include <Arduino.h>")
    lines.append("")
    lines.append("// ============================================================================")
    lines.append("// PROGMEM content — each production file stored exactly once")
    lines.append("// ============================================================================")
    lines.append("")

    # Generate PROGMEM variables
    var_names = []
    for filename, content in assets:
        vname = var_name(filename)
        var_names.append(vname)
        text = content.decode("utf-8", errors="replace")
        delimiter = delim_name(filename)
        lines.append(f'static const char {vname}[] PROGMEM = R"{delimiter}({text}){delimiter}";')
        lines.append("")

    # Generate route table
    lines.append("// ============================================================================")
    lines.append("// Route table: URL path → PROGMEM content + MIME type")
    lines.append("// ============================================================================")
    lines.append("")
    lines.append("struct WebAsset {")
    lines.append("    const char* path;          // URL path to serve this asset at")
    lines.append("    const char* content_type;  // MIME type for Content-Type header")
    lines.append("    const char* html;          // PROGMEM raw string literal with the content")
    lines.append("    size_t length;             // Content length (for Content-Length header)")
    lines.append("};")
    lines.append("")
    lines.append(f"static const WebAsset WEB_ASSETS[] = {{")

    # index.html gets both / and /index.html routes
    for i, (filename, content) in enumerate(assets):
        if filename == "index.html":
            vname = var_names[i]
            mime = mime_type(filename)
            lines.append(f'    {{ "/", "{mime}", {vname}, sizeof({vname}) - 1 }},')
            lines.append(f'    {{ "/index.html", "{mime}", {vname}, sizeof({vname}) - 1 }},')
            break

    # All other files
    for i, (filename, content) in enumerate(assets):
        if filename == "index.html":
            continue
        vname = var_names[i]
        url = f"/{filename}"
        mime = mime_type(filename)
        lines.append(f'    {{ "{url}", "{mime}", {vname}, sizeof({vname}) - 1 }},')

    lines.append("};")
    lines.append("")

    total_routes = len(assets) + (1 if any(f == "index.html" for f, _ in assets) else 0)
    lines.append(f"static const size_t WEB_ASSETS_COUNT = {total_routes};")
    lines.append("")
    lines.append("#endif // WEB_UI_ASSETS_H")
    lines.append("")

    header_content = "\n".join(lines)

    with open(output, "w", encoding="utf-8") as f:
        f.write(header_content)

    print(f"Generated {output}")
    print(f"  Files: {', '.join(f for f, _ in assets)}")
    print(f"  Total PROGMEM size: {sum(len(c) for _, c in assets)} bytes")


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

def main():
    build = True
    header = True

    args = sys.argv[1:]
    filtered_args = []
    for arg in args:
        if arg == "--build-only":
            header = False
        elif arg == "--header-only":
            build = False
        else:
            filtered_args.append(arg)

    data_dir = filtered_args[0] if len(filtered_args) > 0 else DEFAULT_DATA_DIR
    output = filtered_args[1] if len(filtered_args) > 1 else DEFAULT_OUTPUT
    src_dir = os.path.join(data_dir, "src")

    if build:
        build_all(src_dir=src_dir, data_dir=data_dir)

    if header:
        generate_header(data_dir=data_dir, output=output)


if __name__ == "__main__":
    main()