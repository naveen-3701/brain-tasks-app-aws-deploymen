#!/bin/bash

# Setup CodeDeploy Application for Brain Tasks App
set -e

APPLICATION_NAME=${1:-brain-tasks-app}
DEPLOYMENT_GROUP_NAME=${2:-brain-tasks-app-deployment-group}
REGION=${3:-us-east-1}

echo "Setting up CodeDeploy application: $APPLICATION_NAME in region: $REGION"

# Create CodeDeploy application (skip if exists)
aws deploy create-application \
    --application-name $APPLICATION_NAME \
    --region $REGION 2>/dev/null || echo "Application already exists"

echo "CodeDeploy application created successfully!"

# Create CodeDeploy service role (skip if exists)
aws iam create-role \
    --role-name CodeDeployServiceRole \
    --assume-role-policy-document '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {
                    "Service": "codedeploy.amazonaws.com"
                },
                "Action": "sts:AssumeRole"
            }
        ]
    }' 2>/dev/null || echo "Role already exists"

# Attach required policies
aws iam attach-role-policy \
    --role-name CodeDeployServiceRole \
    --policy-arn arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS 2>/dev/null || echo "Policy already attached"

# Get account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create deployment group (skip if exists)
aws deploy create-deployment-group \
    --application-name $APPLICATION_NAME \
    --deployment-group-name $DEPLOYMENT_GROUP_NAME \
    --region $REGION \
    --deployment-config-name CodeDeployDefault.OneAtATime \
    --service-role-arn arn:aws:iam::${ACCOUNT_ID}:role/CodeDeployServiceRole 2>/dev/null || echo "Deployment group already exists"

echo "CodeDeploy deployment group created successfully!"
echo "Application name: $APPLICATION_NAME"
echo "Deployment group: $DEPLOYMENT_GROUP_NAME"
echo "Region: $REGION"
echo "Setup completed successfully!"