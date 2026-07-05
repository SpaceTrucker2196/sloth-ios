# tools/

Developer tooling. Nothing here ships in the app or is imported by
app code; MISSION §2 applies to the app, and these tools keep it
honest by making verification repeatable.

## fake-producer.py

A stand-in for sloth's `--data-socket`: listens on
`127.0.0.1:8765` and emits one JSONL batch per second covering
every record type the client renders, with sinusoidal rates so
sparklines have a shape. Python 3 stdlib only.

```
python3 tools/fake-producer.py          # default 127.0.0.1:8765
python3 tools/fake-producer.py --port 9999
```

The iOS Simulator shares the Mac's loopback, so the app reaches it
at `tcp:127.0.0.1:8765`. To skip typing the URI in the sim, seed
the legacy profile key before first launch (ProfileStore upgrades
it to the active profile, and the app auto-dials the active
profile at launch):

```
HEX=$(printf '{"host":"127.0.0.1","port":8765}' | xxd -p | tr -d '\n')
xcrun simctl spawn <device> defaults write io.river.sloth.ios \
    io.river.sloth.connectionProfile.v1 -data "$HEX"
```

Field spellings must match `SlothRecord.swift`'s `CodingKeys`
(schema truth lives in sloth's `docs/wiki/jsonl-schema.md`). If a
record type gains fields, update the producer or the new band
renders its quiet row and the render check silently thins out.
