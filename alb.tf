# =============================================================================
# alb.tf — Application Load Balancer
# =============================================================================
# The ALB sits between the internet and web01.
# Users never hit web01's IP directly — they hit the ALB's DNS name.
#
# WHY USE AN ALB EVEN WITH ONE SERVER?
# → Health checks: if Nginx crashes, the ALB stops sending traffic
# → Scalability: when you add more web servers later, just register them here
# → Stable DNS: the ALB's DNS name never changes; web01's IP might
# → SSL termination: you can add HTTPS at the ALB layer later
#
# THREE COMPONENTS WORK TOGETHER:
#
#   aws_lb                          The ALB itself. The traffic entry point.
#   aws_lb_target_group             The group of servers behind the ALB (web01).
#                                   Also defines how to health-check them.
#   aws_lb_listener                 The rule: "listen on port 80, forward to target group"
#   aws_lb_target_group_attachment  Registers web01 into the target group
#
# ANALOGY:
#   ALB = receptionist at the front desk
#   Target group = the list of offices the receptionist can send visitors to
#   Listener = the receptionist's instructions: "anyone who comes in, send to office 80"
#   Attachment = adding web01's name to the office list
# =============================================================================


# -----------------------------------------------------------------------------
# The ALB
# -----------------------------------------------------------------------------
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false           # false = internet-facing (public)
  load_balancer_type = "application"   # ALB = HTTP/HTTPS aware (vs NLB = raw TCP)
  security_groups    = [aws_security_group.alb.id]

  # AWS requires an ALB to span at least two Availability Zones for redundancy.
  # We use both our public subnets (1a and 1b).
  subnets = [
    aws_subnet.public.id,
    aws_subnet.public_2.id
  ]

  tags = {
    Name = "${var.project_name}-alb"
  }
}


# -----------------------------------------------------------------------------
# Target Group
# -----------------------------------------------------------------------------
# A target group is the pool of servers the ALB routes traffic to.
# It also defines the health check — how the ALB knows if a server is alive.
#
# HEALTH CHECK EXPLAINED:
# Every 30 seconds, the ALB sends a GET / request to web01 on port 80.
# If web01 returns HTTP 200 twice in a row → marked healthy → receives traffic.
# If web01 fails 3 checks in a row → marked unhealthy → ALB stops sending traffic.
# This is automatic. You don't need to monitor it manually.
resource "aws_lb_target_group" "web" {
  name     = "${var.project_name}-web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    path                = "/"           # The URL the ALB requests to check health
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2             # 2 passing checks → healthy
    unhealthy_threshold = 3             # 3 failing checks → unhealthy
    timeout             = 5             # Wait 5 seconds for a response
    interval            = 30            # Check every 30 seconds
    matcher             = "200"         # HTTP 200 = server is healthy
  }

  tags = {
    Name = "${var.project_name}-web-tg"
  }
}


# -----------------------------------------------------------------------------
# Listener
# -----------------------------------------------------------------------------
# The listener tells the ALB: "listen on this port, apply this rule."
# Our rule: forward everything to the web target group.
# In production you'd add more rules: redirect HTTP to HTTPS, route /api to a
# different target group, etc. For now: simple forward.
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn   # Attach this listener to our ALB
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}


# -----------------------------------------------------------------------------
# Register web01 into the Target Group
# -----------------------------------------------------------------------------
# This is the final wiring step: "web01 is a member of the web target group."
# Now the ALB knows to send traffic to web01 and to health-check it.
resource "aws_lb_target_group_attachment" "web01" {
  target_group_arn = aws_lb_target_group.web.arn
  target_id        = aws_instance.web01.id
  port             = 80
}
