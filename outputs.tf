# =============================================================================
# outputs.tf — What Terraform Tells You After Apply
# =============================================================================
# After `terraform apply` completes, Terraform prints every output value
# to your terminal. These are the "return values" of your infrastructure run.
#
# They serve three purposes:
#
#   1. HUMAN USE: Copy the SSH command or ALB URL directly from the terminal
#   2. AUTOMATION: GitHub Actions can read outputs with `terraform output -json`
#      and pass them to subsequent steps (e.g., run tests against the ALB URL)
#   3. MODULES: If this config were a Terraform module, other configs could
#      read these outputs to chain infrastructure together
#
# You'll see these at the very end of every `terraform apply` run.
# Testing outputs is a great way to verify your infrastructure works as expected.
# =============================================================================

output "alb_dns_name" {
  description = "Paste this into your browser — it should show the web01 page"
  value       = aws_lb.main.dns_name
}

output "web01_public_ip" {
  description = "web01's public IP address"
  value       = aws_instance.web01.public_ip
}

output "web01_private_ip" {
  description = "web01's private IP — used internally to reach db01"
  value       = aws_instance.web01.private_ip
}

output "db01_private_ip" {
  description = "db01's private IP — only reachable from web01, never from the internet"
  value       = aws_instance.db01.private_ip
}

output "vpc_id" {
  description = "The ID of the VPC created by this project"
  value       = aws_vpc.main.id
}

# A ready-to-paste SSH command — no need to look up the IP manually
output "ssh_to_web01" {
  description = "Copy and paste this directly into your terminal to SSH into web01"
  value       = "ssh -i ~/.ssh/samson-key.pem ec2-user@${aws_instance.web01.public_ip}"
}

# From web01, use this to hop into db01 (bastion pattern)
output "ssh_to_db01_via_web01" {
  description = "Run this FROM web01 to reach db01 in the private subnet"
  value       = "ssh -i ~/.ssh/samson-key.pem ec2-user@${aws_instance.db01.private_ip}"
}
# pipeline test
