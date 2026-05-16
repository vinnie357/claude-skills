# Jinja2 Filter and Test Reference

## String Filters

```jinja
{{ name | upper }}                    {# "hello" → "HELLO" #}
{{ name | lower }}                    {# "HELLO" → "hello" #}
{{ name | capitalize }}               {# "hello world" → "Hello world" #}
{{ name | title }}                    {# "hello world" → "Hello World" #}
{{ name | replace("old", "new") }}    {# string substitution #}
{{ name | trim }}                     {# strip leading/trailing whitespace #}
{{ name | truncate(20) }}             {# truncate to 20 chars with "..." #}
{{ text | wordwrap(80) }}             {# wrap text at 80 characters #}
{{ value | string }}                  {# convert to string #}
{{ name | regex_replace('^www\.', '') }}  {# regex substitution #}
{{ name | regex_search('(\d+)') }}    {# extract first match #}
```

## List Filters

```jinja
{{ list | join(', ') }}               {# ["a", "b", "c"] → "a, b, c" #}
{{ list | first }}                    {# first element #}
{{ list | last }}                     {# last element #}
{{ list | length }}                   {# count elements #}
{{ list | sort }}                     {# sort ascending #}
{{ list | reverse | list }}           {# reverse order #}
{{ list | unique }}                   {# remove duplicates #}
{{ list | flatten }}                  {# flatten nested lists one level #}
{{ list | flatten(levels=2) }}        {# flatten 2 levels deep #}
{{ list | min }}                      {# smallest value #}
{{ list | max }}                      {# largest value #}
{{ list | sum }}                      {# sum numeric values #}
{{ list | random }}                   {# random element #}
{{ list | shuffle }}                  {# randomly reorder #}
{{ list | select('match', '^web') | list }}  {# filter by regex match #}
{{ list | reject('equalto', 'skip_me') | list }}  {# exclude values #}
{{ list | map('upper') | list }}      {# apply filter to each element #}
{{ list | zip(other_list) | list }}   {# pair two lists element-wise #}
```

## List of Dicts Filters

```jinja
{# Filter objects where attribute matches a value #}
{{ users | selectattr('active', 'equalto', true) | list }}

{# Filter objects where attribute is defined #}
{{ users | selectattr('email', 'defined') | list }}

{# Extract one attribute from each object #}
{{ users | map(attribute='name') | list }}

{# Sort by attribute #}
{{ users | sort(attribute='name') }}

{# Group by attribute → dict of lists #}
{{ users | groupby('department') }}

{# Find first match #}
{{ users | selectattr('name', 'equalto', 'alice') | first }}
```

## Dict Filters

```jinja
{{ my_dict | dict2items }}            {# [{"key": k, "value": v}, ...] #}
{{ items_list | items2dict }}         {# reverse of dict2items #}
{{ my_dict | combine(other_dict) }}   {# merge dicts (other_dict wins on conflict) #}
{{ my_dict.keys() | list }}           {# list of keys #}
{{ my_dict.values() | list }}         {# list of values #}
{{ my_dict | length }}                {# number of keys #}
```

## Path and File Filters

```jinja
{{ "/etc/nginx/nginx.conf" | basename }}      {# "nginx.conf" #}
{{ "/etc/nginx/nginx.conf" | dirname }}       {# "/etc/nginx" #}
{{ "nginx.conf" | splitext }}                 {# ["nginx", ".conf"] #}
{{ path | expanduser }}                       {# expand ~ #}
{{ path | realpath }}                         {# resolve symlinks #}
{{ "/etc" | path_join("nginx", "conf.d") }}   {# "/etc/nginx/conf.d" #}
```

## Type Conversion Filters

```jinja
{{ "42" | int }}                      {# string → integer #}
{{ "3.14" | float }}                  {# string → float #}
{{ value | bool }}                    {# truthy → True/False #}
{{ value | string }}                  {# any → string #}
{{ value | list }}                    {# iterable → list #}
{{ dict | to_json }}                  {# serialize to JSON #}
{{ dict | to_nice_json }}             {# pretty-printed JSON #}
{{ json_str | from_json }}            {# parse JSON string #}
{{ dict | to_yaml }}                  {# serialize to YAML #}
{{ yaml_str | from_yaml }}            {# parse YAML string #}
```

## Default and Fallback Filters

```jinja
{# Return default if variable is undefined or empty #}
{{ my_var | default('fallback') }}

{# Return default only if variable is undefined (not if empty string) #}
{{ my_var | default('fallback', boolean=true) }}

{# Omit the key entirely from a module call if variable is undefined #}
{{ my_var | default(omit) }}

{# Example: only set owner if defined #}
ansible.builtin.file:
  path: /var/app
  owner: "{{ file_owner | default(omit) }}"
```

## Hash and Encoding Filters

```jinja
{{ "password" | password_hash('sha512') }}    {# hash for /etc/shadow #}
{{ data | b64encode }}                        {# base64 encode #}
{{ encoded | b64decode }}                     {# base64 decode #}
{{ text | hash('sha256') }}                   {# SHA-256 hex digest #}
{{ text | checksum }}                         {# SHA-1 checksum #}
```

## Jinja2 Tests

Tests return `true`/`false` and are used with `is`:

```jinja
{% if my_var is defined %}            {# variable exists #}
{% if my_var is undefined %}          {# variable does not exist #}
{% if my_var is none %}               {# variable is null #}
{% if my_var is string %}             {# is a string type #}
{% if my_var is number %}             {# is a number type #}
{% if my_var is iterable %}           {# can be iterated #}
{% if my_var is mapping %}            {# is a dict #}
{% if my_var is sequence %}           {# is a list or string #}
{% if my_var is sameas other %}       {# identical object #}
{% if my_var is equalto 42 %}         {# equals value #}
{% if path is file %}                 {# path is a file (Ansible-specific) #}
{% if path is directory %}            {# path is a directory #}
{% if path is link %}                 {# path is a symlink #}
{% if version is version('2.0', '>=') %}  {# version comparison #}
```

## Common Template Patterns

### Config file with conditional sections

```jinja
{# nginx.conf.j2 #}
user {{ nginx_user | default('www-data') }};
worker_processes {{ nginx_worker_processes | default('auto') }};

{% if nginx_error_log is defined %}
error_log {{ nginx_error_log }};
{% else %}
error_log /var/log/nginx/error.log warn;
{% endif %}

events {
    worker_connections {{ nginx_worker_connections | default(1024) }};
    {% if nginx_multi_accept | default(false) %}
    multi_accept on;
    {% endif %}
}
```

### Iterating a list of dicts to produce config blocks

```jinja
{# haproxy.cfg.j2 #}
{% for backend in haproxy_backends %}
backend {{ backend.name }}
    balance {{ backend.balance | default('roundrobin') }}
    {% for server in backend.servers %}
    server {{ server.name }} {{ server.host }}:{{ server.port }} check
    {% endfor %}

{% endfor %}
```

### Building a list of values from group members

```jinja
{# List all webserver IPs for an upstream block #}
{% for host in groups['webservers'] %}
    server {{ hostvars[host].ansible_host }}:8080 weight=1;
{% endfor %}
```

### Conditional include of a config section

```jinja
{% if ssl_enabled | default(false) | bool %}
    ssl_certificate {{ ssl_cert_path }};
    ssl_certificate_key {{ ssl_key_path }};
    ssl_protocols {{ ssl_protocols | default('TLSv1.2 TLSv1.3') }};
{% endif %}
```
