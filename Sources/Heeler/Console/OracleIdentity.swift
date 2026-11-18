import Foundation
import Observation

/// Which oracle an Agent belongs to, and what to draw for it. The oracle is
/// found from the Agent's name, then the repository folder it runs in
/// (`<name>-oracle`, `wt/<slug>-<oracle>-<date>`, `<oracle>-soul`), then its
/// Workspace label, and matched against the oracles whose icons the Host has.
enum OracleIdentity {
    /// Shortest oracle name that may match inside a longer folder name, so a
    /// two-letter oracle cannot claim every folder that contains it.
    static let minimumSubstringLength = 3

    /// Lowercased, trimmed, with a trailing `-oracle` or `-soul` removed.
    static func normalized(_ text: String) -> String {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        for suffix in ["-oracle", "-soul"] where s.hasSuffix(suffix) {
            s.removeLast(suffix.count)
        }
        return s
    }

    /// The names to try, in priority order: the Agent's name, each folder of
    /// its working directory from the innermost out, then the Workspace label.
    static func sources(agentName: String?, cwd: String?, workspaceLabel: String?) -> [String] {
        var out: [String] = []
        if let agentName, !agentName.isEmpty { out.append(agentName) }
        if let cwd {
            out += cwd.split(separator: "/").reversed().prefix(3).map(String.init)
        }
        if let workspaceLabel, !workspaceLabel.isEmpty { out.append(workspaceLabel) }
        return out.map(normalized).filter { !$0.isEmpty }
    }

    /// The known oracle `text` names: equal to it, or holding it as whole
    /// dash-separated words (`app-studio-labs-issue4`). The longest match
    /// wins, so `studio-labs` beats `studio`.
    static func match(_ text: String, in known: Set<String>) -> String? {
        if known.contains(text) { return text }
        let padded = "-\(text)-"
        return known
            .filter { $0.count >= minimumSubstringLength && padded.contains("-\($0)-") }
            .max { $0.count < $1.count }
    }

    /// The oracle of an Agent among `known`, or nil.
    static func resolve(
        agentName: String?, cwd: String?, workspaceLabel: String?, known: Set<String>
    ) -> String? {
        for source in sources(agentName: agentName, cwd: cwd, workspaceLabel: workspaceLabel) {
            if let hit = match(source, in: known) { return hit }
        }
        return nil
    }

    /// The name to draw a fallback for when no icon matched: the first source
    /// that is not a bare path artefact.
    static func fallbackName(agentName: String?, cwd: String?, workspaceLabel: String?) -> String? {
        sources(agentName: agentName, cwd: cwd, workspaceLabel: workspaceLabel).first
    }
}

/// What the avatar draws in place of the program mark.
struct OracleIcon: Equatable, Sendable {
    enum Face: Equatable, Sendable {
        /// The oracle's own picture (PNG data).
        case picture(Data)
        /// An emoji or monogram on a colour derived from the name.
        case glyph(String, hue: Double)
    }

    let name: String
    let face: Face

    /// An emoji for an oracle; others get a monogram.
    static let emojis: [String: String] = ["studio-labs": "🏮"]

    /// A stable hue (0...1) from the name: the same oracle always gets the
    /// same colour on every device. FNV-1a, so it does not vary per launch
    /// the way `hashValue` does.
    static func hue(for name: String) -> Double {
        var hash: UInt32 = 2_166_136_261
        for byte in name.utf8 {
            hash = (hash ^ UInt32(byte)) &* 16_777_619
        }
        return Double(hash % 360) / 360
    }

    /// First letter of the name, uppercased; `?` for an empty one.
    static func monogram(for name: String) -> String {
        name.first(where: { $0.isLetter || $0.isNumber }).map { String($0).uppercased() } ?? "?"
    }

    static func fallback(name: String) -> OracleIcon {
        OracleIcon(
            name: name,
            face: .glyph(emojis[name] ?? monogram(for: name), hue: hue(for: name)))
    }

    /// The picture when the Host has one, else the fallback.
    static func make(name: String, pictures: [String: Data]) -> OracleIcon {
        if let data = pictures[name] { return OracleIcon(name: name, face: .picture(data)) }
        return fallback(name: name)
    }
}

/// The `icons.json` bundle the Host's script writes next to the plugin's
/// other config: `{"v":1,"icons":{"<oracle>":"<base64 png>"}}`.
enum OracleIconBundle {
    /// Oracle name to PNG data; empty when the file is absent or malformed.
    static func decode(_ data: Data?) -> [String: Data] {
        guard let data,
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            root["v"] as? Int == 1,
            let icons = root["icons"] as? [String: String]
        else { return [:] }
        return icons.compactMapValues { Data(base64Encoded: $0) }
    }
}

/// Each Host's oracle pictures, read once per connection over SSH.
@MainActor
@Observable
final class OracleIconStore {
    private(set) var pictures: [Host.ID: [String: Data]] = [:]
    @ObservationIgnored private var generations: [Host.ID: UInt64] = [:]
    @ObservationIgnored private var tasks: [Host.ID: Task<Void, Never>] = [:]

    /// The icon for `agent`, from its Host's pictures when any oracle
    /// matches, else a fallback for the best-guess name; nil when the Agent
    /// names no oracle at all.
    func icon(for agent: ConsoleAgent) -> OracleIcon? {
        let hostPictures = pictures[agent.hostID] ?? [:]
        let cwd = agent.agent.foregroundCwd ?? agent.agent.cwd
        if let name = OracleIdentity.resolve(
            agentName: agent.agent.name, cwd: cwd, workspaceLabel: agent.workspaceLabel,
            known: Set(hostPictures.keys))
        {
            return .make(name: name, pictures: hostPictures)
        }
        return OracleIdentity.fallbackName(
            agentName: agent.agent.name, cwd: cwd, workspaceLabel: agent.workspaceLabel
        ).map(OracleIcon.fallback(name:))
    }

    /// Reads a Host's bundle when its connection is new to this store.
    func reconcile(
        _ connections: [Host.ID: UInt64], transports: any NotificationTransportProvider
    ) {
        for id in Array(generations.keys) where connections[id] == nil {
            tasks.removeValue(forKey: id)?.cancel()
            generations[id] = nil
            pictures[id] = nil
        }
        for (id, generation) in connections where generations[id] != generation {
            generations[id] = generation
            tasks[id]?.cancel()
            tasks[id] = Task { [weak self] in
                let data = try? await transports.withNotificationTransport(for: id) {
                    try await $0.readOracleIcons()
                }
                guard let self, !Task.isCancelled, generations[id] == generation else { return }
                pictures[id] = OracleIconBundle.decode(data)
                tasks[id] = nil
            }
        }
    }
}
