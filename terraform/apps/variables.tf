# ── Identity ───────────────────────────────────────────────────────────────────

variable "aws_region" {
  description = "AWS region to deploy resources into."
  type        = string
  default     = "eu-west-1"
}

variable "project" {
  description = "Short project name used in resource names alongside platform."
  type        = string
  default     = "gists-api"
}

variable "platform" {
  description = <<-DESC
    Target environment / platform. Injected into every resource name so the
    same Terraform code can be applied to staging and production without
    conflicts. Typical values: staging, production.
  DESC
  type        = string

  validation {
    condition     = contains(["staging", "production"], var.platform)
    error_message = "platform must be one of: staging, production."
  }
}

# ── Networking ─────────────────────────────────────────────────────────────────

variable "vpc_id" {
  description = "ID of the VPC in which the ECS service runs."
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for the ECS service ENIs."
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for the Application Load Balancer."
  type        = list(string)
}

# ── Container / task ───────────────────────────────────────────────────────────

variable "ecr_image_uri" {
  description = "Full ECR image URI (including tag or digest) to deploy, e.g. 123456789.dkr.ecr.eu-west-1.amazonaws.com/gists-api:latest."
  type        = string
}

variable "container_name" {
  description = "Name of the container inside the task definition. Must match the name used by CodePipeline's imagedefinitions.json."
  type        = string
  default     = "gists-api"
}

variable "container_port" {
  description = "Port the container listens on."
  type        = number
  default     = 8080
}

variable "task_cpu" {
  description = "CPU units for the Fargate task (256, 512, 1024, 2048, 4096)."
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Memory (MiB) for the Fargate task."
  type        = number
  default     = 512
}

variable "task_environment_vars" {
  description = "Map of plain-text environment variables to inject into the container."
  type        = map(string)
  default     = {}
}

variable "task_secrets" {
  description = <<-DESC
    Map of secret environment variable names to their SSM Parameter Store ARNs
    or Secrets Manager ARNs. Values are never stored in state.
    Example: { GITHUB_TOKEN = "arn:aws:ssm:eu-west-1:123:parameter/gists-api/staging/GITHUB_TOKEN" }
  DESC
  type        = map(string)
  default     = {}
  sensitive   = true
}

# ── ECS service ────────────────────────────────────────────────────────────────

variable "desired_count" {
  description = "Desired number of running task replicas."
  type        = number
  default     = 1
}

variable "min_capacity" {
  description = "Minimum number of tasks for auto-scaling."
  type        = number
  default     = 1
}

variable "max_capacity" {
  description = "Maximum number of tasks for auto-scaling."
  type        = number
  default     = 4
}

variable "scale_out_cpu_threshold" {
  description = "CPU utilisation (%) above which a scale-out policy fires."
  type        = number
  default     = 70
}

variable "scale_in_cpu_threshold" {
  description = "CPU utilisation (%) below which a scale-in policy fires."
  type        = number
  default     = 30
}

# ── ALB / health check ─────────────────────────────────────────────────────────

variable "health_check_path" {
  description = "HTTP path used for ALB target group health checks."
  type        = string
  default     = "/health"
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS on the ALB. Leave empty to use HTTP only (not recommended for production)."
  type        = string
  default     = ""
}

# ── Tags ───────────────────────────────────────────────────────────────────────

variable "extra_tags" {
  description = "Additional tags merged into every resource."
  type        = map(string)
  default     = {}
}

# ── Fastly ─────────────────────────────────────────────────────────────────────

variable "fastly_domain" {
  description = <<-DESC
    Public domain routed through Fastly.
    staging:    staging.equalexperts.com
    production: www.equalexperts.com
  DESC
  type        = string
}

variable "fastly_force_destroy" {
  description = "Allow Terraform to destroy the Fastly service even when it has active versions. Set to false in production."
  type        = bool
  default     = false
}

variable "fastly_default_ttl" {
  description = "Default cache TTL in seconds for cacheable responses."
  type        = number
  default     = 60
}

variable "fastly_backend_connect_timeout" {
  description = "Milliseconds to wait for a connection to the origin (ALB)."
  type        = number
  default     = 5000
}

variable "fastly_backend_first_byte_timeout" {
  description = "Milliseconds to wait for the first byte from the origin (ALB)."
  type        = number
  default     = 60000
}

variable "fastly_backend_between_bytes_timeout" {
  description = "Milliseconds to wait between bytes received from the origin (ALB)."
  type        = number
  default     = 30000
}

variable "fastly_ssl_backend" {
  description = "Whether to connect to the ALB backend over HTTPS. Set to true when certificate_arn is provided."
  type        = bool
  default     = false
}

# ── NGWAF ─────────────────────────────────────────────────────────────────────

variable "ngwaf_workspace_name" {
  description = "Display name for the NGWAF workspace. Defaults to <project>-<platform>."
  type        = string
  default     = ""
}

variable "ngwaf_mode" {
  description = "NGWAF operational mode: 'log' (observe only) or 'block'."
  type        = string
  default     = "block"

  validation {
    condition     = contains(["log", "block"], var.ngwaf_mode)
    error_message = "ngwaf_mode must be 'log' or 'block'."
  }
}

variable "ngwaf_traffic_ramp" {
  description = "Percentage of traffic (0-100) to send through NGWAF inspection."
  type        = number
  default     = 100
}

variable "ngwaf_threshold_one_minute" {
  description = "Attack signal threshold per one-minute window."
  type        = number
  default     = 100
}

variable "ngwaf_threshold_ten_minutes" {
  description = "Attack signal threshold per ten-minute window."
  type        = number
  default     = 500
}

variable "ngwaf_threshold_one_hour" {
  description = "Attack signal threshold per one-hour window."
  type        = number
  default     = 1000
}
