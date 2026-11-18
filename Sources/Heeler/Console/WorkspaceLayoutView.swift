import SwiftUI

/// A herdr Tab drawn the way herdr draws it: its panes at herdr's split
/// geometry, one tile each. A tile shows the pane's Agent or shell, its
/// status and its last output; a tap opens that pane full screen through the
/// Console's usual Agent or Terminal detail. Follow Mac keeps the view on the
/// Workspace and Tab the Mac has focused.
struct WorkspaceLayoutView: View {
    let console: ConsoleStore
    let hosts: [Host]
    /// Opens one pane full screen; the caller dismisses this view.
    let onOpen: (ConsoleTerminal) -> Void
    let onClose: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage("workspace-layout.follow-mac") private var followsMac = true
    @State private var hostID: Host.ID?
    @State private var pickedWorkspaceID: String?
    @State private var pickedTabID: String?
    /// Main spaces whose worktrees are folded away, as on the Mac.
    @AppStorage("workspace-layout.collapsed") private var collapsedStorage = ""
    private var collapsed: Set<String> {
        Set(collapsedStorage.split(separator: ",").map(String.init))
    }

    private var activeHost: Host? {
        hosts.first { $0.id == hostID } ?? hosts.first
    }

    private var state: HostLayoutState {
        activeHost.flatMap { console.layoutsByHost[$0.id] } ?? HostLayoutState()
    }

    private var selection: WorkspaceLayoutSelection {
        WorkspaceLayoutSelection(
            workspaceID: pickedWorkspaceID, tabID: pickedTabID, follows: followsMac)
    }

    private var resolved: (workspaceID: String, tabID: String)? {
        selection.resolved(in: state)
    }

    private var workspaces: [ConsoleWorkspace] {
        guard let host = activeHost else { return [] }
        let ids = Set(state.layouts.map(\.workspaceID))
        return console.workspaces(for: host.id)
            .filter { ids.contains($0.id) }
            .sorted { $0.order < $1.order }
    }

    var body: some View {
        NavigationStack {
            Group {
                if horizontalSizeClass == .regular {
                    HStack(spacing: 0) {
                        sidebar.frame(width: 260)
                        Divider()
                        VStack(spacing: 0) {
                            tabStrip
                            Divider()
                            canvas
                        }
                    }
                } else {
                    VStack(spacing: 0) {
                        pickers
                        Divider()
                        canvas
                    }
                }
            }
            .navigationTitle("Workspace")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done", action: onClose)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Toggle(isOn: $followsMac) {
                        Label("Follow Mac", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .toggleStyle(.button)
                    .accessibilityIdentifier("workspace-layout.follow-mac")
                }
            }
        }
    }

    @ViewBuilder
    private var pickers: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if hosts.count > 1 {
                    Menu {
                        Picker("Host", selection: $hostID) {
                            ForEach(hosts) { @Sendable host in
                                Text(host.displayName).tag(Host.ID?.some(host.id))
                            }
                        }
                    } label: {
                        Label(activeHost?.displayName ?? "Host", systemImage: "server.rack")
                    }
                    .buttonStyle(.bordered)
                }
                ForEach(WorkspaceTree.rows(workspaces, collapsed: collapsed), id: \.id) { row in
                    treeRow(row, indented: false)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
        }
        tabStrip
    }

    @ViewBuilder
    private var tabStrip: some View {
        if let current = resolved, state.tabIDs(inWorkspace: current.workspaceID).count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(
                        Array(state.tabIDs(inWorkspace: current.workspaceID).enumerated()),
                        id: \.element
                    ) { index, tabID in
                        chip("Tab \(index + 1)", isSelected: tabID == current.tabID) {
                            followsMac = false
                            pickedWorkspaceID = current.workspaceID
                            pickedTabID = tabID
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 8)
            }
        }
    }

    /// Workspace names as herdr's sidebar nests them: worktree spaces one
    /// level under their repository, folding with their repository.
    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                if hosts.count > 1 {
                    Menu {
                        Picker("Host", selection: $hostID) {
                            ForEach(hosts) { @Sendable host in
                                Text(host.displayName).tag(Host.ID?.some(host.id))
                            }
                        }
                    } label: {
                        Label(activeHost?.displayName ?? "Host", systemImage: "server.rack")
                    }
                    .buttonStyle(.bordered)
                }
                ForEach(WorkspaceTree.rows(workspaces, collapsed: collapsed), id: \.id) { row in
                    treeRow(row, indented: true)
                }
            }
            .padding(12)
        }
    }

    private func treeRow(_ row: WorkspaceTree.Row, indented: Bool) -> some View {
        HStack(spacing: 4) {
            if row.depth > 0 {
                if indented {
                    Color.clear.frame(width: 20)
                } else {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.caption2).foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
            if let workspace = row.workspace {
                chip(
                    workspace.label,
                    systemImage: row.isWorktree ? "arrow.triangle.branch" : nil,
                    isSelected: workspace.id == resolved?.workspaceID
                ) {
                    followsMac = false
                    pickedWorkspaceID = workspace.id
                    pickedTabID = state.tabIDs(inWorkspace: workspace.id).first
                }
            } else {
                Label(row.title, systemImage: "book.closed")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            if indented { Spacer(minLength: 0) }
            if row.isGroupHead {
                Button {
                    toggleFold(row.id)
                } label: {
                    Image(systemName: row.isCollapsed ? "chevron.right" : "chevron.down")
                    Text("\(row.childCount)").font(.caption2)
                }
                .buttonStyle(.plain).foregroundStyle(.secondary)
                .accessibilityLabel(row.isCollapsed ? "Expand worktrees" : "Fold worktrees")
            }
        }
    }

    private func toggleFold(_ id: String) {
        var next = collapsed
        if !next.insert(id).inserted { next.remove(id) }
        collapsedStorage = next.sorted().joined(separator: ",")
    }

    private func chip(
        _ title: String, systemImage: String? = nil, isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            if let systemImage {
                Label(title, systemImage: systemImage).lineLimit(1)
            } else {
                Text(title).lineLimit(1)
            }
        }
        .buttonStyle(.bordered)
        .tint(isSelected ? .accentColor : .secondary)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var canvas: some View {
        if let host = activeHost, let current = resolved,
            let layout = state.layout(forTab: current.tabID)
        {
            GeometryReader { proxy in
                ZStack(alignment: .topLeading) {
                    ForEach(layout.frames, id: \.paneID) { frame in
                        let rect = WorkspaceTabLayout.scaled(
                            frame.rect, to: proxy.size, gap: 3)
                        PaneTile(
                            terminal: terminal(host.id, frame.paneID),
                            agent: console.agents.first {
                                $0.id == ConsoleAgent.ID(hostID: host.id, paneID: frame.paneID)
                            },
                            paneID: frame.paneID,
                            isFocused: frame.isFocused
                        ) {
                            if let terminal = terminal(host.id, frame.paneID) {
                                onOpen(terminal)
                            }
                        }
                        .frame(width: max(rect.width, 0), height: max(rect.height, 0))
                        .offset(x: rect.minX, y: rect.minY)
                    }
                }
            }
            .padding(6)
            .accessibilityIdentifier("workspace-layout.canvas")
        } else {
            ContentUnavailableView(
                "No layout yet", systemImage: "rectangle.split.3x1",
                description: Text("Connect a Host running herdr 0.9 or newer."))
        }
    }

    private func terminal(_ hostID: Host.ID, _ paneID: String) -> ConsoleTerminal? {
        console.terminals.first { $0.hostID == hostID && $0.paneID == paneID }
    }
}

/// One pane of the layout: a header with the pane's identity and status over
/// its last output. A focused pane (the Mac's) carries an accent border.
private struct PaneTile: View {
    let terminal: ConsoleTerminal?
    let agent: ConsoleAgent?
    let paneID: String
    let isFocused: Bool
    let action: () -> Void

    private var title: String {
        agent?.agent.displayName ?? terminal?.displayTitle ?? paneID
    }

    private var status: AgentStatus { agent?.agent.status ?? .unknown }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle().fill(Color(uiColor: status.inkUIColor)).frame(width: 8, height: 8)
                    Text(title).font(.caption.weight(.semibold)).lineLimit(1)
                    Spacer(minLength: 0)
                }
                if let subtitle = terminal?.displayTitle, subtitle != title {
                    Text(subtitle).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
                Text(agent?.lastOutputSnippet ?? "")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(6)
                Spacer(minLength: 0)
            }
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(uiColor: .secondarySystemBackground), in: .rect(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isFocused ? Color.accentColor : Color.secondary.opacity(0.25),
                        lineWidth: isFocused ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(terminal == nil)
        .accessibilityLabel("\(title), pane \(paneID)")
        .accessibilityHint("Opens this pane full screen")
    }
}
