#!/bin/bash

# Setup CodePipeline for Brain Tasks App
set -e

PIPELINE_NAME=${1:-brain-tasks-app-pipeline}
REGION=${2:-us-east-1}
CODEBUILD_PROJECT_NAME=${3:-brain-tasks-app-build}
CODEDEPLOY_APPLICATION_NAME=${4:-brain-tasks-app}
CODEDEPLOY_DEPLOYMENT_GROUP_NAME=${5:-brain-tasks-app-deployment-group}

echo "Setting up CodePipeline: $PIPELINE_NAME in region: $REGION"

# Create CodePipeline service role
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
    }'

# Attach required policies
aws iam attach-role-policy \
    --role-name CodePipelineServiceRole \
    --policy-arn arn:aws:iam::aws:policy/AWSCodePipelineFullAccess

# Create pipeline configuration
cat > pipeline-config.json << EOF
{
    "pipeline": {
        "name": "$PIPELINE_NAME",
        "roleArn": "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/CodePipelineServiceRole",
        "artifactStore": {
            "type": "S3",
            "location": "codepipeline-$(aws sts get-caller-identity --query Account --output text)-$REGION"
        },
        "stages": [
            {
                "name": "Source",
                "actions": [
                    {
                        "name": "Source",
                        "actionTypeId": {
                            "category": "Source",
                            "owner": "AWS",
                            "provider": "CodeStarSourceConnection",
                            "version": "1"
                        },
                        "configuration": {
                            "ConnectionArn": "arn:aws:codestar-connections:us-east-1:$(aws sts get-caller-identity --query Account --output text):connection/$(aws codestar-connections list-connections --query 'Connections[0].ConnectionArn' --output text | cut -d'/' -f2)",
                            "FullRepositoryId": "Vennilavan12/Brain-Tasks-App",
                            "BranchName": "main"
                        },
                        "outputArtifacts": [
                            {
                                "name": "SourceCode"
                            }
                        ]
                    }
                ]
            },
            {
                "name": "Build",
                "actions": [
                    {
                        "name": "Build",
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
                                "name": "SourceCode"
                            }
                        ],
                        "outputArtifacts": [
                            {
                                "name": "BuildOutput"
                            }
                        ]
                    }
                ]
            },
            {
                "name": "Deploy",
                "actions": [
                    {
                        "name": "Deploy",
                        "actionTypeId": {
                            "category": "Deploy",
                            "owner": "AWS",
                            "provider": "CodeDeploy",
                            "version": "1"
                        },
                        "configuration": {
                            "ApplicationName": "$CODEDEPLOY_APPLICATION_NAME",
                            "DeploymentGroupName": "$CODEDEPLOY_DEPLOYMENT_GROUP_NAME"
                        },
                        "inputArtifacts": [
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

# Create CodePipeline
aws codepipeline create-pipeline \
    --region $REGION \
    --cli-input-json file://pipeline-config.json

echo "CodePipeline created successfully!"
echo "Pipeline name: $PIPELINE_NAME"
echo "Region: $REGION"
echo "Source: GitHub (Vennilavan12/Brain-Tasks-App)"
echo "Build: CodeBuild ($CODEBUILD_PROJECT_NAME)"
echo "Deploy: CodeDeploy ($CODEDEPLOY_APPLICATION_NAME)"

# Clean up temporary files
rm pipeline-config.json

echo "Setup completed successfully!"
