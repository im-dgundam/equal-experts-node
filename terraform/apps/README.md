# terraform/apps

Terraform manifests that provision a complete application stack: ECS Fargate cluster + service, an Application Load Balancer, a Fastly VCL CDN service, and an NGWAF workspace. The same code deploys to both **staging** and **production** — `var.platform` drives every resource name so the two environments never conflict.

---

## Architecture

```
Internet
   │
   ▼
Fastly VCL Service  (staging.equalexperts.com / www.equalexperts.com)
   │  NGWAF inspects/blocks traffic at the edge
   │
   ▼ origin request
Application Load Balancer  (AWS, public subnets)
   │
   ▼
ECS Fargate Service  (private subnets, auto-scaling)
   │
   ▼
Gists API container  (port 8080)
```

---

## Resources created

### AWS

| Resource | Service | Notes |
|----------|---------|-------|
| `aws_ecs_cluster` | ECS | Container Insights enabled |
| `aws_ecs_cluster_capacity_providers` | ECS | FARGATE_SPOT (staging) / FARGATE (production) |
| `aws_ecs_task_definition` | ECS | Fargate, awsvpc networking |
| `aws_ecs_service` | ECS | Rolling deploy, circuit breaker + auto-rollback |
| `aws_appautoscaling_target/policy` × 2 | App Auto Scaling | CPU-based scale-out and scale-in |
| `aws_cloudwatch_metric_alarm` × 2 | CloudWatch | Triggers scaling policies |
| `aws_cloudwatch_log_group` | CloudWatch Logs | 14 days (staging) / 90 days (production) |
| `aws_lb` | ALB | Public; deletion protection on in production |
| `aws_lb_target_group` | ALB | IP target type for Fargate |
| `aws_lb_listener` HTTP | ALB | Redirects to HTTPS when `certificate_arn` set |
| `aws_lb_listener` HTTPS | ALB | Created only when `certificate_arn` is set |
| `aws_security_group` × 2 | VPC | ALB (public) and ECS tasks (ALB → container only) |
| `aws_iam_role` × 2 | IAM | Task execution role and task role |

### Fastly

| Resource | Notes |
|----------|-------|
| `fastly_ngwaf_workspace` | Per-platform NGWAF workspace with tuned attack-signal thresholds |
| `fastly_service_vcl` | VCL service with ALB as backend, HTTPS redirect snippet, NGWAF enabled |

---

## File layout

```
terraform/apps/
├── versions.tf          # Terraform, AWS provider, Fastly provider constraints
├── variables.tf         # All inputs (including var.platform + Fastly/NGWAF vars)
├── locals.tf            # name_prefix, common_tags, ngwaf_workspace_name
├── iam.tf               # Task execution and task IAM roles
├── security_groups.tf   # ALB and ECS task security groups
├── alb.tf               # ALB, target group, listeners
├── ecs.tf               # Cluster, task definition, service, auto-scaling
├── fastly.tf            # Fastly VCL service + NGWAF workspace
├── outputs.tf           # Cluster/service names, ALB DNS, Fastly IDs
├── envs/
│   ├── staging/
│   │   └── terraform.tfvars    # staging.equalexperts.com, NGWAF log mode
│   └── production/
│       └── terraform.tfvars    # www.equalexperts.com, NGWAF block mode
└── README.md
```

---

## Prerequisites

- Terraform >= 1.6
- AWS credentials with permissions to manage ECS, ALB, IAM, CloudWatch, and VPC
- A Fastly API key exported as `FASTLY_API_KEY` (or set as a Terraform variable)
- The VPC, subnets, and any ACM certificate must already exist

---

## Deploying

Export your Fastly API key before running Terraform:

```bash
export FASTLY_API_KEY="your-fastly-api-key"
```

### Staging

```bash
cd terraform/apps

terraform init -backend-config="key=gists-api/staging/terraform.tfstate"
terraform plan  -var-file=envs/staging/terraform.tfvars
terraform apply -var-file=envs/staging/terraform.tfvars
```

### Production

```bash
cd terraform/apps

terraform init -backend-config="key=gists-api/production/terraform.tfstate"
terraform plan  -var-file=envs/production/terraform.tfvars
terraform apply -var-file=envs/production/terraform.tfvars
```

> Each environment must use a **separate state file** (the `-backend-config key` differs). Terraform workspaces are an alternative.

### Remote state backend (recommended)

Add to `versions.tf`:

```hcl
terraform {
  backend "s3" {
    bucket         = "your-tfstate-bucket"
    region         = "eu-west-1"
    dynamodb_table = "your-tfstate-lock-table"
    encrypt        = true
    # key is supplied per-environment via -backend-config
  }
}
```

---

## DNS configuration

After `terraform apply`, point your domain's DNS to Fastly:

```bash
# Get the CNAME target
terraform output fastly_cname_target
```

| Environment | Domain | DNS record type | Value |
|-------------|--------|----------------|-------|
| Staging | `staging.equalexperts.com` | CNAME | `<fastly_service_id>.global.ssl.fastly.net` |
| Production | `www.equalexperts.com` | CNAME | `<fastly_service_id>.global.ssl.fastly.net` |

Fastly also requires the domain to be added to a TLS subscription in the Fastly console (or via `fastly_tls_subscription` resource) for HTTPS to work end-to-end at the Fastly edge.

---

## How `var.platform` works

Every resource name is composed as `<project>-<platform>-<suffix>`:

| `platform` | Example resource name |
|------------|----------------------|
| `staging` | `gists-api-staging-cluster` |
| `production` | `gists-api-production-vcl-service` |

The same `.tf` files apply to both environments by switching which `terraform.tfvars` file is passed in.

---

## NGWAF behaviour per environment

| Setting | Staging | Production |
|---------|---------|-----------|
| `fastly_domain` | `staging.equalexperts.com` | `www.equalexperts.com` |
| `ngwaf_mode` | `log` (observe only, no blocking) | `block` |
| `ngwaf_traffic_ramp` | 100% | 100% |
| 1-min threshold | 100 | 50 |
| 10-min threshold | 500 | 250 |
| 1-hour threshold | 1000 | 500 |
| `fastly_ssl_backend` | `false` (HTTP to ALB) | `true` (HTTPS to ALB) |
| `fastly_force_destroy` | `true` | `false` |

Staging runs in `log` mode so you can review NGWAF findings before enabling blocking in production. Promote to `block` in staging by changing `ngwaf_mode = "block"` in the staging tfvars.

---

## Connecting to the pipeline module

After `terraform apply`, pipe the outputs to `terraform/pipeline/terraform.tfvars`:

```bash
staging_cluster_name           = "$(cd terraform/apps && terraform output -raw cluster_name -var-file=envs/staging/terraform.tfvars)"
staging_service_name           = "$(cd terraform/apps && terraform output -raw service_name -var-file=envs/staging/terraform.tfvars)"
staging_task_definition_family = "$(cd terraform/apps && terraform output -raw task_definition_family -var-file=envs/staging/terraform.tfvars)"
staging_url                    = "http://$(cd terraform/apps && terraform output -raw alb_dns_name -var-file=envs/staging/terraform.tfvars)"

production_cluster_name           = "$(cd terraform/apps && terraform output -raw cluster_name -var-file=envs/production/terraform.tfvars)"
production_service_name           = "$(cd terraform/apps && terraform output -raw service_name -var-file=envs/production/terraform.tfvars)"
production_task_definition_family = "$(cd terraform/apps && terraform output -raw task_definition_family -var-file=envs/production/terraform.tfvars)"
```

---

## Inputs reference

### Core

| Name | Description | Default |
|------|-------------|---------|
| `aws_region` | AWS region | `eu-west-1` |
| `project` | Resource name prefix | `gists-api` |
| `platform` | `staging` or `production` | _(required)_ |
| `vpc_id` | VPC ID | _(required)_ |
| `private_subnet_ids` | Subnets for ECS tasks | _(required)_ |
| `public_subnet_ids` | Subnets for ALB | _(required)_ |
| `ecr_image_uri` | Full ECR image URI | _(required)_ |
| `container_name` | Container name in task def | `gists-api` |
| `container_port` | Port the container listens on | `8080` |
| `task_cpu` | Fargate CPU units | `256` |
| `task_memory` | Fargate memory (MiB) | `512` |
| `desired_count` | Initial task count | `1` |
| `min_capacity` / `max_capacity` | Auto-scaling bounds | `1` / `4` |
| `health_check_path` | ALB health check path | `/health` |
| `certificate_arn` | ACM cert ARN for ALB HTTPS | `""` |
| `task_environment_vars` | Plain-text env vars | `{}` |
| `task_secrets` | SSM/Secrets Manager ARNs | `{}` |
| `extra_tags` | Additional resource tags | `{}` |

### Fastly / NGWAF

| Name | Description | Default |
|------|-------------|---------|
| `fastly_domain` | Public domain routed through Fastly | _(required)_ |
| `fastly_ssl_backend` | Connect to ALB over HTTPS | `false` |
| `fastly_force_destroy` | Allow destroy of active service | `false` |
| `fastly_default_ttl` | Default cache TTL (seconds) | `60` |
| `fastly_backend_connect_timeout` | ALB connect timeout (ms) | `5000` |
| `fastly_backend_first_byte_timeout` | ALB first-byte timeout (ms) | `60000` |
| `fastly_backend_between_bytes_timeout` | ALB between-bytes timeout (ms) | `30000` |
| `ngwaf_workspace_name` | NGWAF workspace display name | `<name_prefix>-ngwaf-workspace` |
| `ngwaf_mode` | `log` or `block` | `block` |
| `ngwaf_traffic_ramp` | % of traffic through NGWAF | `100` |
| `ngwaf_threshold_one_minute` | Attack signals / 1 min | `100` |
| `ngwaf_threshold_ten_minutes` | Attack signals / 10 min | `500` |
| `ngwaf_threshold_one_hour` | Attack signals / 1 hour | `1000` |

## Outputs reference

| Name | Description |
|------|-------------|
| `cluster_name` | ECS cluster name |
| `cluster_arn` | ECS cluster ARN |
| `service_name` | ECS service name |
| `task_definition_family` | Task definition family |
| `alb_dns_name` | ALB DNS name |
| `alb_arn` | ALB ARN |
| `task_execution_role_arn` | Task execution role ARN |
| `task_role_arn` | Task role ARN |
| `log_group_name` | CloudWatch log group name |
| `fastly_service_id` | Fastly VCL service ID |
| `fastly_service_version` | Active Fastly service version |
| `fastly_cname_target` | CNAME target for the domain DNS record |
| `ngwaf_workspace_id` | NGWAF workspace ID |

---

## Environment differences enforced by `var.platform`

| Behaviour | `staging` | `production` |
|-----------|-----------|-------------|
| ECS capacity provider | `FARGATE_SPOT` | `FARGATE` |
| Log retention | 14 days | 90 days |
| ALB deletion protection | disabled | enabled |
| NGWAF mode | `log` | `block` |
| NGWAF thresholds | relaxed | tighter |
| Fastly backend protocol | HTTP | HTTPS |
| `fastly_force_destroy` | `true` | `false` |
