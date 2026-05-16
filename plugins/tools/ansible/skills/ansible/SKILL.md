---
name: ansible
description: Guide for Ansible automation and configuration management. Use when writing playbooks, tasks, handlers, variables, conditionals, loops, or needing an overview of Ansible project structure and development workflows.
license: MIT
---

# Ansible

Activate when working with Ansible playbooks, tasks, variables, handlers, conditionals, loops, or setting up an Ansible project from scratch.

## What Is Ansible

Ansible is an agentless, push-based automation tool. The control node (your machine) connects to managed nodes (servers) over SSH and runs tasks declared in YAML files called playbooks. There is no agent to install on managed nodes — only Python and SSH access are required.

Key properties:
- **Idempotent**: Running a playbook multiple times produces the same result. Tasks check current state before making changes.
- **Declarative**: You describe the desired state, not step-by-step instructions.
- **Push-based**: The control node initiates all connections.

## Available Skills

| Skill | When to load |
|-------|-------------|
| `ansible` | Core playbooks, tasks, vars, loops — this file |
| `ansible-inventory` | Configuring hosts, groups, group_vars, dynamic inventory |
| `ansible-roles` | Reusable role structure, Galaxy, Jinja2 templates |
| `ansible-vault` | Encrypting secrets, vault passwords, vault IDs |
| `ansible-testing` | Molecule test scenarios, Testinfra, CI integration |

## Install

```bash
pip install ansible          # recommended via pip
brew install ansible         # macOS Homebrew alternative
ansible --version            # verify
```

## Project Directory Layout

```
my-project/
├── ansible.cfg              # project-level config (overrides /etc/ansible/ansible.cfg)
├── inventory/
│   ├── hosts.ini            # static inventory
│   ├── group_vars/
│   │   ├── all.yml          # vars for every host
│   │   └── webservers.yml   # vars for the webservers group
│   └── host_vars/
│       └── web1.yml         # vars for a specific host
├── roles/
│   └── my_role/             # reusable role
├── playbooks/
│   └── site.yml             # top-level playbook
└── requirements.yml         # Galaxy roles/collections to install
```

## Playbook Anatomy

```yaml
---
- name: Configure web servers          # human-readable play name
  hosts: webservers                    # target group from inventory
  become: true                         # run tasks as root (sudo)
  vars:
    app_port: 8080
  vars_files:
    - vars/secrets.yml                 # load vars from a file
  pre_tasks:
    - name: Update apt cache
      ansible.builtin.apt:
        update_cache: true
  tasks:
    - name: Install nginx
      ansible.builtin.package:
        name: nginx
        state: present
      notify: Restart nginx            # trigger handler on change
  handlers:
    - name: Restart nginx
      ansible.builtin.service:
        name: nginx
        state: restarted
  post_tasks:
    - name: Verify nginx is running
      ansible.builtin.uri:
        url: "http://localhost:{{ app_port }}"
```

## Task Structure

```yaml
- name: Ensure /var/app exists        # always include a name
  ansible.builtin.file:               # fully-qualified module name (recommended)
    path: /var/app
    state: directory
    owner: www-data
    mode: "0755"
  become: true                        # task-level privilege escalation
  when: ansible_os_family == "Debian" # conditional
  register: dir_result                # save task output to a variable
  notify: Restart app                 # call handler if task changed
  ignore_errors: true                 # continue even if task fails
  tags:
    - setup
```

## Handlers

Handlers run at the end of a play, only once, and only if notified. Use them for service restarts triggered by config changes.

```yaml
handlers:
  - name: Restart nginx
    ansible.builtin.service:
      name: nginx
      state: restarted

  - name: Reload systemd
    ansible.builtin.systemd:
      daemon_reload: true
```

Force handlers to run before the end of the play:

```yaml
- name: Flush handlers now
  ansible.builtin.meta: flush_handlers
```

## Variables

Ansible merges variables from many sources. Higher numbers override lower:

| Precedence | Source |
|------------|--------|
| 1 (lowest) | Role defaults (`roles/x/defaults/main.yml`) |
| 2 | Inventory group_vars |
| 3 | Inventory host_vars |
| 4 | Playbook `vars:` block |
| 5 | `vars_files:` |
| 6 | `register:` output |
| 7 (highest) | Extra vars (`-e` flag) |

```yaml
vars:
  app_name: myapp
  app_port: 8080
  app_config:
    debug: false
    workers: 4

tasks:
  - name: Print app name
    ansible.builtin.debug:
      msg: "App: {{ app_name }} on port {{ app_port }}"

  - name: Access nested var
    ansible.builtin.debug:
      msg: "{{ app_config.workers }} workers"
```

## Conditionals

```yaml
- name: Install on Debian only
  ansible.builtin.apt:
    name: curl
    state: present
  when: ansible_os_family == "Debian"

- name: Run only if previous task changed
  ansible.builtin.debug:
    msg: "Config was updated"
  when: config_result.changed

- name: Multiple conditions (AND)
  ansible.builtin.debug:
    msg: "Production Debian host"
  when:
    - ansible_os_family == "Debian"
    - env == "production"

- name: Either condition (OR)
  ansible.builtin.debug:
    msg: "RedHat family"
  when: ansible_os_family == "RedHat" or ansible_distribution == "Amazon"
```

## Loops

```yaml
- name: Install multiple packages
  ansible.builtin.package:
    name: "{{ item }}"
    state: present
  loop:
    - git
    - curl
    - vim

- name: Create users
  ansible.builtin.user:
    name: "{{ item.name }}"
    groups: "{{ item.groups }}"
  loop:
    - { name: alice, groups: sudo }
    - { name: bob, groups: www-data }

- name: Loop with index
  ansible.builtin.debug:
    msg: "{{ loop_index }}: {{ item }}"
  loop: [a, b, c]
  loop_control:
    index_var: loop_index
    label: "{{ item }}"   # cleaner output in --verbose
```

## Tags

Run or skip specific tasks without modifying the playbook:

```yaml
tasks:
  - name: Install packages
    ansible.builtin.package:
      name: nginx
      state: present
    tags: [install, packages]

  - name: Configure nginx
    ansible.builtin.template:
      src: nginx.conf.j2
      dest: /etc/nginx/nginx.conf
    tags: [configure]
```

```bash
ansible-playbook site.yml --tags install          # only tagged tasks
ansible-playbook site.yml --skip-tags configure   # skip tagged tasks
ansible-playbook site.yml --tags all              # all tasks (default)
```

## Common CLI Flags

```bash
ansible-playbook site.yml -i inventory/hosts.ini  # specify inventory
ansible-playbook site.yml --limit webservers       # target subset of hosts
ansible-playbook site.yml --check                  # dry run (no changes)
ansible-playbook site.yml --diff                   # show file diffs
ansible-playbook site.yml -v / -vv / -vvv          # verbosity levels
ansible-playbook site.yml -e "env=production"      # extra vars
ansible-playbook site.yml --start-at-task "Install nginx"  # resume mid-play
ansible-playbook site.yml --step                   # confirm each task
```

## References

- **[playbook-patterns.md](references/playbook-patterns.md)** — Multi-play playbooks, import vs include, error handling blocks, delegation, `run_once`
