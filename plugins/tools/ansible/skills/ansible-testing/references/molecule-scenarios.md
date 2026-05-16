# Molecule Scenario Reference

## Docker Driver — Full Annotated molecule.yml

```yaml
# molecule/default/molecule.yml
---
dependency:
  name: galaxy
  options:
    # Install Galaxy requirements before running tests
    requirements-file: requirements.yml
    ignore-errors: false

driver:
  name: docker

platforms:
  - name: ubuntu22-instance        # unique name for this container
    image: geerlingguy/docker-ubuntu2204-ansible
    pre_build_image: true           # use image as-is, don't build from Dockerfile
    command: /lib/systemd/systemd  # init system (needed for service tests)
    privileged: true               # required for systemd inside Docker
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:ro
    capabilities:
      - SYS_ADMIN
    tmpfs:
      - /run
      - /tmp

provisioner:
  name: ansible
  playbooks:
    prepare: prepare.yml           # optional: runs before converge
    converge: converge.yml
    verify: verify.yml
  config_options:
    defaults:
      interpreter_python: auto_silent
      callback_whitelist: profile_tasks   # show task timing
  inventory:
    group_vars:
      all:
        ansible_user: root
  env:
    ANSIBLE_ROLES_PATH: ../../     # look for roles relative to molecule dir

verifier:
  name: ansible                    # or: testinfra

lint: |
  set -e
  yamllint .
  ansible-lint
```

## Podman Driver — molecule.yml

```yaml
# molecule/default/molecule.yml
---
dependency:
  name: galaxy

driver:
  name: podman

platforms:
  - name: instance
    image: ghcr.io/hifis-net/ubuntu-systemd:22.04
    pre_build_image: true
    systemd: always                # enable systemd in container
    privileged: false              # Podman works rootless
    capabilities:
      - SYS_ADMIN
    tmpfs:
      - /tmp
      - /run

provisioner:
  name: ansible
  inventory:
    group_vars:
      all:
        ansible_user: root
        ansible_connection: podman

verifier:
  name: ansible

lint: |
  set -e
  yamllint .
  ansible-lint
```

## Delegated Driver — molecule.yml

Use the delegated driver when you want to manage your own test infrastructure (existing VMs, cloud instances, etc.):

```yaml
# molecule/default/molecule.yml
---
driver:
  name: delegated
  options:
    managed: false                 # Molecule won't create/destroy — you manage instances
    login_cmd_template: "ssh {instance}"
    ansible_connection_options:
      ansible_connection: ssh

platforms:
  - name: my-test-vm
    address: 10.0.1.100           # IP of your existing test VM

provisioner:
  name: ansible
  inventory:
    hosts:
      all:
        hosts:
          my-test-vm:
            ansible_host: 10.0.1.100
            ansible_user: ubuntu
            ansible_ssh_private_key_file: ~/.ssh/test_key

verifier:
  name: ansible
```

With `managed: false`, you are responsible for running `create` and `destroy` yourself — Molecule skips those phases.

## Multi-Platform Test Matrix

```yaml
platforms:
  - name: ubuntu22
    image: geerlingguy/docker-ubuntu2204-ansible
    pre_build_image: true
    command: /lib/systemd/systemd
    privileged: true
    groups:
      - debian_family

  - name: ubuntu20
    image: geerlingguy/docker-ubuntu2004-ansible
    pre_build_image: true
    command: /lib/systemd/systemd
    privileged: true
    groups:
      - debian_family

  - name: rocky9
    image: geerlingguy/docker-rockylinux9-ansible
    pre_build_image: true
    command: /usr/lib/systemd/systemd
    privileged: true
    groups:
      - redhat_family

  - name: debian12
    image: geerlingguy/docker-debian12-ansible
    pre_build_image: true
    command: /lib/systemd/systemd
    privileged: true
    groups:
      - debian_family
```

Target only specific platforms:

```bash
molecule converge --platform ubuntu22
molecule test -- --platform rocky9
```

## Testinfra Assertion Patterns

```python
# molecule/default/tests/test_default.py
import pytest


# ─── Package assertions ───────────────────────────────────────────────────────

def test_nginx_installed(host):
    pkg = host.package("nginx")
    assert pkg.is_installed

def test_nginx_version(host):
    pkg = host.package("nginx")
    assert pkg.is_installed
    # Version string varies by distro — check it's not empty
    assert pkg.version


# ─── Service assertions ───────────────────────────────────────────────────────

def test_nginx_running_and_enabled(host):
    svc = host.service("nginx")
    assert svc.is_running
    assert svc.is_enabled


# ─── File and directory assertions ───────────────────────────────────────────

def test_config_file_exists(host):
    conf = host.file("/etc/nginx/nginx.conf")
    assert conf.exists
    assert conf.is_file

def test_config_permissions(host):
    conf = host.file("/etc/nginx/nginx.conf")
    assert conf.user == "root"
    assert conf.group == "root"
    assert oct(conf.mode) == "0o644"

def test_config_contains_port(host):
    conf = host.file("/etc/nginx/nginx.conf")
    assert conf.contains("listen 80")

def test_web_root_is_directory(host):
    d = host.file("/var/www/html")
    assert d.is_directory
    assert d.user == "www-data"


# ─── Socket and port assertions ───────────────────────────────────────────────

def test_nginx_listening_on_80(host):
    socket = host.socket("tcp://0.0.0.0:80")
    assert socket.is_listening

def test_nginx_listening_on_ipv6(host):
    socket = host.socket("tcp://:::80")
    assert socket.is_listening


# ─── HTTP endpoint assertions ─────────────────────────────────────────────────

def test_nginx_returns_200(host):
    cmd = host.run("curl -s -o /dev/null -w '%{http_code}' http://localhost")
    assert cmd.rc == 0
    assert cmd.stdout == "200"


# ─── User and group assertions ────────────────────────────────────────────────

def test_deploy_user_exists(host):
    user = host.user("deploy")
    assert user.exists
    assert user.shell == "/bin/bash"
    assert "www-data" in user.groups


# ─── Process assertions ───────────────────────────────────────────────────────

def test_nginx_process_running(host):
    process = host.process.filter(user="root", comm="nginx")
    assert len(process) >= 1


# ─── Command output assertions ────────────────────────────────────────────────

def test_nginx_config_valid(host):
    cmd = host.run("nginx -t")
    assert cmd.rc == 0
```

## GitHub Actions CI Workflow

```yaml
# .github/workflows/molecule.yml
name: Molecule Tests

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    name: Molecule (${{ matrix.role }} / ${{ matrix.scenario }})
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        role:
          - nginx
          - postgresql
        scenario:
          - default

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.11"
          cache: pip

      - name: Install Molecule and dependencies
        run: |
          pip install molecule molecule-plugins[docker] ansible-lint testinfra pytest

      - name: Install Ansible Galaxy requirements
        run: ansible-galaxy install -r requirements.yml
        if: hashFiles('requirements.yml') != ''

      - name: Run Molecule
        run: molecule test -s ${{ matrix.scenario }}
        working-directory: roles/${{ matrix.role }}
        env:
          MOLECULE_NO_LOG: "false"
          PY_COLORS: "1"
          ANSIBLE_FORCE_COLOR: "1"
```

## Named Scenarios

Create additional scenarios for different test conditions:

```bash
# Initialize a named scenario
molecule init scenario production --driver-name docker
molecule init scenario check-mode --driver-name delegated

# Run a specific scenario
molecule test -s production
molecule converge -s check-mode

# List all scenarios in a role
molecule list
```

Each scenario lives in its own directory under `molecule/`:

```
roles/nginx/
└── molecule/
    ├── default/       # normal install + verify
    ├── production/    # test with production-like settings
    └── upgrade/       # test upgrading from a previous version
```
