# Load balancer is main point of entry for
# http traffic to application servers
resource "aws_lb" "demo" {
  name               = "demo-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.load_balancer.id]
  subnets            = var.public_subnets
}

resource "aws_security_group" "load_balancer" {
  name        = "load-balancer-security-group"
  description = "allow http access"
  vpc_id      = var.vpc_id

  ingress {
    description = "public http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Application server instance
resource "aws_instance" "application_server" {
  ami           = var.application_server_ami
  instance_type = "t3.medium"

  subnet_id                   = var.public_subnets[0]
  associate_public_ip_address = true

  key_name = "demo-key"

  iam_instance_profile = aws_iam_instance_profile.demo_profile.name

  vpc_security_group_ids = [
    aws_security_group.application_server_sg.id,
  ]
}

# Instance profile which allows us to attach iam roles
# to the application server ec2 instance
resource "aws_iam_instance_profile" "demo_profile" {
  name = "demo_profile"
  role = aws_iam_role.demo_role.name
}

resource "aws_iam_role" "demo_role" {
  name = "demo-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

# Application server needs to be able to write to
# some s3 buckets
resource "aws_iam_role_policy" "demo_policy" {
  name = "demo_policy"
  role = aws_iam_role.demo_role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_security_group" "application_server_sg" {
  name        = "application-server_sg-security-group"
  description = "application_server_sg"
  vpc_id      = var.vpc_id

  ingress {
    description = "public http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Elasticsearch EC2 instance
# used by application servers for search
resource "aws_instance" "elasticsearch" {
  ami           = var.elasticsearch_ami
  instance_type = "t3.medium"

  subnet_id                   = module.vpc.public_subnets[0]
  associate_public_ip_address = true

  key_name = "demo-key"

  vpc_security_group_ids = [
    aws_security_group.allow_es_from_app.id
  ]
}

resource "aws_security_group" "allow_es_from_app" {
  name        = "allow-es-from-app-security-group"
  description = "allow-es-from-app"
  vpc_id      = var.vpc_id

  ingress {
    description     = "elasticsearch cluster"
    from_port       = 9300
    to_port         = 9300
    protocol        = "tcp"
    security_groups = [aws_security_group.application_server_sg.id]
  }

  ingress {
    description     = "elasticsearch api"
    from_port       = 9200
    to_port         = 9200
    protocol        = "tcp"
    security_groups = [aws_security_group.application_server_sg.id]
  }

  ingress {
    description = "ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
