# ── CloudWatch Log Group ───────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "load_test" {
  name              = "/aws/codebuild/${var.project}-load-test"
  retention_in_days = 14
  tags              = var.environment_tags
}

# ── CodeBuild project – load tests ────────────────────────────────────────────
# Runs after the staging ECS deployment to validate the service under load
# before the manual promotion gate to production.

resource "aws_codebuild_project" "load_test" {
  name          = "${var.project}-load-test"
  description   = "Runs load tests against the staging environment using Locust"
  build_timeout = 10 # minutes
  service_role  = aws_iam_role.codebuild.arn

  artifacts {
    # Artifacts are managed by CodePipeline
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = var.codebuild_compute_type
    image                       = var.codebuild_image
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "STAGING_URL"
      value = var.staging_url
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = var.load_test_buildspec
  }

  logs_config {
    cloudwatch_logs {
      group_name  = aws_cloudwatch_log_group.load_test.name
      stream_name = "build"
    }
  }

  tags = var.environment_tags
}
