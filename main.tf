variable "region" {
  default = "us-east-2"
}

variable "cluster_name" {
  default= ""
}


provider "aws" {
  access_key = ""
  secret_key = "" 
  region= var.region
}


#Data sources





#VPC resource

resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
}

#Subnet resource

resource "aws_subnet" "main" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "Main"
  }
}


#IAM Role

resource "aws_iam_role" "eks_cluster_role" {
  name = "eks_cluster_role"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:CreateNetworkInterface",
                "ec2:DeleteNetworkInterface",
                "ec2:DetachNetworkInterface",
                "ec2:ModifyNetworkInterfaceAttribute",
                "ec2:DescribeInstances",
                "ec2:DescribeNetworkInterfaces",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeSubnets",
                "ec2:DescribeVpcs",
                "ec2:CreateNetworkInterfacePermission",
                "iam:ListAttachedRolePolicies",
                "ec2:CreateSecurityGroup"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:DeleteSecurityGroup",
                "ec2:RevokeSecurityGroupIngress",
                "ec2:AuthorizeSecurityGroupIngress"
            ],
            "Resource": "arn:aws:ec2:*:*:security-group/*",
            "Condition": {
                "ForAnyValue:StringLike": {
                    "ec2:ResourceTag/Name": "eks-cluster-sg*"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:CreateTags",
                "ec2:DeleteTags"
            ],
            "Resource": [
                "arn:aws:ec2:*:*:vpc/*",
                "arn:aws:ec2:*:*:subnet/*"
            ],
            "Condition": {
                "ForAnyValue:StringLike": {
                    "aws:TagKeys": [
                        "kubernetes.io/cluster/*"
                    ]
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:CreateTags",
                "ec2:DeleteTags"
            ],
            "Resource": [
                "arn:aws:ec2:*:*:security-group/*"
            ],
            "Condition": {
                "ForAnyValue:StringLike": {
                    "aws:TagKeys": [
                        "kubernetes.io/cluster/*"
                    ],
                    "aws:RequestTag/Name": "eks-cluster-sg*"
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": "route53:AssociateVPCWithHostedZone",
            "Resource": "arn:aws:route53:::hostedzone/*"
        },
        {
            "Effect": "Allow",
            "Action": "logs:CreateLogGroup",
            "Resource": "arn:aws:logs:*:*:log-group:/aws/eks/*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogStream",
                "logs:DescribeLogStreams"
            ],
            "Resource": "arn:aws:logs:*:*:log-group:/aws/eks/*:*"
        },
        {
            "Effect": "Allow",
            "Action": "logs:PutLogEvents",
            "Resource": "arn:aws:logs:*:*:log-group:/aws/eks/*:*:*"
        }
    ]
})

  tags = {
    tag-key = "tag-value"
  }
}


#Subnets Resource


#Security Groups Resource


#EKS cluster  Resource

resource "aws_eks_cluster" "my_test_cluster" {
name     = var.cluster_name
  role_arn = aws_iam_role.my_test_cluster.arn

  vpc_config {
    subnet_ids = [aws_subnet.example1.id, aws_subnet.example2.id]
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Cluster handling.
  # Otherwise, EKS will not be able to properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [
    aws_iam_role_policy_attachment.example-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.example-AmazonEKSVPCResourceController,
  ]
}

output "endpoint" {
  value = aws_eks_cluster.my_test_cluster.endpoint
}

output "kubeconfig-certificate-authority-data" {
  value = aws_eks_cluster.my_test_cluster.certificate_authority[0].data
}
  
}

