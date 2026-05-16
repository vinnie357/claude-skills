---
name: ansible-testing
description: Guide for testing Ansible roles and playbooks with Molecule. Use when writing Molecule test scenarios, configuring drivers (Docker, Podman, delegated), writing Testinfra or Ansible Verify tests, or integrating Molecule into CI pipelines.
license: MIT
---

# Ansible Testing with Molecule

Activate when setting up Molecule for a role, writing test scenarios, configuring drivers, writing Testinfra assertions, or integrating Ansible tests into CI.

## Why Test Ansible Code

Without automated tests:
- Refactoring breaks things silently
- Idempotency regressions go undetected (tasks that should be no-ops make changes on repeated runs)
- Roles stop working on newer OS versions without anyone noticing

Molecule provides a framework to spin up a test environment, run your role against it, verify the end state, and tear it down — all automatically.

## Molecule Test Phases

Molecule runs these phases in order when you execute `molecule test`:

| Phase | What it does |
|-------|-------------|
| `lint` | Run `ansible-lint` and `yamllint` on your role |
| `destroy` | Remove any leftover test instances |
| `create` | Spin up fresh test instances (containers or VMs) |
| `prepare` | Optional: run a prepare playbook before converge |
| `converge` | Apply your role to the test instances |
| `idempotency` | Run converge again — assert zero changes |
| `verify` | Run your test assertions against live instances |
| `cleanup` | Optional: cleanup tasks before destroy |
| `destroy` | Tear down all test instances |

Run individual phases during development:

```bash
molecule converge     # apply role (keep instance running)
molecule verify       # run assertions only
molecule login        # SSH into the test instance
molecule destroy      # tear down
molecule test         # full cycle: destroy → create → converge → verify → destroy
```

## Install Molecule

```bash
pip install molecule molecule-plugins[docker]   # Docker driver
pip install molecule molecule-plugins[podman]   # Podman driver
pip install pytest testinfra                    # for Testinfra verifier
```

## Initialize a Molecule Scenario

From inside an existing role directory:

```bash
cd roles/my_role
molecule init scenario --driver-name docker         # default scenario
molecule init scenario staging --driver-name podman  # named scenario
```

This creates:

```
roles/my_role/
└── molecule/
    └── default/             # scenario name
        ├── molecule.yml     # driver, platforms, verifier config
        ├── converge.yml     # playbook Molecule runs against instances
        ├── verify.yml       # assertions (if using ansible verifier)
        └── prepare.yml      # optional: pre-role setup
```

## molecule.yml Structure

```yaml
# molecule/default/molecule.yml
---
dependency:
  name: galaxy
  options:
    requirements-file: requirements.yml   # install Galaxy deps before testing

driver:
  name: docker                            # docker, podman, delegated

platforms:
  - name: instance                        # container name
    image: geerlingguy/docker-ubuntu2204-ansible  # pre-built image with systemd+Python
    pre_build_image: true
    command: /lib/systemd/systemd         # init system (for service tests)
    privileged: true                      # needed for systemd inside Docker

provisioner:
  name: ansible
  playbooks:
    converge: converge.yml
    prepare: prepare.yml                  # optional
  config_options:
    defaults:
      interpreter_python: auto_silent
  inventory:
    group_vars:
      all:
        ansible_user: root

verifier:
  name: ansible                           # or: testinfra

lint: |
  set -e
  yamllint .
  ansible-lint
```

## converge.yml

The playbook Molecule runs to apply your role to test instances:

```yaml
# molecule/default/converge.yml
---
- name: Converge
  hosts: all
  become: true
  vars:
    nginx_port: 80
  roles:
    - role: my_role
```

## Idempotency

Molecule runs converge twice and checks that the second run produces zero changed tasks. Tasks that always report `changed` will fail the idempotency check.

Common idempotency failures:
- `command:` / `shell:` tasks without `changed_when: false` or `creates:`
- Tasks that generate random values on each run
- File timestamps checked as changed

Fix:

```yaml
- name: Compile app (only when source changes)
  ansible.builtin.command: make build
  args:
    chdir: /var/app
    creates: /var/app/dist/app.bin    # skip if output already exists
  changed_when: false                 # or mark as never changed
```

## Verify Phase — Ansible Verifier

Write a playbook of assertion tasks:

```yaml
# molecule/default/verify.yml
---
- name: Verify
  hosts: all
  become: true
  tasks:
    - name: Check nginx is installed
      ansible.builtin.package:
        name: nginx
        state: present
      check_mode: true
      register: pkg
      failed_when: pkg.changed

    - name: Check nginx service is running
      ansible.builtin.service:
        name: nginx
        state: started
        enabled: true
      check_mode: true
      register: svc
      failed_when: svc.changed

    - name: Check nginx responds on port 80
      ansible.builtin.uri:
        url: http://localhost:80
        status_code: 200

    - name: Check config file exists with correct permissions
      ansible.builtin.stat:
        path: /etc/nginx/nginx.conf
      register: conf
      failed_when: not conf.stat.exists or conf.stat.mode != "0644"
```

## Verify Phase — Testinfra Verifier

Testinfra is a Python testing library with a pytest interface. More expressive for complex assertions.

```yaml
# molecule.yml — switch verifier
verifier:
  name: testinfra
```

```python
# molecule/default/tests/test_nginx.py
import pytest

def test_nginx_installed(host):
    pkg = host.package("nginx")
    assert pkg.is_installed

def test_nginx_running(host):
    svc = host.service("nginx")
    assert svc.is_running
    assert svc.is_enabled

def test_nginx_config_exists(host):
    conf = host.file("/etc/nginx/nginx.conf")
    assert conf.exists
    assert conf.mode == 0o644
    assert conf.user == "root"

def test_nginx_listening(host):
    socket = host.socket("tcp://0.0.0.0:80")
    assert socket.is_listening

def test_nginx_responds(host):
    cmd = host.run("curl -s -o /dev/null -w '%{http_code}' http://localhost")
    assert cmd.stdout == "200"
```

## Linting

```bash
# Run all linting (yamllint + ansible-lint)
molecule lint

# Run ansible-lint directly
ansible-lint roles/my_role/

# yamllint config
# .yamllint
extends: default
rules:
  line-length:
    max: 120
  truthy:
    allowed-values: ['true', 'false']
```

```yaml
# .ansible-lint
skip_list:
  - yaml[line-length]    # skip specific rules
profile: production      # safety, shared, production (strictest)
```

## Multiple Platforms

Test across OS versions with multiple platform entries:

```yaml
platforms:
  - name: ubuntu22
    image: geerlingguy/docker-ubuntu2204-ansible
    pre_build_image: true
  - name: ubuntu20
    image: geerlingguy/docker-ubuntu2004-ansible
    pre_build_image: true
  - name: rocky9
    image: geerlingguy/docker-rockylinux9-ansible
    pre_build_image: true
```

## CI Integration

```bash
# GitHub Actions: run molecule test for a role
molecule test -s default
```

## check_mode and --diff

Before running against production, validate with a dry run:

```bash
ansible-playbook site.yml --check           # no changes made
ansible-playbook site.yml --check --diff    # show what would change
```

Some tasks behave differently in check mode. Mark tasks that must always run regardless:

```yaml
- name: Always run this
  ansible.builtin.command: echo "status check"
  check_mode: false
```

## References

- **[molecule-scenarios.md](references/molecule-scenarios.md)** — Complete annotated `molecule.yml` for Docker, Podman, and delegated drivers; multi-platform test matrix; Testinfra assertion patterns; GitHub Actions CI workflow
