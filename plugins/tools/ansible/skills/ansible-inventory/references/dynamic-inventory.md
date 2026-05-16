# Dynamic Inventory Reference

## AWS EC2 Inventory Plugin

Requires the `amazon.aws` collection:

```bash
ansible-galaxy collection install amazon.aws
pip install boto3 botocore
```

```yaml
# inventory/aws_ec2.yml
# File must end in aws_ec2.yml or aws_ec2.yaml
plugin: amazon.aws.aws_ec2

regions:
  - us-east-1
  - us-west-2

# Credentials — prefer environment variables or IAM roles over hardcoded values
# AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN
# Or configure a profile in ~/.aws/credentials:
# boto_profile: myprofile

filters:
  instance-state-name: running          # only running instances
  tag:Environment: production           # filter by tag
  tag:Role:                             # any value for this tag
    - webserver
    - appserver

# What to use as the inventory hostname
hostnames:
  - private-ip-address                  # use private IP (common for internal VPC access)
  # - tag:Name                          # use Name tag
  # - dns-name                          # use public DNS

# Build groups from instance properties
keyed_groups:
  - key: tags.Role                      # group by Role tag value
    prefix: role
    separator: "_"
  - key: tags.Environment
    prefix: env
  - key: placement.region
    prefix: region
  - key: instance_type
    prefix: type

# Add all instances to a top-level group
groups:
  aws_ec2: true                         # group all EC2 instances together

# Set host variables from instance attributes
compose:
  ansible_host: private_ip_address      # connect via private IP
  ansible_user: "'ubuntu'"             # hardcode SSH user for all
```

Verify the output:

```bash
ansible-inventory -i inventory/aws_ec2.yml --list
ansible-inventory -i inventory/aws_ec2.yml --graph
```

## Azure Resource Manager Inventory Plugin

Requires the `azure.azcollection` collection:

```bash
ansible-galaxy collection install azure.azcollection
pip install -r ~/.ansible/collections/ansible_collections/azure/azcollection/requirements.txt
```

```yaml
# inventory/azure_rm.yml
plugin: azure.azcollection.azure_rm

# Authentication — prefer environment variables:
# AZURE_SUBSCRIPTION_ID, AZURE_CLIENT_ID, AZURE_SECRET, AZURE_TENANT
auth_source: auto                       # tries env vars, then CLI credentials

include_vm_resource_groups:
  - my-app-rg
  - my-db-rg
# exclude_vm_resource_groups:
#   - staging-rg

# Build groups from Azure tags
keyed_groups:
  - key: tags.Environment | default('untagged')
    prefix: env
  - key: tags.Role | default('untagged')
    prefix: role

# Use private IP for connection
hostnames:
  - default                             # uses the VM name

compose:
  ansible_host: private_ipv4_addresses[0]
```

## GCP Compute Engine Inventory Plugin

Requires the `google.cloud` collection:

```bash
ansible-galaxy collection install google.cloud
pip install requests google-auth
```

```yaml
# inventory/gcp_compute.yml
plugin: google.cloud.gcp_compute

projects:
  - my-gcp-project-id

zones:
  - us-central1-a
  - us-central1-b

# Authenticate via service account key or application default credentials
# auth_kind: serviceaccount
# service_account_file: /path/to/key.json
# Or set GOOGLE_APPLICATION_CREDENTIALS env var

filters:
  - status = RUNNING
  - labels.environment = production

keyed_groups:
  - key: labels.role
    prefix: role
  - key: zone
    prefix: zone

compose:
  ansible_host: networkInterfaces[0].networkIP    # private IP
```

## Constructing Groups from Tags

The `constructed` inventory plugin can post-process any other inventory source to add groups based on variable values:

```yaml
# inventory/constructed.yml
plugin: ansible.builtin.constructed

# Point to another inventory source
strict: false

# Create groups from expressions
groups:
  # Group hosts that have the "webserver" role tag
  webservers: "'webserver' in (tags | default({}) | dict2items | map(attribute='value'))"

  # Group hosts in us-east-1
  us_east: "placement.region == 'us-east-1'"

# Compose new host variables from existing ones
compose:
  # Set ansible_host based on environment
  ansible_host: >-
    private_ip_address if tags.Environment == 'production'
    else public_ip_address
```

## Testing Dynamic Inventory

Before running a playbook, always verify dynamic inventory output:

```bash
# List all hosts and their variables as JSON
ansible-inventory -i inventory/ --list | jq .

# Show host tree grouped by inventory groups
ansible-inventory -i inventory/ --graph

# Show all variables for a specific host
ansible-inventory -i inventory/ --host 10.0.1.15

# Test connectivity to all dynamic hosts
ansible all -i inventory/ -m ping

# Limit to one group
ansible role_webserver -i inventory/ -m ping

# Combine static and dynamic inventory
ansible all -i inventory/hosts.ini -i inventory/aws_ec2.yml -m ping
```

## Caching Dynamic Inventory

Dynamic inventory can be slow when querying large cloud environments. Enable caching:

```ini
# ansible.cfg
[inventory]
cache = true
cache_plugin = jsonfile
cache_connection = /tmp/ansible_inventory_cache
cache_timeout = 3600    # seconds (1 hour)
```

Or per-plugin:

```yaml
# inventory/aws_ec2.yml
plugin: amazon.aws.aws_ec2
cache: true
cache_plugin: jsonfile
cache_connection: /tmp/aws_inventory_cache
cache_timeout: 3600
```

Clear the cache:

```bash
ansible-inventory -i inventory/ --list --refresh-cache
```
