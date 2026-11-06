aws_region = "eu-west-1"
project    = "gists-api"
platform   = "production"

# Networking – replace with your actual VPC/subnet IDs
vpc_id             = "vpc-xxxxxxxxxxxxxxxxx"
private_subnet_ids = ["subnet-xxxxxxxxxxxxxxxxx", "subnet-xxxxxxxxxxxxxxxxx"]
public_subnet_ids  = ["subnet-xxxxxxxxxxxxxxxxx", "subnet-xxxxxxxxxxxxxxxxx"]

# Container image – updated by the pipeline after manual approval
ecr_image_uri  = "123456789012.dkr.ecr.eu-west-1.amazonaws.com/gists-api:latest"
container_port = 8080

# Task sizing – larger allocation for production traffic
task_cpu    = 512
task_memory = 1024

# Scaling – production can run multiple replicas
desired_count   = 2
min_capacity    = 2
max_capacity    = 8

# HTTPS recommended for production
certificate_arn = "arn:aws:acm:eu-west-1:123456789012:certificate/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# ── Fastly ─────────────────────────────────────────────────────────────────────
fastly_domain        = "www.equalexperts.com"
fastly_ssl_backend   = true  # ALB has an HTTPS listener via certificate_arn above
fastly_force_destroy = false # Protect production from accidental deletion

# NGWAF – block in production with tighter thresholds
ngwaf_mode                  = "block"
ngwaf_traffic_ramp          = 100
ngwaf_threshold_one_minute  = 50
ngwaf_threshold_ten_minutes = 250
ngwaf_threshold_one_hour    = 500

extra_tags = {
  CostCentre = "engineering"
}

