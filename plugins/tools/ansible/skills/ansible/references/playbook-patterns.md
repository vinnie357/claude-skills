# Playbook Patterns

## Multi-Play Playbooks

A single playbook file can contain multiple plays, each targeting different hosts:

```yaml
---
# site.yml — full stack deployment
- name: Configure database servers
  hosts: dbservers
  become: true
  roles:
    - common
    - postgresql

- name: Configure web servers
  hosts: webservers
  become: true
  roles:
    - common
    - nginx
    - app

- name: Configure load balancer
  hosts: loadbalancers
  become: true
  roles:
    - common
    - haproxy
```

Run a single play from a multi-play file using `--limit`:

```bash
ansible-playbook site.yml --limit webservers
```

## pre_tasks and post_tasks

`pre_tasks` run before roles, `post_tasks` run after handlers. Use them to set up preconditions or run teardown steps that don't belong in roles.

```yaml
- hosts: webservers
  become: true
  pre_tasks:
    - name: Wait for system to be ready
      ansible.builtin.wait_for_connection:
        timeout: 60

    - name: Gather facts after connection
      ansible.builtin.setup:

  roles:
    - nginx

  post_tasks:
    - name: Verify deployment succeeded
      ansible.builtin.uri:
        url: http://localhost/healthz
        status_code: 200
      retries: 5
      delay: 3
```

## import vs include

| Feature | `import_*` (static) | `include_*` (dynamic) |
|---------|--------------------|-----------------------|
| Resolved at | Parse time | Runtime |
| `when:` applies | To each imported task | To the include itself |
| `tags:` propagate | Yes | Partial |
| `loop:` supported | No | Yes |
| `--list-tasks` shows | All tasks | Only the include line |

```yaml
# Static: use for standard task files, tags propagate correctly
- ansible.builtin.import_tasks: tasks/install.yml

# Dynamic: use when you need loops or conditionals on the file itself
- ansible.builtin.include_tasks: "tasks/{{ ansible_os_family }}.yml"

- ansible.builtin.include_tasks: tasks/configure.yml
  when: configure_enabled | bool
  loop: "{{ sites }}"
  loop_control:
    loop_var: site
```

## Error Handling with block/rescue/always

```yaml
- name: Deploy application
  block:
    - name: Stop the service
      ansible.builtin.service:
        name: myapp
        state: stopped

    - name: Update the binary
      ansible.builtin.copy:
        src: dist/myapp
        dest: /usr/local/bin/myapp
        mode: "0755"

    - name: Start the service
      ansible.builtin.service:
        name: myapp
        state: started

  rescue:
    # Runs only if a task in block fails
    - name: Roll back binary
      ansible.builtin.copy:
        src: dist/myapp.bak
        dest: /usr/local/bin/myapp
        mode: "0755"

    - name: Restart service with old binary
      ansible.builtin.service:
        name: myapp
        state: started

    - name: Notify team of failure
      ansible.builtin.debug:
        msg: "Deployment failed — rolled back"

  always:
    # Runs whether block succeeded or failed
    - name: Collect deployment log
      ansible.builtin.fetch:
        src: /var/log/myapp/deploy.log
        dest: logs/
```

## Task Delegation

Run a task on a different host than the current play's target. Common for:
- Registering/deregistering from a load balancer before deploying
- Running a command on a central DB host while iterating web hosts
- Creating a local file based on remote facts

```yaml
- name: Remove from load balancer before update
  ansible.builtin.uri:
    url: "http://lb.example.com/api/deregister/{{ inventory_hostname }}"
    method: POST
  delegate_to: loadbalancer       # run this task on loadbalancer host

- name: Run migration on db host
  ansible.builtin.command: /var/app/migrate.sh
  delegate_to: db1.example.com

- name: Write inventory report locally
  ansible.builtin.copy:
    content: "{{ ansible_facts | to_nice_json }}"
    dest: "/tmp/facts-{{ inventory_hostname }}.json"
  delegate_to: localhost
```

## run_once

Execute a task exactly once, regardless of how many hosts are in the play. The task runs on the first host in the batch; Ansible skips all others.

```yaml
- name: Run database migration (only once for the whole play)
  ansible.builtin.command: /var/app/manage.py migrate
  delegate_to: "{{ groups['dbservers'][0] }}"
  run_once: true

- name: Send deployment notification
  ansible.builtin.uri:
    url: https://hooks.slack.com/services/XXX/YYY/ZZZ
    method: POST
    body_format: json
    body:
      text: "Deployed version {{ app_version }} to {{ inventory_hostname }}"
  run_once: true
  delegate_to: localhost
```

## Rolling Updates with serial

By default Ansible runs each task across all hosts before moving to the next task. Use `serial` to process hosts in batches (rolling deploy):

```yaml
- hosts: webservers
  serial: 2              # process 2 hosts at a time
  # serial: "25%"        # or percentage of total hosts
  # serial: [1, 5, "50%"]  # progressive: 1 host, then 5, then 50%
  become: true
  roles:
    - app
```

With `serial`, all tasks run on the first batch before moving to the next, limiting the blast radius if a deployment fails.

## Waiting for Hosts

```yaml
- name: Wait for SSH to come back after reboot
  ansible.builtin.wait_for:
    host: "{{ inventory_hostname }}"
    port: 22
    delay: 10
    timeout: 300
  delegate_to: localhost

- name: Wait for service port to be open
  ansible.builtin.wait_for:
    host: "{{ ansible_host }}"
    port: 8080
    state: started
    timeout: 60
  delegate_to: localhost

- name: Pause for human confirmation
  ansible.builtin.pause:
    prompt: "Press Enter to continue deployment, Ctrl+C to abort"
```

## Gathering Facts Selectively

Fact gathering runs at the start of each play and adds overhead. Disable or limit it when speed matters:

```yaml
- hosts: all
  gather_facts: false           # skip all facts

- hosts: all
  gather_subset:                # gather only specific subsets
    - network
    - hardware
  # subsets: all, min, hardware, network, virtual, ohai, facter
```
