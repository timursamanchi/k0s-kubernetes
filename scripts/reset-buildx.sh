#!/bin/bash
set -e

echo "🔄 Cleaning up all existing Buildx builders..."

# Try to remove the builder named 'mybuilder' directly if it exists
if docker buildx inspect mybuilder &>/dev/null; then
  echo "🗑 Removing builder: mybuilder"
  docker buildx rm mybuilder || echo "⚠️ Could not remove 'mybuilder'"
else
  echo "✅ 'mybuilder' not found, skipping removal."
fi

echo ""
echo "🛠 Creating new builder: mybuilder"
docker buildx create --use --name mybuilder --driver docker-container

echo ""
echo "🚀 Bootstrapping builder..."
docker buildx inspect --bootstrap

echo ""
echo "✅ Done. Here's your current builder:"
docker buildx ls

echo ""
echo "🔧 You can now use 'docker buildx' to build multi-arch images."
