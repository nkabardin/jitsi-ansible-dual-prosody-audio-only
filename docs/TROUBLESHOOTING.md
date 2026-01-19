# Troubleshooting Guide

## Common Issues and Solutions

### 1. Conference Doesn't Start

**Symptoms:**
- Users see "Oops, something went wrong"
- Conference loads but no audio

**Checks:**
```bash
# Check all services
systemctl status prosody prosody-jvb jicofo jitsi-videobridge2 nginx

# Check Jicofo logs
journalctl -u jicofo -n 100 | grep -i error

# Check JVB logs
journalctl -u jitsi-videobridge2 -n 100 | grep -i error
```

**Common Causes:**
1. Jicofo can't find any bridges
2. JVB not registered in Prosody-JVB
3. MUC JID mismatch

**Solutions:**
```bash
# Register JVB user in Prosody-JVB
prosodyctl --config /etc/prosody-jvb/prosody.cfg.lua register jvb tech.YOUR_DOMAIN YOUR_JVB_PASSWORD

# Register focus in Prosody-JVB
prosodyctl --config /etc/prosody-jvb/prosody.cfg.lua register focus tech.YOUR_DOMAIN YOUR_JICOFO_PASSWORD

# Restart services
systemctl restart prosody-jvb jicofo jitsi-videobridge2
```

### 2. JVB Connects But Shows "No Operational Bridges"

**Check Jicofo logs:**
```bash
journalctl -u jicofo | grep -i "bridge\|xmpp"
```

**Verify configuration alignment:**

In `/etc/jitsi/jicofo/jicofo.conf`:
```hocon
bridge {
  brewery-jid = "jvbbrewery@muc.tech.YOUR_DOMAIN"
  xmpp-connection-name = Service  # This must be "Service"!
}
```

In `/etc/jitsi/videobridge/jvb.conf`:
```hocon
MUC_JIDS = "jvbbrewery@muc.tech.YOUR_DOMAIN"  # Must match!
```

### 3. Prosody Configuration Errors

**Check configuration:**
```bash
prosodyctl check config
prosodyctl --config /etc/prosody-jvb/prosody.cfg.lua check config
```

**Common issues:**
- Missing Lua modules
- SSL certificate path errors
- Syntax errors in config

**Solutions:**
```bash
# Install missing modules
apt install prosody-modules

# Check certificate paths exist
ls -la /etc/prosody/certs/
ls -la /etc/letsencrypt/live/YOUR_DOMAIN/
```

### 4. SSL Certificate Issues

**Symptoms:**
- Browser shows certificate warning
- WebSocket connection fails

**Checks:**
```bash
# Check certificate validity
openssl x509 -in /etc/letsencrypt/live/YOUR_DOMAIN/fullchain.pem -text -noout | grep -A2 "Validity"

# Check nginx config
nginx -t
```

**Renew certificate:**
```bash
certbot renew
systemctl reload nginx
```

### 5. Cannot Connect to Meeting

**Client-side checks:**
- Open browser developer console (F12)
- Check for CORS errors
- Check WebSocket connection status

**Server-side checks:**
```bash
# Check nginx is proxying correctly
curl -v http://localhost:5280/http-bind

# Check websocket proxy
curl -v http://localhost:5280/xmpp-websocket
```

### 6. Audio Not Working

**Symptoms:**
- Conference connects but no audio
- Some users hear others, some don't

**Checks:**
```bash
# Check JVB is receiving media
journalctl -u jitsi-videobridge2 | grep -i "receive\|send"

# Check UDP port is open
ss -ulnp | grep 10000
```

**Firewall:**
```bash
# Ensure UDP 10000 is open
ufw allow 10000/udp
ufw reload
```

### 7. Prosody-JVB Not Starting

**Check logs:**
```bash
journalctl -u prosody-jvb -n 50
```

**Common issues:**
- Port 15222 already in use
- Missing runtime directory

**Solutions:**
```bash
# Check if port is in use
ss -tlnp | grep 15222

# Create runtime directory
mkdir -p /run/prosody-jvb
chown prosody:prosody /run/prosody-jvb

# Restart
systemctl restart prosody-jvb
```

### 8. High CPU/Memory Usage

**Diagnosis:**
```bash
# Check which service is using resources
htop

# Check Prosody stats
prosodyctl about
```

**Solutions:**
- Enable SMACKS (`smacks_max_queue_size = 1500`)
- Reduce history (`max_history_messages = 0`)
- Add JVB firewall rules to filter presence traffic

### 9. Users Can't Join Full Conference

**Check JVB capacity:**
```bash
curl http://localhost:8080/colibri/stats | jq
```

**Increase capacity:**
Edit `/etc/jitsi/jicofo/jicofo.conf`:
```hocon
bridge {
  max-bridge-participants = 300
}
```

Or add more JVB servers.

## Log Locations

| Service | Log |
|---------|-----|
| Prosody | `/var/log/prosody/prosody.log` |
| Prosody-JVB | `/var/log/prosody-jvb/prosody.log` |
| Jicofo | `journalctl -u jicofo` |
| JVB | `journalctl -u jitsi-videobridge2` |
| Nginx | `/var/log/nginx/error.log` |

## Health Checks

```bash
# Quick health check script
echo "=== Prosody ===" && systemctl is-active prosody
echo "=== Prosody-JVB ===" && systemctl is-active prosody-jvb
echo "=== Jicofo ===" && systemctl is-active jicofo
echo "=== JVB ===" && systemctl is-active jitsi-videobridge2
echo "=== Nginx ===" && systemctl is-active nginx
echo "=== JVB Stats ===" && curl -s http://localhost:8080/colibri/stats | jq '.conferences, .participants'
```

## Getting Help

1. Check this guide first
2. Review logs for error messages
3. Consult [docs/ARCHITECTURE.md](ARCHITECTURE.md) for understanding the system
4. Open an issue with:
   - Error messages from logs
   - Your configuration (remove secrets!)
   - Steps to reproduce
