# ================================================================================
# FILE: alb.tf
#
# Purpose:
#   - The one internet-facing piece: an Application Load Balancer in the two
#     public subnets, terminating HTTPS with a self-signed certificate and
#     forwarding to Guacamole on :8080. HTTP redirects to HTTPS.
#
# Notes:
#   - The certificate is self-signed (generated here, imported into ACM), so
#     browsers warn on first visit. Swap in a real ACM certificate and a DNS
#     name for anything beyond a demo.
#   - Guacamole's remote-desktop traffic is a long-lived WebSocket; the ALB
#     carries it natively. Guacamole sends keep-alives well inside the
#     ALB's 60-second idle timeout.
# ================================================================================

# ------------------------------------------------------------------------------
# Self-signed certificate
# ------------------------------------------------------------------------------
resource "tls_private_key" "guacamole" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "guacamole" {
  private_key_pem = tls_private_key.guacamole.private_key_pem

  subject {
    common_name  = "guacamole.${var.dns_zone}"
    organization = "Guacamole demo (self-signed)"
  }

  validity_period_hours = 24 * 365
  allowed_uses          = ["key_encipherment", "digital_signature", "server_auth"]
}

resource "aws_acm_certificate" "guacamole" {
  private_key      = tls_private_key.guacamole.private_key_pem
  certificate_body = tls_self_signed_cert.guacamole.cert_pem

  tags = { Name = "guacamole-self-signed" }
}

# ------------------------------------------------------------------------------
# Load balancer, target group, listeners
# ------------------------------------------------------------------------------
resource "aws_lb" "guacamole" {
  name               = "guacamole-alb"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [data.aws_subnet.vm_subnet_1.id, data.aws_subnet.vm_subnet_2.id]

  tags = { Name = "guacamole-alb" }
}

resource "aws_lb_target_group" "guacamole" {
  name     = "guacamole-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.ad_vpc.id

  health_check {
    path                = "/"
    matcher             = "200"
    interval            = 15
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  # One target, but keep a user's tunnel on it if more are ever added.
  stickiness {
    type    = "lb_cookie"
    enabled = true
  }
}

resource "aws_lb_target_group_attachment" "guacamole" {
  target_group_arn = aws_lb_target_group.guacamole.arn
  target_id        = aws_instance.guacamole.id
  port             = 8080
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.guacamole.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate.guacamole.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.guacamole.arn
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.guacamole.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}
