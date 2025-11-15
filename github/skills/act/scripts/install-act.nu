#!/usr/bin/env nu

# Install act (GitHub Actions local testing tool)
# Tries mise first, then falls back to platform-specific methods

def main [] {
  print "Installing act..."

  # Try mise first
  if (which mise | is-not-empty) {
    print "✓ Installing act via mise..."
    mise install act
    print "✓ act installed successfully via mise"
    verify-installation
    return
  }

  # Fallback to platform-specific installation
  print "mise not found, using platform-specific installation..."

  let os = (sys host | get name)

  if $os == "Darwin" {
    install-macos
  } else if $os == "Linux" {
    install-linux
  } else if $os == "Windows" {
    install-windows
  } else {
    print $"✗ Unsupported operating system: ($os)"
    print "Please install act manually: https://github.com/nektos/act#installation"
    exit 1
  }

  verify-installation
}

def install-macos [] {
  if (which brew | is-not-empty) {
    print "✓ Installing act via Homebrew..."
    brew install act
    print "✓ act installed successfully via Homebrew"
  } else {
    print "✗ Homebrew not found"
    print "Please install Homebrew first: https://brew.sh"
    print "Or install act manually: https://github.com/nektos/act#installation"
    exit 1
  }
}

def install-linux [] {
  print "✓ Installing act via install script..."

  try {
    curl -s https://raw.githubusercontent.com/nektos/act/master/install.sh | bash
    print "✓ act installed successfully"
  } catch {
    print "✗ Installation failed"
    print "Please install act manually: https://github.com/nektos/act#installation"
    exit 1
  }
}

def install-windows [] {
  if (which choco | is-not-empty) {
    print "✓ Installing act via Chocolatey..."
    choco install act-cli -y
    print "✓ act installed successfully via Chocolatey"
  } else {
    print "✗ Chocolatey not found"
    print "Please install Chocolatey first: https://chocolatey.org/install"
    print "Or install act manually: https://github.com/nektos/act#installation"
    exit 1
  }
}

def verify-installation [] {
  if (which act | is-not-empty) {
    print ""
    print "act version:"
    act --version
  } else {
    print "✗ act installation failed - command not found"
    exit 1
  }
}
