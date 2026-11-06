locals {
  # Every resource name follows the pattern: <project>-<platform>-<resource>
  # e.g.  gists-api-staging-cluster, gists-api-production-svc
  name_prefix = "${var.project}-${var.platform}"

  common_tags = merge(
    {
      Project     = var.project
      Platform    = var.platform
      ManagedBy   = "terraform"
    },
    var.extra_tags
  )

  # Build the container environment list from the var.task_environment_vars map
  container_env = [
    for k, v in var.task_environment_vars : {
      name  = k
      value = v
    }
  ]

  # Build the container secrets list from var.task_secrets map
  container_secrets = [
    for k, v in var.task_secrets : {
      name      = k
      valueFrom = v
    }
  ]

  # Whether to add an HTTPS listener to the ALB
  enable_https = var.certificate_arn != ""

  # NGWAF workspace display name – caller can override via var.ngwaf_workspace_name
  ngwaf_workspace_name = (
    var.ngwaf_workspace_name != ""
    ? var.ngwaf_workspace_name
    : "${local.name_prefix}-ngwaf-workspace"
  )
}
