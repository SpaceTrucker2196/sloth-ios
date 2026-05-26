// SlothCore — headless networking + state for sloth-ios.
//
// This file is the umbrella for the module's public surface. Concrete
// types land in:
//
//   SlothRecord.swift       — Codable sum type for every JSONL `type`
//   SlothClient.swift       — Network.framework wrapper
//   LineReader.swift        — newline framing over an async byte stream
//   SlothStore.swift        — @Observable state holder; rings per type
//   AlertHotIndex.swift     — cross-panel severity index
//   ConnectionProfile.swift — UserDefaults-backed profile
//   Theme.swift             — SwiftUI Color extensions (also re-exported
//                             for any non-UI module that wants the hexes)
//
// As of pre-M1 only this placeholder exists; concrete files land per
// `docs/milestones.md`.

import Foundation

/// Build / version metadata for diagnostics. Bumped per release.
public enum SlothCoreInfo: Sendable {
    public static let version = "0.0.0-pre-m1"
}
