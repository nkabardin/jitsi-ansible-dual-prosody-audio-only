#!/bin/bash
# Deploy Jitsi Meet server

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

# Check if inventory exists
if [ ! -f "inventory.yml" ]; then
    echo "ERROR: inventory.yml not found!"
    echo ""
    echo "Please create your inventory file:"
    echo "  cp inventory.yml.example inventory.yml"
    echo ""
    echo "Then edit inventory.yml with your configuration."
    exit 1
fi

# Check for CHANGE_ME values
if grep -q "CHANGE_ME" inventory.yml; then
    echo "WARNING: Found CHANGE_ME values in inventory.yml"
    echo ""
    echo "Please generate secrets first:"
    echo "  ./scripts/generate-secrets.sh"
    echo ""
    echo "Then update inventory.yml with the generated values."
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "=========================================="
echo "Deploying Jitsi Meet Server"
echo "=========================================="

# Run syntax check
echo "Running syntax check..."
ansible-playbook --syntax-check playbook-jitsi.yml

echo ""
echo "Deploying..."
ansible-playbook playbook-jitsi.yml "$@"

echo ""
echo "=========================================="
echo "Deployment complete!"
echo "=========================================="
