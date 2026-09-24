# EC2 Module - t3.micro / t2.micro free-tier eligible
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "app" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  iam_instance_profile   = var.instance_profile_name
  key_name               = var.key_name

  user_data_replace_on_change = true

  metadata_options {
    http_tokens                 = "required" # enforce IMDSv2
    http_put_response_hop_limit = 1
    http_endpoint               = "enabled"
  }

  root_block_device {
    volume_size = var.root_volume_size # Keep total <= 30 GB across both instances for free tier EBS
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = base64encode(templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
    ecr_repository_url = var.ecr_repository_url
    aws_region         = var.aws_region
    project_name       = var.project_name
    environment        = var.environment     # ✅ add — required by SSM path in template
    image_tag          = var.image_tag
  }))

  tags = merge(var.tags, {
    Name = "${var.project_name}-app-ec2"
  })

  lifecycle {
    ignore_changes = [ami] # Avoid recreation on AMI updates unless intentional
  }
}

# Optional Elastic IP (free while instance is running)
resource "aws_eip" "app" {
  count    = var.allocate_eip ? 1 : 0
  instance = aws_instance.app.id
  domain   = "vpc"

  tags = merge(var.tags, {
    Name = "${var.project_name}-eip"
  })
}