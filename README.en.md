# distributed-x-infrastructure-single-dev-ecs · Single ECS Dev Host · Huawei Cloud Practice

![License](https://img.shields.io/badge/License-MIT--0-blue.svg)
![Huawei Cloud](https://img.shields.io/badge/Huawei%20Cloud-ECS-orange.svg)
![IaC](https://img.shields.io/badge/IaC-Terraform--1.96-success.svg)

## 1. Overview

### Overview

A best practice for a single ECS development host on Huawei Cloud that is **created on demand and can be stopped and rebuilt at any time**. Use Terraform to bring up a fixed-spec ECS with one command, preinstalled with Git, Node (nvm), Python, and the Huawei Cloud SDK; `stop` it when not in use, and `destroy` it when no longer needed. Suitable for engineers and teams who need a "clean Linux box" for verification, builds, and learning.

---

## 2. Table of Contents

- [1. Overview](#1-overview)
- [2. Table of Contents](#2-table-of-contents)
- [3. Architecture Diagram](#3-architecture-diagram)
- [4. Highlights](#4-highlights)
- [5. Cloud Services Used](#5-cloud-services-used)
- [6. Prerequisites](#6-prerequisites)
- [7. Quick Start](#7-quick-start)
- [8. Step-by-Step Deployment](#8-step-by-step-deployment)
- [9. Usage / Verification](#9-usage--verification)
- [10. Cleanup](#10-cleanup)
- [11. Detailed Explanation](#11-detailed-explanation)
- [12. Dependencies](#12-dependencies)
- [13. FAQ / Troubleshooting](#13-faq--troubleshooting)
- [14. Contributing](#14-contributing)
- [15. License](#15-license)
- [16. Contact / Maintainers](#16-contact--maintainers)

---

## 3. Architecture Diagram

```mermaid
graph TD
User([Developer]) -->|SSH 22 / EIP| ECS[(ECS dev host<br/>s6.large.2 · CentOS 7.9)]
EIP[Elastic IP] -->|bind| ECS
ECS --> SG[Security group: inbound 22 only]
ECS --> Subnet[Subnet 10.0.1.0/24]
Subnet --> VPC[VPC 10.0.0.0/16]
ECS -.->|update A record on boot (optional)| DNS[(Cloud DNS)]
Agency[IAM agency of ECS type] -.->|temporary credentials| ECS
```

---

## 4. Highlights

- **One-command IaC**: declarative Terraform management; recreate a "clean environment" with zero manual steps.
- **Controllable cost**: `stop`/`destroy` when idle; minimal spec means very low overhead.
- **Secure access**: key pair + security group (SSH port 22 only); credentials provided only via environment variables, never written to disk.
- **Optional DNS**: when enabled, the ECS writes its EIP into the Cloud DNS A record on every boot.

---

## 5. Cloud Services Used

- ECS (Elastic Cloud Server)
- VPC (Virtual Private Cloud)
- EIP (Elastic IP)
- IAM (Identity and Access Management)
- Cloud DNS (optional)

---

## 6. Prerequisites

- Huawei Cloud account with permissions to create VPC / ECS / EIP / key pair / (optional) DNS.
- Locally installed [Terraform](https://www.terraform.io/downloads) ≥ 1.5 and Python ≥ 3.7.
- Credentials configured (environment variables only, never written to disk):
```bash
export HW_ACCESS_KEY="<HW_ACCESS_KEY>"
export HW_SECRET_KEY="<HW_SECRET_KEY>"
```
- An SSH public key prepared (e.g. `~/.ssh/id_rsa.pub`).

---

## 7. Quick Start

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars # edit as needed (public_key via CLI injection recommended)
terraform init
terraform apply -var="public_key=$(cat ~/.ssh/id_rsa.pub)"
terraform output ssh_command # get the connection string
```

---

## 8. Step-by-Step Deployment

1. Copy `terraform.tfvars.example` to `terraform.tfvars`.
2. Prepare an SSH public key; using variable injection is recommended.
3. Run `terraform init` to initialize the provider.
4. Run `terraform apply` to deploy.
5. Get the connection string with `terraform output ssh_command`.
6. Verify SSH login and that Node/nvm/Git are available.

---

## 9. Usage / Verification

### Usage / Verification

Get the SSH connection string with `terraform output`, and use the `src/scripts/ecs` script to stop/start the host and check status, as described below.

```bash
# Generate outputs.json for operations scripts
terraform output -json > src/outputs.json
cp src/configs/config.json.example src/configs/config.json
pip install -r src/scripts/requirements.txt

# Stop/start and status
python src/scripts/ecs status
python src/scripts/ecs stop # stop
python src/scripts/ecs start

# After writing to ~/.ssh/config, just `ssh <nick_name>`
python src/scripts/setssh
ssh <nick_name>
```

Success indicators: SSH login works; `node -v` / `nvm -v` / `git --version` are available; with DNS enabled, `dig +short <ecs_name>.<domain>` resolves to the EIP.

After deployment, follow these steps to verify that the business functionality works before considering the delivery complete.

---

## 10. Cleanup

```bash
terraform destroy
# and query the API directly to confirm no leftovers (EIP / ECS / orphaned disks, etc.)
```

---

## 11. Detailed Explanation

- Architecture and resources: see [docs/architecture.md](docs/architecture.md)
- Deployment steps: see [docs/deployment-guide.md](docs/deployment-guide.md)

---

## 12. Dependencies

- Huawei Cloud Terraform Provider (`huaweicloud`)
- Huawei Cloud native services: ECS / VPC / EIP / IAM / Cloud DNS

---

## 13. FAQ / Troubleshooting

### FAQ

- **SSH connection fails**: check whether `ssh_allowed_cidr` is narrowed to a non-local IP; the EIP does not change after ECS restart — if you get a host-key change warning, run `ssh-keygen -R <ip>` first.
- **Image not found**: if the target region has no `CentOS 7.9 64bit`, change the `image_name` variable (e.g. `Huawei Cloud EulerOS 2.0 64bit`).
- **DNS not effective**: confirm `account_domain` (IAM account domain name) is correct, `dns_zone_id` is filled, and the ECS has the agency bound; run `python3 /var/lib/cloud/scripts/per-boot/set-dns` manually to see the output.

---

## 14. Contributing

Issues and PRs are welcome. Please follow the repository's existing directory structure and code style.

---

## 15. License

This practice is licensed under **MIT No Attribution**, see the [`LICENSE`](LICENSE) file in the repository root.

This practice is released under the **MIT-0** license. See [LICENSE](LICENSE).

---

## 16. Contact / Maintainers
| Item | Content |
|---|---|
| **Creator** | [dgc-git](https://github.com/dgc-git) |
| **Maintainer** | [dgc-git](https://github.com/dgc-git) |
| **Contact** | GitHub Issues / PR (see [Section 14](#14-contributing)) |
