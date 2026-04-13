# HealthConnect Project - GCP 3-Tier VPC with Terraform

## Overview

This project builds a secure 3-tier network architecture in Google Cloud Platform (GCP) using Terraform for the fictional healthcare company **HealthConnect**.

The goal this project is to design and deploy a custom VPC that satisfies the following requirements:

- Logical isolation between tiers
- Controlled outbound internet access through Cloud NAT
- Zero-trust administrative access using Identity-Aware Proxy (IAP)
- Infrastructure as Code (IaC) using Terraform

## Architecture

The environment includes:

- **Custom Mode VPC**
- **Public Subnet**: `10.0.1.0/24`
- **Private App Subnet**: `10.0.2.0/24`
- **Data-Isolated Subnet**: `10.0.3.0/24`
- **Cloud Router**
- **Cloud NAT**
- **Firewall Rule for IAP SSH**
- **Firewall Rule allowing Public -> Private-App on TCP 8080**
- **Verification VM** deployed in the private-app subnet with **no public IP**

## Project Files

- `provider.tf` - Configures the Google provider. Tells Terraform which cloud to build on
- `variables.tf` - Declares reusable input variables
- `terraform.tfvars` - Stores environment-specific values such as project ID and region
- `network.tf` - Defines the VPC, subnets, NAT, firewall rules, and verification VM
- `.gitignore` - Prevents sensitive/local Terraform files from being uploaded to GitHub

## Security Design

### Logical Isolation
Each subnet uses a separate, non-overlapping CIDR range:

- Public: `10.0.1.0/24`
- Private App: `10.0.2.0/24`
- Data: `10.0.3.0/24`

This separation supports the HealthConnect RFP requirement for network isolation.

### Controlled Egress
Instances in the private-app subnet do not receive external IP addresses.  
Outbound internet access is provided through **Cloud NAT**, which allows systems to download updates without being directly exposed to the internet.

### Zero Trust Access
SSH access is restricted to the Google IAP range:

- `35.235.240.0/20`

This prevents direct SSH access from the public internet.

## Verification VM

A small test VM named `hc-test-vm` is deployed in the private-app subnet to verify:

- No public IP is assigned
- IAP SSH works correctly
- Cloud NAT allows outbound traffic
- VPC Flow Logs / topology visibility can be tested

## Prerequisites

Before deployment, make sure you have:

- A Google Cloud project
- Billing enabled
- Terraform installed
- Google Cloud CLI (`gcloud`) installed
- Authenticated with GCP

## Deployment Steps

### 1. Authenticate to Google Cloud

```bash
gcloud auth application-default login
```

### 2. Initialize Terraform

```bash
terraform init
```

### 3. Format and validate the code

```bash
terraform fmt
terraform validate
```

### 4. Review the execution plan

```bash
terraform plan -var-file="terraform.tfvars"
```

### 5. Deploy the infrastructure

```bash
terraform apply -var-file="terraform.tfvars"
```

## Example terraform.tfvars

> Do not upload your real `terraform.tfvars` file to GitHub.

Example:

```hcl
project_id = "your-gcp-project-id"
region     = "us-central1"
vpc_name   = "healthconnect-vpc-prod"
```

## SSH Access Through IAP

After deployment, connect to the verification VM using:

```bash
gcloud compute ssh hc-test-vm \
  --zone=us-central1-a \
  --tunnel-through-iap
```

## GitHub Submission Notes

Upload these files to GitHub:

- `provider.tf`
- `variables.tf`
- `network.tf`
- `README.md`
- `.gitignore`
- `.terraform.lock.hcl`

Do **not** upload:

- `terraform.tfvars`
- `.terraform/`
- `*.tfstate`
- `*.tfstate.backup`

##  Objectives Demonstrated

Project Objectivess:

- Terraform resource creation in GCP
- Custom VPC design
- Subnet segmentation
- Firewall rule design using least privilege
- Cloud NAT configuration
- Private VM deployment without public IP
- IAP-based administration

## Author

Created for a Capstone Sprint 1. Project focused on secure cloud network design for HealthConnect.

## Technical Features (Updated Sprint 2)
​
- **Logical Isolation:** 3-tier subnets (Public, Private, Isolated).
- **Security:** IAP-based SSH access and Cloud NAT for secure egress.
- **Identity & Access:** OS Login for centralized SSH identity on `hc-test-vm`.
- **Automation:** Ansible playbooks for:
  - Baseline configuration (curl/jq/unzip, proof file)
  - Web server setup (Nginx) served via WSL inventory with IAP tunneled SSH
- **Auditability:** Cloud Audit Logs providing evidence trail.
​
## Getting Started
​
### Prerequisites
- Google Cloud SDK
- Terraform >= 1.4.0
- Ansible >= 2.x
- WSL Ubuntu with gcloud CLI (installed inside WSL)
​
### Deployment
1. Set your `project_id` in `terraform.tfvars` (see `terraform.tfvars.example`)
2. Run:
   ```bash
   terraform init
   terraform apply
3. Configure Ansible inventory (WSL-only workflow with IAP tunneled SSH):
   ```bash
# In WSL
cd ansible
# Follow the Sprint 2 Lab Guide for inventory.ini and key setup
ansible webservers -i inventory.ini -m ping
ansible-playbook -i inventory.ini site.yml
# To run web server setup
ansible-playbook -i inventory.ini websetup.yml
# Verify Nginx is serving (replace webservers with your inventory group)
ansible webservers -i inventory.ini -a "curl -s http://localhost"