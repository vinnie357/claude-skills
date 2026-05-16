---
name: ansible-vault
description: Guide for Ansible Vault secrets management and security practices. Use when encrypting variables or files with ansible-vault, configuring vault passwords, using vault IDs, or applying security hardening to playbooks.
license: MIT
---

# Ansible Vault

Activate when encrypting secrets, managing vault passwords, configuring vault IDs, or applying security hardening to Ansible playbooks and variable files.

## Why Vault Exists

Secrets (passwords, API keys, certificates) must never be committed to version control in plaintext. Ansible Vault encrypts secrets at rest using AES-256 so they can be safely committed to git while remaining usable by Ansible at runtime.

## ansible-vault CLI Commands

```bash
# Create a new encrypted file
ansible-vault create secrets.yml

# Encrypt an existing file
ansible-vault encrypt vars/db_password.yml

# Decrypt a file to plaintext (use with caution)
ansible-vault decrypt vars/db_password.yml

# View encrypted content without decrypting the file
ansible-vault view vars/secrets.yml

# Edit an encrypted file (opens $EDITOR)
ansible-vault edit vars/secrets.yml

# Change the vault password on an encrypted file
ansible-vault rekey vars/secrets.yml

# Encrypt a single string value (paste the output inline in YAML)
ansible-vault encrypt_string 'my-secret-value' --name 'db_password'
```

## Encrypting Individual Variables

Use `encrypt_string` to encrypt a single value and embed it inline in an otherwise plain YAML file:

```bash
ansible-vault encrypt_string 'super_secret_pw' --name 'db_password'
```

Output to paste into your vars file:

```yaml
db_password: !vault |
  $ANSIBLE_VAULT;1.1;AES256
  61383334343430363636393231363962626536346232613...
  ...
```

This lets you keep most vars readable while encrypting only the sensitive ones.

## Encrypting Entire Files

For files that are entirely sensitive (private keys, certificates), encrypt the whole file:

```bash
ansible-vault encrypt roles/app/files/server.key
```

The `copy:` module works transparently with vault-encrypted files — Ansible decrypts at runtime before copying.

## Vault Password Sources

Ansible needs the vault password at runtime to decrypt. Provide it in one of these ways:

```bash
# Interactive prompt (good for one-off runs)
ansible-playbook site.yml --ask-vault-pass

# Password file (good for automation)
ansible-playbook site.yml --vault-password-file ~/.vault_pass

# Environment variable (set ANSIBLE_VAULT_PASSWORD_FILE in ansible.cfg or shell)
export ANSIBLE_VAULT_PASSWORD_FILE=~/.vault_pass
ansible-playbook site.yml
```

```ini
# ansible.cfg
[defaults]
vault_password_file = ~/.vault_pass
```

The password file should contain only the password string with no trailing newline. Protect it with `chmod 600`.

## Vault IDs

Vault IDs let you manage multiple passwords — useful when different environments (dev, prod) or different secret types use different passwords.

```bash
# Encrypt with a vault ID label
ansible-vault encrypt_string 'dev_secret' --name 'api_key' --vault-id dev@prompt
ansible-vault encrypt_string 'prod_secret' --name 'api_key' --vault-id prod@~/.prod_vault_pass

# Run with multiple vault IDs
ansible-playbook site.yml \
  --vault-id dev@~/.dev_vault_pass \
  --vault-id prod@~/.prod_vault_pass
```

Encrypted values tagged with a vault ID look like:

```yaml
api_key: !vault |
  $ANSIBLE_VAULT;1.2;AES256;prod
  ...
```

## Organizing Vault Files with group_vars

A common pattern: keep plaintext vars and vault vars side by side in a directory:

```
inventory/
└── group_vars/
    └── production/
        ├── vars.yml       # plaintext — committed as-is
        └── vault.yml      # encrypted — committed safely
```

```yaml
# vars.yml — plaintext reference file
db_host: db.example.com
db_user: app
db_password: "{{ vault_db_password }}"   # references the vaulted var
```

```yaml
# vault.yml — encrypted file, edit with: ansible-vault edit
vault_db_password: actual_secret_here
```

Prefix vault variables with `vault_` to make it obvious where they come from.

## Security Practices

**Prevent plaintext leakage in task output:**

```yaml
- name: Set database password
  ansible.builtin.command: "db-cli set-password {{ db_password }}"
  no_log: true          # suppress this task's output entirely
```

**Suppress skipped host output:**

```bash
ANSIBLE_DISPLAY_SKIPPED_HOSTS=false ansible-playbook site.yml
```

**Protect local files:**

```bash
chmod 600 ~/.vault_pass
echo ".vault_pass" >> .gitignore
echo "*.key" >> .gitignore
```

**Audit what's encrypted before committing:**

```bash
git diff --cached | grep -E "^\+.*\$ANSIBLE_VAULT"
```

Never use `ansible-vault decrypt` on a file you intend to commit — keep encrypted versions in the repo.

## External Secret Backends

For production environments, consider lookup plugins that retrieve secrets from a dedicated secrets manager at runtime instead of storing vault-encrypted values in the repo.

```yaml
# HashiCorp Vault lookup (requires community.hashi_vault collection)
db_password: "{{ lookup('community.hashi_vault.hashi_vault',
    'secret/data/myapp/db password',
    url='https://vault.example.com',
    token=lookup('env', 'VAULT_TOKEN')) }}"

# AWS SSM Parameter Store (requires amazon.aws collection)
db_password: "{{ lookup('amazon.aws.aws_ssm',
    '/myapp/production/db_password',
    region='us-east-1') }}"

# Simple environment variable lookup (no collection needed)
api_key: "{{ lookup('env', 'MY_API_KEY') }}"
```

## References

- **[secret-backends.md](references/secret-backends.md)** — HashiCorp Vault, AWS Secrets Manager, AWS SSM, Azure Key Vault lookup plugin examples with authentication config and failure handling
