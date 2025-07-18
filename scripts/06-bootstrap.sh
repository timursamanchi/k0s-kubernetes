#!/bin/bash
set -e

echo -e "\n🚀 Starting full bootstrap sequence...\n"

chmod +x *.sh

./01-install-docker.sh
./02-install-k0s.sh
./03-setup-kubectl.sh
./04-install-flannel.sh
./05-install-nginx-ingress.sh
./06-bootstrap.sh

echo -e "\n🎉 All components installed successfully.\n"
echo "Optional: log out and back in to apply Docker group changes for user '$USER'"

