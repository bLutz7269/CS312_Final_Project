# Creating an automated Minecraft Server Using AWS
This project automates the creation of a Minecraft server(Java 1.19.3) using terraform and ansible. This project was created for class CS312(System Admin). I used https://github.com/Tom01098/terraform-aws-minecraft/tree/main as reference for some of the code so checkout this link if you are having trouble setting up your server.
## Setup
1. To start you create a folder to store all of your code named my_aws_server. Then in that folder create a scripts folder and a keys folder. 

2. install terraform using ```brew install terraform```

3. create the main terraform file using ```touch main.tf```. Then in your terminal run ```terraform init``` to intialize your terraform enviornment.

4. create a credential file then go to AWS Lab and start it up. After starting it press AWS Details in the top right. Next press show next to AWS CLI and copy the credentails into your credentials file. (remember the path to the file)

5. Navigate into to the keys folder and create a key pair using ```ssh-keygen -t ed25519``` and name it awsKey.
## Creating the Terraform Script to Create the EC2 
1. create the provider configurations by copying the code below. Change the shared_credentials_files path to your path and region to your prefered region.
``` 
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
    region     = "us-west-2"
    shared_credentials_files=["file/path/to/credentials/file"]
} 
```
2. Create the keypair and instance configuration. Make sure to paste in your awsKey.pub contents.
```
data "aws_ami" "amazon_linux_2" {
  owners      = ["amazon"]
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-2.*"]
  }
}

resource "aws_key_pair" "awsKey" {
    key_name = "awKey"
    public_key = <"paste in awsKey.pub content">
}
```

3. Create a security group to allow access into your minecraft server and connection to install the server.
```
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
```
4. Create the EC2 instance by copying in the code below. This uses the previous resource creations to create an EC2 instance.
```
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
      echo "${self.public_dns}     ansible_user=ec2-user     ansible_ssh_private_key_file=keys/awsKey" >> hosts
    EOT
  }
}
```

5. Create a ```variables.tf``` file and paste the following code:
```
variable "ec2_instance_connect" {
  type        = bool
  default     = false
  description = "Keep SSH (port 22) open to allow connections via EC2 Instance Connect."
}

variable "download_url" {
  type        = string
  default     = "https://piston-data.mojang.com/v1/objects/c9df48efed58511cdd0213c56b9013a7b5c9ac1f/server.jar"
  description = "Minecraft server download URL"
}

variable "instance_type" {
  type        = string
  default     = "t2.medium"
  description = "The EC2 instance type of the server. Requires at least t2.medium."
}

variable "region" {
  type        = string
  default     = "eu-west-2"
  description = "AWS region to deploy to"
}

variable "static_ip" {
  type        = bool
  default     = false
  description = "Should the instance retain its IPv4 address after being stopped? Charges apply while the server is stopped."
}

variable "private_key"{
  type        = string
  default     = "keys/awsKey"
  description = "The path to your key files"
}
```

6. Create a ```outputs.tf``` file and paste the following code. This printsout the outputs after running ```terraform apply```:
```
output "ssh" {
  value       = aws_instance.minecraft.public_dns
  description = "URL to SSH into the server"
}

output "ip" {
  value       = var.static_ip ? aws_eip.minecraft[0].public_ip : aws_instance.minecraft.public_ip
  description = "The IPv4 address assigned to the server"
}
```

## Creating the Ansible playbook
1. In the scripts folder create a file named ```startup.sh``` and paste in the following code: 
``` 
#!/bin/bash
sudo yum update -y
sudo yum install -y java

mkdir minecraft
cd minecraft
sudo wget "https://piston-data.mojang.com/v1/objects/c9df48efed58511cdd0213c56b9013a7b5c9ac1f/server.jar" -O server.jar
sudo echo "eula=true" > eula.txt
```
2. go back to your main folder and create a file named ```playbook.yml```. Paste in the following code that is used to run the install script and create the ```minecraft.service```:
```
- name: Minecraft server
  hosts: all
  become: yes
  tasks:
  - name: copy and execute script
    script: scripts/startup.sh

  - name: Create systemd service unit for Minecraft
    copy:
      content: |
        [Unit]
        Description=Minecraft Server
        After=network.target

        [Service]
        User=root

        WorkingDirectory=/home/ec2-user/minecraft
        ExecStart=/usr/bin/java -jar /home/ec2-user/minecraft/server.jar nogui
        Restart=always
        RestartSec=3

        [Install]
        WantedBy=multi-user.target
      dest: /etc/systemd/system/minecraft.service
      mode: '0644'
      
  - name: Reload systemd to apply changes
    command: sudo systemctl daemon-reload

  - name: Enable minecraft.service
    command: sudo systemctl enable minecraft.service

  - name: Start minecraft.service
    command: sudo systemctl start minecraft.service

```

## Starting the Server
1. To start the server Run ```terraform apply``` to create your EC2 instance. This will also print out your IP address that your server is hosted on.
2. Then Run ```ansible-playbook -i hosts playbook.yml``` to install and configure your minecraft server.
3. After waiting a couple minuets you can open up Minecraft on java version 1.19.3 and connect to your server using the servers IP address.
