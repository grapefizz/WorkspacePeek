# WorkspacePeek

<img width="952" height="224" alt="Screenshot 2026-07-03 at 5 06 18 PM" src="https://github.com/user-attachments/assets/0f5f89a5-911f-4430-9b50-37a455fc549f" />

Transparent pywal-coloured workspace switcher HUD for macOS WMs (**Aerospace** and **rift**) built with Swift. Primarily made for macOS Sequoia 15.7.7, but I've also tested it working on macOS 26 (Tahoe). It'll auto-detect either of those two choices at runtime. 

The flow is you would hit a hotkey --> horizontal strip of workspace thumbnails appear centre of your screen --> navigate with arrow keys + enter, or press a number to jump --> dismisses right after. There's no Dock or menu bar icon, just a floating overlay. 

## How it works

The thumbnails are screenshots taken w/ ScreenCaptureKit (`SCScreenshotManager.captureImage` over current display) to snapshot the screen whenever you pull up the swapper, then cache it as a PNG at the configured cache path, which defaults to `~/.cache/workspacepeek/<workspace-id>.png`. In other words, they are NOT live views of those workspaces like mission control (though I find it good enough for my purposes).

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

To change it, edit `~/.config/workspacepeek/config.json`. WorkspacePeek creates that file on startup if it does not exist.

```json
{
  "hotkey": {
    "triggerKey": "w",
    "triggerModifiers": ["option"],
    "consumeEvent": true
  }
}
```

Use lowercase key names like `w`, `s`, `space`, `tab`, `return`, or `escape`.

Modifier flags:
- Option: `option`
- Command: `command`
- Control: `control`
- Shift: `shift`

Use `option`, `command`, `control`, and `shift` in the config. Restart WorkspacePeek after changing hotkey settings.

## Pywal integration

Colours are read live from the configured pywal file every time the picker opens. The default is `~/.cache/wal/colors.json`,
so it always matches your current wallpaper palette automatically.

## Customising it

Runtime settings live in `~/.config/workspacepeek/config.json`. The app creates a full default file on startup if none exists. Most HUD edits are read each time you open the picker, so sizing and colour tweaks do not need a rebuild.

- The title --> change `"hud.badge.titleText"`, or set `"hud.badge.showTitle": false` to hide it.
- Hotkey, navigation keys, cache path, screenshot scale, backend selection, CLI paths, app glyphs, fonts, layout, fallback colours, and colour roles are all configurable there.
- Set `"windowManager.backend"` to `"auto"`, `"rift"`, or `"aerospace"`.

### Colours

Out of the box the HUD comes up pink, that's the built-in fallback palette. There's two ways to change it:

- **The proper way (pywal):** the switcher reads the configured pywal JSON live on every open, so if you set pywal up and generate a scheme, it just follows your wallpaper. No rebuild needed.
- **The quick way:** if you don't want pywal, set `"colors.useWalColors": false` and edit the hex values under `"colors.fallback"` in `~/.config/workspacepeek/config.json`.

Here's what each default colour role paints in the switcher:

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

So the big levers are `background` (the whole HUD), `color13` (the focused workspace bubble), and `color4` (the selection ring). If you fat-finger a hex, WorkspacePeek falls back to a safe built-in colour for that field.

## Is this safe?

You can verify for yourself! It's all Swift w/ no third-party dependencies and no network code. The permissions are just for visible features, Accessibility for the hotkey, and Screen Recording for grabbing the workspace thumbnails. You can build and ad-hoc sign yourself, since this repo ships no certificate or Apple identity. 

## Uninstall

```bash
pkill -x WorkspacePeek
rm -rf /Applications/WorkspacePeek.app
```

It'll register as a Login Item. One the app is gone, the entry should clear itself. If it doesn't, remove it under **System Settings -> General -> Login Items**.
