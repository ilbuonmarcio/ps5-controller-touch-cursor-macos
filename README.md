# DualSense Cursor

A native macOS menu bar utility that turns a PS5 DualSense touchpad into a mouse. Requires macOS 12 or later and a connected DualSense controller.

## Build and run

```sh
zsh scripts/build.sh
open "build/DualSense Cursor.app"
```

Click the controller icon in the menu bar and choose **Grant Accessibility permission…**. Enable DualSense Cursor in System Settings → Privacy & Security → Accessibility. If it is absent, add the app using the + button. Quit and reopen if macOS requests it.

Slide one finger to move the pointer. Press the touchpad for left click; hold it while sliding to drag. Lift and reposition your finger to continue moving. The menu offers an enable switch, three sensitivity levels, connection status, and live touch coordinates for troubleshooting. Sensitivity is saved between launches.

The app reads DualSense HID reports through IOKit, enabling full Bluetooth reports with a firmware feature request on connection. It uses explicit contact state to reset movement when you lift your finger, including at the center of the pad. It does not provide scrolling, tap to click, or right click yet.

Protocol references: [SDL's DualSense driver](https://github.com/libsdl-org/SDL/blob/main/src/joystick/hidapi/SDL_hidapi_ps5.c) documents enabling enhanced Bluetooth reporting, and [Linux's PlayStation driver](https://github.com/torvalds/linux/blob/master/drivers/hid/hid-playstation.c) documents report layouts. The Swift implementation is independent.

The app is locally ad hoc signed. Rebuilding may require renewing its Accessibility permission. No network access or third party dependencies are used.
