# Oracle build of Heeler

A fork of [ZingerLittleBee/Heeler](https://github.com/ZingerLittleBee/Heeler) (Apache-2.0; see `LICENSE`).
Everything specific to running it as an oracle fleet client lives in this folder; the app changes
are ordinary source under `Sources/`.

## Workspace layout view

Local build of Heeler that shows a herdr Tab the way the Mac does: the panes at
herdr's own split geometry, one tile per pane. Not for upstream; local branch only.

## What it does

- **Workspace Layout** button in the Agents / Terminals toolbar (square-split icon)
  opens a full-screen view: pick Workspace (and Tab), see the panes laid out.
- Each tile shows the pane's Agent or shell, status dot, and last output.
  Tap a tile to open that pane full screen in the existing Agent / Terminal detail.
- **Follow Mac** (toggle, on by default): the view follows the Workspace and Tab the
  Mac has focused. Picking a Workspace or Tab by hand turns it off.
- Data: `session.snapshot` already carries `layouts` (per-pane cell rectangles and
  splits with direction and ratio) and the focused workspace, tab and pane ids (herdr 0.9.5).
  The Console now also resyncs on `workspace.focused`, `tab.focused`, `pane.focused`,
  `layout.updated`, so the view tracks the Mac within one snapshot round trip.

## Code

- `Sources/Heeler/Console/WorkspaceLayoutModel.swift`: layout parsing (rects to unit
  frames, split tree), follow-mode selection.
- `Sources/Heeler/Console/WorkspaceLayoutView.swift`: the view.
- `HostConsoleProjection.layoutState` / `ConsoleStore.layoutsByHost`: state plumbing.
- Tests: `Tests/HeelerTests/WorkspaceLayoutModelTests.swift`.

## Build and test

```
make test-app SIM_DESTINATION='platform=iOS Simulator,id=<iPad sim udid>' \
  TEST_SELECTOR='HeelerTests/WorkspaceLayoutModelTests'
```

Screenshot: `oracle/docs/layout-follow-mac.png` (demo data; launch arg `--demo-workspace-layout` opens the view).

Demo screenshots (iPad simulator, fake data, no network): build for the simulator and
launch with `--demo-screenshots`. The demo "iOS App" Workspace has a 3-pane Tab.

## Install on an iPad

```
oracle/install-ipad.sh <device-id>   # your signing team and bundle id
```

Needs the iPad unlocked, trusted and paired with this Mac. Not run by this branch.

## Still needs a real device

- Real herdr over SSH (host key trust, host entry): the simulator
  run used demo data.
- Follow Mac against a live focus change on the Mac.
- Tiles show the last output snippet, not a live terminal. Live terminals per tile
  (one SSH attach each) are the next step.
- Signing and the Apple PLA (no Push, App Groups or extensions until accepted).

## Oracle icons

Each Agent's avatar shows its oracle instead of the program mark; the program mark
(Claude, Codex, ...) stays as a small badge in the corner.

- **Fetch (on the Host that owns the tokens):** `oracle/scripts/oracle-icons.py` reads each `pass discord/<name>-token`,
  asks Discord `GET /users/@me` for the bot's avatar, downloads it once from the public CDN
  (64 px), and writes `~/.config/herdr/plugins/config/heeler/icons/<oracle>.png` plus
  `icons.json` (`{"v":1,"icons":{"<oracle>":"<base64 png>"}}`, about 0.5 MB). Tokens are never
  printed or logged. Options: `--only NAME ...`, `--dry-run`. Re-run to refresh avatars.
  First run on the Host (2026-11-18): 54 pictures, 11 bots without an avatar, 6 failed (revoked or
  invalid tokens).
- **Serve:** no plugin change. The app reads `icons.json` through the same SFTP reader as
  `sidebar.json` (`Transport.readOracleIcons`), once per connection.
- **Map agent to oracle** (`OracleIdentity`): agent name, then the working-directory folders
  (`<name>-oracle`, `<name>-soul`, `wt/<slug>-<oracle>-<date>`), then the workspace label,
  matched against the oracles that have icons (longest whole-word match wins; names under 3
  letters match only exactly).
- **Fallback:** emoji (`OracleIcon.emojis`, `studio-labs` = lantern) or the name's first letter on
  a colour derived from the name (stable FNV hue).
- **Tests:** `Tests/HeelerTests/OracleIdentityTests.swift`. Screenshot (demo data, drawn
  pictures): `oracle/docs/agents-oracle-icons.png`
  (launch args `--demo-screenshots --demo-show-sidebar`).
- **Needs a device:** an Agents list on the real iPad reading the Host's `icons.json` over SSH.

## Worktree nesting (as herdr's sidebar)

- Grouping is by the space's `worktree.repo_key` (never a pane's cwd); a space without a
  `worktree` object stands alone. Main checkouts and plain spaces sit at the left edge;
  linked-worktree spaces are indented one level under their repo's main space, with a branch
  mark, in herdr's own order. A worktree whose main space is not open shows under a header
  made for its repo (`repo_name`), indented.
- **Agents list:** the app now starts in "By Workspace" (was "All Agents") for a Console that
  never chose a presentation; a saved choice is kept (pick By Workspace once if it was flat).
  Cards fold with their chevron. `ConsoleListPresentationStore.workspaceSections` makes the
  header-only section for missing mains.
- **Layout picker:** a left column on iPad width (`WorkspaceTree`, shared model), a chip strip
  with a turn-arrow on compact width. Fold state persists.
- Tests: `WorkspaceTreeTests` (trimmed real `workspace list` reply from the Host: two repos with
  worktrees listed far from their main, a repo with worktrees only, plain spaces) and the
  updated `ConsoleListPresentationStoreTests`. Screenshots: `oracle/docs/agents-nested-worktrees.png`,
  `layout-picker-tree.png` (demo data).

## Nesting in By Host and All Agents (device fix)

On the iPad the Agents list was in By Host, where rows were flat. `AgentRepoNesting` now
orders each Host's rows so a repo's worktree Agents follow its main space's Agents, indented
22 pt with a branch mark; a repo header row appears only when the main space has no Agents
in the list. Grouping is by `worktree.repo_key` within one Host. The nested order also drives
keyboard navigation. Tests: `AgentRepoNestingTests` on the full real the Host `workspace list`
(decode keeps `repo_key` and `is_linked_worktree` for every space that has a `worktree`
object; wDW holds wKR..wM1; relic-extract and flood-cam nest; By Host sections use the
nested order). Screenshot: `oracle/docs/agents-by-host-nested.png` (demo data).

## App icon

The dog layer is replaced by a plain tabby cat face (🐱, not a Siamese) on the same blue fill:
`Sources/Heeler/AppIcon.icon/Assets/cat.png`, referenced from `icon.json`.
Preview: `oracle/docs/app-icon-cat.png` (simulator home screen crop).

## Sidebar stays open after a pick (iPad portrait)

Upstream hides a portrait sidebar (shown only on request) when an Agent is picked, so the
terminal keeps the full width. This build keeps it open: `selectionDidOpenDetail()` in
`ConsoleSplitPresentation.swift` is a no-op. Hide it with the sidebar button. Test:
`ConsoleSplitPresentationTests.portraitPickKeepsTheSidebarOpen`.

## Highlight of the open agent in the sidebar

The row whose terminal is open now has a clear blue wash (blue edge on plain rows) in By Host,
All Agents and By Workspace, also on iPad portrait where the sidebar shows over the detail
(it used to show only a faint gray band, or the system's square band). The nested-row indent
now lives inside the row label, because a row's background must sit on the row itself.
Screenshots (demo data): `oracle/docs/selected-row-by-host.png`, `selected-row-by-workspace.png`
(DEBUG launch arg `--demo-select-agent` opens an agent).

## Active row always marked and centered

The open agent's highlight is drawn at every width and column state (no gating), and the
sidebar list scrolls the active row to the vertical middle (`ScrollViewReader`,
`scrollToActiveRow` in `ConsoleView.swift`) when an agent is opened, the list mode changes,
or the list appears. A row at the very top or bottom of a short list cannot be centered.
Needs a device check with a long list (the demo list is too short to scroll).
