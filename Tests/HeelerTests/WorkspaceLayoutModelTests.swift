import CoreGraphics
import Foundation
import Testing

@testable import Heeler

@Suite("Workspace layout model")
struct WorkspaceLayoutModelTests {
    private func rect(_ x: Int, _ y: Int, _ w: Int, _ h: Int) -> PaneLayoutRect {
        PaneLayoutRect(height: h, width: w, x: x, y: y)
    }

    /// Left pane, right column split top/bottom 0.6: the common 3-pane tab.
    private func threePane(zoomed: Bool = false) -> PaneLayoutSnapshot {
        PaneLayoutSnapshot(
            area: rect(0, 0, 100, 50), focusedPaneID: "w1:p2",
            panes: [
                PaneLayoutPane(focused: false, paneID: "w1:p1", rect: rect(0, 0, 50, 50)),
                PaneLayoutPane(focused: true, paneID: "w1:p2", rect: rect(50, 0, 50, 30)),
                PaneLayoutPane(focused: false, paneID: "w1:p3", rect: rect(50, 30, 50, 20)),
            ],
            splits: [
                PaneLayoutSplit(direction: .right, id: "s0", ratio: 0.5, rect: rect(0, 0, 100, 50)),
                PaneLayoutSplit(direction: .down, id: "s1", ratio: 0.6, rect: rect(50, 0, 50, 50)),
            ],
            tabID: "w1:t1", workspaceID: "w1", zoomed: zoomed)
    }

    @Test func parsesFramesInReadingOrderAsUnitRects() throws {
        let layout = try #require(WorkspaceTabLayout(threePane()))
        #expect(layout.frames.map(\.paneID) == ["w1:p1", "w1:p2", "w1:p3"])
        #expect(layout.frames[0].rect == CGRect(x: 0, y: 0, width: 0.5, height: 1))
        #expect(layout.frames[1].rect == CGRect(x: 0.5, y: 0, width: 0.5, height: 0.6))
        #expect(layout.frames[2].rect == CGRect(x: 0.5, y: 0.6, width: 0.5, height: 0.4))
        #expect(layout.frames.map(\.isFocused) == [false, true, false])
        #expect(layout.focusedPaneID == "w1:p2")
    }

    @Test func buildsTreeFromSplits() throws {
        let layout = try #require(WorkspaceTabLayout(threePane()))
        let expected = WorkspaceTabLayout.Node.split(
            direction: .right, ratio: 0.5,
            first: .pane(id: "w1:p1"),
            second: .split(
                direction: .down, ratio: 0.6, first: .pane(id: "w1:p2"), second: .pane(id: "w1:p3")))
        #expect(layout.root == expected)
        #expect(layout.root?.paneIDs == ["w1:p1", "w1:p2", "w1:p3"])
    }

    @Test func treeFramesAgreeWithReportedFrames() throws {
        let layout = try #require(WorkspaceTabLayout(threePane()))
        let fromTree = layout.treeFrames()
        #expect(fromTree.map(\.paneID) == layout.frames.map(\.paneID))
        for (a, b) in zip(fromTree, layout.frames) {
            #expect(abs(a.rect.minX - b.rect.minX) < 0.001)
            #expect(abs(a.rect.minY - b.rect.minY) < 0.001)
            #expect(abs(a.rect.width - b.rect.width) < 0.001)
            #expect(abs(a.rect.height - b.rect.height) < 0.001)
        }
    }

    @Test func singlePaneIsOneFullFrame() throws {
        let snapshot = PaneLayoutSnapshot(
            area: rect(0, 0, 80, 24), focusedPaneID: "w1:p1",
            panes: [PaneLayoutPane(focused: true, paneID: "w1:p1", rect: rect(0, 0, 80, 24))],
            splits: [], tabID: "w1:t1", workspaceID: "w1", zoomed: false)
        let layout = try #require(WorkspaceTabLayout(snapshot))
        #expect(layout.root == .pane(id: "w1:p1"))
        #expect(layout.frames.map(\.rect) == [CGRect(x: 0, y: 0, width: 1, height: 1)])
    }

    @Test func emptyOrZeroAreaReplyHasNoLayout() {
        let empty = PaneLayoutSnapshot(
            area: rect(0, 0, 80, 24), focusedPaneID: "", panes: [], splits: [],
            tabID: "t", workspaceID: "w", zoomed: false)
        #expect(WorkspaceTabLayout(empty) == nil)
        let flat = PaneLayoutSnapshot(
            area: rect(0, 0, 0, 0), focusedPaneID: "p",
            panes: [PaneLayoutPane(focused: true, paneID: "p", rect: rect(0, 0, 0, 0))],
            splits: [], tabID: "t", workspaceID: "w", zoomed: false)
        #expect(WorkspaceTabLayout(flat) == nil)
    }

    @Test func inconsistentSplitsKeepFramesButDropTree() throws {
        var snapshot = threePane()
        snapshot = PaneLayoutSnapshot(
            area: snapshot.area, focusedPaneID: snapshot.focusedPaneID, panes: snapshot.panes,
            splits: [], tabID: snapshot.tabID, workspaceID: snapshot.workspaceID, zoomed: false)
        let layout = try #require(WorkspaceTabLayout(snapshot))
        #expect(layout.root == nil)
        #expect(layout.frames.count == 3)
    }

    @Test func scalesFramesToContainerWithGap() {
        let unit = CGRect(x: 0.5, y: 0, width: 0.5, height: 0.6)
        let scaled = WorkspaceTabLayout.scaled(unit, to: CGSize(width: 1000, height: 500), gap: 4)
        #expect(scaled == CGRect(x: 504, y: 4, width: 492, height: 292))
    }

    @Test func decodesHerdrsRealReply() throws {
        // Shape captured from herdr 0.9.5 `pane layout` (geometry only).
        let json = """
            {"area":{"height":45,"width":162,"x":0,"y":0},"focused_pane_id":"wDW:p1",
             "panes":[{"focused":true,"pane_id":"wDW:p1","rect":{"height":41,"width":162,"x":0,"y":0}},
                      {"focused":false,"pane_id":"wDW:p3E","rect":{"height":4,"width":162,"x":0,"y":41}}],
             "splits":[{"direction":"down","id":"split_0_root","ratio":0.9,"rect":{"height":45,"width":162,"x":0,"y":0}}],
             "tab_id":"wDW:t1","workspace_id":"wDW","zoomed":false}
            """
        let snapshot = try JSONDecoder().decode(PaneLayoutSnapshot.self, from: Data(json.utf8))
        let layout = try #require(WorkspaceTabLayout(snapshot))
        #expect(layout.root == .split(
            direction: .down, ratio: 0.9, first: .pane(id: "wDW:p1"), second: .pane(id: "wDW:p3E")))
        #expect(layout.treeFrames().map(\.paneID) == ["wDW:p1", "wDW:p3E"])
    }

    @Test func selectionFollowsMacFocusAndFallsBack() throws {
        var state = HostLayoutState()
        let a = try #require(WorkspaceTabLayout(threePane()))
        let other = PaneLayoutSnapshot(
            area: rect(0, 0, 80, 24), focusedPaneID: "w2:p1",
            panes: [PaneLayoutPane(focused: true, paneID: "w2:p1", rect: rect(0, 0, 80, 24))],
            splits: [], tabID: "w2:t1", workspaceID: "w2", zoomed: false)
        let b = try #require(WorkspaceTabLayout(other))
        state.layouts = [a, b]
        state.focusedWorkspaceID = "w2"
        state.focusedTabID = "w2:t1"

        let following = WorkspaceLayoutSelection(workspaceID: "w1", tabID: "w1:t1", follows: true)
        #expect(following.resolved(in: state)?.tabID == "w2:t1")
        let manual = WorkspaceLayoutSelection(workspaceID: "w1", tabID: "w1:t1", follows: false)
        #expect(manual.resolved(in: state)?.tabID == "w1:t1")
        let gone = WorkspaceLayoutSelection(workspaceID: "w9", tabID: "w9:t1", follows: false)
        #expect(gone.resolved(in: state)?.tabID == "w2:t1")
        #expect(WorkspaceLayoutSelection(workspaceID: nil, tabID: nil, follows: false)
            .resolved(in: HostLayoutState()) == nil)
    }
}
