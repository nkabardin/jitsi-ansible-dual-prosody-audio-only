# Development History: Scaling Jitsi for 300+ Audio Participants

This document tells the story of how this dual-Prosody architecture was developed for a real-world deployment serving 300+ concurrent audio participants.

## The Challenge

We needed to host large audio-only conferences (think webinars, group calls, or community events) with 300+ simultaneous participants. Standard Jitsi deployments struggled with this scale.

## Phase 1: Single-Prosody Limitations

### The Setup
Initially, we deployed a standard Jitsi setup:
- Single Prosody instance handling all XMPP traffic
- Jicofo and JVBs connecting to the same Prosody
- Clients connecting to the same Prosody

### The Problem
At around 150-200 concurrent users, we observed:
- Increased latency in audio
- Connection timeouts
- JVBs occasionally disconnecting
- Jicofo struggling to manage conferences

### The Discovery
Analyzing the traffic, we found that Prosody was bottlenecked by mixing two very different traffic patterns:

1. **Client traffic**: Bursty, lots of small messages, presence updates
2. **JVB/Jicofo traffic**: Constant, high-frequency signaling for media routing

These competed for the same XMPP connection handlers.

## Phase 2: The Dual-Prosody Solution

### The Idea
What if we separated these traffic types completely?

- **Main Prosody (port 5222)**: Handle client connections only
- **Prosody-JVB (port 15222)**: Handle JVB and Jicofo internal communication

### The Implementation
We created a second Prosody instance with:
- A dedicated "tech" domain (e.g., `tech.jitsi.example.com`)
- MUC for JVB brewery
- Authentication for JVB and Jicofo service connections

Jicofo was configured with two XMPP connections:
- `client`: Connects to main Prosody for conference management
- `service`: Connects to Prosody-JVB for JVB communication

JVBs connect only to Prosody-JVB.

## Phase 3: The "Almost Working" Problem

### The Symptom
JVBs connected successfully to Prosody-JVB. The MUC showed them online. But conferences didn't work! Participants could connect, but audio routing failed.

### The Investigation
Hours of log analysis revealed the issue. The conference MUC JID pattern expected by Jicofo didn't match what the JVBs were reporting through the service connection.

### The Root Cause
MUC domain mismatches! The JVB was registered in one MUC (`jvbbrewery@muc.tech.domain`) but Jicofo was looking for it in a different pattern.

### The Solution
Careful alignment of:
- `brewery-jid` in Jicofo configuration
- `MUC_JIDS` in JVB configuration
- `xmpp-connection-name` pointing Jicofo to use the service connection for bridge selection

The key insight: Jicofo's `bridge.xmpp-connection-name = Service` tells it to use the Prosody-JVB connection for finding available bridges.

## Phase 4: Audio-Only Optimization

With the architecture working, we optimized for audio-only:

### Jicofo
```hocon
conference {
  enable-video = false
}
```

### JVB
```hocon
video {
  enabled = false
}
```

### sip-communicator.properties
```
org.jitsi.videobridge.DISABLE_VIDEO_SUPPORT=true
```

### config.js
```javascript
disableVideo: true,
disableVideoInput: true,
disableDesktopSharing: true,
channelLastN: 0,
constraints: {
  video: { height: { ideal: 0, max: 0 }, ... }
},
videoQuality: { maxBitratesVideo: { low: 0, standard: 0, high: 0 } },
p2p: { enabled: false }
```

## Phase 5: Additional Optimizations

### Prosody Firewall Rules
Added mod_firewall rules to filter unnecessary presence traffic in the JVB MUC, reducing CPU load.

### Connection Limits
Tuned sysctl and ulimit settings:
- `net.core.somaxconn = 65535`
- `fs.file-max = 2097152`

### SMACKS
Enabled SMACKS (XEP-0198) for reliable message delivery and connection resumption.

## Results

After implementing this architecture:

- **Capacity**: 300+ concurrent audio participants in a single conference
- **Stability**: JVBs maintain stable connections
- **Latency**: Sub-second audio latency
- **Scalability**: Easy to add more JVB servers

## Lessons Learned

1. **Separate traffic types**: Don't mix client and internal server traffic on the same connection handlers.

2. **MUC JIDs matter**: Small mismatches in MUC JID configuration can cause complete communication failures while appearing to work at the connection level.

3. **Test at scale**: Many issues only appear under load. Test with realistic participant counts.

4. **Audio-only simplifies**: Disabling video at all levels dramatically reduces complexity and increases capacity.

5. **Logs are your friend**: Jicofo, JVB, and Prosody logs tell the story. Learn to read them.

## Acknowledgments

This architecture was developed through trial and error, countless hours of log analysis, and the help of the Jitsi community forums.

---

*This document accompanies the jitsi-audio-meet repository, making this battle-tested configuration available for others facing similar scaling challenges.*
