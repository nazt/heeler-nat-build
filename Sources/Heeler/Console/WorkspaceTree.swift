import Foundation

/// herdr's sidebar tree of spaces: each linked worktree nests under its
/// repository's main space. Grouping is by the space's `worktree.repo_key`,
/// never by a pane's cwd; a space without a `worktree` object stands alone.
/// Order is herdr's own: a main space keeps its place, and its worktrees
/// follow it in the order herdr lists them. A worktree whose repository has
/// no main space in the list stays top-level, where herdr listed it.
enum WorkspaceTree {
    struct Row: Equatable, Sendable {
        /// The space this row is; nil for a repository header made for
        /// worktrees whose main space is not open.
        let workspace: ConsoleWorkspace?
        /// Stable row identity, also the fold key: the space's id, or
        /// `repo:<repo_key>` for a made header.
        let id: String
        let title: String
        /// 0 for a plain space, a main checkout or a header; 1 for a worktree
        /// space under its repository.
        let depth: Int
        /// A row with worktrees under it: the row that folds.
        let childCount: Int
        let isCollapsed: Bool
        /// A linked-worktree space, which the view marks with a branch icon.
        let isWorktree: Bool

        var isGroupHead: Bool { childCount > 0 }
        var isHeaderOnly: Bool { workspace == nil }
    }

    /// The rows to show for `workspaces` (any order; sorted by herdr's
    /// `order` here), with the groups in `collapsed` folded.
    static func rows(
        _ workspaces: [ConsoleWorkspace], collapsed: Set<String> = []
    ) -> [Row] {
        let ordered = workspaces.sorted { $0.order < $1.order }
        func isMain(_ w: ConsoleWorkspace) -> Bool { w.checkout?.isLinkedWorktree == false }
        func isLinked(_ w: ConsoleWorkspace) -> Bool { w.checkout?.isLinkedWorktree == true }
        var mainByRepo: [String: String] = [:]
        for w in ordered where isMain(w) {
            if let key = w.checkout?.repoKey, mainByRepo[key] == nil { mainByRepo[key] = w.id }
        }
        // Linked worktrees by repository, in herdr's order.
        var linkedByRepo: [String: [ConsoleWorkspace]] = [:]
        for w in ordered where isLinked(w) {
            if let key = w.checkout?.repoKey { linkedByRepo[key, default: []].append(w) }
        }
        func row(_ w: ConsoleWorkspace, depth: Int, kids: Int, folded: Bool) -> Row {
            Row(
                workspace: w, id: w.id, title: w.label, depth: depth, childCount: kids,
                isCollapsed: folded, isWorktree: isLinked(w))
        }
        var out: [Row] = []
        var madeHeaders: Set<String> = []
        for w in ordered {
            if isLinked(w), let key = w.checkout?.repoKey {
                if mainByRepo[key] != nil { continue }  // placed under its main
                // No main space open: one header where the first worktree is,
                // the repository's worktrees indented under it.
                guard madeHeaders.insert(key).inserted else { continue }
                let kids = linkedByRepo[key] ?? []
                let id = "repo:\(key)"
                let folded = collapsed.contains(id)
                out.append(
                    Row(
                        workspace: nil, id: id, title: w.checkout?.repoName ?? key, depth: 0,
                        childCount: kids.count, isCollapsed: folded, isWorktree: false))
                if !folded { out += kids.map { row($0, depth: 1, kids: 0, folded: false) } }
                continue
            }
            let kids = isMain(w) ? ((w.checkout?.repoKey).flatMap { linkedByRepo[$0] } ?? []) : []
            let folded = collapsed.contains(w.id) && !kids.isEmpty
            out.append(row(w, depth: 0, kids: kids.count, folded: folded))
            if !folded { out += kids.map { row($0, depth: 1, kids: 0, folded: false) } }
        }
        return out
    }

    /// The main space whose fold hides `workspaceID`, so a selection inside a
    /// folded group can be shown or unfolded.
    static func parentID(of workspaceID: String, in workspaces: [ConsoleWorkspace]) -> String? {
        guard let w = workspaces.first(where: { $0.id == workspaceID }),
            let checkout = w.checkout, checkout.isLinkedWorktree
        else { return nil }
        return workspaces.sorted { $0.order < $1.order }
            .first { $0.checkout?.repoKey == checkout.repoKey && $0.checkout?.isLinkedWorktree == false }?.id
    }
}
