#!/bin/bash

# Setup CodePipeline for Brain Tasks App
set -e

PIPELINE_NAME=${1:-brain-tasks-app-pipeline}
REGION=${2:-us-east-1}
CODEBUILD_PROJECT_NAME=${3:-brain-tasks-app-build}

echo "Setting up CodePipeline: $PIPELINE_NAME in region: $REGION"

# Create CodePipeline service role (skip if exists)
aws iam create-role \
    --role-name CodePipelineServiceRole \
    --assume-role-policy-document '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {
                    "Service": "codepipeline.amazonaws.com"
                },
                "Action": "sts:AssumeRole"
            }
        ]
    }' 2>/dev/null || echo "Role already exists"

# Attach required policies
aws iam attach-role-policy \
    --role-name CodePipelineServiceRole \
    --policy-arn arn:aws:iam::aws:policy/AWSCodePipeline_FullAccess 2>/dev/null || echo "Policy already attached"

# Get account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create S3 bucket for artifacts (skip if exists)
aws s3 mb s3://codepipeline-${ACCOUNT_ID}-${REGION} --region $REGION 2>/dev/null || echo "Bucket already exists"

# Create pipeline configuration
cat > pipeline-config.json << EOF
{
    "pipeline": {
        "name": "$PIPELINE_NAME",
        "roleArn": "arn:aws:iam::${ACCOUNT_ID}:role/CodePipelineServiceRole",
        "artifactStore": {
            "type": "S3",
            "location": "codepipeline-${ACCOUNT_ID}-${REGION}"
        },
        "stages": [
            {
                "name": "Source",
                "actions": [
                    {
                        "name": "SourceAction",
                        "actionTypeId": {
                            "category": "Source",
                            "owner": "AWS",
                            "provider": "S3",
                            "version": "1"
                        },
                        "configuration": {
                            "S3Bucket": "codepipeline-${ACCOUNT_ID}-${REGION}",
                            "S3ObjectKey": "source.zip"
                        },
                        "outputArtifacts": [
                            {
                                "name": "SourceOutput"
                            }
                        ]
                    }
                ]
            },
            {
                "name": "Build",
                "actions": [
                    {
                        "name": "BuildAction",
                        "actionTypeId": {
                            "category": "Build",
                            "owner": "AWS",
                            "provider": "CodeBuild",
                            "version": "1"
                        },
                        "configuration": {
                            "ProjectName": "$CODEBUILD_PROJECT_NAME"
                        },
                        "inputArtifacts": [
                            {
                                "name": "SourceOutput"
                            }
                        ],
                        "outputArtifacts": [
                            {
                                "name": "BuildOutput"
                            }
                        ]
                    }
                ]
            }
        ]
    }
}
EOF

# Create CodePipeline (skip if exists)
aws codepipeline create-pipeline \
    --region $REGION \
    --cli-input-json file://pipeline-config.json 2>/dev/null || echo "Pipeline already exists"

echo "CodePipeline created successfully!"
echo "Pipeline name: $PIPELINE_NAME"
echo "Region: $REGION"
echo "Build: CodeBuild ($CODEBUILD_PROJECT_NAME)"
echo "Artifact Store: codepipeline-${ACCOUNT_ID}-${REGION}"

# Clean up temporary files
rm pipeline-config.json

echo "Setup completed successfully!"