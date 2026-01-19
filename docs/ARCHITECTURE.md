# Dual-Prosody Architecture Explained

This document provides a deep dive into the dual-Prosody architecture used in this deployment.

## The Problem with Single Prosody

In a standard Jitsi deployment, a single Prosody instance handles:

1. **Client connections** (port 5222)
   - User authentication
   - Presence updates
   - Chat messages
   - Conference join/leave signals

2. **JVB communication**
   - Bridge registration
   - Colibri messages
   - Statistics reporting
   - Health checks

3. **Jicofo communication**
   - Conference allocation
   - Bridge selection
   - Participant tracking

As participant count grows, these traffic types compete for resources, causing bottlenecks.

## The Dual-Prosody Solution

We split Prosody into two instances:

### Main Prosody (Port 5222)

Handles client-facing XMPP:

```
VirtualHost "jitsi.example.com"
    authentication = "internal_hashed"
    modules_enabled = { "bosh", "websocket", "smacks", ... }

Component "conference.jitsi.example.com" "muc"
    -- Main conference MUC for clients

VirtualHost "auth.jitsi.example.com"
    -- Authentication domain

Component "focus.jitsi.example.com" "client_proxy"
    -- Jicofo proxy for clients
```

### Prosody-JVB (Port 15222)

Handles internal JVB/Jicofo traffic only:

```
c2s_ports = { 15222 }  -- Different port
s2s_ports = { }        -- No server-to-server
http_ports = { }       -- No HTTP

VirtualHost "tech.jitsi.example.com"
    authentication = "internal_hashed"

Component "muc.tech.jitsi.example.com" "muc"
    -- JVB brewery MUC
    admins = { "focus@tech.jitsi.example.com", "jvb@tech.jitsi.example.com" }
```

## Component Configuration

### Jicofo

Jicofo connects to **both** Prosody instances:

```hocon
jicofo {
  xmpp {
    # Client connection - main Prosody
    client {
      hostname = localhost
      port = 5222
      xmpp-domain = "jitsi.example.com"
      domain = "auth.jitsi.example.com"
    }

    # Service connection - Prosody-JVB
    service {
      enabled = true
      hostname = localhost
      port = 15222
      domain = "tech.jitsi.example.com"
    }
  }

  bridge {
    # Use the service connection for bridge discovery
    brewery-jid = "jvbbrewery@muc.tech.jitsi.example.com"
    xmpp-connection-name = Service  # CRITICAL!
  }
}
```

The `xmpp-connection-name = Service` setting tells Jicofo to use the Prosody-JVB connection when looking for available bridges.

### Jitsi Videobridge (JVB)

JVBs connect only to Prosody-JVB:

```hocon
videobridge {
  apis {
    xmpp-client {
      configs {
        tech {
          HOSTNAME = "jitsi.example.com"
          PORT = 15222
          DOMAIN = "tech.jitsi.example.com"
          MUC_JIDS = "jvbbrewery@muc.tech.jitsi.example.com"
        }
      }
    }
  }
}
```

## Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                         User Browser                             │
└─────────────────────────────────────────────────────────────────┘
                                │
                                │ HTTPS/WSS
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                            Nginx                                 │
│                    (SSL termination, routing)                    │
└─────────────────────────────────────────────────────────────────┘
          │                              │
          │ /xmpp-websocket              │ /colibri-ws
          ▼                              ▼
┌─────────────────────┐        ┌─────────────────────┐
│   Main Prosody      │        │        JVB          │
│     (port 5222)     │        │   (port 10000 UDP)  │
│                     │        │                     │
│ - Client auth       │        │ - Audio/video relay │
│ - Presence          │        │ - Colibri WS        │
│ - Chat              │        └─────────┬───────────┘
│ - Conference MUC    │                  │
└─────────┬───────────┘                  │
          │                              │
          │                              │ XMPP
          │                              ▼
          │                 ┌─────────────────────────┐
          │                 │     Prosody-JVB         │
          │                 │      (port 15222)       │
          │                 │                         │
          │                 │ - JVB MUC (brewery)     │
          │                 │ - Colibri signaling     │
          │                 │ - Bridge registration   │
          │                 └─────────┬───────────────┘
          │                           │
          │        ┌──────────────────┘
          │        │
          ▼        ▼
┌─────────────────────────────────────────────────────────────────┐
│                          Jicofo                                  │
│                                                                  │
│  client connection ◄─────► port 5222 (conference management)    │
│  service connection ◄────► port 15222 (bridge selection)        │
└─────────────────────────────────────────────────────────────────┘
```

## Port Summary

| Port  | Service     | Protocol | Purpose |
|-------|-------------|----------|---------|
| 443   | Nginx       | HTTPS    | Client web access |
| 5222  | Prosody     | XMPP     | Client XMPP |
| 5280  | Prosody     | HTTP     | BOSH/WebSocket (internal) |
| 15222 | Prosody-JVB | XMPP     | JVB/Jicofo internal |
| 10000 | JVB         | UDP      | Media (RTP) |
| 9090  | JVB         | HTTP     | Colibri WebSocket |

## Critical Configuration Points

### 1. Jicofo Service Connection

Must be `enabled = true` with matching domain to Prosody-JVB.

### 2. Bridge xmpp-connection-name

The `bridge.xmpp-connection-name = Service` setting ensures Jicofo uses the correct connection for bridge discovery.

### 3. MUC JID Alignment

The brewery JID must match exactly:
- Jicofo: `brewery-jid = "jvbbrewery@muc.tech.example.com"`
- JVB: `MUC_JIDS = "jvbbrewery@muc.tech.example.com"`

### 4. User Registration

Users must be registered in the correct Prosody instance:
- Main Prosody: `focus@auth.jitsi.example.com`
- Prosody-JVB: `focus@tech.jitsi.example.com`, `jvb@tech.jitsi.example.com`

## Scaling

To add more JVBs:

1. Deploy JVB on a new server
2. Configure it to connect to Prosody-JVB at the main server's IP
3. Register the JVB user in Prosody-JVB
4. JVB automatically joins the brewery and becomes available

No changes needed on the main server!

## Troubleshooting

### JVB Connected but Conferences Fail

Check:
1. MUC JID alignment between Jicofo and JVB
2. `xmpp-connection-name = Service` in Jicofo config
3. JVB user registered in Prosody-JVB

### Clients Can't Join

Check:
1. Main Prosody is running
2. Focus user registered in main Prosody
3. Nginx proxying correctly to port 5280

### Bridge Selection Fails

Check:
1. Jicofo logs for "no operational bridges"
2. JVB health status in logs
3. Prosody-JVB MUC contains JVB entries
