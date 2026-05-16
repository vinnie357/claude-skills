---
name: ansible-roles
description: Guide for Ansible roles and Galaxy. Use when creating or consuming roles, structuring role directories, defining role dependencies, using meta/main.yml, working with Jinja2 templates, or installing collections and roles from Ansible Galaxy.
license: MIT
---

# Ansible Roles and Galaxy

Activate when creating reusable role structures, using `import_role:` or `include_role:`, writing Jinja2 templates, or working with Ansible Galaxy collections and roles.

## What Are Roles

A role is a self-contained directory of tasks, handlers, variables, templates, and files organized for reuse. Instead of copying tasks between playbooks, extract them into a role and apply the role wherever needed.

Roles enforce a consistent directory layout that Ansible recognizes automatically.

## Role Directory Structure

```
roles/
└── my_role/
    ├── tasks/
    │   └── main.yml        # entry point — required
    ├── handlers/
    │   └── main.yml        # handlers (notified by tasks)
    ├── defaults/
    │   └── main.yml        # default variables (lowest precedence)
    ├── vars/
    │   └── main.yml        # role variables (higher precedence than defaults)
    ├── files/
    │   └── app.conf        # static files (copy: module)
    ├── templates/
    │   └── nginx.conf.j2   # Jinja2 templates (template: module)
    ├── meta/
    │   └── main.yml        # role metadata and dependencies
    └── tests/
        ├── inventory
        └── test.yml        # simple smoke test playbook
```

Scaffold a new role:

```bash
ansible-galaxy role init my_role
```

## Defaults vs Vars

| Location | Precedence | Purpose |
|----------|-----------|---------|
| `defaults/main.yml` | Lowest — easily overridden | User-facing knobs with sensible fallbacks |
| `vars/main.yml` | Higher — harder to override | Internal role constants |

```yaml
# defaults/main.yml
nginx_port: 80
nginx_worker_processes: auto
nginx_log_level: warn

# vars/main.yml
nginx_config_dir: /etc/nginx
nginx_pid_file: /var/run/nginx.pid
```

Set defaults for everything a consumer might want to change. Put implementation details in vars.

## Using Roles in Playbooks

```yaml
# Classic roles: block (static, resolved at parse time)
- hosts: webservers
  roles:
    - common
    - role: nginx
      vars:
        nginx_port: 8080

# import_role (static — analyzed before execution)
- hosts: webservers
  tasks:
    - name: Apply base role
      ansible.builtin.import_role:
        name: common

# include_role (dynamic — resolved at runtime, supports when:/loop:)
- hosts: webservers
  tasks:
    - name: Apply role conditionally
      ansible.builtin.include_role:
        name: nginx
      when: install_nginx | bool
      loop: "{{ nginx_sites }}"
      loop_control:
        loop_var: nginx_site
```

Use `import_role` when you need tags to propagate; use `include_role` when you need conditionals or loops on the role itself.

## Role Dependencies

Declare roles that must run before this role in `meta/main.yml`:

```yaml
# roles/app/meta/main.yml
galaxy_info:
  author: rginnow
  description: Deploy the application
  license: MIT
  min_ansible_version: "2.14"

dependencies:
  - role: common
  - role: nginx
    vars:
      nginx_port: 8080
```

Dependencies run first, in order. Ansible deduplicates them — a dependency listed by multiple roles only runs once per play.

## Jinja2 Templates

Use the `template:` module to render Jinja2 templates from `templates/` onto managed nodes.

```yaml
- name: Write nginx config
  ansible.builtin.template:
    src: nginx.conf.j2         # relative to templates/ — Ansible finds it
    dest: /etc/nginx/nginx.conf
    owner: root
    group: root
    mode: "0644"
  notify: Reload nginx
```

Template syntax:

```jinja
{# nginx.conf.j2 #}
worker_processes {{ nginx_worker_processes }};
pid {{ nginx_pid_file }};

events {
    worker_connections {{ nginx_worker_connections | default(1024) }};
}

http {
    server {
        listen {{ nginx_port }};
        server_name {{ ansible_fqdn }};

        {% for location in nginx_locations %}
        location {{ location.path }} {
            proxy_pass {{ location.upstream }};
        }
        {% endfor %}
    }
}
```

Key Jinja2 syntax:
- `{{ variable }}` — output a value
- `{% if condition %}...{% endif %}` — conditional block
- `{% for item in list %}...{% endfor %}` — loop
- `{# comment #}` — template comment (not in output)
- `{{ value | filter }}` — apply a filter

Common filters:
```jinja
{{ my_list | join(', ') }}           {# join list items #}
{{ name | upper }}                   {# uppercase #}
{{ path | basename }}                {# filename from path #}
{{ value | default('fallback') }}    {# fallback if undefined #}
{{ items | selectattr('active') }}   {# filter objects by attribute #}
{{ count | int }}                    {# type conversion #}
```

## Ansible Galaxy

Galaxy is the public hub for community roles and collections.

### Install from Galaxy

```bash
# Install a role
ansible-galaxy role install geerlingguy.nginx

# Install a collection (namespaced: namespace.collection)
ansible-galaxy collection install community.general
ansible-galaxy collection install amazon.aws

# Specify version
ansible-galaxy collection install community.general:==6.0.0
```

### requirements.yml

Pin dependencies in a `requirements.yml` file and install all at once:

```yaml
# requirements.yml
roles:
  - name: geerlingguy.nginx
    version: "3.2.0"
  - src: https://github.com/example/my-role
    name: my_custom_role

collections:
  - name: community.general
    version: ">=6.0.0"
  - name: amazon.aws
    version: "6.5.0"
```

```bash
ansible-galaxy role install -r requirements.yml
ansible-galaxy collection install -r requirements.yml
```

### Local Roles Path

```ini
# ansible.cfg
[defaults]
roles_path = roles:~/.ansible/roles:/usr/share/ansible/roles
```

Ansible searches each path in order when resolving role names.

## References

- **[jinja2-filters.md](references/jinja2-filters.md)** — Complete Jinja2 filter and test reference with examples; template patterns for common config file structures
