# Development History: Scaling Jitsi for 500+ Audio Participants

This document tells the real story of how this dual-Prosody architecture was developed for a production deployment now serving 470+ concurrent audio participants.

**Repository**: https://github.com/nkabardin/jitsi-ansible-dual-prosody-audio-only

**Community Discussion**: [Scaling Jitsi for 500+ audio-only participants](https://community.jitsi.org/t/scaling-jitsi-for-500-audio-only-participants-help-needed-with-prosody-jicofo-bottlenecks/141201)

## The Challenge

We needed to host large audio-only conferences (webinars, group calls, community events) with 500+ simultaneous participants. Standard Jitsi deployments struggled at this scale.

## Phase 1: The October 17, 2025 Incident

### The Setup
We deployed a multi-JVB architecture with OCTO (Oasis Cascade Token Optimization):
- **Main server**: Prosody, Jicofo, JVB
- **jvb2**: Additional video bridge
- **Backup server**: Standby JVB
- OCTO enabled for load distribution between bridges

### The Incident
On October 17, 2025, at 19:57-20:00, the system experienced a complete failure with ~200 participants.

**Timeline:**
- **19:57:16-21**: Health-check timeouts on ALL bridges simultaneously
- **19:57:30-45**: Mass ICE connectivity failures on jvb2
- **19:57:38**: Jicofo expired the conference on jvb2
- **19:58:25**: "There are no operational bridges" — complete collapse
- **19:59:15-45**: Full system unavailability

### The Root Cause Discovery
Initial assumption was network issues due to ICE failures. **Wrong.**

The real chain of events:
1. **Prosody hit 100% CPU** — the actual root cause
2. Health-check XMPP messages from Jicofo to bridges started timing out
3. Jicofo marked all bridges as unhealthy
4. Jicofo decided to expire/migrate conferences
5. ICE failures appeared as a *symptom*, not cause

**Critical insight**: The old architecture (without OCTO) handled 250 participants at <50% CPU. The OCTO architecture failed at 200 participants with 100% CPU. OCTO's inter-bridge coordination via XMPP MUC was overloading Prosody.

## Phase 2: Seeking Help from Jitsi Team

Posted to the Jitsi community forum asking for help with Prosody/Jicofo bottlenecks.

### Advice from damencho (Jitsi Team)

**1. Remove unused Prosody modules:**
```lua
-- Remove these if not needed:
-- bookmarks, carbons, dialback, pep, register, invites, vcards
```

**2. Enable essential modules under main virtual host:**
```lua
modules_enabled = {
    "smacks";  -- Stream management
    "jiconop"; -- Jitsi-specific optimizations
}
```

**3. Tune Lua 5.4 garbage collection** (more memory, less CPU):
```lua
gc = {
    mode = "incremental";
    threshold = 400;
    speed = 250;
    step_size = 13;
}
```

**4. Be careful with mod_limits** — rate limiting can cause ping timeouts.

## Phase 3: The Breakthrough — mod_muc_rate_limit

Following damencho's advice, I cleaned up modules and added GC tuning. Initial tests showed no improvement — still hitting 100% CPU with many clients joining simultaneously.

Then I tried **disabling mod_muc_rate_limit completely**.

**The result was magical:**
- Prosody CPU never exceeded 20%
- Achieved stable **470 participants** with virtually no server stress
- The rate limiting itself was consuming incredible CPU

### Why This Works
`mod_muc_rate_limit` tracks and limits message rates per-participant in MUCs. With 400+ participants, the overhead of tracking all those rate limits became the bottleneck itself. Removing it eliminated that overhead entirely.

## Phase 4: The Dual-Prosody Architecture

To further isolate client traffic from JVB/Jicofo signaling:

- **Main Prosody (port 5222)**: Client connections only
- **Prosody-JVB (port 15222)**: JVB and Jicofo internal communication

### Prosody-JVB Setup
A dedicated "tech" domain with:
- MUC for JVB brewery (`jvbbrewery@muc.tech.domain`)
- Authentication for JVB and Jicofo service connections

### Jicofo Dual-Connection Config
```hocon
xmpp {
  client {
    # Main Prosody for conference management
  }
  service {
    # Prosody-JVB for bridge communication
  }
}
bridge {
  xmpp-connection-name = "Service"  # Use Prosody-JVB for bridge selection
}
```

### mod_firewall Rules for Prosody-JVB
Filter unnecessary presence traffic in the JVB MUC:
```
::preroute
KIND: iq
TYPE: get
PAYLOAD: urn:xmpp:ping
PASS.

FROM: jvbbrewery@muc.tech.meet.domain.com
TO: <jvb*>@tech.meet.domain.com
KIND: presence
TYPE: available
NOT INSPECT: {http://jabber.org/protocol/muc#user}x/status@code=110
DROP.
```

## Phase 5: Audio-Only Optimization

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

## Results

After implementing this architecture:

- **Capacity**: 470+ concurrent audio participants in a single conference
- **Server Load**: Prosody CPU stays under 20%
- **Stability**: No more cascading health-check failures
- **Scalability**: Easy to add more JVB servers

### Remaining Challenges
Slower devices (older Android phones) struggle to load 450+ user profiles — this is now a client-side limitation, not server-side.

## Lessons Learned

1. **mod_muc_rate_limit is expensive**: At scale, the rate limiting overhead exceeds the cost of the traffic it's limiting. Disable it for large conferences.

2. **OCTO adds XMPP overhead**: The inter-bridge coordination through MUC can overload Prosody. For single large rooms, simpler may be better.

3. **ICE failures are often symptoms, not causes**: When debugging connectivity issues, look at Prosody CPU and health-check logs first.

4. **Tune Prosody GC for Lua 5.4**: The incremental GC settings from Jitsi team significantly reduce CPU spikes.

5. **Separate traffic types**: Dual-Prosody prevents client presence storms from affecting JVB signaling.

6. **Test at scale**: The October 17 incident only appeared under real production load. Synthetic tests help but real usage reveals different patterns.

## Acknowledgments

Huge thanks to **damencho** and the Jitsi team for their guidance on the community forums. Their advice about module cleanup, GC tuning, and ultimately the insight about rate limiting was invaluable.

---

*This configuration is battle-tested in production and made available for others facing similar scaling challenges.*
