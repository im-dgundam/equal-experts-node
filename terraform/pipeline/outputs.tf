output "ecr_repository_url" {
  description = "Full ECR repository URL. Use this as the image base in your CI push step."
  value       = aws_ecr_repository.app.repository_url
}

output "ecr_repository_arn" {
  description = "ARN of the ECR repository."
  value       = aws_ecr_repository.app.arn
}

output "pipeline_name" {
  description = "Name of the CodePipeline."
  value       = aws_codepipeline.app.name
}

output "pipeline_arn" {
  description = "ARN of the CodePipeline."
  value       = aws_codepipeline.app.arn
}

output "codebuild_project_name" {
  description = "Name of the CodeBuild load-test project."
  value       = aws_codebuild_project.load_test.name
}

output "artifact_bucket_name" {
  description = "S3 bucket used to store pipeline artifacts."
  value       = aws_s3_bucket.pipeline_artifacts.bucket
}

output "approval_sns_topic_arn" {
  description = "ARN of the SNS topic that notifies approvers before the production stage."
  value       = aws_sns_topic.pipeline_approval.arn
}
