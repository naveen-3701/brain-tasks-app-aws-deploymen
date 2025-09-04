#!/bin/bash

# Setup EKS Cluster for Brain Tasks App
set -e

CLUSTER_NAME=${1:-brain-tasks-cluster}
REGION=${2:-us-east-1}
NODE_TYPE=${3:-t3.medium}
NODES=${4:-3}
MIN_NODES=${5:-1}
MAX_NODES=${6:-4}

echo "Setting up EKS cluster: $CLUSTER_NAME in region: $REGION"

# Check if eksctl is installed
if ! command -v eksctl &> /dev/null; then
    echo "eksctl is not installed. Please install it first."
    echo "Visit: https://eksctl.io/introduction/installation/"
    exit 1
fi

# Create EKS cluster (skip if exists)
eksctl create cluster \
    --name $CLUSTER_NAME \
    --region $REGION \
    --nodegroup-name standard-workers \
    --node-type $NODE_TYPE \
    --nodes $NODES \
    --nodes-min $MIN_NODES \
    --nodes-max $MAX_NODES \
    --with-oidc \
    --managed 2>/dev/null || echo "Cluster already exists"

echo "EKS cluster created successfully!"

# Update kubeconfig
aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION

# Install AWS Load Balancer Controller
echo "Installing AWS Load Balancer Controller..."

# Create IAM OIDC provider (skip if exists)
eksctl utils associate-iam-oidc-provider --cluster $CLUSTER_NAME --region $REGION --approve 2>/dev/null || echo "OIDC provider already exists"

# Get account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create IAM policy for Load Balancer Controller (skip if exists)
aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://aws-load-balancer-controller-policy.json 2>/dev/null || echo "Policy already exists"

# Create service account (skip if exists)
eksctl create iamserviceaccount \
    --cluster=$CLUSTER_NAME \
    --namespace=kube-system \
    --name=aws-load-balancer-controller \
    --role-name AmazonEKSLoadBalancerControllerRole \
    --attach-policy-arn=arn:aws:iam::${ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy \
    --approve 2>/dev/null || echo "Service account already exists"

# Install Load Balancer Controller using Helm
if ! command -v helm &> /dev/null; then
    echo "Helm is not installed. Please install it first."
    echo "Visit: https://helm.sh/docs/intro/install/"
    exit 1
fi

helm repo add eks https://aws.github.io/eks-charts 2>/dev/null || echo "Helm repo already exists"
helm repo update

# Install Load Balancer Controller (skip if exists)
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
    -n kube-system \
    --set clusterName=$CLUSTER_NAME \
    --set serviceAccount.create=false \
    --set serviceAccount.name=aws-load-balancer-controller 2>/dev/null || echo "Load Balancer Controller already installed"

echo "AWS Load Balancer Controller installed!"

# Create namespace for the application (skip if exists)
kubectl create namespace brain-tasks-app 2>/dev/null || echo "Namespace already exists"

echo "EKS setup completed successfully!"
echo "Cluster name: $CLUSTER_NAME"
echo "Region: $REGION"