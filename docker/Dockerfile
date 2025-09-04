# Use nginx as base image for serving static files
FROM nginx:alpine

# Copy the built React application
COPY Brain-Tasks-App/dist /usr/share/nginx/html

# Copy custom nginx configuration
COPY docker/nginx.conf /etc/nginx/nginx.conf

# Expose port 3000
EXPOSE 3000

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
