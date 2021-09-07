variable "region" {
  default = "us-east-2"
}

variable "cluster_name" {
  default = ""
}


provider "aws" {
  #access_key = "AKIARU7V64ZGRSNAAT45"
  #secret_key = "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"
  region     = var.region
}


#Data sources



#VPC resource
#2 vpcs are needed, one for the EKS Control Plane and another for the worker nodes
#Check Cidr blocks!!!


resource "aws_vpc" "eks_control_plane_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "eks_control_plane_vpc"
  }
}

resource "aws_vpc" "worker_nodes_vpc" {
  cidr_block = "192.168.0.0/16"

  tags = {
    Name = "worker_nodes_vpc"
  }
}

#Control Plane Subnet

resource "aws_subnet" "control_plane_subnet" {
  vpc_id     = aws_vpc.eks_control_plane_vpc.id
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "Control Plane Subnet"
  }
}

#Worker nodes subnet

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "worker_nodes_subnet" {
  count = 2

  availability_zone = data.aws_availability_zones.available.names[count.index]
  cidr_block        = cidrsubnet(aws_vpc.worker_nodes_vpc.cidr_block, 8, count.index)
  vpc_id            = aws_vpc.worker_nodes_vpc.id

  tags = {
    "kubernetes.io/cluster/${aws_eks_cluster.eks_cluster.name}" = "shared"
  }
}

#EKS Cluster IAM Role resource

resource "aws_iam_role" "eks_cluster_iam_role" {
  name = "eks_cluster_iam_role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "example-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_iam_role.name
}

# Optionally, enable Security Groups for Pods
# Reference: https://docs.aws.amazon.com/eks/latest/userguide/security-groups-for-pods.html
resource "aws_iam_role_policy_attachment" "example-AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks_cluster_iam_role.name
}



#EKS cluster  Resource

resource "aws_eks_cluster" "eks_cluster" {
  name     = "eric_eks_cluster"
  role_arn = aws_iam_role.eks_cluster_iam_role.arn

  vpc_config {
    subnet_ids = [aws_subnet.control_plane_subnet.id, aws_subnet.control_plane_subnet.id]
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Cluster handling.
  # Otherwise, EKS will not be able to properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [
    aws_iam_role_policy_attachment.example-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.example-AmazonEKSVPCResourceController,
  ]
}

output "endpoint" {
  value = aws_eks_cluster.eks_cluster.endpoint
}

output "kubeconfig-certificate-authority-data" {
  value = aws_eks_cluster.eks_cluster.certificate_authority[0].data
}


#Worker Nodes IAM Roles

resource "aws_iam_role" "worker_nodes_iam_role" {
  name = "worker_nodes_iam_role"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "example-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.worker_nodes_iam_role.name
}

resource "aws_iam_role_policy_attachment" "example-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.worker_nodes_iam_role.name
}

resource "aws_iam_role_policy_attachment" "example-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.worker_nodes_iam_role.name
}


#EKS Worker Nodes ResourceS
#Incomplete: cluster name not set, subnets not set

  resource "aws_eks_node_group" "eks_node_group" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "eric_node_group_test"
  node_role_arn   = aws_iam_role.worker_nodes_iam_role.arn
  subnet_ids      = aws_subnet.worker_nodes_subnet[*].id

  scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }

  update_config {
    max_unavailable = 2
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
    depends_on = [
    aws_iam_role_policy_attachment.example-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.example-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.example-AmazonEC2ContainerRegistryReadOnly,
  ]
}
