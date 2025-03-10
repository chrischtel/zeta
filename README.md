# Zeta

[![GitHub release (latest by date)](https://img.shields.io/github/v/release/chrischtel/zeta)](https://github.com/chrischtel/zeta/releases/latest)
[![License](https://img.shields.io/github/license/chrischtel/zeta)](LICENSE)
[![Build Status](https://img.shields.io/github/actions/workflow/status/chrischtel/zeta/build.yml?branch=main)](https://github.com/chrischtel/zeta/actions/workflows/build.yml)
[![GitHub stars](https://img.shields.io/github/stars/chrischtel/zeta?style=social)](https://github.com/chrischtel/zeta/stargazers)

**Zeta** is a modern, high-performance replacement for the traditional `ls` command with enhanced features, beautiful output formatting, and powerful filtering capabilities.

<p align="center">
  <img src="docs/assets/zeta-demo.gif" width="700" alt="Zeta in action">
</p>

## ✨ Latest Release

<table>
<tr>
<td>

### Zeta v0.0.0-alpha.8

**Released:** <!-- RELEASE_DATE -->2023-04-28<!-- /RELEASE_DATE -->

**Key Changes:**
<!-- LATEST_CHANGES -->
- Improved directory scanning performance by 35%
- Added ANSI color profile support
- Fixed file permission display on Windows
<!-- /LATEST_CHANGES -->

[Release Notes](https://github.com/chrischtel/zeta/releases/tag/v0.0.0-alpha.8) | [Installation](#installation) | [Download](https://github.com/chrischtel/zeta/releases/latest)

</td>
</tr>
</table>

## ⚠️ Breaking Changes

<!-- BREAKING_CHANGES -->
- **v0.0.0-alpha.7**: Changed configuration file format from TOML to JSON
- **v0.0.0-alpha.5**: Renamed `--time-format` flag to `--date-format`
- **v0.0.0-alpha.3**: Changed default output to minimalist mode
<!-- /BREAKING_CHANGES -->

## 🚀 Features

- **Modern Interface**: Beautiful, colorful display with icons for different file types
- **Smart Filtering**: Quickly find what you need with regex and glob pattern support
- **Sorting Options**: Sort by name, size, date modified, or custom attributes
- **Performance**: 5-10x faster than traditional `ls` for large directories
- **Customizable**: Extensive theming and format options
- **Git Integration**: Shows file status in Git repositories
- **Powerful Search**: Fast file content search with preview
- **Multi-Column Layout**: Optimized for modern terminal displays

## 📋 Feature Comparison

| Feature | Zeta | ls | dir | Find |
|---------|------|----|----|------|
| Color output | ✅ | ✅ | ❌ | ❌ |
| File icons | ✅ | ❌ | ❌ | ❌ |
| Git status | ✅ | ❌ | ❌ | ❌ |
| Sorting options | ✅ | ✅ | ✅ | ❌ |
| File previews | ✅ | ❌ | ❌ | ❌ |
| Performance on large dirs | ⚡ | 🐢 | 🐢 | 🐢 |
| Content search | ✅ | ❌ | ❌ | ✅ |
| Multi-threaded | ✅ | ❌ | ❌ | ❌ |

## 📦 Installation

### Using Package Managers

```bash
# Homebrew (macOS and Linux)
brew install chrischtel/tools/zeta

# Scoop (Windows)
scoop bucket add extras
scoop install zeta

# Winget (Windows)
winget install chrischtel.zeta

# Cargo (Rust)
cargo install zeta-ls
```

### Manual Installation

1. Download the [latest release](https://github.com/chrischtel/zeta/releases/latest) for your platform
2. Extract the archive
3. Add the binary to your PATH

### Build from Source

```bash
git clone https://github.com/chrischtel/zeta.git
cd zeta
zig build -Doptimize=ReleaseFast
```

## 🔧 Usage

### Basic Commands

```bash
# List files in current directory
zeta

# List files in specified directory
zeta /path/to/directory

# List with detailed information
zeta -l

# List including hidden files
zeta -a

# Sort by size (largest first)
zeta -S

# List recursively with a maximum depth
zeta -R --depth=3

# Display as a tree
zeta --tree
```

### Advanced Examples

```bash
# Find large files
zeta --sort=size --reverse --no-dirs

# Find recently modified files
zeta --sort=time --modified-after="2 days ago"

# Search for files containing text
zeta --find="TODO:"

# Export listing to JSON
zeta --json > files.json

# Show only specific file types
zeta --filter="*.{jpg,png,gif}"

# List with git status
zeta --git-status
```

### Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `j/k` | Navigate up/down |
| `h/l` | Navigate in/out of directories |
| `/` | Search within results |
| `s` | Change sort order |
| `f` | Filter results |
| `v` | Preview file |
| `q` | Quit interactive mode |

## ⚙️ Configuration

Zeta uses a configuration file located at:

- **Linux/macOS**: `~/.config/zeta/config.json`
- **Windows**: `%APPDATA%\zeta\config.json`

### Sample Configuration

```json
{
  "theme": {
    "directory": "blue bold",
    "executable": "green bold",
    "symlink": "cyan",
    "file": "default"
  },
  "display": {
    "showIcons": true,
    "showGitStatus": true,
    "layout": "grid",
    "dateFormat": "relative"
  },
  "behavior": {
    "sortBy": "name",
    "maxDepth": 5,
    "followSymlinks": false
  },
  "performance": {
    "cacheEnabled": true,
    "threads": "auto"
  }
}
```

## 📊 Performance

Benchmarks comparing Zeta with traditional tools (lower is better):

<p align="center">
  <img src="docs/assets/performance-chart.svg" width="600" alt="Performance Chart">
</p>

Testing methodology can be found in the [benchmarks directory](./benchmarks).

## 🧩 Integration

### Shell Integration

```bash
# Add to your ~/.bashrc or ~/.zshrc
alias ls="zeta"
alias ll="zeta -l"
alias la="zeta -a"
alias lt="zeta --tree"
```

### VS Code Integration

Install the [Zeta Integration](https://marketplace.visualstudio.com/items?itemName=chrischtel.zeta-vscode) extension for VS Code.

## 📚 Documentation

Full documentation is available at [https://zeta.docs.chrischtel.dev](https://zeta.docs.chrischtel.dev).

## 🛠️ Development

### Prerequisites

- Zig 0.12.0 or later
- Git
- C compiler (for some dependencies)

### Building

```bash
git clone https://github.com/chrischtel/zeta.git
cd zeta
zig build
```

### Testing

```bash
zig build test
```

### Release Process

New releases are published automatically when a tag is pushed:

```bash
git tag v0.1.0
git push origin v0.1.0
```

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📝 Changelog

<details>
<summary>Click to expand changelog</summary>

<!-- CHANGELOG -->
### v0.0.0-alpha.8 (2023-04-28)
- Improved directory scanning performance by 35%
- Added ANSI color profile support
- Fixed file permission display on Windows

### v0.0.0-alpha.7 (2023-04-27)
- Added multi-column layout
- Fixed crash on symbolic link loops
- Added file preview functionality

### v0.0.0-alpha.6 (2023-04-26)
- Initial public release
- Basic file listing functionality
- Color and icon support
<!-- /CHANGELOG -->

</details>

[Full Changelog](CHANGELOG.md)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 💖 Acknowledgements

- [ls-colors](https://github.com/sharkdp/lscolors) for color scheme inspiration
- [zig](https://ziglang.org/) for the amazing programming language
- All our [contributors](https://github.com/chrischtel/zeta/graphs/contributors)

---

<p align="center">
  Made with ❤️ by <a href="https://github.com/chrischtel">Chris</a>
</p>

<p align="center">
  <a href="https://github.com/chrischtel/zeta/stargazers">⭐ Star this project if you find it useful! ⭐</a>
</p>