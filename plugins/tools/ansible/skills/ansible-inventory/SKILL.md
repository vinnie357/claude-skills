---
name: ansible-inventory
description: Guide for Ansible inventory management. Use when configuring static or dynamic inventory files, defining host patterns, setting host and group variables, using group_vars and host_vars directories, or working with inventory plugins.
license: MIT
---

# Ansible Inventory

Activate when defining which hosts Ansible should manage, grouping hosts, setting connection parameters, or configuring dynamic inventory sources like AWS or Azure.

## What Is Inventory

An inventory maps the control node's knowledge of managed nodes. At minimum it lists hostnames or IP addresses. Inventory also defines groups, per-host and per-group variables, and connection parameters.

Ansible looks for inventory in this order:
1. `-i` flag on the command line
2. `inventory` key in `ansible.cfg`
3. `/etc/ansible/hosts` (fallback default)

```ini
# ansible.cfg
[defaults]
inventory = inventory/
```

## Static Inventory — INI Format

```ini
# inventory/hosts.ini

# Ungrouped hosts
192.168.1.10
backup.example.com

[webservers]
web1.example.com
web2.example.com ansible_port=2222    # host-level variable inline

[dbservers]
db1.example.com
db2.example.com

[webservers:vars]
http_port=80
max_connections=200

[production:children]   # group of groups
webservers
dbservers
```

## Static Inventory — YAML Format

```yaml
# inventory/hosts.yml
all:
  children:
    webservers:
      hosts:
        web1.example.com:
          ansible_port: 22
        web2.example.com:
      vars:
        http_port: 80
    dbservers:
      hosts:
        db1.example.com:
        db2.example.com:
    production:
      children:
        webservers:
        dbservers:
  vars:
    ansible_user: deploy          # applies to all hosts
```

## Host Patterns

Use patterns with `-i` or in the `hosts:` field to target a subset:

```bash
# In ansible-playbook command
ansible-playbook site.yml --limit webservers
ansible-playbook site.yml --limit "web1.example.com,web2.example.com"

# Wildcard
ansible-playbook site.yml --limit "web*.example.com"

# Union (comma separated)
ansible-playbook site.yml --limit "webservers,dbservers"

# Intersection (AND): hosts in both groups
ansible-playbook site.yml --limit "production:&webservers"

# Exclusion (NOT): production but not dbservers
ansible-playbook site.yml --limit "production:!dbservers"

# Numeric ranges
ansible-playbook site.yml --limit "web[1:5].example.com"
```

In a playbook `hosts:` field:

```yaml
- hosts: webservers:&production   # webservers that are also in production
- hosts: all:!dbservers           # every host except dbservers
```

## group_vars and host_vars

Variables in these directories are automatically loaded by Ansible — no explicit include needed.

```
inventory/
├── hosts.ini
├── group_vars/
│   ├── all.yml           # applies to every host in every group
│   ├── webservers.yml    # applies to webservers group
│   └── webservers/       # directory form: all files here merge together
│       ├── main.yml
│       └── vault.yml     # encrypted vars (ansible-vault)
└── host_vars/
    ├── web1.example.com.yml    # applies to this specific host
    └── db1.example.com/
        ├── main.yml
        └── vault.yml
```

```yaml
# group_vars/webservers.yml
nginx_version: "1.24"
app_root: /var/www/html
```

## Connection Variables

Set these per host or group to control how Ansible connects:

| Variable | Purpose | Default |
|----------|---------|---------|
| `ansible_host` | IP or hostname to connect to | inventory hostname |
| `ansible_port` | SSH port | 22 |
| `ansible_user` | SSH user | current user |
| `ansible_ssh_private_key_file` | Path to SSH key | SSH agent / default key |
| `ansible_become` | Enable privilege escalation | false |
| `ansible_become_user` | User to become | root |
| `ansible_python_interpreter` | Python path on managed node | auto-detected |
| `ansible_connection` | Connection plugin (`ssh`, `local`, `docker`) | ssh |

```yaml
# host_vars/web1.example.com.yml
ansible_host: 10.0.1.15
ansible_user: ubuntu
ansible_ssh_private_key_file: ~/.ssh/deploy_key
ansible_become: true
```

## Dynamic Inventory

When infrastructure changes frequently (cloud, containers), use a dynamic inventory plugin instead of a static file. Plugins query your cloud provider's API and return hosts at runtime.

### Using a Plugin

Create a YAML file that ends in `.yml` or `.yaml` and configure the plugin:

```yaml
# inventory/aws_ec2.yml
plugin: amazon.aws.aws_ec2
regions:
  - us-east-1
  - us-west-2
filters:
  instance-state-name: running
  tag:Environment: production
keyed_groups:
  - key: tags.Role
    prefix: role
  - key: placement.region
    prefix: region
hostnames:
  - private-ip-address
```

```yaml
# inventory/azure_rm.yml
plugin: azure.azcollection.azure_rm
auth_source: auto
include_vm_resource_groups:
  - my-resource-group
keyed_groups:
  - key: tags.Environment
    prefix: env
```

Install the collection before use:

```bash
ansible-galaxy collection install amazon.aws
ansible-galaxy collection install azure.azcollection
```

## Inspecting Inventory

Always verify your inventory before running a playbook:

```bash
ansible-inventory -i inventory/ --list          # JSON dump of all hosts and vars
ansible-inventory -i inventory/ --graph         # tree view of groups
ansible-inventory -i inventory/ --host web1     # vars for a specific host
ansible all -m ping                             # test connectivity to all hosts
ansible webservers -m ping -i inventory/        # test a group
```

## References

- **[dynamic-inventory.md](references/dynamic-inventory.md)** — AWS EC2, Azure, GCP inventory plugin config examples; constructing groups from instance tags
