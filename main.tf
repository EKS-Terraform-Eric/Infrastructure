data "aws_availability_zones" "available" {}

variable "region" {
  default = "us-east-2"
}

variable "cluster_name" {
  default = "terraform_eks_eric"
  type= string
}


provider "aws" {
  #access_key = "AKIARU7V64ZGRSNAAT45"
  #secret_key = "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"
  region     = var.region
}

#Data sources



#VPC resource

resource "aws_vpc" "eks_vpc" {
  cidr_block = "10.0.0.0/16"

 # tags = {
 #    map(
 #      "Name" , "terraform-eks-vpc",
 #      "kubernetes.io/cluster/${var.cluster_name}", "shared",
 #    )
 # }

 tags = "${
    map(
     "Name", "terraform-eks-vpc",
     "kubernetes.io/cluster/${var.cluster_name}", "shared",
    )
  }"
}
resource "aws_subnet" "eks_subnet" {
  count = 2

  availability_zone = data.aws_availability_zones.available.names[count.index]
  cidr_block        = "10.0.${count.index}.0/24"
  vpc_id            = aws_vpc.eks_vpc.id

  tags =
    map(
     Name = "terraform-eks-subnet",
     "kubernetes.io/cluster/${var.cluster_name}" = "shared",
    )
}

resource "aws_internet_gateway" "eks_internet_gateway" {
  vpc_id = aws_vpc.eks_vpc.id

  tags = {
    Name = "terraform-eks-igw"
  }
}

resource "aws_route_table" "eks_route_table" {
  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.eks_internet_gateway.id
  }
}

resource "aws_route_table_association" "route_table_association" {
  count = 2

  subnet_id      = aws_subnet.eks_subnet[*].id[count.index]
  route_table_id = aws_route_table.eks_route_table.id
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

resource "aws_iam_role_policy_attachment" "AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_iam_role.name
}

# Optionally, enable Security Groups for Pods
# Reference: https://docs.aws.amazon.com/eks/latest/userguide/security-groups-for-pods.html
resource "aws_iam_role_policy_attachment" "AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks_cluster_iam_role.name
}

#EKS Cluster Security group
#Controls Access to Kubernetes master nodes

resource "aws_security_group" "master_nodes_sg" {
  name        = "master_nodes_sg"
  vpc_id      = aws_vpc.eks_vpc.id

  ingress = [
    {
      description      = "TLS from VPC"
      from_port        = 443
      to_port          = 443
      protocol         = "tcp"
      cidr_blocks      = [aws_vpc.eks_vpc.cidr_block]
      ipv6_cidr_blocks = [aws_vpc.eks_vpc.ipv6_cidr_block]
    }
  ]

  egress = [
    {
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  ]

  tags = {
  Name = "master_nodes_sg"
}
}

#EKS cluster  Resource

resource "aws_eks_cluster" "eks_cluster" {
  name     = "eric_eks_cluster"
  role_arn = aws_iam_role.eks_cluster_iam_role.arn

  vpc_config {
    security_group_ids = [aws_security_group.master_nodes_sg.id]
    subnet_ids = [aws_subnet.eks_subnet[*].id]
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Cluster handling.
  # Otherwise, EKS will not be able to properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.AmazonEKSVPCResourceController,
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

resource "aws_iam_role_policy_attachment" "AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.worker_nodes_iam_role.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.worker_nodes_iam_role.name
}

resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.worker_nodes_iam_role.name
}


#EKS Worker Nodes ResourceS
#Incomplete: cluster name not set, subnets not set

  resource "aws_eks_node_group" "eks_node_group" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "eric_node_group_test"
  node_role_arn   = aws_iam_role.worker_nodes_iam_role.arn
  subnet_ids      = aws_subnet.eks_subnet[*].id

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
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly,
  ]
}
