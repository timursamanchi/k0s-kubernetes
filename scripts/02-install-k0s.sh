#!/bin/bash
# 2-install-k0s.sh
set -e

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
