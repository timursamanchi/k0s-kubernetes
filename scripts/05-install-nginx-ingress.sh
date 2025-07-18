#!/bin/bash
set -e

echo "🔧 Installing NGINX Ingress controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.1/deploy/static/provider/cloud/deploy.yaml
echo "✅ NGINX Ingress controller plugin applied."
