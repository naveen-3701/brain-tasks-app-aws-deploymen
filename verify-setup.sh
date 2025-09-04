#!/bin/bash

# Verification Script for Brain Tasks App Setup
set -e

REGION=${1:-us-east-1}
CLUSTER_NAME=${2:-brain-tasks-cluster}

echo "=========================================="
echo "Brain Tasks App - Setup Verification"
echo "=========================================="
echo "Region: $REGION"
echo "EKS Cluster: $CLUSTER_NAME"
echo "=========================================="

# Check AWS CLI configuration
echo "1. Checking AWS CLI configuration..."
if aws sts get-caller-identity >/dev/null 2>&1; then
    echo "✅ AWS CLI is configured"
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    echo "   Account ID: $ACCOUNT_ID"
else
    echo "❌ AWS CLI is not configured or credentials are invalid"
    exit 1
fi

# Check ECR repository
echo ""
echo "2. Checking ECR repository..."
if aws ecr describe-repositories --repository-names brain-tasks-app --region $REGION >/dev/null 2>&1; then
    echo "✅ ECR repository exists"
    REPO_URI=$(aws ecr describe-repositories --repository-names brain-tasks-app --region $REGION --query 'repositories[0].repositoryUri' --output text)
    echo "   Repository URI: $REPO_URI"
else
    echo "❌ ECR repository not found"
fi

# Check EKS cluster
echo ""
echo "3. Checking EKS cluster..."
if aws eks describe-cluster --name $CLUSTER_NAME --region $REGION >/dev/null 2>&1; then
    echo "✅ EKS cluster exists"
    CLUSTER_STATUS=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query 'cluster.status' --output text)
    echo "   Cluster status: $CLUSTER_STATUS"
    
    # Check if kubectl can access the cluster
    if kubectl get nodes >/dev/null 2>&1; then
        echo "✅ kubectl can access EKS cluster"
        NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
        echo "   Node count: $NODE_COUNT"
    else
        echo "❌ kubectl cannot access EKS cluster"
    fi
else
    echo "❌ EKS cluster not found"
fi

# Check CodeBuild project
echo ""
echo "4. Checking CodeBuild project..."
if aws codebuild batch-get-projects --names brain-tasks-app-build --region $REGION >/dev/null 2>&1; then
    echo "✅ CodeBuild project exists"
else
    echo "❌ CodeBuild project not found"
fi

# Check CodeDeploy application
echo ""
echo "5. Checking CodeDeploy application..."
if aws deploy get-application --application-name brain-tasks-app --region $REGION >/dev/null 2>&1; then
    echo "✅ CodeDeploy application exists"
else
    echo "❌ CodeDeploy application not found"
fi

# Check CodePipeline
echo ""
echo "6. Checking CodePipeline..."
if aws codepipeline get-pipeline --name brain-tasks-app-pipeline --region $REGION >/dev/null 2>&1; then
    echo "✅ CodePipeline exists"
else
    echo "❌ CodePipeline not found"
fi

# Check Kubernetes resources
echo ""
echo "7. Checking Kubernetes resources..."
if kubectl get namespace brain-tasks-app >/dev/null 2>&1; then
    echo "✅ Kubernetes namespace exists"
    
    # Check deployment
    if kubectl get deployment brain-tasks-app -n brain-tasks-app >/dev/null 2>&1; then
        echo "✅ Kubernetes deployment exists"
        DEPLOYMENT_STATUS=$(kubectl get deployment brain-tasks-app -n brain-tasks-app -o jsonpath='{.status.conditions[?(@.type=="Available")].status}')
        echo "   Deployment status: $DEPLOYMENT_STATUS"
    else
        echo "❌ Kubernetes deployment not found"
    fi
    
    # Check service
    if kubectl get service brain-tasks-app-service -n brain-tasks-app >/dev/null 2>&1; then
        echo "✅ Kubernetes service exists"
    else
        echo "❌ Kubernetes service not found"
    fi
    
    # Check ingress
    if kubectl get ingress brain-tasks-app-ingress -n brain-tasks-app >/dev/null 2>&1; then
        echo "✅ Kubernetes ingress exists"
        INGRESS_STATUS=$(kubectl get ingress brain-tasks-app-ingress -n brain-tasks-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "Not available")
        echo "   Load Balancer: $INGRESS_STATUS"
    else
        echo "❌ Kubernetes ingress not found"
    fi
else
    echo "❌ Kubernetes namespace not found"
fi

# Check Docker image
echo ""
echo "8. Checking Docker image..."
if docker images | grep -q brain-tasks-app; then
    echo "✅ Docker image exists locally"
else
    echo "❌ Docker image not found locally"
fi

echo ""
echo "=========================================="
echo "Verification completed!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. If any checks failed, run the setup script again"
echo "2. Test the application locally: ./local-dev.sh"
echo "3. Push code to GitHub to trigger the CI/CD pipeline"
echo "4. Monitor deployment in AWS Console"
echo "=========================================="
