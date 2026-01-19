# Jibri Recording Setup

Jibri (Jitsi Broadcasting Infrastructure) enables recording and streaming of Jitsi conferences. This guide covers setting up Jibri with S3 upload for recordings.

## Prerequisites

- Jitsi Meet server deployed with this repository
- Additional server(s) for Jibri (recommended: 4+ CPU cores, 8GB+ RAM)
- S3-compatible storage for recordings (optional but recommended)

## Quick Setup

### 1. Enable Jibri on Main Server

Edit `inventory.yml`:

```yaml
all:
  vars:
    jibri_enabled: true
    jibri_password: "YOUR_GENERATED_PASSWORD"
    recorder_password: "YOUR_GENERATED_PASSWORD"
```

Re-run the main playbook:
```bash
./scripts/deploy.sh
```

This will:
- Add recorder domain to Prosody
- Configure Jicofo for Jibri
- Enable recording UI in config.js

### 2. Configure Jibri Server

Add to `inventory.yml`:

```yaml
all:
  vars:
    # ... existing vars ...

    # S3 Storage (optional)
    storage_access_key: "YOUR_S3_ACCESS_KEY"
    storage_secret_key: "YOUR_S3_SECRET_KEY"
    storage_bucket: "jitsi-recordings"
    storage_endpoint: "s3.example.com"

  children:
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

### 3. Deploy Jibri

```bash
ansible-playbook jibri/playbook-jibri.yml
```

### 4. Register Jibri Users in Prosody

On the main Jitsi server:

```bash
# Register jibri control user
prosodyctl register jibri auth.YOUR_DOMAIN YOUR_JIBRI_PASSWORD

# Register recorder user
prosodyctl register recorder recorder.YOUR_DOMAIN YOUR_RECORDER_PASSWORD
```

### 5. Restart Services

On Jitsi server:
```bash
systemctl restart prosody jicofo
```

On Jibri server:
```bash
systemctl restart jibri
```

## Configuration Details

### Jibri Config

Location: `/etc/jitsi/jibri/jibri.conf`

Key settings:
```hocon
jibri {
  api {
    xmpp {
      environments = [{
        xmpp-server-hosts = [ "jitsi.example.com" ]
        xmpp-domain = "jitsi.example.com"

        control-muc {
          domain = "internal.auth.jitsi.example.com"
          room-name = "JibriBrewery"
          nickname = "jibri-1"  # Unique per Jibri instance
        }

        control-login {
          domain = "auth.jitsi.example.com"
          username = "jibri"
          password = "YOUR_PASSWORD"
        }

        call-login {
          domain = "recorder.jitsi.example.com"
          username = "recorder"
          password = "YOUR_PASSWORD"
        }
      }]
    }
  }

  recording {
    recordings-directory = "/srv/recordings"
    finalize-script = "/usr/local/sbin/jibri-finalize-upload.sh"
  }
}
```

### S3 Upload

The finalize script uploads recordings to S3 after completion:

Location: `/usr/local/sbin/jibri-finalize-upload.sh`

Rclone config: `/etc/jibri/rclone.conf`

Recordings are uploaded to:
```
s3://BUCKET/incoming/YYYY/MM/DD/RECORDING_ID/
```

A `.done` marker file is created when upload completes.

## Multiple Jibri Instances

For concurrent recordings, add more Jibri servers:

```yaml
jibri_servers:
  hosts:
    jibri-1:
      ansible_host: IP_1
      jibri_nick: "jibri-1"
      # ... other vars ...

    jibri-2:
      ansible_host: IP_2
      jibri_nick: "jibri-2"
      # ... other vars ...

    jibri-3:
      ansible_host: IP_3
      jibri_nick: "jibri-3"
      # ... other vars ...
```

Each Jibri needs a unique `jibri_nick`.

## Audio-Only Recording

Since this setup is audio-only, Jibri will record:
- Audio from all participants
- The Jitsi Meet UI (mostly static for audio-only)

The Chrome window size is set small (320x240) to minimize resource usage:

```hocon
chrome {
  flags = [
    "--window-size=320x240",
    # ... other flags ...
  ]
}
```

## Troubleshooting

### Jibri Not Appearing in Jicofo

Check Jibri logs:
```bash
journalctl -u jibri -f
```

Look for:
- XMPP connection errors
- Authentication failures
- MUC join errors

Verify users are registered:
```bash
# On Jitsi server
prosodyctl list auth.YOUR_DOMAIN
prosodyctl list recorder.YOUR_DOMAIN
```

### Recording Starts But Fails

Check:
1. Chrome/ChromeDriver versions match
2. ALSA loopback module loaded: `lsmod | grep snd_aloop`
3. Xvfb running: `ps aux | grep Xvfb`

### Recordings Not Uploading

Check rclone config:
```bash
sudo -u jibri rclone lsd hetzner-s3: --config /etc/jibri/rclone.conf
```

Test upload:
```bash
sudo -u jibri rclone copy /srv/recordings/test hetzner-s3:BUCKET/test --config /etc/jibri/rclone.conf
```

### Chrome Crashes

Increase resources or add swap:
```bash
# Check available memory
free -h

# Add swap if needed
fallocate -l 8G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
```

## Monitoring

Check Jibri status:
```bash
# Service status
systemctl status jibri

# Recent recordings
ls -la /srv/recordings/

# Check if Jibri is idle or busy
curl localhost:2222/jibri/api/v1.0/health
```

## Resource Requirements

Per Jibri instance:
- CPU: 4+ cores (Chrome + FFmpeg are CPU-intensive)
- RAM: 8GB+ (Chrome is memory-hungry)
- Disk: Depends on recording length (100MB+ per hour typical)
- Network: Good connectivity to Jitsi server and S3

For 1 concurrent recording: 1 Jibri server
For N concurrent recordings: N Jibri servers
