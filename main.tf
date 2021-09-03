variable "region" {
  default = "us-east-2"
}

variable "cluster_name" {
  default = ""
}


provider "aws" {
  access_key = "AKIARU7V64ZGRSNAAT45"
  secret_key = "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"
  region     = var.region
}


#Data sources



#VPC resource
#2 vpcs are needed, one for the EKS Control Plane and another for the worker nodes


resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"k

  tags = {
    Name = "eks_vpc"
  }
}

#Subnet resource

resource "aws_subnet" "main" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "Main"
  }
}

#IAM Role resource 

resource "aws_iam_role" "eks_cluster_role" {
  name = "eks_cluster_role"

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

resource "aws_iam_policy" "eks_cluster_policy" {
  name        = "eks_cluster_policy"
  description = "An Amazon EKS Cluster policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ec2:Describe*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "test-attach" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = aws_iam_policy.eks_cluster_policy.arn
}

#Security Groups Resource


#EKS cluster  Resource

#resource "aws_eks_cluster" "my_test_cluster" {
#name     = var.cluster_name
#  role_arn = aws_iam_role.my_test_cluster.arn
#
#  vpc_config {
#    subnet_ids = [aws_subnet.example1.id, aws_subnet.example2.id]
#  }
#
#  # Ensure that IAM Role permissions are created before and deleted after EKS Cluster handling.
#  # Otherwise, EKS will not be able to properly delete EKS managed EC2 infrastructure such as Security Groups.
#  depends_on = [
#    aws_iam_role_policy_attachment.example-AmazonEKSClusterPolicy,
#    aws_iam_role_policy_attachment.example-AmazonEKSVPCResourceController,
#  ]
#}
#
#output "endpoint" {
#  value = aws_eks_cluster.my_test_cluster.endpoint
#}
#
#output "kubeconfig-certificate-authority-data" {
#  value = aws_eks_cluster.my_test_cluster.certificate_authority[0].data
#}

#}

