#!/bin/bash

# Local Development Script for Brain Tasks App
set -e

echo "=========================================="
echo "Brain Tasks App - Local Development"
echo "=========================================="

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "Error: Docker is not running. Please start Docker and try again."
    exit 1
fi

# Build Docker image
echo "Building Docker image..."
docker build -t brain-tasks-app -f docker/Dockerfile .

# Run container
echo "Starting container on port 3000..."
docker run -d --name brain-tasks-app-dev -p 3000:3000 brain-tasks-app

# Wait for container to start
echo "Waiting for container to start..."
sleep 5

# Check container status
if docker ps | grep -q brain-tasks-app-dev; then
    echo "✅ Container is running successfully!"
    echo "🌐 Application is available at: http://localhost:3000"
    echo ""
    echo "Container logs:"
    docker logs brain-tasks-app-dev
    echo ""
    echo "To stop the container: docker stop brain-tasks-app-dev"
    echo "To remove the container: docker rm brain-tasks-app-dev"
else
    echo "❌ Container failed to start. Check logs:"
    docker logs brain-tasks-app-dev
    exit 1
fi
