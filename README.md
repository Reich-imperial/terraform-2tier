# Terraform Two-Tier AWS Architecture

![Terraform](https://img.shields.io/badge/terraform-%3E%3D1.3.0-623CE4)
![AWS](https://img.shields.io/badge/provider-aws-orange)
![CI](https://img.shields.io/badge/CI-plan--on--PR%2C%20apply--on--merge-blue)

A classic two-tier AWS architecture — public web tier behind a load balancer, private database tier reachable only from the web tier — provisioned entirely with Terraform and deployed through a GitHub Actions pipeline that plans on every pull request and applies on merge to `main`.

---

## Architecture

```
Internet
   │
   ▼
Application Load Balancer  (public subnets: us-east-1a + us-east-1b)
   │  HTTP :80 → target group → health check every 30s, path "/"
   ▼
web01 (EC2, public subnet)         Nginx, bootstrapped via user_data
   │  MySQL :3306 (security-group-to-security-group only)
   ▼
db01 (EC2, private subnet)         MySQL 8, no public IP, no internet route
```

- **VPC**: `10.1.0.0/16`, DNS support/hostnames enabled
- **Public subnets**: `10.1.1.0/24` (us-east-1a) + a second subnet in us-east-1b — the ALB requires two AZs, so the second public subnet exists purely to satisfy that requirement
- **Private subnet**: `10.1.2.0/24` (us-east-1b) — no route to the internet gateway, so `db01` gets no path out and no path in from outside the VPC
- **Bastion pattern**: `db01` has no public IP; you SSH to `web01` first, then hop to `db01` from there

---

## Security model

Every rule is scoped as tightly as Terraform allows:

| Tier | Inbound | Outbound |
|---|---|---|
| ALB | HTTP :80 and HTTPS :443 from `0.0.0.0/0` | All (needs to forward to targets) |
| web01 | HTTP :80 **only from the ALB's security group** (not from the internet directly); SSH :22 open for admin access | All |
| db01 | MySQL :3306 **only from web01's security group**; SSH :22 **only from web01's security group** (bastion hop) | All |

The database is never reachable from the public internet, and the web server never receives traffic except through the ALB — both enforced with security-group-to-security-group references rather than CIDR ranges, so the rule holds even if IPs change.

---

## What Terraform manages

| File | Responsibility |
|---|---|
| `main.tf` | Provider config, S3 remote state backend, default resource tags |
| `vpc.tf` | VPC, both public subnets, private subnet, Internet Gateway, route tables and associations, AMI lookup |
| `ec2.tf` | `web01` (Nginx, public) and `db01` (MySQL 8, private), both self-configuring via `user_data` on first boot |
| `alb.tf` | Application Load Balancer, target group with health checks, listener, target registration |
| `sg.tf` | Three security groups (ALB, web, db) with least-privilege ingress/egress |
| `variable.tf` | All configurable inputs — region, environment, CIDRs, instance type, key pair name |
| `outputs.tf` | ALB DNS name, instance IPs, and ready-to-paste SSH commands for both instances |

**Remote state:**
```
bucket: terraform-state-samson-2tier
key:    terraform-2tier/terraform.tfstate
region: us-east-1
```

---

## CI/CD — GitHub Actions

Two jobs, gated by event type:

**On pull request → `terraform-plan`**
1. `terraform init` → `terraform fmt -check -recursive` → `terraform validate`
2. `terraform plan`, output captured
3. Plan results (format check, validate, plan) posted as a comment on the PR, with the full plan output in a collapsible section — so a reviewer sees exactly what will change before approving

**On push to `main` → `terraform-apply`**
1. `terraform init` → `terraform validate` → `terraform plan` → `terraform apply -auto-approve`
2. Outputs (ALB DNS name, instance IPs) printed at the end of the run

This means infrastructure changes go through the same review discipline as application code — nothing reaches AWS without a plan being visible on the PR first.

---

## Usage

### Prerequisites
- Terraform >= 1.3.0
- An AWS account and credentials configured (locally via `aws configure`, or as `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` GitHub Secrets for CI)
- An existing EC2 key pair (default variable expects one named `samson-key`)

### Deploy locally

```bash
git clone https://github.com/Reich-imperial/terraform-2tier.git
cd terraform-2tier

terraform init
terraform plan
terraform apply
```

### Outputs after apply

```bash
terraform output alb_dns_name        # paste into a browser
terraform output ssh_to_web01        # ready-to-run SSH command
terraform output ssh_to_db01_via_web01  # run this FROM web01
```

Retrieve the MySQL temporary root password (generated on first boot) by SSHing to `web01`, hopping to `db01`, then:
```bash
cat /tmp/setup.log
```

### Tear down

```bash
terraform destroy
```

---

## Key engineering decisions

**Why a second public subnet that isn't strictly needed for traffic?**
AWS requires an Application Load Balancer to span at least two Availability Zones. The second public subnet exists solely to satisfy that constraint — it carries no additional application logic.

**Why security-group references instead of CIDR blocks for internal traffic?**
`db01`'s security group allows MySQL only from instances carrying the web security group, not from the private subnet's CIDR range. If `web01`'s IP changes, or another instance is later added to the public subnet, the rule doesn't silently become more permissive — it stays scoped to exactly the resources that should have access.

**Why is instance bootstrapping done via `user_data` instead of a config management tool?**
At this scale (two EC2 instances), a shell script attached as `user_data` is enough to demonstrate the core idea — infrastructure that configures itself on boot, no manual SSH-and-install step. This is the same principle tools like Ansible, Packer, and cloud-init build on at larger scale.

**Why does `terraform apply` still run automatically on merge, given the risks of unattended infrastructure changes?**
This is a learning/portfolio project without a production database to protect, so automatic apply-on-merge is an intentional choice to demonstrate a full CI/CD loop end-to-end. For anything with real data at stake, see the approval-gated pattern described in [`fleet-platform`](https://github.com/Reich-imperial/fleet-platform)'s Terraform section, where `apply` is deliberately kept manual.

---

## Related projects

[`fleet-platform`](https://github.com/Reich-imperial/fleet-platform) — a similar Terraform-provisioned AWS deployment (single EC2 + Docker Compose stack) with a full CI/CD pipeline to ECR and manual, gated `terraform apply`.

---

## Author

Samson Olanipekun — DevOps / Cloud Engineering
GitHub: [github.com/Reich-imperial](https://github.com/Reich-imperial)
LinkedIn: [linkedin.com/in/samson-olanipekun-devops](https://linkedin.com/in/samson-olanipekun-devops)
