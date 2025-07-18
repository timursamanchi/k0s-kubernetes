#!/bin/bash
# 4-install-flannel.sh
set -e

echo "🔧 Installing Flannel CNI plugin..."
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
echo "✅ Flannel network interface plugin applied."
