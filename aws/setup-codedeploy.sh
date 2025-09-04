#!/bin/bash

# Setup CodeDeploy Application for Brain Tasks App
set -e

APPLICATION_NAME=${1:-brain-tasks-app}
DEPLOYMENT_GROUP_NAME=${2:-brain-tasks-app-deployment-group}
REGION=${3:-us-east-1}
CLUSTER_NAME=${4:-brain-tasks-cluster}

echo "Setting up CodeDeploy application: $APPLICATION_NAME in region: $REGION"

# Create CodeDeploy application
aws deploy create-application \
    --application-name $APPLICATION_NAME \
    --region $REGION

echo "CodeDeploy application created successfully!"

# Create CodeDeploy service role
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
    }'

# Attach required policies
aws iam attach-role-policy \
    --role-name CodeDeployServiceRole \
    --policy-arn arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS

# Create deployment group
aws deploy create-deployment-group \
    --application-name $APPLICATION_NAME \
    --deployment-group-name $DEPLOYMENT_GROUP_NAME \
    --region $REGION \
    --deployment-config-name CodeDeployDefault.ECSAllAtOnce \
    --service-role-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/CodeDeployServiceRole \
    --auto-scaling-groups \
    --ecs-services serviceName=$APPLICATION_NAME,clusterName=$CLUSTER_NAME \
    --deployment-style deploymentType=BLUE_GREEN,deploymentOption=WITH_TRAFFIC_CONTROL \
    --blue-green-deployment-configuration \
        terminationWaitTimeInMinutes=5,deploymentReadyOption=actionOnTimeout=CONTINUE_DEPLOYMENT

echo "CodeDeploy deployment group created successfully!"
echo "Application name: $APPLICATION_NAME"
echo "Deployment group: $DEPLOYMENT_GROUP_NAME"
echo "Region: $REGION"
echo "Setup completed successfully!"
