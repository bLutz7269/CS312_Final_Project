terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }
  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "us-west-2"
  shared_credentials_files=["~/.aws/credentials"]
}



data "aws_ami" "amazon_linux_2" {
  owners      = ["amazon"]
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-2.*"]
  }
}

resource "aws_key_pair" "awsKey" {
    key_name = "awsKey"
    public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHFaVGPdKVPAIjPv9O+2pM/IbjXHFhc3zqob+XAeIy/b BryceLutz@10-248-80-248.wireless.oregonstate.edu"
}

resource "aws_security_group" "minecraft" {
  name        = "Minecraft"
  description = "Minecraft server traffic"
}

resource "aws_security_group_rule" "minecraft" {
  type              = "ingress"
  from_port         = 25565
  to_port           = 25565
  protocol          = "tcp"
  security_group_id = aws_security_group.minecraft.id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  security_group_id = aws_security_group.minecraft.id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "all"
  security_group_id = aws_security_group.minecraft.id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_instance" "minecraft" {
  ami                  = data.aws_ami.amazon_linux_2.id
  instance_type        = var.instance_type
  key_name             = aws_key_pair.awsKey.key_name
  security_groups      = [aws_security_group.minecraft.name]
  associate_public_ip_address = true
  
  tags = {
    Name = "Minecraft"
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo '[servers]' > hosts
      echo "${self.public_dns}     ansible_user=ec2-user     ansible_ssh_private_key_file=keys/awskey" >> hosts
    EOT
  }
}

resource "aws_eip" "minecraft" {
  count    = var.static_ip ? 1 : 0
  instance = aws_instance.minecraft.id
}
