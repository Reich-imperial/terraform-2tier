# =============================================================================
# ec2.tf — The Servers
# =============================================================================
# We create two EC2 instances:
#
#   web01 → public subnet, Nginx installed, receives traffic from the ALB
#   db01  → private subnet, MySQL installed, only web01 can reach it
#
# THE user_data CONCEPT:
# user_data is a shell script you attach to an EC2 instance.
# It runs ONCE, automatically, when the instance first boots.
# This means you never have to SSH in and manually install software.
# The instance configures itself.
#
# This is Infrastructure as Code applied to the OS layer — not just AWS resources.
# It's the foundation of how tools like Ansible, Packer, and cloud-init work.
#
# NOTE ON THE AMI:
# We reference data.aws_ami.amazon_linux_2.id — the dynamic lookup defined
# in vpc.tf. Terraform resolves this cross-file reference automatically.
# =============================================================================


# -----------------------------------------------------------------------------
# web01 — Nginx Web Server
# -----------------------------------------------------------------------------
resource "aws_instance" "web01" {
  ami           = data.aws_ami.amazon_linux_2.id  # Dynamic AMI from vpc.tf
  instance_type = var.instance_type
  subnet_id     = aws_subnet.public.id            # Public subnet → gets public IP

  # Associates the web security group with this instance.
  # This is how the SG-to-SG rules in sg.tf become real:
  # the ALB SG can send HTTP here; the DB SG accepts MySQL from here.
  vpc_security_group_ids = [aws_security_group.web.id]

  key_name = var.key_pair_name  # Your existing samson-key

  # THE BOOTSTRAP SCRIPT
  # <<-EOF ... EOF is Terraform's heredoc syntax for multi-line strings.
  # The "-" before EOF means: strip leading tabs (for clean indentation).
  #
  # This script runs as root on first boot.
  # `set -e` → stop immediately if any command fails (fail fast = good practice)
  user_data = <<-EOF
    #!/bin/bash
    set -e

    yum update -y

    # Amazon Linux 2 doesn't have Nginx in its default repo.
    # It's available through amazon-linux-extras — you've hit this before in P3.
    amazon-linux-extras install nginx1 -y

    systemctl start nginx
    systemctl enable nginx   # Start nginx automatically on every reboot

    # Write a custom landing page so you can verify the server is running
    # ${var.project_name} and ${var.environment} are Terraform variables
    # interpolated into the heredoc at apply time.
    cat > /usr/share/nginx/html/index.html <<HTML
    <!DOCTYPE html>
    <html>
      <head><title>${var.project_name} — web01</title></head>
      <body>
        <h1>web01 is alive</h1>
        <p>Project: ${var.project_name} | Environment: ${var.environment}</p>
        <p>Provisioned by Terraform + GitHub Actions</p>
      </body>
    </html>
    HTML
  EOF

  tags = {
    Name = "${var.project_name}-web01"
    Role = "webserver"
  }
}


# -----------------------------------------------------------------------------
# db01 — MySQL Database Server
# -----------------------------------------------------------------------------
resource "aws_instance" "db01" {
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.private.id           # Private subnet → NO public IP

  # Only the db security group — which accepts MySQL from web01's SG only.
  vpc_security_group_ids = [aws_security_group.db.id]

  key_name = var.key_pair_name

  # Install MySQL 8 on first boot.
  # The temp password is logged to /tmp/setup.log — retrieve it after first boot:
  # ssh to web01 → ssh to db01 → cat /tmp/setup.log
  user_data = <<-EOF
    #!/bin/bash
    set -e

    yum update -y

    # Add the MySQL 8 community repository
    rpm -Uvh https://dev.mysql.com/get/mysql80-community-release-el7-5.noarch.rpm

    # Install MySQL server
    yum install -y mysql-community-server

    systemctl start mysqld
    systemctl enable mysqld

    # MySQL generates a temporary root password on first install.
    # Capture it so you can log in and change it after the instance boots.
    TEMP_PASS=$(grep "temporary password" /var/log/mysqld.log | tail -1 | awk '{print $NF}')
    echo "MySQL temp password: $TEMP_PASS" > /tmp/setup.log
    echo "Retrieved on: $(date)" >> /tmp/setup.log
  EOF

  tags = {
    Name = "${var.project_name}-db01"
    Role = "database"
  }
}
