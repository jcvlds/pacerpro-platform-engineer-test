terraform {
    required_version = ">= 1.8.0"

    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "~> 6.0"
        }
        archive = {
            source = "hashicorp/archive"
            version = "~> 2.7"
        }
    }
}

provider "aws" {
    region = var.aws_region
    access_key = var.access_key
    secret_key = var.secret_key
}

# EC2 Instance AMI + SSH KEY + Instance

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_key_pair" "ssh_key" {
  key_name   = "sumo-demo-key"
  public_key = file("../sumo-demo-key.pub")
}

resource "aws_instance" "web_server" {
    ami = data.aws_ami.amazon_linux.id
    instance_type = "t3.micro"
    key_name = aws_key_pair.ssh_key.key_name

    root_block_device {
        volume_size = 50
        volume_type = "gp3"
        delete_on_termination = true
    }
    
    tags = {
        Name = "sumo-demo-instance"
    }
}

# SNS
resource "aws_sns_topic" "alert_topic" {
    name = "sumo-alert-topic"
}

# LAMBDA Role + Role Attachment

resource "aws_iam_role" "lambda_role" {
    name = "sumo-lambda-role"

    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
        {
            Action = "sts:AssumeRole"
            Effect = "Allow"
            Sid    = ""
            Principal = {
            Service = "lambda.amazonaws.com"
            }
        },
        ]
    })
}

resource "aws_iam_policy" "lambda_policy" {
    name = "sumo-lambda-policy"

    policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "ec2:RebootInstances"
        Effect = "Allow"
        Resource = aws_instance.web_server.arn
      },
      {
        Action = "ec2:DescribeInstances"
        Effect = "Allow"
        Resource = aws_instance.web_server.arn
      },
      {
        Action = "sns:Publish"
        Effect = "Allow"
        Resource = aws_sns_topic.alert_topic.arn
      },
      {
        Effect = "Allow"
        Action = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# Lambda Function + Function URL

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir = "${path.module}/../lambda_function"
  output_path = "${path.module}/../lambda_function/lambda.zip"
}

resource "aws_lambda_function" "sumo_handler" {
    function_name = "sumo-alert-handler"
    role          = aws_iam_role.lambda_role.arn
    handler       = "app.lambda_handler"
    runtime       = "python3.14"
    filename      = data.archive_file.lambda_zip.output_path
    code_sha256   = data.archive_file.lambda_zip.output_base64sha256


    environment {
        variables = {
        SNS_TOPIC_ARN   = aws_sns_topic.alert_topic.arn
        }
    }
}

resource "aws_lambda_function_url" "secure_url" {
  function_name      = aws_lambda_function.sumo_handler.function_name
  authorization_type = "AWS_IAM"
}