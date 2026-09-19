# NexusTAS

> Advanced TAS (Tool-Assisted Speedrun) toolkit for Roblox — frame-perfect movement,
> physics-tick stepping, and input replay.

**BETA v1.0** — read the [Status](#status) section before use.

---

## Table of Contents

- [What is NexusTAS](#what-is-nexustas)
- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Manual](#manual)
  - [Modes](#modes)
  - [Recording](#recording)
  - [Replay](#replay)
  - [Editing](#editing)
  - [Saving and Importing](#saving-and-importing)
  - [The HUD](#the-hud)
  - [Keybinds](#keybinds)
- [GUI Overview](#gui-overview)
- [Status](#status)
  - [Known Issues](#known-issues)
- [Reporting Bugs](#reporting-bugs)
- [Credits](#credits)
- [License](#license)

---

## What is NexusTAS

NexusTAS is a frame-by-frame TAS toolkit for Roblox. It lets you:

- Record your character's position, rotation, velocity, humanoid state, camera, and
  **raw input** every physics frame (60 Hz).
- Freeze the world on any frame and inspect / scrub through it.
- Advance the simulation **one physics tick at a time** to build pixel-perfect movement.
- Replay recordings through Roblox's `VirtualInputManager`, so the game actually
  receives your inputs.
- Save and import recordings as serialized strings.

It aims to feel like a real TAS tool (à la BizHawk, libTAS) — but inside a Roblox
script-executor environment.

Of the public Roblox TAS scripts I've looked at, this is the only one I've found that
combines proper physics-frame stepping, virtual input replay, camera capture,
animation time-position preservation, and a fully customizable UI in one place —
without falling apart the moment you touch it.

## Features

- **Physics-accurate frame stepping** — every tick is captured at the
  `PreSimulation` / `PostSimulation` boundary, so velocity, rotation, and humanoid
  state are exact.
- **One-tick advance** — advance the simulation by exactly one physics frame while
  frozen. *(Experimental — see [Known Issues](#known-issues).)*
- **Virtual input replay** — recorded keyboard / mouse / wheel events are fired
  through `VirtualInputManager` on playback, so the game processes them as real input.
- **Animation sync** — animation tracks are captured with their exact `TimePosition`
  and `Speed`, and re-applied on replay (including interpolation between frames).
- **Camera capture** — camera CFrame and FOV are recorded per-frame and restored on
  playback.
- **Frame-level editing** — seek backward / forward (hold or step), jump to any frame
  via the progress bar, splice recordings by recording over an existing one.
- **Pause removal** — auto-detects and strips idle frames, merging their inputs into
  the surrounding frames.
- **Serialization** — full recordings export to a compact Lua string; importable via
  `_G.importReplay(<string>)`.
- **6 themes** — Midnight, Ocean, Sakura, Matrix, Sunset, Mono.
- **Fully rebindable** — every action is bound to a key or mouse button of your choice.
- **Draggable GUI and HUD** — reposition and minimize as you like.
- **Character respawn safe** — reconnects to the new character automatically.

## Requirements

- A Roblox script executor with:
  - `VirtualInputManager` access — required for input replay; without it, input
    replay is silently disabled.
  - `setclipboard` / `toclipboard` — required for saving recordings to the clipboard.
  - `gethui` or `CoreGui` write access — falls back to `PlayerGui` if unavailable.
- No external dependencies.

## Installation

1. Copy the full script.
2. Paste it into your executor and run.
3. The `NexusTAS` window appears in the center of the screen.
4. Default binds are already active — see [Keybinds](#keybinds).

---

## Manual

### Modes

NexusTAS operates in four modes. Switch between them with the tabs or the bound keys
(`1` / `2` / `3` / `4` by default).

| Mode | Description |
|------|-------------|
| **Idle** | Free mode. Character is fully released — no anchoring, no camera lock, all inputs pass through normally. |
| **Create** | Editing / recording mode. Character is anchored at the current frame; all input is captured into the recording buffer. |
| **Test** | Straight playback from frame 1 to the end at the original recorded speed. |
| **Editable Test** | Playback with the ability to pause mid-way, scrub, and resume recording from any frame. |

**Create** is where you'll spend most of your time — it's both the recording mode and
the editing mode.

### Recording

1. Enter **Create** mode.
2. Press the **Record** bind (default: middle mouse button).
3. Your character is released, movement is enabled, and recording begins.
4. Perform the movement / actions you want to record.
5. Press the **Record** bind again to pause — the character is anchored and the frame
   is frozen.
6. From here you can:
   - Press **Record** again to continue recording from this frame (any frames after
     the current index are discarded).
   - Use **Seek** / **Step** to move backward / forward.
   - Press **One Tick** to advance exactly one physics frame.

Each recorded frame stores:

- Root CFrame (position + rotation)
- Linear and angular velocity
- Humanoid state (`Running`, `Freefall`, `Jumping`, …)
- Camera CFrame and FOV
- All playing animations (id + time position + speed)
- All raw inputs that occurred during the frame

### Replay

Switch to **Test** mode (`3`). The recording plays back from frame 1 in real time.
Camera, animations, velocity, and input events are all replayed. When playback reaches
the end, NexusTAS returns to Idle automatically.

To cancel playback, press **Idle** (`1`).

### Editing

In **Create** mode while paused, you can navigate the recording:

| Action | Default bind |
|--------|--------------|
| Seek backward (hold) | `Q` |
| Seek forward (hold) | `E` |
| Step one frame back | `F` |
| Step one frame forward | `G` |
| Jump to frame | click the progress bar |
| Remove pauses | `L` |

**Remove Pauses** scans the recording for consecutive frames where the character did
not meaningfully move or rotate, and removes them — merging any inputs from those
frames into the surviving frame. Useful for trimming idle time.

**Recording over a frame:** if you press Record while paused at frame `N`, playback
continues from that frame, and every frame after `N` is deleted as new frames are
written. This is how you splice corrections into an existing recording.

### Saving and Importing

**Save** (`F4` by default) serializes the entire recording to a Lua string and writes
it to your clipboard. The format looks like:

```lua
{
  { cf = CFrame.new(...), cameraCFrame = CFrame.new(...), cameraFOV = 70,
    anims = { ... }, t = 0.0166, velocity = Vector3.new(...), ... },
  ...
}
```

**Import** reads a recording from your clipboard and loads it. You can also import
programmatically:

```lua
_G.importReplay(([[HERE'S YOUR STRING]])
```

Or, in environments that expose them:

```lua
getgenv().importReplay([[HERE'S YOUR STRING]])
shared.importReplay(([[HERE'S YOUR STRING]])
```

The string must be a table literal that evaluates to an array of frame objects.
Malformed or truncated strings are rejected with a warning.

### The HUD

A small draggable panel in the bottom-right corner (toggle: `F5`). It shows:

- Current frame index
- Frame time
- Root position (world space)
- Root rotation (degrees)
- Linear velocity
- Angular velocity
- Camera rotation (degrees)
- Humanoid state name
- Camera zoom (distance to character)

When frozen on a frame in **Create** / **Editable Test**, it shows data from that
frame. Otherwise it shows live data from the character.

### Keybinds

Every action is rebindable from the **Binds** tab. Click any bind button, then press
the key or mouse button you want. Click another bind button to reassign, or press
**Reset to Defaults** at the bottom.

Default binds:

| Action | Key |
|--------|-----|
| Idle mode | `1` |
| Create mode | `2` |
| Test mode | `3` |
| Editable Test mode | `4` |
| Start / Pause recording | `R` |
| Start / Pause recording (mouse) | Middle Mouse Button |
| Editable Test play / pause | `Space` |
| Single physics tick | `V` |
| Seek backward (hold) | `Q` |
| Seek forward (hold) | `E` |
| Step back one frame | `F` |
| Step forward one frame | `G` |
| Remove pauses | `L` |
| Toggle camera lock | `C` |
| Clear recording | `F3` |
| Save to clipboard | `F4` |
| Toggle GUI | `F2` |
| Toggle HUD | `F5` |

Bound keys are automatically excluded from the recording — pressing `2` to enter
Create mode will not show up as a recorded input.

## GUI Overview

The window has four tabs:

- **Binds** — rebind every action.
- **Themes** — pick one of six color themes.
- **Settings** — camera lock, HUD toggle, smooth animations, and quick actions
  (reset camera, clear recording, return to idle).
- **Info** — quick start guide and hotkey reference.

The **status bar** at the bottom of the window shows: current state (mode + paused /
recording), frame count, current frame index, elapsed recording time, and a record
on/off indicator.

The **header** has:

- A collapse button (`—`) to shrink the window to just the header bar.
- A close button (`X`) to hide the window entirely. Bring it back with the GUI toggle
  bind (default `F2`).

## Status

**This is BETA v1.0. Expect bugs.**

NexusTAS is an experimental project. It is not feature-complete, it has not been tested
across every executor, and there are almost certainly scenarios where it will behave
incorrectly, desync, or crash. It's published because it's already useful enough to be
worth sharing, and because feedback is welcome.

Known-fragile areas:

- One-tick advance (see below).
- Animation timing across long recordings — drift can accumulate.
- Input replay in games that heavily sanitize or reorder input events.
- Character respawn mid-recording — the recording buffer is preserved, but the state
  machine resets.
- Save / Import on extremely long recordings — the serialized string can get large,
  and some executors truncate clipboard writes.

Use it, break it, report it.

### Known Issues

#### One-tick advance is experimental and currently buggy

The **One Tick** feature (a.k.a. *unpause 1 frame*) is meant to advance the simulation
by exactly one physics frame while the world is frozen, so you can build frame-perfect
movement manually.

It does not currently work correctly. Known problems:

- Velocity applied at the start of the tick is not always respected by the physics
  solver — the character may slide, stall, or jitter.
- Humanoid state transitions can desync from what was captured.
- The result of a tick does not always match what the same input would produce during
  a live recording.
- Multiple consecutive ticks can accumulate drift.

It's left in because it's the foundation for the feature that most needs to be done
right, and because it sometimes works. If you're building a run that needs
frame-perfect movement, **do not rely on One Tick yet** — record live instead.

Bug reports on this specific feature are especially welcome.

#### Other known issues

- The HUD's **Frame Time** field shows wall-clock elapsed time in live mode, not the
  exact frame delta.
- **Camera rotation** in the HUD is computed from `CFrame:ToOrientation()` and may
  differ from what the game reports internally.
- **Remove Pauses** uses a hardcoded position and rotation threshold — extremely slow
  movement may be incorrectly classified as idle.
- Rebinding a key to a mouse button while a recording is in progress can cause a
  spurious input to be captured.

## Reporting Bugs

If you hit a bug, please open an issue and include:

- What you were doing (mode, keybind used, etc.).
- What you expected to happen.
- What actually happened.
- Your executor name and version.
- If possible, the recording that triggered it (via **Save** → paste into the issue).
- Console output — NexusTAS prints warnings with the `[NexusTAS]` prefix.

Issues about the One Tick feature are especially useful if you can attach the frame
before and the frame after the broken tick.

Pull requests are welcome for small fixes. For larger features, please open an issue
first so we can discuss the approach.

## Credits

NexusTAS was directly inspired by **HappaTAS** — a brilliant little tool that
demonstrated what a minimal, focused TAS system could look like in Roblox. Many of the
core ideas here (physics-tick stepping, per-frame input capture, the "freeze and scrub"
workflow) were shaped by studying how HappaTAS did it. If you haven't seen HappaTAS,
go look at it — this project would not exist without it.

NexusTAS itself is a from-scratch reimplementation with a different architecture, a
heavier feature set (input replay, animation sync, camera capture, serialization, GUI),
and a different set of goals. It is **not** a fork.

## License

MIT — do whatever you want, just don't blame me if your WR gets rejected.
