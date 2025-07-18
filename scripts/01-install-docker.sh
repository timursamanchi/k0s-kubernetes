#!/bin/bash
# 01-install-docker.sh
set -e

echo "🔧 Updating APT packages..."
sudo apt-get update

echo "📦 Installing prerequisites..."
sudo apt-get install -y ca-certificates curl gnupg

echo "🔐 Setting up Docker GPG key..."
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo "📄 Adding Docker APT repository..."
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "🔄 Updating package index with Docker repo..."
sudo apt-get update -y

echo "🐳 Installing Docker packages..."
sudo apt-get install -y docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin

echo "🔧 Enabling and starting Docker..."
sudo systemctl enable docker
sudo systemctl start docker

echo "👤 Adding user '$USER' to docker group..."
sudo usermod -aG docker $USER
