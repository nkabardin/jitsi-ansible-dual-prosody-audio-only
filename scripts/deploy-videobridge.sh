#!/bin/bash
# Deploy additional Jitsi Videobridge servers

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

# Check if inventory exists
if [ ! -f "inventory.yml" ]; then
    echo "ERROR: inventory.yml not found!"
    exit 1
fi

echo "=========================================="
echo "Deploying Jitsi Videobridge Servers"
echo "=========================================="

# Run syntax check
echo "Running syntax check..."
ansible-playbook --syntax-check playbook-videobridge.yml

echo ""
echo "Deploying..."
ansible-playbook playbook-videobridge.yml "$@"

echo ""
echo "=========================================="
echo "Videobridge deployment complete!"
echo "=========================================="
