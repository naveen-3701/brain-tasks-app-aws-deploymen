#!/bin/bash

# Setup ECR Repository for Brain Tasks App
set -e

REGION=${1:-us-east-1}
REPOSITORY_NAME="brain-tasks-app"

echo "Setting up ECR repository in region: $REGION"

# Create ECR repository (skip if exists)
aws ecr create-repository \
    --repository-name $REPOSITORY_NAME \
    --region $REGION \
    --image-scanning-configuration scanOnPush=true \
    --encryption-configuration encryptionType=AES256 2>/dev/null || echo "Repository already exists"

# Get repository URI
REPOSITORY_URI=$(aws ecr describe-repositories \
    --repository-names $REPOSITORY_NAME \
    --region $REGION \
    --query 'repositories[0].repositoryUri' \
    --output text)

echo "ECR Repository created successfully!"
echo "Repository URI: $REPOSITORY_URI"

# Create repository policy for CodeBuild access
cat > ecr-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "CodeBuildAccess",
            "Effect": "Allow",
            "Principal": {
                "Service": "codebuild.amazonaws.com"
            },
            "Action": [
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage",
                "ecr:BatchCheckLayerAvailability",
                "ecr:PutImage",
                "ecr:InitiateLayerUpload",
                "ecr:UploadLayerPart",
                "ecr:CompleteLayerUpload"
            ]
        }
    ]
}
EOF

aws ecr set-repository-policy \
    --repository-name $REPOSITORY_NAME \
    --region $REGION \
    --policy-text file://ecr-policy.json 2>/dev/null || echo "Policy already set"

echo "ECR repository policy updated!"
echo "Setup completed successfully!"

# Clean up temporary files
rm ecr-policy.json