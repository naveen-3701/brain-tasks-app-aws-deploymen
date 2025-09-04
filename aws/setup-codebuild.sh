#!/bin/bash

# Setup CodeBuild Project for Brain Tasks App
set -e

PROJECT_NAME=${1:-brain-tasks-app-build}
REGION=${2:-us-east-1}
ECR_REPOSITORY_URI=${3}
GITHUB_REPO=${4:-https://github.com/naveen-3701/brain-tasks-app-aws-deploymen.git}

if [ -z "$ECR_REPOSITORY_URI" ]; then
    echo "Error: ECR_REPOSITORY_URI is required"
    echo "Usage: $0 <project-name> <region> <ecr-repository-uri> [github-repo]"
    exit 1
fi

echo "Setting up CodeBuild project: $PROJECT_NAME in region: $REGION"

# Create CodeBuild service role (skip if exists)
aws iam create-role \
    --role-name CodeBuildServiceRole \
    --assume-role-policy-document '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {
                    "Service": "codebuild.amazonaws.com"
                },
                "Action": "sts:AssumeRole"
            }
        ]
    }' 2>/dev/null || echo "Role already exists"

# Attach required policies
aws iam attach-role-policy \
    --role-name CodeBuildServiceRole \
    --policy-arn arn:aws:iam::aws:policy/AdministratorAccess 2>/dev/null || echo "Policy already attached"

# Create CodeBuild project
aws codebuild create-project \
    --name $PROJECT_NAME \
    --region $REGION \
    --source type=GITHUB,location=$GITHUB_REPO \
    --artifacts type=NO_ARTIFACTS \
    --environment type=LINUX_CONTAINER,image=aws/codebuild/amazonlinux2-x86_64-standard:4.0,computeType=BUILD_GENERAL1_SMALL,privilegedMode=true \
    --service-role CodeBuildServiceRole

echo "CodeBuild project created successfully!"
echo "Project name: $PROJECT_NAME"
echo "Region: $REGION"
echo "ECR Repository: $ECR_REPOSITORY_URI"
echo "GitHub Repository: $GITHUB_REPO"

# Update project with environment variables
aws codebuild update-project \
    --name $PROJECT_NAME \
    --region $REGION \
    --environment type=LINUX_CONTAINER,image=aws/codebuild/amazonlinux2-x86_64-standard:4.0,computeType=BUILD_GENERAL1_SMALL,privilegedMode=true,environmentVariables='[{"name":"ECR_REPOSITORY_URI","value":"'$ECR_REPOSITORY_URI'","type":"PLAINTEXT"}]'

echo "Environment variables updated!"
echo "Setup completed successfully!"