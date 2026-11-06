output "cluster_name" {
  description = "ECS cluster name – used by the pipeline module's cluster_name variables."
  value       = aws_ecs_cluster.app.name
}

output "cluster_arn" {
  description = "ECS cluster ARN."
  value       = aws_ecs_cluster.app.arn
}

output "service_name" {
  description = "ECS service name – used by the pipeline module's service_name variables."
  value       = aws_ecs_service.app.name
}

output "task_definition_family" {
  description = "ECS task definition family – used by the pipeline module."
  value       = aws_ecs_task_definition.app.family
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer. Use as the staging_url in the pipeline module."
  value       = aws_lb.app.dns_name
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer."
  value       = aws_lb.app.arn
}

output "task_execution_role_arn" {
  description = "ARN of the ECS task execution IAM role."
  value       = aws_iam_role.task_execution.arn
}

output "task_role_arn" {
  description = "ARN of the ECS task IAM role."
  value       = aws_iam_role.task.arn
}

output "log_group_name" {
  description = "CloudWatch log group name for ECS task logs."
  value       = aws_cloudwatch_log_group.app.name
}

output "fastly_service_id" {
  description = "Fastly VCL service ID."
  value       = fastly_service_vcl.app.id
}

output "fastly_service_version" {
  description = "Active Fastly service version number."
  value       = fastly_service_vcl.app.active_version
}

output "fastly_cname_target" {
  description = "CNAME target to point the domain DNS record at. Set an alias/CNAME for var.fastly_domain to this value."
  value       = "${fastly_service_vcl.app.id}.global.ssl.fastly.net"
}

output "ngwaf_workspace_id" {
  description = "NGWAF workspace ID."
  value       = fastly_ngwaf_workspace.app.id
}
