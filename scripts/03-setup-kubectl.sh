#!/bin/bash
set -e

echo "🔗 Creating kubectl symlink to k0s..."
sudo ln -sf /usr/local/bin/k0s /usr/local/bin/kubectl

echo "🛠 Setting up kubeconfig for current user..."
mkdir -p "$HOME/.kube"
sudo k0s kubectl config view --raw > "$HOME/.kube/config"
chmod 600 "$HOME/.kube/config"
export KUBECONFIG="$HOME/.kube/config"

echo "⚠️ Disabling swap (required for Kubernetes)..."
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

echo "🔍 Docker version: $(docker --version)"
echo "🔍 Docker Compose version: $(docker compose version --short)"
echo "🔍 k0s version: $(k0s version)"
echo "🔍 kubectl version:"
kubectl version || echo "❌ kubectl version command failed"

echo "✅ Verifying k0s cluster nodes..."
sleep 3
kubectl get nodes -o wide || echo "❌ Failed to get cluster nodes"
