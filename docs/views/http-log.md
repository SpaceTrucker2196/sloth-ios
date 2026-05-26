# HTTPLogView

Milestone: M5
Status: spec

## Data source

Store ring: `store.httpLog`.
Update cadence: realtime.

## Layout

```
┌──────────────────────────────────────────────────────┐
│  HTTP                                         🔍 ___ │
│  21:00:01  GET   detectportal.firefox.com  /success │
│  21:00:01  GET   www.msftncsi.com         /ncsi.txt │
│  21:00:02  POST  iot-device.local         /api/upd  │
│  21:00:03  GET   victim.example.com       /admin/.. │  ← CRIT (attack path)
└──────────────────────────────────────────────────────┘
```

## Graphs

None on M5. Method-distribution chart deferred — HTTP traffic in
modern networks is overwhelmingly captive-portal noise, and the
distribution is uninformative.

## Interactions

- Search: substring against host + path + method.
- Tap row → bottom-sheet with the raw JSONL.

## Severity / colour

- Cleartext POSTs to non-localhost hosts render in WARN.
- Attack-path matches (e.g. `/.git/config`, `/.env`, `..%2f`) render
  in CRIT and register the src IP as alert-hot.
- Hosts that match a threat-domain IOC pick up CRIT.

## Accessibility

- Per-row a11y: "HTTP GET to example dot com, path /admin slash …"
