# ── General ────────────────────────────────────────────────────────────────────

variable "aws_region" {
  description = "AWS region to deploy resources into."
  type        = string
  default     = "eu-west-1"
}

variable "project" {
  description = "Short project identifier used to name all resources."
  type        = string
  default     = "gists-api"
}

variable "environment_tags" {
  description = "Common tags applied to every resource."
  type        = map(string)
  default = {
    Project   = "gists-api"
    ManagedBy = "terraform"
  }
}

# ── ECR ────────────────────────────────────────────────────────────────────────

variable "ecr_image_tag_mutability" {
  description = "Image tag mutability for the ECR repository (MUTABLE or IMMUTABLE)."
  type        = string
  default     = "MUTABLE"
}

variable "ecr_untagged_expiry_days" {
  description = "Number of days after which untagged images are expired."
  type        = number
  default     = 14
}

# ── CodeBuild ──────────────────────────────────────────────────────────────────

variable "codebuild_compute_type" {
  description = "CodeBuild compute type for the load-test project."
  type        = string
  default     = "BUILD_GENERAL1_SMALL"
}

variable "codebuild_image" {
  description = "Docker image used by CodeBuild for the load-test stage."
  type        = string
  default     = "aws/codebuild/standard:7.0"
}

variable "load_test_buildspec" {
  description = "Inline buildspec YAML for the load-test stage. Override to customise the test command."
  type        = string
  default     = <<-BUILDSPEC
    version: 0.2
    phases:
      install:
        commands:
          - pip install locust
      build:
        commands:
          - echo "Running load tests against staging"
          - locust --headless -u 50 -r 10 --run-time 60s --host $STAGING_URL -f loadtest/locustfile.py
    BUILDSPEC
}

variable "staging_url" {
  description = "Base URL of the staging ECS service used by the load-test stage."
  type        = string
}

# ── ECS ────────────────────────────────────────────────────────────────────────

variable "staging_cluster_name" {
  description = "Name of the ECS cluster used for staging deployments."
  type        = string
}

variable "staging_service_name" {
  description = "Name of the ECS service in the staging cluster."
  type        = string
}

variable "staging_task_definition_family" {
  description = "ECS task definition family used in staging."
  type        = string
}

variable "production_cluster_name" {
  description = "Name of the ECS cluster used for production deployments."
  type        = string
}

variable "production_service_name" {
  description = "Name of the ECS service in the production cluster."
  type        = string
}

variable "production_task_definition_family" {
  description = "ECS task definition family used in production."
  type        = string
}

variable "container_name" {
  description = "Name of the container inside the ECS task definition (must match the task def)."
  type        = string
  default     = "gists-api"
}

# ── CodePipeline ───────────────────────────────────────────────────────────────

variable "pipeline_approval_email" {
  description = "Email address to notify when the manual promotion approval is required."
  type        = string
  default     = ""
}
