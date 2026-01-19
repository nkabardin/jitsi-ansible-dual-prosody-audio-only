# Jitsi Audio Meet - Dual-Prosody Architecture

A production-ready Ansible setup for deploying **audio-only** Jitsi Meet conferences with a **dual-Prosody architecture** for scaling to 300+ concurrent participants.

## Features

- **Audio-only mode**: Video disabled at all levels for maximum capacity
- **Dual-Prosody architecture**: Separate XMPP traffic for clients and JVBs
- **Scalable**: Add videobridge servers as needed
- **Recording**: Optional Jibri support with S3 upload
- **Battle-tested**: Configuration tested with 300+ concurrent users

## Quick Start

### Prerequisites

- Ubuntu 22.04 server(s) with root access
- Domain name pointing to your server
- Ansible 2.12+ on your local machine

### 1. Clone and Configure

```bash
git clone https://github.com/yourusername/jitsi-audio-meet.git
cd jitsi-audio-meet

# Copy example configuration
cp inventory.yml.example inventory.yml
```

### 2. Generate Secrets

```bash
./scripts/generate-secrets.sh
```

Copy the generated secrets to your `inventory.yml`.

### 3. Edit Configuration

Open `inventory.yml` and configure:

```yaml
all:
  vars:
    jitsi_domain: "jitsi.yourdomain.com"
    admin_email: "admin@yourdomain.com"

    # Paste generated secrets here
    jvb_secret: "your_generated_secret"
    jvb_password: "your_generated_password"
    jicofo_password: "your_generated_password"
    turn_secret: "your_generated_secret"

  children:
    jitsi_servers:
      hosts:
        jitsi-main:
          ansible_host: YOUR_SERVER_IP
          ansible_user: root
```

### 4. Deploy

```bash
./scripts/deploy.sh
```

### 5. Access

Open `https://your-jitsi-domain.com` in your browser.

## Architecture Overview

```
                    Internet
                        │
                        ▼
                  ┌──────────┐
                  │  Nginx   │
                  │  :443    │
                  └────┬─────┘
                       │
         ┌─────────────┼─────────────┐
         ▼             ▼             ▼
    ┌─────────┐  ┌─────────┐  ┌─────────┐
    │ Prosody │  │ Jicofo  │  │  JVB    │
    │  :5222  │  │         │  │         │
    │ clients │  └────┬────┘  └────┬────┘
    └─────────┘       │            │
                      ▼            ▼
               ┌─────────────────────┐
               │     Prosody-JVB     │
               │       :15222        │
               │  (JVB/Jicofo only)  │
               └─────────────────────┘
```

The key innovation is the **dual-Prosody setup**:
- **Main Prosody (port 5222)**: Handles client XMPP connections
- **Prosody-JVB (port 15222)**: Dedicated for JVB and Jicofo communication

This separation prevents internal traffic from competing with client connections, enabling much larger conferences.

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for detailed explanation.

## Scaling with Additional Videobridges

To handle more participants, add JVB servers:

1. Add to `inventory.yml`:

```yaml
videobridge_servers:
  hosts:
    jvb-eu:
      ansible_host: EU_SERVER_IP
      ansible_user: root
      jvb_relay_id: "jvb-eu"
      jvb_region: "eu"
      jitsi_server_ip: MAIN_JITSI_IP
```

2. Deploy:

```bash
./scripts/deploy-videobridge.sh
```

## Recording with Jibri

To enable recording:

1. Set in `inventory.yml`:

```yaml
jibri_enabled: true
jibri_password: "generated_password"
recorder_password: "generated_password"

# S3 storage for recordings
storage_access_key: "your_access_key"
storage_secret_key: "your_secret_key"
storage_bucket: "jitsi-recordings"
storage_endpoint: "s3.example.com"
```

2. Add Jibri server:

```yaml
jibri_servers:
  hosts:
    jibri-1:
      ansible_host: JIBRI_SERVER_IP
      ansible_user: root
      jibri_nick: "jibri-1"
      jibri_user: "jibri"
      jibri_password: "{{ jibri_password }}"
      recorder_user: "recorder"
      recorder_password: "{{ recorder_password }}"
      jitsi_hostname: "{{ jitsi_domain }}"
```

3. Deploy Jibri:

```bash
ansible-playbook jibri/playbook-jibri.yml
```

See [docs/JIBRI.md](docs/JIBRI.md) for detailed setup.

## Configuration Reference

### Required Variables

| Variable | Description |
|----------|-------------|
| `jitsi_domain` | Your Jitsi domain (e.g., `jitsi.example.com`) |
| `admin_email` | Email for Let's Encrypt certificates |
| `jvb_secret` | JVB secret (generate with script) |
| `jvb_password` | JVB password (generate with script) |
| `jicofo_password` | Jicofo password (generate with script) |
| `turn_secret` | TURN server secret (generate with script) |

### Optional Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `tech_domain` | `tech.{{ jitsi_domain }}` | Internal domain for JVB communication |
| `jvb_region` | `default` | Region identifier for JVB |
| `max_bridge_participants` | `220` | Max participants per JVB |
| `default_language` | `en` | UI language |
| `jibri_enabled` | `false` | Enable Jibri recording |

## Troubleshooting

See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for common issues.

### Quick Checks

```bash
# Check services
systemctl status prosody prosody-jvb jicofo jitsi-videobridge2 nginx

# Check Prosody configuration
prosodyctl check config

# Check JVB connection
journalctl -u jitsi-videobridge2 | grep "Connected"

# Check Jicofo
journalctl -u jicofo | tail -50
```

## Development Story

See [HISTORY.md](HISTORY.md) for the story of how this architecture was developed and the lessons learned while scaling Jitsi for 300+ users.

## License

MIT License - see [LICENSE](LICENSE) file.

## Contributing

Contributions welcome! Please submit issues and pull requests.
