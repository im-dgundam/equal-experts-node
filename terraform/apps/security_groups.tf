# ── Fastly IP ranges ──────────────────────────────────────────────────────────
# Fetches the current Fastly edge node CIDR blocks from the public API
# (https://api.fastly.com/public-ip-list).  No API key is required for this
# endpoint so the provider can be called unauthenticated.

data "fastly_ip_ranges" "fastly" {}

# ── ALB security group ─────────────────────────────────────────────────────────
# Inline ingress rules are intentionally removed so that the Fastly CIDR rules
# below (defined as separate aws_security_group_rule resources) can be updated
# without forcing a full SG replacement.

resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "ALB for ${var.project} ${var.platform}: accepts traffic from Fastly edge nodes only"
  vpc_id      = var.vpc_id

  # Egress is unrestricted – the ALB needs to reach ECS tasks and AWS services.
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # NOTE: All ingress rules are managed as separate aws_security_group_rule
  # resources below.  Do not add inline ingress blocks here or Terraform will
  # fight with the external rules on every plan.

  lifecycle {
    # Prevent accidental replacement of the SG (which would break ALB
    # associations and require restarting ECS tasks).
    create_before_destroy = true
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-alb-sg" })
}

# ── Fastly IPv4 ingress – HTTP ─────────────────────────────────────────────────
# AWS allows up to 60 CIDRs per rule. Fastly currently publishes ~20 IPv4
# ranges, so a single rule is sufficient.  If the list ever grows past 60 the
# cidr_blocks can be chunked into multiple rules.

resource "aws_security_group_rule" "alb_http_fastly_ipv4" {
  security_group_id = aws_security_group.alb.id
  type              = "ingress"
  description       = "HTTP from Fastly IPv4 edge nodes"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = data.fastly_ip_ranges.fastly.cidr_blocks
}

# ── Fastly IPv6 ingress – HTTP ─────────────────────────────────────────────────

resource "aws_security_group_rule" "alb_http_fastly_ipv6" {
  security_group_id = aws_security_group.alb.id
  type              = "ingress"
  description       = "HTTP from Fastly IPv6 edge nodes"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  ipv6_cidr_blocks  = data.fastly_ip_ranges.fastly.ipv6_cidr_blocks
}

# ── Fastly IPv4 ingress – HTTPS (only when certificate_arn is set) ─────────────

resource "aws_security_group_rule" "alb_https_fastly_ipv4" {
  count = local.enable_https ? 1 : 0

  security_group_id = aws_security_group.alb.id
  type              = "ingress"
  description       = "HTTPS from Fastly IPv4 edge nodes"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = data.fastly_ip_ranges.fastly.cidr_blocks
}

# ── Fastly IPv6 ingress – HTTPS ────────────────────────────────────────────────

resource "aws_security_group_rule" "alb_https_fastly_ipv6" {
  count = local.enable_https ? 1 : 0

  security_group_id = aws_security_group.alb.id
  type              = "ingress"
  description       = "HTTPS from Fastly IPv6 edge nodes"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  ipv6_cidr_blocks  = data.fastly_ip_ranges.fastly.ipv6_cidr_blocks
}

# ── ECS task security group ────────────────────────────────────────────────────
# Only accepts traffic from the ALB security group – not from the internet.

resource "aws_security_group" "ecs_task" {
  name        = "${local.name_prefix}-task-sg"
  description = "Allow inbound traffic from the ${var.platform} ALB to ECS tasks"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Container port from ALB only"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Allow all outbound (ECR pull, CloudWatch, GitHub API)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-task-sg" })
}
