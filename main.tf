provider "aws" {
  region = "ap-northeast-1"
}

module "vpc" {
  source      = "./modules/vpc"
  project     = var.project
  environment = var.environment
}


data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "role" {
  name               = "private_ec2_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}


resource "aws_iam_instance_profile" "systems_manager" {
  name = "InstanceProfile"
  role = aws_iam_role.role.name
}

resource "aws_iam_instance_profile" "default" {
  name = "ssm_role_profile"
  role = aws_iam_role.default.name
  path = "/"
}

resource "aws_instance" "private" {
  ami           = "ami-0f310fced6141e627"
  instance_type = "t2.micro"
  # iam_instance_profile = aws_iam_instance_profile.systems_manager.name
  iam_instance_profile = aws_iam_instance_profile.default.name
  subnet_id            = module.vpc.private_subnet_ids[0]
  user_data            = "${base64encode(file("./userdata.sh"))}"

}

resource "random_id" "ssm_id" {
  byte_length = 8
}

resource "aws_s3_bucket" "session_manager_log_bucket" {
  bucket        = "session-manager-log-${random_id.ssm_id.hex}"
  force_destroy = true

  lifecycle_rule {
    enabled = true

    expiration {
      days = "180"
    }
  }
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

resource "aws_ssm_document" "default" {
  name            = "ssh_document"
  document_type   = "Session"
  document_format = "JSON"
  tags = merge(
    {
      Name        = "ssh_document",
      Project     = var.project,
      Environment = var.environment
    },
    var.tags
  )
  content = <<DOC
{
    "schemaVersion": "1.0",
    "description": "Document to hold regional settings for Session Manager",
    "sessionType": "Standard_Stream",
    "inputs": {
        "s3BucketName": "${aws_s3_bucket.session_manager_log_bucket.id}",
        "s3EncryptionEnabled": true
    }
}
DOC

}

resource "aws_iam_policy" "ssm_policy" {
  name   = "ssm_policy"
  policy = local.iam_policy
  path   = "/"
}


locals {
  iam_name   = "${var.name}-session-manager"
  iam_policy = data.aws_iam_policy.default.policy
}

data "aws_iam_policy" "default" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
}




resource "aws_iam_role" "default" {
  name               = "ssm_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
  path               = "/"
  description        = ""
  tags = merge(
    {
      Name        = "ssh_document",
      Project     = var.project,
      Environment = var.environment
    },
    var.tags
  )
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}


resource "aws_iam_role_policy" "s3" {
  name               = "s3full"
  role   = aws_iam_role.default.id

  policy = data.aws_iam_policy_document.s3full.json
  
}

data "aws_iam_policy_document" "s3full" {
  statement {
    actions = [
      "s3:*"
    ]
    resources = ["*"]

  }
}

resource "aws_iam_role_policy_attachment" "default" {
  role       = aws_iam_role.default.name
  policy_arn = aws_iam_policy.ssm_policy.arn
}


