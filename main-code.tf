#Deploying a service with AWS using Terraform: 


#First, connect to the provider (in this case that would be AWS)
terraform {
  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region     = "us-east-1" #change the region depending on requirments 

  #the following secret keys are required to access an AWS account, but we wont use them since this is
  #a educational account 
  access_key = "user-access-key" #aws access key (can be found in the IAM console)
  secret_key = "user-secret-key" #aws secret key (can be found in the IAM console)
}

#1 Create a vpc
resource "aws_vpc" "prod_vpc" {
  cidr_block = "10.0.0.0/16"
}

#2 create an internet gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prod_vpc.id
}

#3 create custom route table
resource "aws_route_table" "prod_route_table" {
  vpc_id = aws_vpc.prod_vpc.id

  route {
    cidr_block = "0.0.0.0/0" #goes wherever (open to all)
    gateway_id = aws_internet_gateway.gw.id
  }
  route{
    ipv6_cidr_block = "::/0" #goes wherever (open to all)
    gateway_id = aws_internet_gateway.gw.id
  }
}

#4 create a subnet
resource "aws_subnet" "subnet-1" {
  vpc_id = aws_vpc.prod_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"
}

#5 associate the route table with the subnet
resource "aws_route_table_association" "subnet-1-assoc" {
  subnet_id = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.prod_route_table.id
}

#6 create a security group that allow port 22,80,443
resource "aws_security_group" "web_sg" {
  vpc_id = aws_vpc.prod_vpc.id
  name = "web_sg"
  description = "Allow SSH and HTTP and HTTPS traffic"

  ingress {
    description = "SSH access"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"] #anyone can access it (Website)
  }
  ingress {
    description = "HTTP access"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"] #anyone can access it (Website)
}

  ingress {
    description = "HTTPS access"
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"] #anyone can access it (Website)
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1" #all protocols
    cidr_blocks = ["0.0.0.0/0"] #anyone can access it (Website)
  }
}

#7 create network interface with an ip in the subnet that was created in step 4
resource "aws_network_interface" "eni" {
  subnet_id = aws_subnet.subnet-1.id
  security_groups = [aws_security_group.web_sg.id]
  private_ips = ["10.0.1.50"]
  
  attachment {
    instance = aws_instance.web.id
    device_index = 1
  }
}
#8 assign an elastic ip to the network interface created in step 7
resource "aws_eip" "web_eip" {
  vpc = true
  network_interface = aws_network_interface.eni.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.gw]
}

#9 create a server and install/enable apache2
resource "aws_instance" "web-server-instance" {
  ami = "ami-0c55b159cbfafe1f0" #ubuntu server, but it can be any ami
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "labsuser" #key pair name

  network_interface {
    network_interface_id = aws_network_interface.eni.id
    device_index = 0
  } 
  #the following code allows a user to run a script when the instance is created by using yaml
  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemctl start apache2
              sudo bash -c 'echo "<h1>Hello World</h1>" > /var/www/html/index.html'
              EOF
  tags = {
    Name = "web-server-instance"
  }
}











# #terraform init: looks at all the config and looks for all the providers
# #and then it will download all the necessary plugins to interact with it

# #terraform plan: looks at the current state of the infrastructure and compares it to the desired state
# #and then it will show you a plan of what it will do to get to the desired state

# #terraform apply: will apply the changes to the infrastructure
# #if you terraform apply again with a copy of the same instance, it
# #will not create a new instance, it will just update the existing one (yipee!)

# #terraform destroy: will destroy the infrastructure