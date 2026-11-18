import Foundation

/// herdr's sidebar nesting, for a plain list of Agent rows (All Agents and
/// By Host): each linked-worktree space's Agents follow their repository's
/// main space and sit indented under it. Grouping is by the Workspace's
/// `worktree.repo_key` within one Host; an Agent whose Workspace has no
/// `worktree` object stands alone. Worktree Agents whose main space has no
/// Agents in the list sit under a header made for the repository.
enum AgentRepoNesting {
    enum Item: Equatable, Sendable, Identifiable {
        case header(repoName: String, id: String)
        case agent(ConsoleAgent, isNested: Bool)

        var id: String {
            switch self {
            case .header(_, let id): id
            case .agent(let agent, _): "\(agent.hostID.uuidString)/\(agent.agent.paneID)"
            }
        }
    }

    private struct Group: Hashable {
        let hostID: Host.ID
        let repoKey: String
    }

    private static func group(_ agent: ConsoleAgent) -> Group? {
        agent.repositoryCheckout.map { Group(hostID: agent.hostID, repoKey: $0.repoKey) }
    }

    private static func isLinked(_ agent: ConsoleAgent) -> Bool {
        agent.repositoryCheckout?.isLinkedWorktree == true
    }

    /// `agents` (already in the order the list sorts them) as rows: nested
    /// Agents after their main space's, headers for orphaned worktrees.
    static func items(_ agents: [ConsoleAgent]) -> [Item] {
        var mains: [Group: [ConsoleAgent]] = [:]
        var linked: [Group: [ConsoleAgent]] = [:]
        for agent in agents {
            guard let key = group(agent) else { continue }
            if isLinked(agent) { linked[key, default: []].append(agent) } else { mains[key, default: []].append(agent) }
        }
        var out: [Item] = []
        var done: Set<Group> = []
        for agent in agents {
            guard let key = group(agent) else {
                out.append(.agent(agent, isNested: false))
                continue
            }
            guard done.insert(key).inserted else { continue }
            if let main = mains[key] {
                out += main.map { .agent($0, isNested: false) }
                out += (linked[key] ?? []).map { .agent($0, isNested: true) }
            } else {
                let name = agent.repositoryCheckout?.repoName ?? key.repoKey
                out.append(.header(repoName: name, id: "repo:\(key.hostID.uuidString)/\(key.repoKey)"))
                out += (linked[key] ?? []).map { .agent($0, isNested: true) }
            }
        }
        return out
    }

    /// Only the order, for keyboard navigation and anything else that walks
    /// the Agents.
    static func ordered(_ agents: [ConsoleAgent]) -> [ConsoleAgent] {
        items(agents).compactMap {
            if case .agent(let agent, _) = $0 { agent } else { nil }
        }
    }
}
