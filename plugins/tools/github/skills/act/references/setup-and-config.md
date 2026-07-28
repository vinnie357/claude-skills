# act Setup and Configuration Reference

Installation methods, prerequisites, `.actrc` configuration, runner images, event payloads, and
advanced flags for act.

## Contents

- [Installation](#installation)
- [Prerequisites](#prerequisites)
- [Configuration](#configuration)
- [Event Payloads](#event-payloads)
- [Advanced Usage](#advanced-usage)

## Installation

### Using mise (Recommended for this project)

The act tool is configured in the github plugin's mise.toml:

```bash
# Install act via mise
mise install act

# Verify installation
act --version
```

### Alternative Installation Methods

**macOS (Homebrew):**
```bash
brew install act
```

**Linux (via script):**
```bash
curl -s https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash
```

**From source:**
```bash
git clone https://github.com/nektos/act.git
cd act
make install
```

**Windows (Chocolatey):**
```powershell
choco install act-cli
```

## Prerequisites

- **Docker**: act requires Docker to run workflows
- **Workflow files**: Valid `.github/workflows/*.yml` files in repository

Verify Docker is running:
```bash
docker ps
```

## Configuration

### .actrc File

Create `.actrc` in repository root or home directory:

```
# Use specific platform
-P ubuntu-latest=catthehacker/ubuntu:act-latest

# Default secrets file
--secret-file .secrets

# Default environment
--env-file .env

# Container architecture
--container-architecture linux/amd64

# Verbose output
-v
```

### Custom Runner Images

```bash
# Use custom image for platform
act -P ubuntu-latest=my-custom-image:latest

# Use medium size images (recommended)
act -P ubuntu-latest=catthehacker/ubuntu:act-latest

# Use micro images (faster, less compatible)
act -P ubuntu-latest=node:16-buster-slim
```

### Recommended Images

act supports different image sizes:

**Medium images (recommended):**
- Better compatibility with GitHub Actions
- More pre-installed tools
- Slower startup but fewer failures

```bash
-P ubuntu-latest=catthehacker/ubuntu:act-latest
-P ubuntu-22.04=catthehacker/ubuntu:act-22.04
```

**Micro images:**
- Faster startup
- Minimal pre-installed tools
- May require additional setup

## Event Payloads

### Custom Event Data

Create event JSON file:

```json
{
  "pull_request": {
    "number": 123,
    "head": {
      "ref": "feature-branch"
    },
    "base": {
      "ref": "main"
    }
  }
}
```

Use with act:
```bash
act pull_request -e event.json
```

### workflow_dispatch Inputs

```json
{
  "inputs": {
    "environment": "staging",
    "debug": true
  }
}
```

```bash
act workflow_dispatch -e inputs.json
```

## Advanced Usage

### Bind Workspace

Mount local directory into container:
```bash
act --bind
```

### Reuse Containers

Keep containers between runs for faster execution:
```bash
act --reuse
```

### Specific Platforms

```bash
# Run on specific platform
act -P ubuntu-latest=ubuntu:latest

# Multiple platforms
act -P ubuntu-latest=ubuntu:latest \
    -P windows-latest=windows:latest
```

### Container Architecture

```bash
# Specify architecture (useful for M1/M2 Macs)
act --container-architecture linux/amd64
```

### Network Configuration

Per `act --help` on 0.2.89: `--network` sets the Docker network for job containers and defaults to
`host`; `--container-daemon-socket` is the Docker Engine socket URI, where `-` disables
bind-mounting the socket into job containers.

```bash
# Custom docker network (default is host)
act --network my-network

# Disable bind-mounting the Docker socket into job containers
act --container-daemon-socket -
```

### Artifact Server

```bash
# Enable artifact server on specific port
act --artifact-server-path /tmp/artifacts \
    --artifact-server-port 34567
```
