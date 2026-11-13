# DualSense Cursor

Turn your PS5 DualSense touchpad into a mouse on macOS. A small native menu bar app provides smooth cursor movement, stable clicks, and two-finger gestures over Bluetooth—with no Dock icon or third-party dependencies.

## Features

- **Smooth cursor control** with jitter filtering and protection against jumps when lifting or repositioning your finger.
- **Left click, double-click, and drag**, with movement suppression while pressing and releasing the touchpad.
- **Two-finger scrolling** on both axes, with independent scroll-speed settings.
- **Two-finger tap for right click.**
- **Pinch-to-zoom shortcuts**, with smoothed detection and a limit on how quickly zoom steps are sent.
- **Separate cursor and scroll speeds**, each with Slow, Normal, and Fast presets saved between launches.
- **Menu bar controls** for enabling the cursor, checking controller and permission status, and viewing touch activity.
- **Automatic relaunch after an Accessibility grant**, preserving speed settings and the cursor enable switch.

## Requirements

- macOS 12 or later.
- A Sony DualSense controller paired with your Mac.
- Xcode or Apple's Command Line Tools with the macOS SDK and Swift compiler.
- Accessibility permission to move the cursor and send clicks, scrolling, and keyboard shortcuts.

Bluetooth input has been tested with a connected DualSense. The report parser also supports USB; physical USB operation has not yet been verified.

## Build and launch

From the repository directory:

```sh
zsh scripts/build.sh
open "build/DualSense Cursor.app"
```

The build creates a locally signed app at `build/DualSense Cursor.app`. Click the controller icon in the macOS menu bar to access its controls.

### Grant Accessibility permission

1. In the app menu, choose **Grant Accessibility permission…**.
2. Open **System Settings → Privacy & Security → Accessibility** and enable **DualSense Cursor**.
3. If the app is missing, use **+** to add `build/DualSense Cursor.app`.

The app polls Accessibility trust every second. After detecting a grant for two consecutive checks, it requests one automatic relaunch to refresh mouse-event access. The menu shows **Cursor: ready** when both permissions are available.

Local builds use ad hoc signing, so rebuilding can invalidate an earlier grant. If the switch is already enabled but the menu says **Cursor: blocked by Accessibility**, remove the old entry and add the current app again. If the automatic relaunch does not complete, quit and reopen the app manually.

## Controls

| Action | Touchpad gesture |
| --- | --- |
| Move the cursor | Slide one finger |
| Left click | Press and release the touchpad |
| Double-click | Press and release twice quickly at the same cursor position |
| Drag | Hold the touchpad pressed, then deliberately slide one finger |
| Scroll vertically or horizontally | Slide two fingers together |
| Right click | Briefly touch and lift two fingers without physically pressing |
| Zoom in / out | Spread / pinch two fingers |

Double-click detection follows the macOS double-click interval. Pressing and releasing briefly suppresses cursor movement; dragging begins after a small intentional slide, helping prevent accidental drags when clicking.

Two-finger gestures hold the cursor still. Once one starts, **lift both fingers before returning to cursor movement**. Each gesture locks into scrolling or zooming until release. A physical press cancels the two-finger gesture to avoid accidental clicks.

### Adjust movement and scrolling

Use the menu's **Cursor speed** and **Scroll speed** submenus independently. Both offer **Slow / Normal / Fast** and remember your choice.

Scrolling uses a natural direction. **Normal** is the gentler default; **Slow** halves that speed, and **Fast** doubles it.

### Zoom behavior

Pinching sends standard **⌘+ / ⌘−** shortcuts to the focused app. Detection is smoothed and shortcuts are rate limited, while the receiving app determines the size of each zoom step. Support depends on the app and keyboard layout; this provides stepped zoom rather than continuous native trackpad magnification.

One-finger tap-to-click and scroll momentum are currently unavailable.

## Troubleshooting

| Symptom | What to check |
| --- | --- |
| Controller disconnected | Confirm the DualSense is powered on and connected in macOS Bluetooth settings. |
| Touch values change, but the cursor stays still | Check **Enable cursor** and **Cursor: ready** in the menu. Renew Accessibility permission if blocked. |
| Permission is enabled but still blocked after a rebuild | Remove the existing Accessibility entry and add the newly built app. |
| Cursor stays still after scrolling or pinching | Lift both fingers to finish the gesture. |
| Scrolling is too fast | Choose **Scroll speed → Slow**. |
| Pinching does not zoom | Focus an app that supports the standard Command zoom shortcuts and check its keyboard layout requirements. |

## Development

The app uses AppKit for its menu bar UI, IOKit for DualSense input, and Quartz events for mouse and keyboard output. It reads both touch contacts directly and requests full Bluetooth reports when the controller connects. It does not access the network.

Run the standalone Swift checks with:

```sh
zsh scripts/test.sh
```

These cover Bluetooth and USB report decoding, cursor smoothing, click stabilization, double-click timing, gesture recognition, scroll-speed scaling, pinch rate limiting, and permission-change restart detection. They do not replace testing gestures and Accessibility relaunches on a real Mac.

Optional hardware diagnostics are in `tools/controller-probe.swift` and `tools/input-smoke.swift`.

Protocol references: [SDL's DualSense driver](https://github.com/libsdl-org/SDL/blob/main/src/joystick/hidapi/SDL_hidapi_ps5.c) and [Linux's PlayStation driver](https://github.com/torvalds/linux/blob/master/drivers/hid/hid-playstation.c). The Swift implementation is independent.

## License

[MIT](LICENSE) © 2026 ilbuonmarcio.
