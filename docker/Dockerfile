# frontend/Dockerfile
FROM nginx:alpine
# Copy the index.html file

COPY index.html /usr/share/nginx/html/index.html
COPY default.conf /etc/nginx/conf.d/default.conf

# 🧠 Important: Run NGINX in the foreground so the container stays alive
CMD ["nginx", "-g", "daemon off;"]

# to build: docker buildx build --platform=linux/amd64,linux/arm64 --push -t timursamanchi/docker-image-name:version .