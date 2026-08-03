# Simple wrapper around the official WordPress Apache image (setup only WP version).
# https://hub.docker.com/_/wordpress/
#
# Plugins to setup the correct architecture (Redis Object Cache, WP Offload Media) are 
# manually installed from wp-admin at the first admin access.
#
# Build:  docker build -t wordpress-apache:app .
# Deploy: push ECR tag "app" (PLACEHOLDER: ECS should be forced to take the new image).

ARG WORDPRESS_VERSION=7.0
FROM wordpress:${WORDPRESS_VERSION}-php8.3-apache