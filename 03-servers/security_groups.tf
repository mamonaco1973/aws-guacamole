# ================================================================================
# SECURITY GROUPS
# ================================================================================
# The only internet-facing piece is the ALB:
#
#   internet --443/80--> alb_sg --8080--> guacamole_sg --3389------> windows_sg
#                                                      \--22, 3389--> xubuntu_sg
#
# Every server is in the private subnet with no public IP. ICMP is allowed
# from inside the VPC for reachability checks.
# ================================================================================

# ------------------------------------------------------------------------------
# ALB: HTTPS (and HTTP, redirected) from var.allowed_cidrs
# ------------------------------------------------------------------------------
resource "aws_security_group" "alb_sg" {
  name        = "guacamole-alb-sg"
  description = "Guacamole ALB: HTTPS and HTTP redirect"
  vpc_id      = data.aws_vpc.ad_vpc.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
  }

  ingress {
    description = "HTTP (redirected to HTTPS)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ------------------------------------------------------------------------------
# Guacamole: the web app on 8080, from the ALB only
# ------------------------------------------------------------------------------
resource "aws_security_group" "guacamole_sg" {
  name        = "guacamole-server-sg"
  description = "Guacamole web app, reachable only from the ALB"
  vpc_id      = data.aws_vpc.ad_vpc.id

  ingress {
    description     = "Guacamole (Tomcat) from the ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  ingress {
    description = "ICMP from the VPC"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [data.aws_vpc.ad_vpc.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ------------------------------------------------------------------------------
# Windows: RDP from Guacamole only
# ------------------------------------------------------------------------------
resource "aws_security_group" "windows_sg" {
  name        = "guacamole-windows-sg"
  description = "RDP from the Guacamole server only"
  vpc_id      = data.aws_vpc.ad_vpc.id

  ingress {
    description     = "RDP from Guacamole"
    from_port       = 3389
    to_port         = 3389
    protocol        = "tcp"
    security_groups = [aws_security_group.guacamole_sg.id]
  }

  ingress {
    description = "ICMP from the VPC"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [data.aws_vpc.ad_vpc.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ------------------------------------------------------------------------------
# Xubuntu: SSH and RDP (XRDP) from Guacamole only
# ------------------------------------------------------------------------------
resource "aws_security_group" "xubuntu_sg" {
  name        = "guacamole-xubuntu-sg"
  description = "SSH and RDP from the Guacamole server only"
  vpc_id      = data.aws_vpc.ad_vpc.id

  ingress {
    description     = "SSH from Guacamole"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.guacamole_sg.id]
  }

  ingress {
    description     = "RDP (XRDP) from Guacamole"
    from_port       = 3389
    to_port         = 3389
    protocol        = "tcp"
    security_groups = [aws_security_group.guacamole_sg.id]
  }

  ingress {
    description = "ICMP from the VPC"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [data.aws_vpc.ad_vpc.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
