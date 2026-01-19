#!/bin/bash
# Generate random secrets for Jitsi deployment

set -e

echo "=========================================="
echo "Jitsi Audio Meet - Secret Generator"
echo "=========================================="
echo ""
echo "Add these values to your inventory.yml or group_vars/all/vars.yml:"
echo ""
echo "# Generated secrets ($(date +%Y-%m-%d))"
echo "jvb_secret: \"$(openssl rand -base64 24 | tr -d '/+=' | head -c 24)\""
echo "jvb_password: \"$(openssl rand -base64 24 | tr -d '/+=' | head -c 24)\""
echo "jicofo_password: \"$(openssl rand -base64 24 | tr -d '/+=' | head -c 24)\""
echo "turn_secret: \"$(openssl rand -base64 24 | tr -d '/+=' | head -c 24)\""
echo ""
echo "# Jibri secrets (if using recording)"
echo "jibri_password: \"$(openssl rand -base64 24 | tr -d '/+=' | head -c 24)\""
echo "recorder_password: \"$(openssl rand -base64 24 | tr -d '/+=' | head -c 24)\""
echo ""
echo "=========================================="
echo "IMPORTANT: Keep these secrets safe!"
echo "=========================================="
