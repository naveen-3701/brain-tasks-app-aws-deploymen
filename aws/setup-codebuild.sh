#!/bin/bash

# Setup CodeBuild Project for Brain Tasks App
set -e

PROJECT_NAME=${1:-brain-tasks-app-build}
REGION=${2:-us-east-1}
ECR_REPOSITORY_URI=${3}

if [ -z "$ECR_REPOSITORY_URI" ]; then
    echo "Error: ECR_REPOSITORY_URI is required"
    echo "Usage: $0 <project-name> <region> <ecr-repository-uri>"
    exit 1
fi

echo "Setting up CodeBuild project: $PROJECT_NAME in region: $REGION"

# Create CodeBuild service role
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
    }'

# Attach required policies
aws iam attach-role-policy \
    --role-name CodeBuildServiceRole \
    --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

# Create buildspec template
cat > buildspec-template.yml << EOF
version: 0.2

phases:
  pre_build:
    commands:
      - echo Logging in to Amazon ECR...
      - aws --version
      - aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_REPOSITORY_URI
      - REPOSITORY_URI=$ECR_REPOSITORY_URI
      - IMAGE_TAG=\$(echo \$CODEBUILD_RESOLVED_SOURCE_VERSION | cut -c 1-7)
      - echo Repository URI is \$REPOSITORY_URI
      - echo Image tag is \$IMAGE_TAG
  
  build:
    commands:
      - echo Build started on \`date\`
      - echo Building the Docker image...
      - docker build -t \$REPOSITORY_URI:\$IMAGE_TAG -f docker/Dockerfile .
      - docker tag \$REPOSITORY_URI:\$IMAGE_TAG \$REPOSITORY_URI:latest
      - echo Build completed on \`date\`
  
  post_build:
    commands:
      - echo Pushing the Docker images...
      - docker push \$REPOSITORY_URI:\$IMAGE_TAG
      - docker push \$REPOSITORY_URI:latest
      - echo Writing image definitions file...
      - printf '[{"name":"brain-tasks-app","imageUri":"%s"}]' \$REPOSITORY_URI:\$IMAGE_TAG > imagedefinitions.json

artifacts:
  files:
    - imagedefinitions.json
    - docker/Dockerfile
    - k8s/**/*
  discard-paths: no
EOF

# Create CodeBuild project
aws codebuild create-project \
    --name $PROJECT_NAME \
    --region $REGION \
    --source type=GITHUB,location=https://github.com/Vennilavan12/Brain-Tasks-App.git \
    --artifacts type=NO_ARTIFACTS \
    --environment type=LINUX_CONTAINER,image=aws/codebuild/amazonlinux2-x86_64-standard:4.0,computeType=BUILD_GENERAL1_SMALL,privilegedMode=true \
    --service-role CodeBuildServiceRole \
    --environment-variables name=ECR_REPOSITORY_URI,value=$ECR_REPOSITORY_URI,type=PLAINTEXT

echo "CodeBuild project created successfully!"
echo "Project name: $PROJECT_NAME"
echo "Region: $REGION"
echo "ECR Repository: $ECR_REPOSITORY_URI"

# Create webhook for GitHub integration
aws codebuild create-webhook \
    --project-name $PROJECT_NAME \
    --region $REGION \
    --filter-groups '[
        [
            {
                "type": "EVENT",
                "pattern": "PUSH"
            },
            {
                "type": "HEAD_REF",
                "pattern": "refs/heads/main"
            }
        ]
    ]'

echo "GitHub webhook created for automatic builds!"
echo "Setup completed successfully!"
