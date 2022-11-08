################################################
### EKS CLUSTER - PART 2
################################################

resource "aws_eks_cluster" "eks-cluster" {
  name     = "web-eks-cluster"
  version  = var.k8s_version
  role_arn = aws_iam_role.eks_role.arn

  vpc_config {
    subnet_ids              = flatten([var.public_subnets[*], var.private_subnets[*]])
    security_group_ids      = ["${aws_security_group.eks-cluster-sg.id}"]
    endpoint_private_access = true
  }

  depends_on = [
    aws_iam_role.eks_role
  ]
}

### EKS NODE GROUP

resource "aws_eks_node_group" "web_nodes-group" {

  cluster_name    = aws_eks_cluster.eks-cluster.name
  node_group_name = "web_nodes"
  node_role_arn   = aws_iam_role.web_nodes_role.arn
  subnet_ids      = var.private_subnets[*]

  ami_type       = "AL2_x86_64" # AL2_x86_64, AL2_x86_64_GPU, AL2_ARM_64, CUSTOM
  capacity_type  = "ON_DEMAND"  # ON_DEMAND, SPOT
  disk_size      = 30           # Default is 20
  instance_types = ["t2.large"] # 2 CPU and 8GB of memory

  scaling_config {
    desired_size = var.desired_size
    max_size     = var.max_size
    min_size     = var.min_size
  }

  tags = var.tags

  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
  ]
}

### IAM ROLE

resource "aws_iam_role" "eks_role" {
  name = "eks_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "eks.amazonaws.com"
        }
      },
    ]
  })

  tags = var.tags
}

### IAM ROLE POLICY ATTACHMENTS

resource "aws_iam_role_policy_attachment" "AmazonEKSClusterPolicy" {
  role       = aws_iam_role.eks_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}


### WORKER NODE ROLE

resource "aws_iam_role" "web_nodes_role" {
  name = "web_nodes_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = var.tags
}


### WORKER NODES ROLE POLICY ATTACHMENTS

resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly" {
  role       = aws_iam_role.web_nodes_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "AmazonEKS_CNI_Policy" {
  role       = aws_iam_role.web_nodes_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "AmazonEKSWorkerNodePolicy" {
  role       = aws_iam_role.web_nodes_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "EC2InstanceProfileForImageBuilderECRContainerBuilds" {
  role       = aws_iam_role.web_nodes_role.name
  policy_arn = "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilderECRContainerBuilds"
}


### EKS SECURITY GROUPS

resource "aws_security_group" "eks-cluster-sg" {
  name        = "web-cluster-sg"
  description = "Security Group for Control Plane"
  vpc_id      = var.vpc_id

  tags = {
    Name = "web-cluster-sg"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "eks-cluster-ingress-https" {
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow Inbound HTTPS Traffic to Control Plane"
  from_port         = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.eks-cluster-sg.id
  to_port           = 443
  type              = "ingress"
}

resource "aws_security_group" "eks-node-sg" {
  name        = "web-node-sg"
  description = "Security Group for Worker Nodes"
  vpc_id      = var.vpc_id

  tags = {
    Name      = "web-node-sg"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "eks-node-ingress-self" {
  description              = "Allow worker nodes to communicate with each other"
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.eks-node-sg.id
  source_security_group_id = aws_security_group.eks-node-sg.id
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group_rule" "eks-node-ingress-cluster" {
  description              = "Allow worker nodes to receive inbound traffic from control plane"
  from_port                = 1025
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks-node-sg.id
  source_security_group_id = aws_security_group.eks-cluster-sg.id
  to_port                  = 65535
  type                     = "ingress"
}


resource "aws_security_group_rule" "eks-node-ingress-https" {
  description              = "Allow Control Plane to receive inbound traffic from Worker Nodes"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks-cluster-sg.id
  source_security_group_id = aws_security_group.eks-node-sg.id
  to_port                  = 443
  type                     = "ingress"
}
###################################################################