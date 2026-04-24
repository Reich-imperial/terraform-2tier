

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
# pipeline test
# actions test
