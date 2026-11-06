# ── ECR Repository ─────────────────────────────────────────────────────────────

resource "aws_ecr_repository" "app" {
  name                 = var.project
  image_tag_mutability = var.ecr_image_tag_mutability

  image_scanning_configuration {
    # Enable basic push-time scanning on every image uploaded
    scan_on_push = true
  }

  tags = var.environment_tags
}

# ── Lifecycle policy ──────────────────────────────────────────────────────────
# Keep the last 10 tagged images; expire untagged images after N days.

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images older than ${var.ecr_untagged_expiry_days} days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = var.ecr_untagged_expiry_days
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep only the last 10 tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["sha-", "main", "latest"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = { type = "expire" }
      }
    ]
  })
}
