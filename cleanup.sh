#!/bin/bash

# Cleanup Script for Brain Tasks App AWS Resources
set -e

REGION=${1:-us-east-1}
CLUSTER_NAME=${2:-brain-tasks-cluster}

echo "=========================================="
echo "Brain Tasks App - AWS Resources Cleanup"
echo "=========================================="
echo "Region: $REGION"
echo "EKS Cluster: $CLUSTER_NAME"
echo "=========================================="

read -p "Are you sure you want to delete all AWS resources? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cleanup cancelled."
    exit 1
fi

echo "Starting cleanup process..."

# Delete CodePipeline
echo "Deleting CodePipeline..."
aws codepipeline delete-pipeline --name brain-tasks-app-pipeline --region $REGION 2>/dev/null || echo "Pipeline not found or already deleted"

# Delete CodeDeploy
echo "Deleting CodeDeploy..."
aws deploy delete-application --application-name brain-tasks-app --region $REGION 2>/dev/null || echo "CodeDeploy application not found or already deleted"

# Delete CodeBuild
echo "Deleting CodeBuild..."
aws codebuild delete-project --name brain-tasks-app-build --region $REGION 2>/dev/null || echo "CodeBuild project not found or already deleted"

# Delete ECR repository
echo "Deleting ECR repository..."
aws ecr delete-repository --repository-name brain-tasks-app --force --region $REGION 2>/dev/null || echo "ECR repository not found or already deleted"

# Delete EKS cluster
echo "Deleting EKS cluster..."
eksctl delete cluster --name $CLUSTER_NAME --region $REGION 2>/dev/null || echo "EKS cluster not found or already deleted"

# Delete IAM roles
echo "Deleting IAM roles..."
aws iam delete-role --role-name CodePipelineServiceRole 2>/dev/null || echo "CodePipeline role not found or already deleted"
aws iam delete-role --role-name CodeBuildServiceRole 2>/dev/null || echo "CodeBuild role not found or already deleted"
aws iam delete-role --role-name CodeDeployServiceRole 2>/dev/null || echo "CodeDeploy role not found or already deleted"

echo "=========================================="
echo "Cleanup completed successfully!"
echo "=========================================="
echo "All AWS resources have been removed."
echo "Note: Some resources may take a few minutes to be completely removed."
