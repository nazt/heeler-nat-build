import Foundation
import Testing

@testable import Heeler

@Suite("Workspace tree (herdr sidebar nesting)")
struct WorkspaceTreeTests {
    /// A trimmed real `herdr workspace list` reply (herdr 0.9.5): two
    /// repositories whose worktrees are listed far from their main space, one
    /// repository with a worktree only, and spaces with no `worktree` object.
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
  "active_tab_id": "wM1:t1",
  "agent_status": "working",
  "focused": false,
  "label": "wt-5-repo-a",
  "number": 20,
  "pane_count": 2,
  "tab_count": 1,
  "workspace_id": "wM1",
  "worktree": {
   "checkout_path": "/src/repo-a-worktrees/wt-5",
   "is_linked_worktree": true,
   "repo_key": "/src/repo-a/.git",
   "repo_name": "repo-a",
   "repo_root": "/src/repo-a"
  }
 }
]
"""

    private func workspaces() throws -> [ConsoleWorkspace] {
        let infos = try JSONDecoder().decode([WorkspaceInfo].self, from: Data(Self.reply.utf8))
        return infos.enumerated().map { order, info in
            ConsoleWorkspace(
                id: info.workspaceID, label: info.label, order: order,
                checkoutPath: info.worktree?.checkoutPath,
                checkout: info.worktree.map(RepositoryCheckout.init))
        }
    }

    private func ids(_ rows: [WorkspaceTree.Row]) -> [String] { rows.map(\.id) }

    @Test func nestsWorktreesUnderTheirMainSpaceInHerdrOrder() throws {
        let rows = WorkspaceTree.rows(try workspaces())
        // wJP and wKH are repo-c worktrees listed after other repos;
        // wKR and wM1 are repo-a worktrees. wK6 is repo-d's.
        #expect(ids(rows) == [
            "wDW", "wKR", "wM1",      // repo-a + its worktrees
            "wJE",                    // plain repo, no worktrees
            "wJN", "wJP", "wKH",      // repo-c + its worktrees
            "wJQ", "wK6",             // repo-d + its worktree
            "wJY",                    // no worktree object: stands alone
        ])
        #expect(rows.map(\.depth) == [0, 1, 1, 0, 0, 1, 1, 0, 1, 0])
        #expect(rows.first { $0.id == "wDW" }?.childCount == 2)
        #expect(rows.first { $0.id == "wJE" }?.isGroupHead == false)
    }

    @Test func foldingAMainHidesItsWorktreesOnly() throws {
        let rows = WorkspaceTree.rows(try workspaces(), collapsed: ["wDW", "wJE"])
        #expect(ids(rows) == ["wDW", "wJE", "wJN", "wJP", "wKH", "wJQ", "wK6", "wJY"])
        #expect(rows.first?.isCollapsed == true)
        // Folding a space with no worktrees changes nothing.
        #expect(rows.first { $0.id == "wJE" }?.isCollapsed == false)
    }

    @Test func plainSpacesAndMainsSitAtTheEdgeWorktreesIndented() throws {
        let rows = WorkspaceTree.rows(try workspaces())
        for row in rows {
            let linked = row.workspace?.checkout?.isLinkedWorktree == true
            #expect(row.depth == (linked ? 1 : 0), "\(row.id)")
            #expect(row.isWorktree == linked)
        }
        #expect(rows.first { $0.id == "wJY" }?.depth == 0)  // plain space
    }

    @Test func worktreeWhoseMainIsNotOpenShowsUnderIndentedRepoHeader() throws {
        let all = try workspaces().filter { $0.id != "wDW" }
        let rows = WorkspaceTree.rows(all)
        // repo-a's main is gone: a header stands where its first worktree was.
        let header = try #require(rows.first { $0.isHeaderOnly })
        #expect(header.title == "repo-a")
        #expect(header.id.hasPrefix("repo:"))
        #expect(header.depth == 0)
        #expect(header.childCount == 2)
        #expect(ids(rows) == [
            "wJE", "wJN", "wJP", "wKH", "wJQ", "wK6", "wJY", header.id, "wKR", "wM1",
        ])
        let under = rows.drop { $0.id != header.id }.dropFirst().prefix(2)
        #expect(under.map(\.id) == ["wKR", "wM1"])
        #expect(under.map(\.depth) == [1, 1])
    }

    @Test func foldingAMadeHeaderHidesItsWorktrees() throws {
        let all = try workspaces().filter { $0.id != "wDW" }
        let header = try #require(WorkspaceTree.rows(all).first { $0.isHeaderOnly })
        let folded = WorkspaceTree.rows(all, collapsed: [header.id])
        #expect(!ids(folded).contains("wKR"))
        #expect(folded.first { $0.id == header.id }?.isCollapsed == true)
    }

    @Test func groupsByRepoKeyNotByLabelOrPath() throws {
        let all = try workspaces()
        let wM1 = try #require(all.first { $0.id == "wM1" })
        #expect(wM1.checkout?.repoKey == all.first { $0.id == "wDW" }?.checkout?.repoKey)
        #expect(WorkspaceTree.parentID(of: "wM1", in: all) == "wDW")
        #expect(WorkspaceTree.parentID(of: "wDW", in: all) == nil)
        #expect(WorkspaceTree.parentID(of: "wJY", in: all) == nil)
    }

    @Test func emptyInputIsEmpty() {
        #expect(WorkspaceTree.rows([]).isEmpty)
    }
}
