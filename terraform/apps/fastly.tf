# ── Fastly NGWAF Workspace ─────────────────────────────────────────────────────
#
# Creates a dedicated NGWAF workspace per platform (staging / production).
# Each workspace has its own attack-signal thresholds so staging can be
# kept in log-only mode while production enforces blocking.

resource "fastly_ngwaf_workspace" "app" {
  name        = local.ngwaf_workspace_name
  description = "NGWAF workspace for ${var.project} ${var.platform}"

  # In staging, start in log mode to observe traffic without blocking.
  # In production, block by default – override via var.ngwaf_mode if needed.
  mode = var.ngwaf_mode

  attack_signal_thresholds {
    one_minute  = var.ngwaf_threshold_one_minute
    ten_minutes = var.ngwaf_threshold_ten_minutes
    one_hour    = var.ngwaf_threshold_one_hour
    immediate   = true
  }
}

# ── Fastly VCL Service ─────────────────────────────────────────────────────────
#
# One service per platform. The domain, backend (ALB endpoint), and NGWAF
# workspace are all driven by variables so staging and production share the
# same Terraform code.

resource "fastly_service_vcl" "app" {
  name = "${local.name_prefix}-vcl-service"

  # ── Domain ────────────────────────────────────────────────────────────────────
  domain {
    name    = var.fastly_domain
    comment = "${var.platform} domain for ${var.project}"
  }

  # ── Origin backend – ALB ──────────────────────────────────────────────────────
  # The ALB DNS name comes from the aws_lb resource defined in alb.tf.
  # Fastly connects to it over HTTPS when var.fastly_ssl_backend is true
  # (i.e. when an ACM certificate is attached to the ALB listener).
  backend {
    name    = "${local.name_prefix}-alb-origin"
    address = aws_lb.app.dns_name

    # Use port 443 + SSL when the ALB has an HTTPS listener; otherwise port 80.
    port    = var.fastly_ssl_backend ? 443 : 80
    use_ssl = var.fastly_ssl_backend

    # SNI and certificate hostname must match the ALB's TLS certificate CN/SAN.
    ssl_cert_hostname = var.fastly_ssl_backend ? aws_lb.app.dns_name : null
    ssl_sni_hostname  = var.fastly_ssl_backend ? aws_lb.app.dns_name : null

    # Forward the public domain as the Host header so the ALB listener
    # rule can match on it if needed.
    override_host = var.fastly_domain

    connect_timeout       = var.fastly_backend_connect_timeout
    first_byte_timeout    = var.fastly_backend_first_byte_timeout
    between_bytes_timeout = var.fastly_backend_between_bytes_timeout

    # Health-check: mirrors the /health endpoint in the application.
    healthcheck = "${local.name_prefix}-alb-healthcheck"
  }

  # ── Health check ─────────────────────────────────────────────────────────────
  healthcheck {
    name              = "${local.name_prefix}-alb-healthcheck"
    host              = var.fastly_domain
    path              = "/health"
    method            = "GET"
    expected_response = 200
    check_interval    = 15000  # ms
    timeout           = 5000   # ms
    threshold         = 3
    initial           = 3
    window            = 5
  }

  # ── Cache settings ────────────────────────────────────────────────────────────
  # API responses should not be cached by default; let explicit Cache-Control
  # headers from the origin drive caching decisions.
  default_ttl = var.fastly_default_ttl

  # Pass-through: treat every request as a cache miss so API calls always
  # reach the origin. Override this with a VCL snippet if you add cacheable
  # endpoints later.
  request_setting {
    name      = "pass-all"
    action    = "pass"
    xff       = "append"   # Preserve client IP in X-Forwarded-For
  }

  # ── HTTPS redirect (VCL snippet) ──────────────────────────────────────────────
  # Redirect plain HTTP requests to HTTPS at the edge before they reach the ALB.
  snippet {
    name     = "redirect-http-to-https"
    type     = "recv"
    priority = 100
    content  = <<-VCL
      if (req.http.Fastly-SSL) {
        # Already over HTTPS – nothing to do.
      } else {
        error 801 "Redirect to HTTPS";
      }
    VCL
  }

  snippet {
    name     = "deliver-https-redirect"
    type     = "error"
    priority = 100
    content  = <<-VCL
      if (obj.status == 801) {
        set obj.status = 301;
        set obj.response = "Moved Permanently";
        set obj.http.Location = "https://" + req.http.host + req.url;
        synthetic {""};
        return(deliver);
      }
    VCL
  }

  # ── NGWAF edge deployment ─────────────────────────────────────────────────────
  product_enablement {
    ngwaf {
      enabled      = true
      workspace_id = fastly_ngwaf_workspace.app.id
      traffic_ramp = var.ngwaf_traffic_ramp
    }
  }

  # Allow 'terraform destroy' to delete the service even with active versions.
  # Keep false in production to prevent accidental deletion.
  force_destroy = var.fastly_force_destroy

  # Ensure the ALB is healthy before the Fastly service is created/updated.
  depends_on = [
    aws_lb_listener.http,
    aws_ecs_service.app,
  ]
}
