// ICMPClassify — human-readable names and filter categories for
// ICMP type/code pairs. The name tables mirror sloth's
// `src/icmp_log.c` (`desc_v4` / `desc_v6`) exactly, so the iOS log
// reads identically to the TUI's ICMP panel.
//
// The wire record carries no v4/v6 discriminator — sloth's
// `is_v6` field isn't part of the JSONL subset this client decodes —
// so family is inferred from the address literal (v6 contains ':').

import Foundation

public enum ICMPClassify {

    /// Filter axis for the log view. Coarser than the type number:
    /// operators think "pings", "errors", "neighbor chatter".
    public enum Category: String, Sendable, Equatable, CaseIterable {
        case echo       // request/reply pairs
        case error      // unreachable, TTL exceeded, param problem, too big
        case discovery  // router/neighbor sol+adv, MLD
        case other
    }

    /// v6 ⇔ the literal contains a colon. Bare v4, empty, and
    /// hostnames (which sloth never emits here) all read as v4.
    public static func isV6(address: String?) -> Bool {
        address?.contains(":") ?? false
    }

    /// Short display name, mirroring sloth's `desc_v4`.
    public static func nameV4(type: Int) -> String {
        switch type {
        case 0:  return "Echo Reply"
        case 3:  return "Unreachable"
        case 4:  return "Src Quench"
        case 5:  return "Redirect"
        case 8:  return "Echo Req"
        case 9:  return "Router Adv"
        case 10: return "Router Sol"
        case 11: return "TTL Exceeded"
        case 12: return "Param Prob"
        case 13: return "Timestamp"
        case 14: return "TS Reply"
        case 30: return "Traceroute"
        default: return "ICMP"
        }
    }

    /// Short display name, mirroring sloth's `desc_v6`.
    public static func nameV6(type: Int) -> String {
        switch type {
        case 1:   return "Unreachable"
        case 2:   return "Packet Too Big"
        case 3:   return "TTL Exceeded"
        case 4:   return "Param Prob"
        case 128: return "Echo Req"
        case 129: return "Echo Reply"
        case 130: return "MLD Query"
        case 131: return "MLD Report"
        case 132: return "MLD Done"
        case 133: return "Router Sol"
        case 134: return "Router Adv"
        case 135: return "Neigh Sol"
        case 136: return "Neigh Adv"
        case 137: return "Redirect"
        default:  return "ICMPv6"
        }
    }

    /// Display name for an entry, inferring the family from its
    /// addresses. Unknown type (nil) reads as the bare family name.
    public static func name(for entry: ICMPEntry) -> String {
        let v6 = isV6(address: entry.src) || isV6(address: entry.dst)
        guard let type = entry.icmpType else { return v6 ? "ICMPv6" : "ICMP" }
        return v6 ? nameV6(type: type) : nameV4(type: type)
    }

    public static func categoryV4(type: Int) -> Category {
        switch type {
        case 0, 8:          return .echo
        case 3, 4, 11, 12:  return .error
        case 5, 9, 10:      return .discovery
        default:            return .other
        }
    }

    public static func categoryV6(type: Int) -> Category {
        switch type {
        case 128, 129:                     return .echo
        case 1, 2, 3, 4:                   return .error
        case 130...137:                    return .discovery
        default:                           return .other
        }
    }

    public static func category(for entry: ICMPEntry) -> Category {
        let v6 = isV6(address: entry.src) || isV6(address: entry.dst)
        guard let type = entry.icmpType else { return .other }
        return v6 ? categoryV6(type: type) : categoryV4(type: type)
    }
}
