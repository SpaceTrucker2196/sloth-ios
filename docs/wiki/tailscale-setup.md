# Tailscale setup

How to wire sloth and sloth-ios over a tailnet so the iOS device can
reach the data socket.

## Layout

```
   ┌─────────────────────┐                  ┌─────────────────────┐
   │  sloth server       │                  │  iPhone / iPad      │
   │  (Mac / Linux /     │                  │  sloth-ios          │
   │   Raspberry Pi)     │                  │                     │
   │                     │  WireGuard       │                     │
   │  100.64.0.5         │ ◄──────────────► │  100.96.1.10        │
   │                     │  (encrypted)     │                     │
   │  sloth --data-socket│                  │  tcp:100.64.0.5:8765│
   │    tcp:100.64.0.5:  │                  │                     │
   │    8765             │                  │                     │
   └─────────────────────┘                  └─────────────────────┘
              │
              └─ Tailscale ACL: only this iPhone may
                 connect to TCP/8765 on this node
```

## On the sloth server

Install Tailscale and bring it up:

```sh
# Linux
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up

# macOS
brew install --cask tailscale && tailscale up
```

Find the server's tailnet IP:

```sh
tailscale ip --4
# → 100.64.0.5
```

Run sloth bound to that address:

```sh
sudo ./sloth --data-socket tcp:100.64.0.5:8765 \
             -o /var/log/sloth.jsonl
```

**Do not bind to `0.0.0.0`.** Bind to the Tailscale-assigned IP
specifically so the listener is only reachable from the tailnet —
not from anything else the host happens to be connected to.

## Tailscale ACL (recommended)

In your tailnet admin console (`Access Controls` → `Access policy`),
restrict TCP/8765 to the specific devices that should consume:

```json
{
  "acls": [
    {
      "action": "accept",
      "src":    ["tag:sloth-client"],
      "dst":    ["tag:sloth-server:8765"]
    }
  ],
  "tagOwners": {
    "tag:sloth-server": ["autogroup:admin"],
    "tag:sloth-client": ["autogroup:admin"]
  }
}
```

Then tag the relevant devices:

```sh
# on the sloth server
sudo tailscale up --advertise-tags=tag:sloth-server

# on the iPhone (via the Tailscale admin console — device → edit tags)
# add: tag:sloth-client
```

ACLs are belt-and-suspenders: the bind is already restrictive, but
explicit ACLs document intent.

## On the iPhone

1. Install the **Tailscale** app from the App Store.
2. Sign in to the same tailnet.
3. Verify the server is reachable: in Tailscale's "Machines" tab,
   tap the sloth server; it should show "Online" and the IP
   `100.64.0.5`.
4. Open sloth-ios → Settings → Add profile:
   - Host: `100.64.0.5` (the Tailscale IP of the sloth server)
   - Port: `8765`
   - Transport: TCP
5. Set as active profile. sloth-ios connects.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| "Connection refused" | sloth not running, or not bound to that IP | `ps aux | grep sloth`; restart with the right `--data-socket` |
| "No route to host" | Tailscale not up on the phone | open the Tailscale app; toggle on |
| Connects, but nothing streams | sloth is running but no events on the wire (your network is quiet) | wait for traffic; `tail -f /var/log/sloth.jsonl` to confirm |
| Connects, then drops every ~30s | iOS suspended the app | expected — MISSION §2(4). Foreground reconnects |
| Server tagged but ACL still blocks | tag rules need a re-apply | save the policy in the admin console; tags update on the device within seconds |

## Hardening

If you want stricter isolation:

- Use a dedicated user on the sloth host (`sloth`) with `CAP_NET_RAW`
  only, and run sloth under it. The `--data-socket` listener
  inherits that uid; iOS doesn't care.
- Pin the iPhone's Tailscale node-key in the ACL `src` so a
  device-rename doesn't accidentally open the listener up.
- Use Tailscale's **Funnel** *only* if you actually want internet
  exposure (you probably don't — see MISSION §2). Funnel is off by
  default; leave it that way.
