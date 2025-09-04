#!/bin/bash

# Master Setup Script for Brain Tasks App AWS Deployment
set -e

# Configuration
REGION=${1:-us-east-1}
CLUSTER_NAME=${2:-brain-tasks-cluster}
ECR_REPOSITORY_NAME="brain-tasks-app"
CODEBUILD_PROJECT_NAME="brain-tasks-app-build"
CODEDEPLOY_APPLICATION_NAME="brain-tasks-app"
CODEDEPLOY_DEPLOYMENT_GROUP_NAME="brain-tasks-app-deployment-group"
PIPELINE_NAME="brain-tasks-app-pipeline"

echo "=========================================="
echo "Brain Tasks App - AWS Deployment Setup"
echo "=========================================="
echo "Region: $REGION"
echo "EKS Cluster: $CLUSTER_NAME"
echo "=========================================="

# Check prerequisites
echo "Checking prerequisites..."
command -v aws >/dev/null 2>&1 || { echo "AWS CLI is required but not installed. Aborting." >&2; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "kubectl is required but not installed. Aborting." >&2; exit 1; }
command -v docker >/dev/null 2>&1 || { echo "Docker is required but not installed. Aborting." >&2; exit 1; }

# Make scripts executable
chmod +x aws/*.sh
chmod +x ci-cd/*.sh

# Step 1: Setup ECR Repository
echo ""
echo "Step 1: Setting up ECR Repository..."
./aws/setup-ecr.sh $REGION

# Get ECR repository URI
ECR_REPOSITORY_URI=$(aws ecr describe-repositories \
    --repository-names $ECR_REPOSITORY_NAME \
    --region $REGION \
    --query 'repositories[0].repositoryUri' \
    --output text)

echo "ECR Repository URI: $ECR_REPOSITORY_URI"

# Step 2: Setup EKS Cluster
echo ""
echo "Step 2: Setting up EKS Cluster..."
./aws/setup-eks.sh $CLUSTER_NAME $REGION

# Step 3: Setup CodeBuild
echo ""
echo "Step 3: Setting up CodeBuild..."
./aws/setup-codebuild.sh $CODEBUILD_PROJECT_NAME $REGION $ECR_REPOSITORY_URI

# Step 4: Setup CodeDeploy
echo ""
echo "Step 4: Setting up CodeDeploy..."
./aws/setup-codedeploy.sh $CODEDEPLOY_APPLICATION_NAME $CODEDEPLOY_DEPLOYMENT_GROUP_NAME $REGION $CLUSTER_NAME

# Step 5: Setup CodePipeline
echo ""
echo "Step 5: Setting up CodePipeline..."
./aws/setup-codepipeline.sh $PIPELINE_NAME $REGION $CODEBUILD_PROJECT_NAME $CODEDEPLOY_APPLICATION_NAME $CODEDEPLOY_DEPLOYMENT_GROUP_NAME

# Step 6: Deploy to EKS
echo ""
echo "Step 6: Deploying to EKS..."
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/ingress.yaml

# Wait for deployment
echo "Waiting for deployment to complete..."
kubectl rollout status deployment/brain-tasks-app -n brain-tasks-app

# Get Load Balancer ARN
echo ""
echo "Getting Load Balancer ARN..."
LOAD_BALANCER_ARN=$(kubectl get ingress brain-tasks-app-ingress -n brain-tasks-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "Not available yet")

echo "=========================================="
echo "Setup Completed Successfully!"
echo "=========================================="
echo "ECR Repository: $ECR_REPOSITORY_URI"
echo "EKS Cluster: $CLUSTER_NAME"
echo "CodeBuild Project: $CODEBUILD_PROJECT_NAME"
echo "CodeDeploy Application: $CODEDEPLOY_APPLICATION_NAME"
echo "CodePipeline: $PIPELINE_NAME"
echo "Load Balancer: $LOAD_BALANCER_ARN"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Push code to GitHub to trigger the pipeline"
echo "2. Monitor the pipeline in AWS Console"
echo "3. Check application status: kubectl get pods -n brain-tasks-app"
echo "4. Access application via Load Balancer URL"
echo "=========================================="
