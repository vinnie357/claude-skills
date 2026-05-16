# External Secret Backend Reference

## HashiCorp Vault

Requires the `community.hashi_vault` collection:

```bash
ansible-galaxy collection install community.hashi_vault
pip install hvac
```

### Token Authentication

```yaml
# vars/secrets.yml — retrieved at runtime, never stored in repo
db_password: "{{ lookup('community.hashi_vault.hashi_vault',
    'secret/data/myapp/db',
    return_format='dict',
    url='https://vault.example.com',
    token=lookup('env', 'VAULT_TOKEN')) | json_query('data.password') }}"
```

### AppRole Authentication (for CI/automation)

```yaml
db_password: "{{ lookup('community.hashi_vault.hashi_vault',
    'secret/data/myapp/db password',
    auth_method='approle',
    role_id=lookup('env', 'VAULT_ROLE_ID'),
    secret_id=lookup('env', 'VAULT_SECRET_ID'),
    url='https://vault.example.com') }}"
```

### AWS IAM Authentication

```yaml
db_password: "{{ lookup('community.hashi_vault.hashi_vault',
    'secret/data/myapp/db password',
    auth_method='aws_iam',
    url='https://vault.example.com') }}"
```

### Configuring via Environment Variables

Set these in your shell or CI pipeline to avoid repeating connection details in every lookup:

```bash
export VAULT_ADDR=https://vault.example.com
export VAULT_TOKEN=hvs.xxxxx
# Then lookups can omit url and token:
```

```yaml
db_password: "{{ lookup('community.hashi_vault.hashi_vault',
    'secret/data/myapp/db password') }}"
```

## AWS Secrets Manager

Requires the `amazon.aws` collection:

```bash
ansible-galaxy collection install amazon.aws
pip install boto3
```

```yaml
# Retrieve a secret value
db_password: "{{ lookup('amazon.aws.aws_secret',
    'myapp/production/db_password',
    region='us-east-1') }}"

# Retrieve a JSON secret and extract a field
db_config: "{{ lookup('amazon.aws.aws_secret',
    'myapp/production/db_config',
    region='us-east-1') | from_json }}"
db_password: "{{ db_config.password }}"
```

## AWS SSM Parameter Store

```yaml
# Retrieve a plain SecureString parameter
db_password: "{{ lookup('amazon.aws.aws_ssm',
    '/myapp/production/db_password',
    region='us-east-1') }}"

# Retrieve all parameters under a path prefix
app_params: "{{ lookup('amazon.aws.aws_ssm',
    '/myapp/production/',
    shortnames=true,
    recursive=true,
    region='us-east-1') }}"
# app_params is now a dict: {"db_password": "...", "api_key": "..."}
```

## Azure Key Vault

Requires the `azure.azcollection` collection:

```bash
ansible-galaxy collection install azure.azcollection
```

```yaml
db_password: "{{ lookup('azure.azcollection.azure_keyvault_secret',
    'db-password',
    vault_url='https://mykeyvault.vault.azure.net') }}"
```

Authentication uses the same credential chain as the Azure inventory plugin (`AZURE_CLIENT_ID`, `AZURE_SECRET`, `AZURE_TENANT`, etc.).

## Handling Lookup Failures

By default a failed lookup raises an error and stops the play. Handle failures gracefully:

```yaml
# Provide a fallback default (empty string if secret not found)
db_password: "{{ lookup('amazon.aws.aws_ssm', '/myapp/db_pass',
    region='us-east-1',
    errors='warn') | default('') }}"

# Use default() filter to provide a fallback
api_key: "{{ lookup('env', 'API_KEY') | default(lookup('community.hashi_vault.hashi_vault',
    'secret/data/api api_key'), true) }}"
```

Use `errors='warn'` (warn and continue) instead of the default `errors='fatal'` (stop play) when a missing secret is acceptable.

## Caching Lookup Results

Lookups run on every task evaluation by default. Cache the result in a variable to avoid repeated API calls:

```yaml
- name: Fetch all secrets once
  ansible.builtin.set_fact:
    db_password: "{{ lookup('community.hashi_vault.hashi_vault', 'secret/data/db password') }}"
    api_key: "{{ lookup('community.hashi_vault.hashi_vault', 'secret/data/api key') }}"
  run_once: true
  delegate_to: localhost
  no_log: true

- name: Use the cached secrets
  ansible.builtin.template:
    src: app.conf.j2
    dest: /etc/myapp/app.conf
  no_log: true
```

## Environment Variable Lookups (No Plugin Required)

For simple cases where secrets are injected via CI environment variables:

```yaml
db_password: "{{ lookup('env', 'DB_PASSWORD') }}"
api_key: "{{ lookup('env', 'API_KEY') }}"
```

Fail explicitly if a required variable is missing:

```yaml
- name: Assert required secrets are set
  ansible.builtin.assert:
    that:
      - lookup('env', 'DB_PASSWORD') | length > 0
      - lookup('env', 'API_KEY') | length > 0
    fail_msg: "Required environment variables DB_PASSWORD and API_KEY must be set"
```
