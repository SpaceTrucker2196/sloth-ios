# SettingsView

Milestone: M8
Status: spec

## Data source

`ProfileStore` (UserDefaults-backed).
No streaming data.

## Layout

```
┌──────────────────────────────────────────────────────┐
│  ← Done                Settings                      │
│                                                      │
│  ─ Connection profiles ─                             │
│  ● Home pi          tcp:100.64.0.5:8765              │
│  ○ Office mac       tcp:100.96.1.10:8765             │
│  ○ Local sim        unix:/var/run/sloth.sock         │
│  [+ Add profile]                                     │
│                                                      │
│  ─ Diagnostics ─                                     │
│  • View recent logs                                  │
│                                                      │
│  ─ About ─                                           │
│  • Mission                                           │
│  • Open source acknowledgements                      │
└──────────────────────────────────────────────────────┘
```

## Interactions

- Tap radio button → switch active profile (triggers reconnect).
- Tap row → edit sheet for that profile.
- Swipe-to-delete on non-active profiles.
- `+ Add profile` → modal sheet.
- "View recent logs" → push `DiagnosticsView`.
- "Mission" → push a static view rendering the contents of
  `MISSION.md`.
- "Open source acknowledgements" → push a static list (only
  Apple-vendored frameworks should be in here, per CLAUDE.md).

## Severity / colour

None — settings view is the only screen with no live data and no
severity hues.

## Accessibility

- Profile-list rows announce active status: "Selected. Home pi.
  TCP 100.64.0.5 port 8765."
