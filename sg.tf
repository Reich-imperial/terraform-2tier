# =============================================================================
# sg.tf — Security Groups (Virtual Firewalls)
# =============================================================================
# A security group is a stateful firewall attached to an EC2 instance or ALB.
# "Stateful" means: if you allow traffic IN on port 80, the response is
# automatically allowed OUT — you don't write a matching egress rule for it.
#
# Every security group has two lists of rules:
#   ingress = traffic allowed IN
#   egress  = traffic allowed OUT
#
# THE KEY PRINCIPLE — least privilege:
# Only allow what is absolutely necessary. Everything else is denied by default.
#
# THE POWER MOVE — SG-to-SG references:
# Instead of allowing MySQL from "any IP in the web subnet (10.1.1.0/24)",
# we allow MySQL from "anything that has the web security group attached."
# This is more precise: even if web01's IP changes, the rule still works.
# And it means only web01 — not any random EC2 you put in the public subnet —
# can talk to db01.
#
# TRAFFIC FLOW:
#   Internet → ALB SG (port 80/443) → Web SG (port 80 from ALB) → DB SG (port 3306 from web)
# =============================================================================


# -----------------------------------------------------------------------------
# ALB Security Group
# -----------------------------------------------------------------------------
# The load balancer is the only thing that faces the open internet.
# It must accept HTTP (80) and HTTPS (443) from anywhere.
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Controls traffic to and from the Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from the open internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from the open internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # The ALB needs to forward traffic to web01 and receive health check responses.
  # Allowing all outbound traffic is standard for ALBs.
  egress {
    description = "Allow all outbound so ALB can forward to targets"
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # -1 means ALL protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}


# -----------------------------------------------------------------------------
# Web Server Security Group
# -----------------------------------------------------------------------------
# web01 sits behind the ALB — it should NOT receive traffic directly from the internet.
# HTTP traffic must come from the ALB only. SSH is open for your admin access.
resource "aws_security_group" "web" {
  name        = "${var.project_name}-web-sg"
  description = "Controls traffic to the web/app server"
  vpc_id      = aws_vpc.main.id

  # HTTP only from the ALB security group — not from the open internet.
  # Notice: we reference aws_security_group.alb.id, not a CIDR block.
  # This is the SG-to-SG reference. Only the ALB can send HTTP to web01.
  ingress {
    description     = "HTTP from ALB only"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # SSH open to the world for this learning project.
  # In production: replace 0.0.0.0/0 with your specific IP address.
  ingress {
    description = "SSH for admin access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # web01 needs to reach out: to db01 on port 3306, and to the internet
  # to run yum updates or download packages.
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-web-sg"
    Tier = "web"
  }
}


# -----------------------------------------------------------------------------
# Database Security Group
# -----------------------------------------------------------------------------
# db01 is in a private subnet with no public IP.
# Even if someone found db01's private IP, they couldn't reach it —
# this security group rejects everything except MySQL from web01.
resource "aws_security_group" "db" {
  name        = "${var.project_name}-db-sg"
  description = "Controls traffic to the database server  web tier only"
  vpc_id      = aws_vpc.main.id

  # MySQL ONLY from the web server's security group.
  # Not from the whole subnet — specifically from web01 (which carries the web SG).
  # This is the tightest possible rule for a DB server.
  ingress {
    description     = "MySQL from web server only"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  # SSH via the web server — the "bastion host" pattern.
  # You SSH to web01 (which is public), then SSH from web01 to db01 (private).
  # db01 never needs to be directly reachable from your laptop.
  ingress {
    description     = "SSH via web01 acting as bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-db-sg"
    Tier = "db"
  }
}
