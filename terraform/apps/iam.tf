data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ── ECS task execution role ────────────────────────────────────────────────────
# Used by the ECS agent to pull images from ECR and write logs to CloudWatch.

resource "aws_iam_role" "task_execution" {
  name = "${local.name_prefix}-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "task_execution_managed" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Grant read access to any SSM parameters / Secrets Manager secrets listed in
# var.task_secrets so the ECS agent can inject them into the container.
resource "aws_iam_role_policy" "task_execution_secrets" {
  count = length(var.task_secrets) > 0 ? 1 : 0

  name = "${local.name_prefix}-task-execution-secrets-policy"
  role = aws_iam_role.task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameters",
          "secretsmanager:GetSecretValue",
          "kms:Decrypt"
        ]
        Resource = values(var.task_secrets)
      }
    ]
  })
}

# ── ECS task role ──────────────────────────────────────────────────────────────
# The application itself runs under this role. Add additional policies here
# if the app needs to call other AWS services at runtime.

resource "aws_iam_role" "task" {
  name = "${local.name_prefix}-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}
