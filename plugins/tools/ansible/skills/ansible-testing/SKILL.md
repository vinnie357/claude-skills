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

Molecule runs these phases in order when you execute `molecule test`. `molecule test --help` states the same list (`Test (dependency, cleanup, destroy, syntax, create, prepare, converge, idempotence, side_effect, verify, cleanup, destroy)`), but help text is a claim about behavior, not the behavior itself (this exact gap shipped a broken `bd diff` example in claude-skills-219) — the phase order below is instead cited to molecule 26.6.0's installed `molecule/constants.py`, whose `DEFAULT["scenario"]["test_sequence"]` list matches token-for-token. There is no standalone `lint` phase or `molecule lint` command in current Molecule — `ansible-lint`/`yamllint` are no longer a first-class Molecule action; run them directly (see "Linting" below) or wire them into CI alongside `molecule test`.

| Phase | What it does |
|-------|-------------|
| `dependency` | Install role/collection dependencies (per `dependency:` config) |
| `cleanup` | Optional: cleanup tasks before destroy |
| `destroy` | Remove any leftover test instances |
| `syntax` | Syntax-check the converge playbook |
| `create` | Spin up fresh test instances (containers or VMs) |
| `prepare` | Optional: run a prepare playbook before converge |
| `converge` | Apply your role to the test instances |
| `idempotence` | Run converge again — assert zero changes |
| `side_effect` | Optional: apply changes to test failure/recovery scenarios |
| `verify` | Run your test assertions against live instances |
| `cleanup` | Optional: cleanup tasks before destroy |
| `destroy` | Tear down all test instances |

Run individual phases during development:

```bash
molecule converge     # apply role (keep instance running)
molecule verify       # run assertions only
molecule login        # SSH into the test instance
molecule destroy      # tear down
molecule test         # full cycle above: dependency → cleanup → destroy → syntax → create → prepare → converge → idempotence → side_effect → verify → cleanup → destroy
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
molecule init scenario           # default scenario
molecule init scenario staging   # named scenario
```

`molecule init scenario` takes only an optional scenario-name argument — verified live against molecule 26.6.0 (`molecule init scenario --help` shows no other options) and by running it: `--driver-name docker` errors `Error: No such option '--driver-name'.` The driver is no longer chosen at scaffold time; it's configured (or auto-selected) separately — see "molecule.yml Structure" below.

This creates:

```
roles/my_role/
└── molecule/
    └── default/             # scenario name
        ├── molecule.yml     # scenario config (see below)
        ├── create.yml       # playbook that provisions test instances
        ├── converge.yml     # playbook Molecule runs against instances
        ├── destroy.yml      # playbook that tears instances down
        └── verify.yml       # assertions (if using the ansible verifier)
```

Verified live via `molecule init scenario` with molecule 26.6.0 + molecule-plugins[docker] installed — exactly these 5 files are generated, no `prepare.yml` (the running scenario's `molecule.yml` references a `prepare.yml` playbook path but does not create the file; add it by hand if your role needs a prepare step).

## molecule.yml Structure

**This schema changed from the classic `driver:`/`platforms:`/`provisioner:`/`verifier:`/`lint:` top-level keys documented in older Molecule guides.** Verified live (molecule 26.6.0, both with and without `molecule-plugins[docker]` installed — same result either way) — `molecule init scenario`'s actual default output is:

```yaml
# molecule/default/molecule.yml — captured verbatim from a live `molecule init scenario` run, molecule 26.6.0
---
dependency:
  name: galaxy
  options:
    ignore-certs: false
    ignore-errors: false
    role-file: requirements.yml
    requirements-file: requirements.yml

ansible:
  cfg:
    defaults:
      host_key_checking: false
      verbosity: 1
    ssh_connection:
      pipelining: true
  env:
    ANSIBLE_FORCE_COLOR: "1"
    ANSIBLE_LOAD_CALLBACK_PLUGINS: "1"
  executor:
    backend: ansible-playbook
    args:
      ansible_playbook:
        - --diff
        - --force-handlers
        - --inventory=/path/to/inventory.yml
      ansible_navigator:
        - --mode stdout
        - --pull-policy missing
        - --execution-environment-image ghcr.io/ansible/community-ansible-dev-tools:latest
  playbooks:
    create: create.yml
    converge: converge.yml
    destroy: destroy.yml
    cleanup: cleanup.yml
    prepare: prepare.yml
    side_effect: side_effect.yml
    verify: verify.yml

scenario:
  name: default
  test_sequence:
    - dependency
    - cleanup
    - destroy
    - syntax
    - create
    - prepare
    - converge
    - idempotence
    - side_effect
    - verify
    - cleanup
    - destroy
```

There is no `driver:`, `platforms:`, `provisioner:`, `verifier:`, or `lint:` top-level key in this generated template — driver/platform selection and verifier choice now live elsewhere (the `ansible.executor` block above shows both an `ansible-playbook` and an `ansible-navigator`/execution-environment path). **Out of scope for this verification pass**: the exact current mechanism for pinning a specific driver (Docker/Podman) and platform image under this new schema needs a dedicated follow-up — `molecule drivers` (verified live) lists `gce, azure, docker, ec2, containers, openstack, podman, vagrant, default` as installed drivers, but reproducing a full worked docker-platform example against this schema is more than a factual correction and hasn't been re-authored here. Treat the `driver:`/`platforms:` example previously in this section as unverified for molecule 26.6.0 rather than trusting it.

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
# molecule.yml — switch verifier (same schema caveat as "molecule.yml Structure"
# above: `verifier:` was not present in a live 26.6.0 scaffold, unverified)
verifier:
  name: testinfra
```

The Testinfra assertion API itself below (module names, properties) IS independently verified — confirmed live against pytest-testinfra 10.2.2's actual source (`package`, `service`, `file`, `socket`, `command` modules; `is_installed`, `is_running`, `is_enabled`, `exists`, `mode`, `user`, `is_listening`, `stdout` all present).

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
# There is no `molecule lint` command in current Molecule (26.6.0) — verified
# live: `molecule lint --help` errors "No such command 'lint'." Run the
# linters directly instead:
yamllint .
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

Test across OS versions with multiple platform entries. **Same caveat as "molecule.yml Structure" above: this `platforms:` key was not present in a live molecule 26.6.0 scaffold — unverified against the current schema, kept here as the multi-platform intent to preserve rather than a confirmed-working example:**

```yaml
platforms:
  - name: ubuntu22
    image: geerlingguy/docker-ubuntu2204-ansible
    pre_build_image: true
  - name: ubuntu24
    image: geerlingguy/docker-ubuntu2404-ansible
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

- **[molecule-scenarios.md](references/molecule-scenarios.md)** — Multi-platform test matrix, Testinfra assertion patterns, and GitHub Actions CI workflow examples; its `molecule.yml`/driver/`--driver-name`/`lint:` content documents an older Molecule schema and is stale for 26.6.0 (see the file's own caveat) — use "molecule.yml Structure" above for the current schema
