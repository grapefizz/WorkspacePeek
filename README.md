# WorkspacePeek

<img width="952" height="224" alt="Screenshot 2026-07-03 at 5 06 18 PM" src="https://github.com/user-attachments/assets/7d2d4121-12af-498a-9613-54b340a8f45a" />

Transparent pywal-coloured workspace switcher HUD for macOS WMs (**Aerospace** and **rift**) built with Swift. Primarily made for macOS Sequoia 15.7.7, but I've also tested it working on macOS 26 (Tahoe). It'll auto-detect either of those two choices at runtime. 

The flow is you would hit a hotkey --> horizontal strip of workspace thumbnails appear centre of your screen --> navigate with arrow keys + enter, or press a number to jump --> dismisses right after. There's no Dock or menu bar icon, just a floating overlay. 

## How it works

The thumbnails are screenshots taken w/ ScreenCaptureKit (`SCScreenshotManager.captureImage` over current display) to snapshot the screen whenever you pull up the swapper, then cache it as a PNG at `~/.cache/workspacepeek/<workspace-id>.png`. In other words, they are NOT live views of those workspaces like mission control (though I find it good enough for my purposes).

Pulling up the picker would therefore load those cached PNGs as the tiles, showing the last state you saw on that workspace. This is why the picker needs permissions for Screen Recording, and also why a workspace you haven't been to yet will also show up as blank until you visit it once. This is also why if you switch workspaces through other methods than WorkspacePeek, it will not reflect in the WorkspacePeek thumbnails.

## Install

```bash
chmod +x install.sh
./install.sh
```

**Prerequisite**
> This build will need Swift (comes w Xcode or `xcode-select --install`). The script will build a release binary, wrap it into a `.app`, sign it, install to `/Applications`, and launch it. It'll register as a Login Item.
>
> You also need a window manager (**rift** or **AeroSpace**) actually running, since WorkspacePeek just reads workspaces off it. With no WM up there's nothing to show. It talks to `rift-cli` / `aerospace` directly, so those don't come from my dotfiles, just install the WM itself.

**First Launch**

On first launch macOS will prompt for:
- **Accessibility** (for the global hotkey)
- **Screen Recording** (to snapshot the workspace thumbnails)

## Hotkey to pull it up

**Option + W**

To change it, edit `Sources/WorkspacePeek/HotkeyListener.swift`:

```swift
private let triggerKeyCode: CGKeyCode = 0x0D  // W (change this)
private let triggerModifiers: CGEventFlags = [.maskAlternate]  // Option (change this)
```

Some common key codes (or you can look some up for yourself ofc):
- A=0x00, S=0x01, D=0x02, F=0x03, W=0x0D, E=0x0E, R=0x0F
- Space=0x31, Tab=0x30

Modifier flags:
- Option: `.maskAlternate`
- Command: `.maskCommand`
- Control: `.maskControl`
- Shift: `.maskShift`

After that re-run `./install.sh` to rebuild.

## Pywal integration

Colours are read live from `~/.cache/wal/colors.json` every time the picker opens,
so it always matches your current wallpaper palette automatically.

## Customising it

If you're not into my aesthetic titles (or just want to mess w/ the sizing), it's all in `~/.config/workspacepeek/badge.json`, which install.sh drops a default one of. It's read every time you open the picker so edits are live, no rebuild needed.

- The title (that `꒰ා ✦ ... workspaces ... ໒꒱` header) --> change `"titleText"`, or set `"showTitle": false` to just get rid of it.
- Other stuff in there: bubble size, corner radius, spacing, font size, selection glow.

### Colours

Out of the box the HUD comes up pink, that's the built-in fallback palette. There's two ways to change it:

- **The proper way (pywal):** the switcher reads `~/.cache/wal/colors.json` live on every open, so if you set pywal up and generate a scheme, it just follows your wallpaper. No rebuild needed.
- **The quick way (hardcode it):** if you don't want pywal, edit the fallback hex values in `Sources/WorkspacePeek/WalColors.swift` (the `static var fallback` block) and re-run `./install.sh`. That becomes your permanent colour scheme.

Only change the bit inside the quotes (the `"#280d2a"` part), leave the `NSColor(hex:) ?? .black` stuff alone. Here's what each field actually paints in the switcher:

| What you see | Field |
|---|---|
| Panel + thumbnail background | `background` |
| Title header | `color7` (= `fg` in the fallback) |
| Focused workspace bubble (background) | `color13` |
| Focused workspace number | `background` |
| Unfocused workspace bubble (background) | `color8` |
| Unfocused workspace number | `color15` (= `fg` in the fallback) |
| Window label under the focused workspace | `color7` |
| Window label (other workspaces) | `fg` (foreground) |
| Selected window ring + glow | `color4` |
| Other window rings | `color2` |

So the big levers are `background` (the whole HUD), `color13` (the focused workspace bubble), and `color4` (the selection ring). If you fat-finger a hex it just falls back to the `.white` / `.black` after the `??`, so nothing breaks, you'll just see the wrong colour and know which line to fix.

## Is this safe?

You can verify for yourself! It's all Swift w/ no third-party dependencies and no network code. The permissions are just for visible features, Accessibility for the hotkey, and Screen Recording for grabbing the workspace thumbnails. You can build and ad-hoc sign yourself, since this repo ships no certificate or Apple identity. 

## Uninstall

```bash
pkill -x WorkspacePeek
rm -rf /Applications/WorkspacePeek.app
```

It'll register as a Login Item. One the app is gone, the entry should clear itself. If it doesn't, remove it under **System Settings -> General -> Login Items**.
