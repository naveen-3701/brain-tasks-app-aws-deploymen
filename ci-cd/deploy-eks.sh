#!/bin/bash

# EKS Deployment Script for Brain Tasks App
set -e

echo "Starting EKS deployment..."

# Update image in deployment
kubectl set image deployment/brain-tasks-app brain-tasks-app=$ECR_REPOSITORY_URI:$IMAGE_TAG -n brain-tasks-app

# Wait for deployment to complete
kubectl rollout status deployment/brain-tasks-app -n brain-tasks-app

# Check deployment status
kubectl get pods -n brain-tasks-app

echo "Deployment completed successfully!"

# Get Load Balancer ARN
echo "Getting Load Balancer ARN..."
kubectl get ingress brain-tasks-app-ingress -n brain-tasks-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

echo "Deployment script completed!"
