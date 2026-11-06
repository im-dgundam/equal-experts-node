aws_region = "eu-west-1"
project    = "gists-api"
platform   = "staging"

# Networking – replace with your actual VPC/subnet IDs
vpc_id             = "vpc-xxxxxxxxxxxxxxxxx"
private_subnet_ids = ["subnet-xxxxxxxxxxxxxxxxx", "subnet-xxxxxxxxxxxxxxxxx"]
public_subnet_ids  = ["subnet-xxxxxxxxxxxxxxxxx", "subnet-xxxxxxxxxxxxxxxxx"]

# Container image – updated by the CI push step or pipeline
ecr_image_uri  = "123456789012.dkr.ecr.eu-west-1.amazonaws.com/gists-api:latest"
container_port = 8080

# Task sizing – smaller footprint in staging
task_cpu    = 256
task_memory = 512

# Scaling – tight bounds in staging
desired_count   = 1
min_capacity    = 1
max_capacity    = 2

# Optional HTTPS – leave empty to use plain HTTP in staging
certificate_arn = ""

# ── Fastly ─────────────────────────────────────────────────────────────────────
fastly_domain        = "staging.equalexperts.com"
fastly_ssl_backend   = false  # Set to true when certificate_arn is provided
fastly_force_destroy = true   # Safe to destroy in staging

# NGWAF – use log mode in staging so attacks are observed but not blocked
ngwaf_mode         = "log"
ngwaf_traffic_ramp = 100

extra_tags = {
  CostCentre = "engineering"
}

