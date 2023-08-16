# Pull a multi-architecture base image (Ubuntu)
FROM --platform=$BUILDPLATFORM ubuntu AS base

# Install Nginx
RUN apt-get -y  && apt-get -y install nginx

# Copy the Nginx config
COPY config/default /etc/nginx/sites-available/default
COPY html/*.html /var/www/html/

# Expose the port for access
EXPOSE 80/tcp

# Run the Nginx server
CMD ["/usr/sbin/nginx", "-g", "daemon off;"]

# Build stage for arm64
FROM base AS arm64
RUN [ "cross-build-start", "arm64" ]
RUN [ "cross-build-end" ]

# Build stage for x86
FROM base AS x86
RUN [ "cross-build-start", "amd64" ]
RUN [ "cross-build-end" ]
