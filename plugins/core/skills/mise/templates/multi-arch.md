[tools."github:gastownhall/beads"]
version = "latest"

[tools."github:gastownhall/beads".platforms]
linux-x64 = { asset_pattern = "beads_*_linux_amd64.tar.gz" }
macos-arm64 = { asset_pattern = "beads_*_darwin_arm64.tar.gz" }

# Nushell - no platform-specific config needed (single binary)
[tools]
"github:nushell/nushell" = "latest"

