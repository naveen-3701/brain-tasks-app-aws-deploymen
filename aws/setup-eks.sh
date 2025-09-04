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

# Create EKS cluster
eksctl create cluster \
    --name $CLUSTER_NAME \
    --region $REGION \
    --nodegroup-name standard-workers \
    --node-type $NODE_TYPE \
    --nodes $NODES \
    --nodes-min $MIN_NODES \
    --nodes-max $MAX_NODES \
    --with-oidc \
    --ssh-access \
    --ssh-public-key my-key \
    --managed

echo "EKS cluster created successfully!"

# Update kubeconfig
aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION

# Install AWS Load Balancer Controller
echo "Installing AWS Load Balancer Controller..."

# Create IAM OIDC provider
eksctl utils associate-iam-oidc-provider --cluster $CLUSTER_NAME --region $REGION --approve

# Create IAM policy for Load Balancer Controller
aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://aws-load-balancer-controller-policy.json

# Create service account
eksctl create iamserviceaccount \
    --cluster=$CLUSTER_NAME \
    --namespace=kube-system \
    --name=aws-load-balancer-controller \
    --role-name AmazonEKSLoadBalancerControllerRole \
    --attach-policy-arn=arn:aws:iam::$AWS_ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy \
    --approve

# Install Load Balancer Controller using Helm
helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
    -n kube-system \
    --set clusterName=$CLUSTER_NAME \
    --set serviceAccount.create=false \
    --set serviceAccount.name=aws-load-balancer-controller

echo "AWS Load Balancer Controller installed!"

# Create namespace for the application
kubectl create namespace brain-tasks-app

echo "EKS setup completed successfully!"
echo "Cluster name: $CLUSTER_NAME"
echo "Region: $REGION"
