import CoreGraphics
import Foundation

/// A herdr Tab's pane arrangement, parsed from the `PaneLayoutSnapshot` that
/// `session.snapshot` and `pane.layout` return. herdr reports each pane's
/// rectangle in terminal cells and each split's direction and ratio; this
/// model turns them into a split tree and into unit frames a view scales.
struct WorkspaceTabLayout: Equatable, Sendable {
    /// The split tree: a pane, or two children divided by a ratio.
    indirect enum Node: Equatable, Sendable {
        case pane(id: String)
        case split(direction: SplitDirection, ratio: Double, first: Node, second: Node)

        var paneIDs: [String] {
            switch self {
            case .pane(let id): [id]
            case .split(_, _, let first, let second): first.paneIDs + second.paneIDs
            }
        }
    }

    /// One placed pane, in unit coordinates (0...1 of the tab's area).
    struct Frame: Equatable, Sendable {
        let paneID: String
        let rect: CGRect
        let isFocused: Bool
    }

    let workspaceID: String
    let tabID: String
    let focusedPaneID: String
    let isZoomed: Bool
    let root: Node?
    /// Pane frames in reading order: top to bottom, then left to right.
    let frames: [Frame]
    /// The tab's size in cells, which the unit frames are relative to.
    let cellSize: CGSize

    /// Parses herdr's reply. Frames come from the reported pane rectangles
    /// (herdr's own answer); the tree comes from the splits. A reply without
    /// a usable area, or without panes, yields no layout.
    init?(_ snapshot: PaneLayoutSnapshot) {
        let area = snapshot.area
        guard area.width > 0, area.height > 0, !snapshot.panes.isEmpty else { return nil }
        let width = CGFloat(area.width)
        let height = CGFloat(area.height)
        workspaceID = snapshot.workspaceID
        tabID = snapshot.tabID
        focusedPaneID = snapshot.focusedPaneID
        isZoomed = snapshot.zoomed
        cellSize = CGSize(width: width, height: height)
        frames = snapshot.panes
            .map { pane in
                Frame(
                    paneID: pane.paneID,
                    rect: CGRect(
                        x: (CGFloat(pane.rect.x) - CGFloat(area.x)) / width,
                        y: (CGFloat(pane.rect.y) - CGFloat(area.y)) / height,
                        width: CGFloat(pane.rect.width) / width,
                        height: CGFloat(pane.rect.height) / height),
                    isFocused: pane.paneID == snapshot.focusedPaneID)
            }
            .sorted {
                if $0.rect.minY != $1.rect.minY { return $0.rect.minY < $1.rect.minY }
                return $0.rect.minX < $1.rect.minX
            }
        root = Self.tree(snapshot)
    }

    /// Rebuilds the tree from rectangles: the largest split spans the area,
    /// and each remaining split or pane belongs to the side of its parent
    /// whose region contains it. Nil when the splits do not describe the
    /// panes (a stale or partial reply); frames still work then.
    private static func tree(_ snapshot: PaneLayoutSnapshot) -> Node? {
        if snapshot.panes.count == 1 { return .pane(id: snapshot.panes[0].paneID) }
        let panes = snapshot.panes.map { (id: $0.paneID, rect: $0.rect) }
        func build(_ splits: [PaneLayoutSplit], in rect: PaneLayoutRect) -> Node? {
            guard let split = splits.first(where: { $0.rect == rect }) else {
                let inside = panes.filter { contains(rect, $0.rect) }
                return inside.count == 1 ? .pane(id: inside[0].id) : nil
            }
            let rest = splits.filter { $0.id != split.id }
            guard let (first, second) = halves(of: split) else { return nil }
            guard let a = build(rest, in: first), let b = build(rest, in: second) else { return nil }
            return .split(direction: split.direction, ratio: split.ratio, first: a, second: b)
        }
        let rootRect = snapshot.splits.max {
            $0.rect.width * $0.rect.height < $1.rect.width * $1.rect.height
        }?.rect
        guard let rootRect else { return nil }
        guard let node = build(snapshot.splits, in: rootRect),
            Set(node.paneIDs) == Set(panes.map(\.id))
        else { return nil }
        return node
    }

    /// A split's two regions. herdr gives the split's rectangle and ratio,
    /// not the children's; the first child takes `ratio` of the extent.
    private static func halves(of split: PaneLayoutSplit) -> (PaneLayoutRect, PaneLayoutRect)? {
        let r = split.rect
        switch split.direction {
        case .right:
            let firstWidth = Int((Double(r.width) * split.ratio).rounded())
            return regions(r, firstWidth: firstWidth, firstHeight: nil)
        case .down:
            let firstHeight = Int((Double(r.height) * split.ratio).rounded())
            return regions(r, firstWidth: nil, firstHeight: firstHeight)
        default:
            // A direction this build does not know cannot be divided.
            return nil
        }
    }

    private static func regions(
        _ r: PaneLayoutRect, firstWidth: Int?, firstHeight: Int?
    ) -> (PaneLayoutRect, PaneLayoutRect)? {
        if let w = firstWidth {
            guard w > 0, w < r.width else { return nil }
            return (
                PaneLayoutRect(height: r.height, width: w, x: r.x, y: r.y),
                PaneLayoutRect(height: r.height, width: r.width - w, x: r.x + w, y: r.y)
            )
        }
        if let h = firstHeight {
            guard h > 0, h < r.height else { return nil }
            return (
                PaneLayoutRect(height: h, width: r.width, x: r.x, y: r.y),
                PaneLayoutRect(height: r.height - h, width: r.width, x: r.x, y: r.y + h)
            )
        }
        return nil
    }

    private static func contains(_ outer: PaneLayoutRect, _ inner: PaneLayoutRect) -> Bool {
        inner.x >= outer.x && inner.y >= outer.y
            && inner.x + inner.width <= outer.x + outer.width
            && inner.y + inner.height <= outer.y + outer.height
    }

    /// Frames laid out from the tree alone, in unit coordinates: what the
    /// view falls back to when it only knows ratios. Matches `frames` up to
    /// the one-cell rounding herdr applies at each split.
    func treeFrames() -> [Frame] {
        guard let root else { return [] }
        var out: [Frame] = []
        Self.place(root, in: CGRect(x: 0, y: 0, width: 1, height: 1), focused: focusedPaneID, into: &out)
        return out
    }

    private static func place(
        _ node: Node, in rect: CGRect, focused: String, into out: inout [Frame]
    ) {
        switch node {
        case .pane(let id):
            out.append(Frame(paneID: id, rect: rect, isFocused: id == focused))
        case .split(let direction, let ratio, let first, let second):
            let r = CGFloat(min(max(ratio, 0), 1))
            switch direction {
            case .down:
                place(first, in: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height * r), focused: focused, into: &out)
                place(second, in: CGRect(x: rect.minX, y: rect.minY + rect.height * r, width: rect.width, height: rect.height * (1 - r)), focused: focused, into: &out)
            default:
                place(first, in: CGRect(x: rect.minX, y: rect.minY, width: rect.width * r, height: rect.height), focused: focused, into: &out)
                place(second, in: CGRect(x: rect.minX + rect.width * r, y: rect.minY, width: rect.width * (1 - r), height: rect.height), focused: focused, into: &out)
            }
        }
    }

    /// A unit frame scaled to a container and inset by `gap` on every side,
    /// so neighbouring panes keep `2 * gap` between them.
    static func scaled(_ unit: CGRect, to size: CGSize, gap: CGFloat = 0) -> CGRect {
        CGRect(
            x: unit.minX * size.width, y: unit.minY * size.height,
            width: unit.width * size.width, height: unit.height * size.height
        ).insetBy(dx: gap, dy: gap)
    }
}

/// What one Host's snapshot says about the Mac's focus and every Tab's
/// layout: the input to the Workspace view and its follow-the-Mac mode.
struct HostLayoutState: Equatable, Sendable {
    var layouts: [WorkspaceTabLayout] = []
    var focusedWorkspaceID: String?
    var focusedTabID: String?
    var focusedPaneID: String?

    init() {}

    init(_ snapshot: SessionSnapshot) {
        layouts = snapshot.layouts.compactMap(WorkspaceTabLayout.init)
        focusedWorkspaceID = snapshot.focusedWorkspaceID
        focusedTabID = snapshot.focusedTabID
        focusedPaneID = snapshot.focusedPaneID
    }

    func layout(forTab tabID: String) -> WorkspaceTabLayout? {
        layouts.first { $0.tabID == tabID }
    }

    func tabIDs(inWorkspace workspaceID: String) -> [String] {
        layouts.filter { $0.workspaceID == workspaceID }.map(\.tabID)
    }
}

/// Which Workspace and Tab the layout view shows. Follow mode tracks what
/// the Mac has focused; picking by hand turns it off.
struct WorkspaceLayoutSelection: Equatable, Sendable {
    var workspaceID: String?
    var tabID: String?
    var follows: Bool

    /// The selection for `state`: followed focus when following, else the
    /// pick when it still exists, else the Mac's focus, else the first Tab.
    func resolved(in state: HostLayoutState) -> (workspaceID: String, tabID: String)? {
        if follows, let w = state.focusedWorkspaceID, let t = state.focusedTabID,
            state.layout(forTab: t)?.workspaceID == w
        {
            return (w, t)
        }
        if let t = tabID, let layout = state.layout(forTab: t) {
            return (layout.workspaceID, t)
        }
        if let w = workspaceID, let t = state.tabIDs(inWorkspace: w).first {
            return (w, t)
        }
        if let t = state.focusedTabID, let layout = state.layout(forTab: t) {
            return (layout.workspaceID, t)
        }
        return state.layouts.first.map { ($0.workspaceID, $0.tabID) }
    }
}
