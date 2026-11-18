import Foundation
import Testing

@testable import Heeler

@Suite("Agent list repo nesting (By Host / All Agents)")
struct AgentRepoNestingTests {
    /// The full real `herdr workspace list` reply from a real session (herdr 0.9.5, 2026-11-18).
    private static let reply = """
[
 {
  "active_tab_id": "wDW:t1",
  "agent_status": "idle",
  "focused": true,
  "label": "repo-a",
  "number": 1,
  "pane_count": 2,
  "tab_count": 1,
  "workspace_id": "wDW",
  "worktree": {
   "checkout_path": "/src/repo-a",
   "is_linked_worktree": false,
   "repo_key": "/src/repo-a/.git",
   "repo_name": "repo-a",
   "repo_root": "/src/repo-a"
  }
 },
 {
  "active_tab_id": "wJE:t1",
  "agent_status": "done",
  "focused": false,
  "label": "repo-b",
  "number": 2,
  "pane_count": 1,
  "tab_count": 1,
  "workspace_id": "wJE",
  "worktree": {
   "checkout_path": "/src/repo-b",
   "is_linked_worktree": false,
   "repo_key": "/src/repo-b/.git",
   "repo_name": "repo-b",
   "repo_root": "/src/repo-b"
  }
 },
 {
  "active_tab_id": "wJN:t1",
  "agent_status": "done",
  "focused": false,
  "label": "repo-c",
  "number": 3,
  "pane_count": 1,
  "tab_count": 1,
  "workspace_id": "wJN",
  "worktree": {
   "checkout_path": "/src/repo-c",
   "is_linked_worktree": false,
   "repo_key": "/src/repo-c/.git",
   "repo_name": "repo-c",
   "repo_root": "/src/repo-c"
  }
 },
 {
  "active_tab_id": "wJP:t1",
  "agent_status": "done",
  "focused": false,
  "label": "wt-1-repo-c",
  "number": 4,
  "pane_count": 1,
  "tab_count": 1,
  "workspace_id": "wJP",
  "worktree": {
   "checkout_path": "/src/repo-c-worktrees/wt-1",
   "is_linked_worktree": true,
   "repo_key": "/src/repo-c/.git",
   "repo_name": "repo-c",
   "repo_root": "/src/repo-c"
  }
 },
 {
  "active_tab_id": "wJQ:t1",
  "agent_status": "done",
  "focused": false,
  "label": "repo-d",
  "number": 5,
  "pane_count": 3,
  "tab_count": 1,
  "workspace_id": "wJQ",
  "worktree": {
   "checkout_path": "/src/repo-d",
   "is_linked_worktree": false,
   "repo_key": "/src/repo-d/.git",
   "repo_name": "repo-d",
   "repo_root": "/src/repo-d"
  }
 },
 {
  "active_tab_id": "wJY:t1",
  "agent_status": "done",
  "focused": false,
  "label": "plain-1",
  "number": 6,
  "pane_count": 1,
  "tab_count": 1,
  "workspace_id": "wJY"
 },
 {
  "active_tab_id": "wK1:t1",
  "agent_status": "idle",
  "focused": false,
  "label": "plain-2",
  "number": 7,
  "pane_count": 4,
  "tab_count": 1,
  "workspace_id": "wK1"
 },
 {
  "active_tab_id": "wK5:t1",
  "agent_status": "done",
  "focused": false,
  "label": "plain-3",
  "number": 8,
  "pane_count": 1,
  "tab_count": 1,
  "workspace_id": "wK5"
 },
 {
  "active_tab_id": "wK6:t1",
  "agent_status": "done",
  "focused": false,
  "label": "wt-2-repo-d",
  "number": 9,
  "pane_count": 1,
  "tab_count": 1,
  "workspace_id": "wK6",
  "worktree": {
   "checkout_path": "/src/repo-d-worktrees/wt-2",
   "is_linked_worktree": true,
   "repo_key": "/src/repo-d/.git",
   "repo_name": "repo-d",
   "repo_root": "/src/repo-d"
  }
 },
 {
  "active_tab_id": "wKH:t1",
  "agent_status": "unknown",
  "focused": false,
  "label": "wt-3-repo-c",
  "number": 10,
  "pane_count": 1,
  "tab_count": 1,
  "workspace_id": "wKH",
  "worktree": {
   "checkout_path": "/src/repo-c-worktrees/wt-3",
   "is_linked_worktree": true,
   "repo_key": "/src/repo-c/.git",
   "repo_name": "repo-c",
   "repo_root": "/src/repo-c"
  }
 },
 {
  "active_tab_id": "wKR:t1",
  "agent_status": "idle",
  "focused": false,
  "label": "wt-4-repo-a",
  "number": 11,
  "pane_count": 1,
  "tab_count": 1,
  "workspace_id": "wKR",
  "worktree": {
   "checkout_path": "/src/repo-a-worktrees/wt-4",
   "is_linked_worktree": true,
   "repo_key": "/src/repo-a/.git",
   "repo_name": "repo-a",
   "repo_root": "/src/repo-a"
  }
 },
 {
  "active_tab_id": "wKS:t1",
  "agent_status": "idle",
  "focused": false,
  "label": "wt-5-repo-a",
  "number": 12,
  "pane_count": 1,
  "tab_count": 1,
  "workspace_id": "wKS",
  "worktree": {
   "checkout_path": "/src/repo-a-worktrees/wt-5",
   "is_linked_worktree": true,
   "repo_key": "/src/repo-a/.git",
   "repo_name": "repo-a",
   "repo_root": "/src/repo-a"
  }
 },
 {
  "active_tab_id": "wKT:t1",
  "agent_status": "idle",
  "focused": false,
  "label": "wt-6-repo-a",
  "number": 13,
  "pane_count": 1,
  "tab_count": 1,
  "workspace_id": "wKT",
  "worktree": {
   "checkout_path": "/src/repo-a-worktrees/wt-6",
   "is_linked_worktree": true,
   "repo_key": "/src/repo-a/.git",
   "repo_name": "repo-a",
   "repo_root": "/src/repo-a"
  }
 },
 {
  "active_tab_id": "wKV:t1",
  "agent_status": "idle",
  "focused": false,
  "label": "wt-7-repo-a",
  "number": 14,
  "pane_count": 1,
  "tab_count": 1,
  "workspace_id": "wKV",
  "worktree": {
   "checkout_path": "/src/repo-a-worktrees/wt-7",
   "is_linked_worktree": true,
   "repo_key": "/src/repo-a/.git",
   "repo_name": "repo-a",
   "repo_root": "/src/repo-a"
  }
 },
 {
  "active_tab_id": "wKW:t1",
  "agent_status": "done",
  "focused": false,
  "label": "wt-8-repo-a",
  "number": 15,
  "pane_count": 1,
  "tab_count": 1,
  "workspace_id": "wKW",
  "worktree": {
   "checkout_path": "/src/repo-a-worktrees/wt-8",
   "is_linked_worktree": true,
   "repo_key": "/src/repo-a/.git",
   "repo_name": "repo-a",
   "repo_root": "/src/repo-a"
  }
 },
 {
  "active_tab_id": "wKX:t1",
  "agent_status": "idle",
  "focused": false,
  "label": "wt-9-repo-a",
  "number": 16,
  "pane_count": 1,
  "tab_count": 1,
  "workspace_id": "wKX",
  "worktree": {
   "checkout_path": "/src/repo-a-worktrees/wt-9",
   "is_linked_worktree": true,
   "repo_key": "/src/repo-a/.git",
   "repo_name": "repo-a",
   "repo_root": "/src/repo-a"
  }
 },
 {
  "active_tab_id": "wKY:t1",
  "agent_status": "done",
  "focused": false,
  "label": "wt-10-repo-a",
  "number": 17,
  "pane_count": 2,
  "tab_count": 1,
  "workspace_id": "wKY",
  "worktree": {
   "checkout_path": "/src/repo-a-worktrees/wt-10",
   "is_linked_worktree": true,
   "repo_key": "/src/repo-a/.git",
   "repo_name": "repo-a",
   "repo_root": "/src/repo-a"
  }
 },
 {
  "active_tab_id": "wKZ:t1",
  "agent_status": "done",
  "focused": false,
  "label": "wt-11-repo-a",
  "number": 18,
  "pane_count": 1,
  "tab_count": 1,
  "workspace_id": "wKZ",
  "worktree": {
   "checkout_path": "/src/repo-a-worktrees/wt-11",
   "is_linked_worktree": true,
   "repo_key": "/src/repo-a/.git",
   "repo_name": "repo-a",
   "repo_root": "/src/repo-a"
  }
 },
 {
  "active_tab_id": "wK0:t1",
  "agent_status": "idle",
  "focused": false,
  "label": "wt-12-repo-a",
  "number": 19,
  "pane_count": 2,
  "tab_count": 1,
  "workspace_id": "wK0",
  "worktree": {
   "checkout_path": "/src/repo-a-worktrees/wt-12",
   "is_linked_worktree": true,
   "repo_key": "/src/repo-a/.git",
   "repo_name": "repo-a",
   "repo_root": "/src/repo-a"
  }
 },
 {
  "active_tab_id": "wM1:t1",
  "agent_status": "working",
  "focused": false,
  "label": "wt-13-repo-a",
  "number": 20,
  "pane_count": 2,
  "tab_count": 1,
  "workspace_id": "wM1",
  "worktree": {
   "checkout_path": "/src/repo-a-worktrees/wt-13",
   "is_linked_worktree": true,
   "repo_key": "/src/repo-a/.git",
   "repo_name": "repo-a",
   "repo_root": "/src/repo-a"
  }
 }
]
"""

    private let host = Host.fixture()

    private func infos() throws -> [WorkspaceInfo] {
        try JSONDecoder().decode([WorkspaceInfo].self, from: Data(Self.reply.utf8))
    }

    /// One Agent per workspace, in herdr's order, as the Console builds them.
    private func agents() throws -> [ConsoleAgent] {
        try infos().enumerated().map { index, info in
            ConsoleAgent(
                hostID: host.id, hostName: host.displayName,
                agent: Agent(.fixture(paneID: "p\(index)", status: .idle, workspaceID: info.workspaceID)),
                workspaceLabel: info.label,
                repositoryCheckout: info.worktree.map(RepositoryCheckout.init))
        }
    }

    private func wsIDs(_ items: [AgentRepoNesting.Item]) -> [String] {
        items.map {
            switch $0 {
            case .header(let name, _): "header:\(name)"
            case .agent(let a, _): a.agent.workspaceID
            }
        }
    }

    @Test func liveDecodeKeepsRepoKeyAndLinkedFlag() throws {
        let linked = try infos().filter { $0.worktree?.isLinkedWorktree == true }
        #expect(linked.count >= 12)
        let agents = try agents()
        // herdr reports no `worktree` object for some spaces (wJY, wK1, wK5);
        // every other space must keep its repo_key and linked flag through decode.
        let infoByID = Dictionary(uniqueKeysWithValues: try infos().map { ($0.workspaceID, $0) })
        var withCheckout = 0
        for agent in agents {
            let info = try #require(infoByID[agent.agent.workspaceID])
            #expect((agent.repositoryCheckout == nil) == (info.worktree == nil), "\(info.workspaceID)")
            if let checkout = agent.repositoryCheckout {
                withCheckout += 1
                #expect(checkout.repoKey == info.worktree?.repoKey)
                #expect(checkout.isLinkedWorktree == info.worktree?.isLinkedWorktree)
                #expect(!checkout.repoKey.isEmpty)
            }
        }
        #expect(withCheckout >= 15)
        let wM1 = try #require(agents.first { $0.agent.workspaceID == "wM1" })
        let wDW = try #require(agents.first { $0.agent.workspaceID == "wDW" })
        #expect(wM1.repositoryCheckout?.isLinkedWorktree == true)
        #expect(wDW.repositoryCheckout?.isLinkedWorktree == false)
        #expect(wM1.repositoryCheckout?.repoKey == wDW.repositoryCheckout?.repoKey)
        #expect(wM1.repositoryCheckout?.repoName == "repo-a")
    }

    @Test func worktreeRowsSitInsideTheirMainSpaceIndented() throws {
        let items = AgentRepoNesting.items(try agents())
        let ids = wsIDs(items)
        // repo-a's main wDW is followed by all its worktrees, indented.
        let dw = try #require(ids.firstIndex(of: "wDW"))
        let repoAWorktrees = ["wKR", "wKS", "wKT", "wKV", "wKW", "wKX", "wKY", "wKZ", "wK0", "wM1"]
        #expect(Array(ids[(dw + 1)...].prefix(repoAWorktrees.count)) == repoAWorktrees)
        for item in items {
            guard case .agent(let a, let nested) = item else { continue }
            #expect(nested == (a.repositoryCheckout?.isLinkedWorktree == true), "\(a.agent.workspaceID)")
        }
        // No repo header while the main space is open; every main is present here.
        #expect(!ids.contains { $0.hasPrefix("header:") })
        // repo-c and repo-d nest too.
        let jn = try #require(ids.firstIndex(of: "wJN"))
        #expect(Set(ids[(jn + 1)...].prefix(2)) == ["wJP", "wKH"])
        let jq = try #require(ids.firstIndex(of: "wJQ"))
        #expect(ids[jq + 1] == "wK6")
        // A plain space (no worktree object) is not nested.
        #expect(items.contains { if case .agent(let a, false) = $0 { a.agent.workspaceID == "wJY" } else { false } })
    }

    @Test func everyAgentAppearsOnce() throws {
        let all = try agents()
        let ordered = AgentRepoNesting.ordered(all)
        #expect(ordered.count == all.count)
        #expect(Set(ordered.map(\.id)) == Set(all.map(\.id)))
        // Idempotent: the list's own order survives a second pass.
        #expect(AgentRepoNesting.ordered(ordered).map(\.id) == ordered.map(\.id))
    }

    @Test func orphanWorktreesGetOneHeaderNotACard() throws {
        let withoutMain = try agents().filter { $0.agent.workspaceID != "wDW" }
        let items = AgentRepoNesting.items(withoutMain)
        let headers = items.filter { if case .header = $0 { true } else { false } }
        #expect(headers.count == 1)
        let ids = wsIDs(items)
        let h = try #require(ids.firstIndex(of: "header:repo-a"))
        #expect(ids[(h + 1)...].prefix(3) == ["wKR", "wKS", "wKT"])
    }

    @MainActor @Test func byHostSectionsUseTheNestedOrder() throws {
        let store = ConsoleListPresentationStore(defaults: UserDefaults(suiteName: "nest-\(UUID())")!)
        let sections = store.sections(hosts: [host], agents: try agents())
        let ids = sections.first?.agents.map(\.agent.workspaceID) ?? []
        let dw = try #require(ids.firstIndex(of: "wDW"))
        #expect(ids[dw + 1] == "wKR")
        #expect(ids[dw + 10] == "wM1")
    }
}
