# ── CodePipeline ───────────────────────────────────────────────────────────────
#
# Stage flow:
#   Source  ──►  Staging (ECS deploy + load test)  ──►  Approve  ──►  Production
#
# The Source stage polls the ECR repository for a new image tagged "latest" or
# "main". When a new image digest is detected the pipeline executes automatically.

resource "aws_codepipeline" "app" {
  name     = "${var.project}-pipeline"
  role_arn = aws_iam_role.codepipeline.arn

  artifact_store {
    location = aws_s3_bucket.pipeline_artifacts.bucket
    type     = "S3"
  }

  # ── Stage 1: Source ──────────────────────────────────────────────────────────
  # Watches the ECR repository for a new image with the "latest" tag.
  # CodePipeline stores the image details (digest, tags) as the source artifact.

  stage {
    name = "Source"

    action {
      name             = "ECR-Image"
      category         = "Source"
      owner            = "AWS"
      provider         = "ECR"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        RepositoryName = aws_ecr_repository.app.name
        # Trigger on the tag that the GitHub Actions CI workflow pushes
        ImageTag = "latest"
      }
    }
  }

  # ── Stage 2: Staging ─────────────────────────────────────────────────────────
  # Two sequential actions:
  #   a) Deploy the new image to the staging ECS cluster.
  #   b) Run load tests via CodeBuild against the deployed service.

  stage {
    name = "Staging"

    # 2a – ECS rolling deployment to staging
    action {
      name            = "Deploy-Staging"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      version         = "1"
      input_artifacts = ["source_output"]
      run_order       = 1

      configuration = {
        ClusterName = var.staging_cluster_name
        ServiceName = var.staging_service_name
        # The imagedefinitions.json file is produced automatically by the ECR
        # source action and maps the container name to the new image URI.
        FileName    = "imagedefinitions.json"
      }
    }

    # 2b – Load tests (must pass before the approval gate is presented)
    action {
      name            = "Load-Test"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["source_output"]
      run_order       = 2

      configuration = {
        ProjectName = aws_codebuild_project.load_test.name
      }
    }
  }

  # ── Stage 3: Promote to Production (manual approval) ─────────────────────────
  # A human must approve before production is touched. An SNS notification is
  # sent to the configured email address as soon as the load tests complete.

  stage {
    name = "Promote-to-Production"

    action {
      name      = "Manual-Approval"
      category  = "Approval"
      owner     = "AWS"
      provider  = "Manual"
      version   = "1"
      run_order = 1

      configuration = {
        NotificationArn    = aws_sns_topic.pipeline_approval.arn
        CustomData         = "Load tests passed. Review the staging environment and approve to deploy to production."
        ExternalEntityLink = "https://${data.aws_region.current.name}.console.aws.amazon.com/ecs/home?region=${data.aws_region.current.name}#/clusters/${var.staging_cluster_name}/services/${var.staging_service_name}/details"
      }
    }
  }

  # ── Stage 4: Production ───────────────────────────────────────────────────────
  # ECS rolling deployment to the production cluster using the same image
  # artifact that was validated in staging.

  stage {
    name = "Production"

    action {
      name            = "Deploy-Production"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      version         = "1"
      input_artifacts = ["source_output"]
      run_order       = 1

      configuration = {
        ClusterName = var.production_cluster_name
        ServiceName = var.production_service_name
        FileName    = "imagedefinitions.json"
      }
    }
  }

  tags = var.environment_tags
}
