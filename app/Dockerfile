# Use nginx as base image
FROM nginx:alpine

# Set maintainer
LABEL maintainer="psyunix"
LABEL description="Sample web application for Kubernetes deployment"

# Remove default nginx static content
RUN rm -rf /usr/share/nginx/html/*

# Copy custom nginx configuration
RUN echo 'server { \
    listen 80; \
    server_name localhost; \
    location / { \
        root /usr/share/nginx/html; \
        index index.html; \
        try_files $uri $uri/ /index.html; \
    } \
    location /health { \
        access_log off; \
        return 200 "healthy\n"; \
        add_header Content-Type text/plain; \
    } \
}' > /etc/nginx/conf.d/default.conf

# Copy application files
COPY src/ /usr/share/nginx/html/

# Expose port 80
EXPOSE 80

# Add health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost/health || exit 1

# Run nginx in foreground
CMD ["nginx", "-g", "daemon off;"]
