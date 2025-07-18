#!/bin/bash
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

echo "⬇️ Downloading and installing k0s..."
curl -sSLf https://get.k0s.sh | sudo sh

echo "🚀 Installing k0s in single-node mode..."
sudo k0s install controller --single
sudo k0s start

echo "⏳ Waiting for k0s to become ready..."
for i in {1..30}; do
  if [ -f /var/lib/k0s/pki/admin.conf ]; then
    echo "✅ k0s is ready."
    break
  fi
  echo "⏳ Waiting for admin.conf to be generated... (${i}s)"
  sleep 1
done

if [ ! -f /var/lib/k0s/pki/admin.conf ]; then
  echo "❌ k0s admin.conf not found after waiting. Exiting."
  exit 1
fi

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

echo -e "\n***********************************************************************************"
echo -e "🎉 Docker and k0s installation complete. Optional: log out and back in to apply group changes.\n"

echo "🔍 Docker version: $(docker --version)"
echo "🔍 Docker Compose version: $(docker compose version --short)"
echo ""
echo "🔍 k0s version: $(k0s version)"
echo""
echo "🔍 kubectl version:"
kubectl version || echo "❌ kubectl version command failed"

echo ""
echo "✅ Verifying k0s cluster nodes..."
sleep 3
kubectl get nodes -o wide || echo "❌ Failed to get cluster nodes"

echo "🔧 installing K0s CNI plugin..."
echo ""

sudo kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
echo "✅ Flannel network interface plugin applied."

echo ""
echo "🔧 installing nginx-Ingress plugin..."
echo ""
sudo k0s kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.1/deploy/static/provider/cloud/deploy.yaml
echo "✅ Nginx Ingress controller plugin applied."