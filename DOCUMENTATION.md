# Toron Sketcher — QField Plugin Documentation

## Table of Contents

- [Overview](#overview)
- [How the Plugin Is Supposed to Work](#how-the-plugin-is-supposed-to-work)
  - [Concept](#concept)
  - [Main Workflow](#main-workflow)
  - [Data Reference](#data-reference)
  - [UX Details](#ux-details)
  - [Out of Scope (For Now)](#out-of-scope-for-now)
- [Plugin File Structure](#plugin-file-structure)
- [Installing and Using the Plugin in QField](#installing-and-using-the-plugin-in-qfield)
  - [Method 1: Install via GitHub Release URL](#method-1-install-via-github-release-url)
  - [Method 2: Manual Transfer via USB / File Manager](#method-2-manual-transfer-via-usb--file-manager)
  - [Method 3: QFieldCloud Sync](#method-3-qfieldcloud-sync)
  - [Using the Plugin](#using-the-plugin)
- [Current Development Status](#current-development-status)
  - [Commit History Summary](#commit-history-summary)
  - [What Is Working](#what-is-working)
  - [What Is Not Yet Implemented](#what-is-not-yet-implemented)
  - [Acceptance Criteria Checklist](#acceptance-criteria-checklist)
- [Debugging QField Plugins](#debugging-qfield-plugins)
  - [1. Use the QField Desktop App for Fast Iteration](#1-use-the-qfield-desktop-app-for-fast-iteration)
  - [2. Use console.log Extensively](#2-use-consolelog-extensively)
  - [3. Use displayToast for On-Device Debugging](#3-use-displaytoast-for-on-device-debugging)
  - [4. Use Android Logcat for Mobile Debugging](#4-use-android-logcat-for-mobile-debugging)
  - [5. Incremental Development Strategy](#5-incremental-development-strategy)
  - [6. Common Pitfalls and Gotchas](#6-common-pitfalls-and-gotchas)
- [Dev Cycle Summary](#dev-cycle-summary)

---

## Overview

This is a **learning exercise** plugin for QField (QML/JavaScript, not Python). It will not be used in production — the goal is to explore the QField plugin development pattern and prepare for building real plugins later.

The plugin creates **TORONS** (line features) by tapping on two **POTEAUX** (pole points) on the map, instead of manually drawing and snapping a line. The workflow: tap pole A, tap pole B, the line is created, the attribute form opens.

---

## How the Plugin Is Supposed to Work

### Concept

A surveyor working in QField on a mobile device needs to create line features (torons/cables) that connect two point features (poteaux/poles). Instead of manually drawing a line and snapping to each pole, this plugin lets them simply tap two poles and the line is created automatically.

### Main Workflow

1. The surveyor taps the **plugin button** in the QField toolbar (cable/link icon)
2. The plugin enters **"sketching mode"** — a visual indicator (banner text + button highlight) shows that the plugin is active and waiting for pole selection
3. The surveyor **taps near the first POTEAUX** on the map — the plugin identifies the nearest pole and confirms the selection (shows the pole name/ID)
4. The surveyor **taps near the second POTEAUX** — same confirmation
5. The plugin **creates a MULTILINESTRING geometry** connecting the two pole points
6. The plugin **opens the TORONS attribute form** so the surveyor can fill in properties (`Proprietaire`, `STATUS`, `strnd_size`, etc.)
7. The plugin **exits sketching mode** and returns to normal map interaction

### Data Reference

The plugin works with the demo geopackage `demo_releve_alias.gpkg`. The relevant layers are:

| Layer | Geometry | Key Fields |
|-------|----------|------------|
| `POTEAUX` | POINT | `fid`, `nom_poteau_civique`, `code_barre` |
| `TORONS` | MULTILINESTRING | `fid`, `Proprietaire`, `Longueur`, `STATUS`, `strnd_size` |

### UX Details

- Show the name/ID of each selected pole so the surveyor can confirm the right ones were chosen
- Allow **cancellation** of sketching mode (re-tap the plugin button)
- If the surveyor taps far from any pole, show a brief message ("Aucun poteau trouvé à proximité") and let them retry
- Keep the UI minimal — this runs on phones in the field

### Out of Scope (For Now)

- Sketching mode for ANCRES — only POTEAUX for this version
- Editing or deleting existing TORONS
- Auto-calculating the `Longueur` field — nice-to-have for a future iteration
- Sketching multiple TORONS in a row without re-activating the plugin

---

## Plugin File Structure

```
toron_sketcher/
├── main.qml        # Entry point — toolbar button + sketching logic
├── metadata.txt     # Plugin metadata (name, version, author, icon)
├── icon.svg         # Toolbar icon (cable/toron icon)
└── README.md        # Project readme
```

- **`main.qml`**: The single QML file containing all plugin logic. Uses an `Item` as root, creates UI components (toolbar button, banner, tap catcher) as `Component` definitions, and instantiates them in `Component.onCompleted`.
- **`metadata.txt`**: Standard QField plugin metadata with a `[general]` section containing `name`, `description`, `author`, `icon`, and `version`.
- **`icon.svg`**: SVG icon displayed on the plugin toolbar button.

---

## Installing and Using the Plugin in QField

### Method 1: Install via GitHub Release URL

This is the recommended approach for sharing the plugin.

1. Go to the GitHub repository
2. Navigate to **Releases** 
3. Download the `.zip` file attached to the release — it should contain the `toron_sketcher/` folder with `main.qml`, `metadata.txt`, and `icon.svg`
4. On QField mobile, go to **Settings > Plugins** (or the plugin management screen)
5. Use the **"Install from URL"** option and paste the direct download URL of the `.zip` from the GitHub release
6. QField will install the plugin and it will appear in the plugins toolbar

### Method 2: Manual Transfer via USB / File Manager

1. Connect your phone to your computer via USB
2. Navigate to QField's plugin directory on the device:
   - Android: typically `<internal storage>/Android/data/ch.opengis.qfield/files/QField/plugins/`
   - The exact path may vary by device and QField version
3. Copy the entire `toron_sketcher/` folder (containing `main.qml`, `metadata.txt`, `icon.svg`) into the plugins directory
4. Restart QField — the plugin should appear in the toolbar

### Method 3: QFieldCloud Sync

1. Upload the project (including the plugin folder) to QFieldCloud
2. On QField mobile, sync/download the project from QFieldCloud
3. The plugin will be included with the project

### Using the Plugin

1. Open a project in QField that contains the `POTEAUX` and `TORONS` layers (e.g., the `demo_releve_alias.gpkg` project)
2. Look for the toron sketcher icon in the **plugins toolbar**
3. Tap the icon to enter sketching mode
4. Tap near the first pole on the map
5. Tap near the second pole on the map
6. The TORONS line will be created and the attribute form will open
7. Fill in the attributes and save

---

## Current Development Status

### Commit History Summary

The project has **31 commits** across several development phases:

| Phase | Commits | Description |
|-------|---------|-------------|
| Initial setup | `11fce07` | Initial commit with file structure |
| Button/UI | `a6cabd4` to `10c60e2` (3 commits) | Getting the toolbar button to show up, adding banner, button color and text |
| Map coordinates | `547143b` to `0ee8a99` (5 commits) | Implementing screen-to-map coordinate conversion. Took 4 fix attempts to get `screenToCoordinate` working correctly |
| Finding poteaux | `8409ba9` to `079c8b1` (23 commits) | Implementing the spatial query to find the nearest POTEAUX feature. This was the hardest part — took 22 fix attempts iterating on the `aggregate()` expression approach |

**Version tags**: `v1.0.0` through `v1.1.26` (30 release tags total)

### What Is Working

- **Plugin file structure**: `main.qml`, `metadata.txt`, `icon.svg` are all present and valid
- **Toolbar button**: Appears in QField's plugin toolbar with the custom icon. Changes color (highlighted) when sketching mode is active
- **Sketching mode toggle**: Tapping the button activates/deactivates sketching mode. Tapping again cancels and resets state
- **Visual banner**: A colored banner at the top of the screen shows the current state ("tappez le premier poteau" / "tappez le deuxième poteau")
- **Map tap capture**: A `MouseArea` overlay captures taps on the map canvas when sketching is active
- **Screen-to-map coordinate conversion**: Correctly converts screen pixel taps to real map coordinates using `mapSettings.screenToCoordinate()`
- **Finding POTEAUX layer**: Searches for the layer by multiple possible names (`"POTEAUX"`, `"demo_releve_alias 1 — POTEAUX"`, etc.)
- **Nearest pole spatial query**: Uses a QGIS `aggregate()` expression with a distance filter to find the nearest pole within tolerance (~5 meters)
- **Pole name confirmation**: Shows the selected pole's `nom_poteau_civique` attribute as a toast
- **Duplicate pole guard**: Prevents selecting the same pole twice
- **Extensive debug logging**: `console.log` and toast messages at every step

### What Is Not Yet Implemented

| Feature | Details |
|---------|---------|
| **Create TORONS geometry** | `createToron()` is currently a placeholder — it shows a toast with the two pole names but does not actually create a `MULTILINESTRING` feature on the `TORONS` layer |
| **Use real pole coordinates** | The selected pole stores `tapX/tapY` (where the user tapped) instead of the actual pole feature geometry coordinates. Real coordinates need to be extracted from the pole feature |
| **Open attribute form** | After creating the TORONS feature, the QField attribute form should open automatically so the user can fill in `Proprietaire`, `STATUS`, `strnd_size`, etc. |
| **"No pole nearby" feedback** | When no pole is found near the tap, the function silently returns. Should show "Aucun poteau trouvé à proximité" |

### Acceptance Criteria Checklist

- [x] Plugin appears in QField plugins toolbar with an icon
- [x] Tapping the button activates sketching mode with a visual indicator
- [x] Tapping near a pole selects it and shows confirmation (name/ID)
- [ ] After selecting 2 poles, a TORONS MULTILINESTRING is created connecting them
- [ ] The TORONS attribute form opens automatically after creation
- [x] Sketching mode can be cancelled
- [ ] Tapping far from a pole shows a feedback message (partially done — silently returns)
- [x] `metadata.txt` is present and valid
- [ ] `README.md` documents architecture, data flow, dev setup, and deployment
- [ ] Gotchas and lessons learned are documented
- [x] Plugin tested on QField mobile on a real device

---

## Debugging QField Plugins

QField plugins are written in QML/JavaScript and run inside the QField app. There is no built-in debugger like browser DevTools, so debugging requires creative approaches. Below are the techniques used and learned during development of this plugin.

### 1. Use the QField Desktop App for Fast Iteration

QField has a **desktop version** that runs on Windows/Mac/Linux. This is by far the fastest way to iterate:

- **No need to transfer files to a phone** after every change — just edit `main.qml` and restart the desktop app
- The desktop app shows `console.log` output in real time (via the built-in log panel, or in the terminal if launched from the command line)
- The dev cycle becomes: **edit code → save → restart QField desktop → test → repeat**

This is dramatically faster than the mobile cycle (edit → zip → transfer → install → test).

### 2. Use console.log Extensively

`console.log()` is your primary debugging tool. Add it at **every significant step** in your plugin logic:

```javascript
// Tag all logs with your plugin name for easy filtering
console.log("[toron_sketcher] Component.onCompleted starting")
console.log("[toron_sketcher] toolbarButton created")
console.log("[toron_sketcher] handleMapTap screenPoint=", screenPoint.x, screenPoint.y)
console.log("[toron_sketcher] tap mapCoord=", tapX, tapY)
console.log("[toron_sketcher] layer found:", layer.name)
```

**Best practices:**

- **Prefix every log** with `[toron_sketcher]` so you can filter your plugin's output from QField's own logs
- **Log at entry and exit** of every function
- **Log variable values** (coordinates, layer names, fid results) — not just "got here"
- Use `console.warn()` for unexpected-but-handled cases
- Use `console.error()` for failures, and include `e.message` and `e.stack`

### 3. Use displayToast for On-Device Debugging

When testing on a phone where you can't see `console.log` output, use **toast messages** to show debug information directly on screen:

```javascript
iface.mainWindow().displayToast("Some debug info here")
```

This was used heavily during this plugin's development. For example, showing the raw values of the spatial query result:

```javascript
iface.mainWindow().displayToast(
    "tap=" + tapX.toFixed(4) + "," + tapY.toFixed(4) +
    " | layer='" + layerName + "'" +
    " | agg=" + aggResult +
    " fid=" + nearestFid
)
```

**Best practices:**

- Show toasts at **every major step** so you can see exactly where the plugin gets to before it fails or goes silent
- Include **actual variable values** in the toast (coordinates, layer names, expression results) — not just "Step 3 reached"
- Toasts disappear after a few seconds, so keep messages concise but informative
- When a step is confirmed working, you can remove or reduce the debug toasts for a cleaner UX
- **Wrap toast calls in try/catch** so a failing toast doesn't mask the real error:

```javascript
try {
    iface.mainWindow().displayToast("debug info")
} catch (e) {
    // toast itself failed — don't mask the real error
}
```

### 4. Use Android Logcat for Mobile Debugging

If you need full `console.log` output from a physical phone:

1. Connect your phone to your computer via USB
2. Enable **USB debugging** in Android Developer Options
3. Run `adb logcat` from a terminal on your computer:
   ```bash
   adb logcat | grep -i "toron_sketcher"
   ```
4. This streams all QField logs in real time, including your `console.log` output
5. The `[toron_sketcher]` prefix makes it easy to filter your plugin's output

### 5. Incremental Development Strategy

The single most important debugging strategy is **building incrementally** and testing each piece before moving to the next:

1. **Start with just a button** — confirm it shows up in the toolbar before adding any logic
2. **Add a click handler** that just shows a toast — confirm taps are registered
3. **Add the tap catcher** — confirm map taps are captured (show raw screen coordinates)
4. **Add coordinate conversion** — confirm map coordinates are correct (show them in a toast)
5. **Add the layer lookup** — confirm the POTEAUX layer is found (show the layer name)
6. **Add the spatial query** — confirm the nearest pole is found (show the fid and name)
7. **Add geometry creation** — confirm the TORONS feature is created
8. **Add the attribute form** — confirm it opens

Each step should be a **separate commit** so you can roll back if something breaks. This project followed exactly this pattern — the commit history shows the button working first, then coordinates, then pole finding, with each phase fully tested before moving on.

### 6. Common Pitfalls and Gotchas

**Layer naming varies**: The POTEAUX layer name in QField may not be exactly `"POTEAUX"`. It can include the geopackage file name as a prefix (e.g., `"demo_releve_alias — POTEAUX"` or `"demo_releve_alias 1 — POTEAUX"`). Always try multiple name variants when looking up layers:

```javascript
var namesToTry = [
    "POTEAUX",
    "demo_releve_alias 1 — POTEAUX",
    "demo_releve_alias — POTEAUX"
]
```

**Screen coordinates are not map coordinates**: Screen coordinates (pixels) are NOT the same as map coordinates (lat/lon or projected meters). You must convert using `mapSettings.screenToCoordinate()`. Getting this wrong was a multi-commit debugging effort in this project (commits 4 through 8).

**Distance tolerance depends on coordinate system**: When doing spatial queries with distance, the tolerance value depends on your coordinate reference system. For geographic coordinates (degrees) at ~46° latitude, `0.000045` degrees is approximately 5 meters. For projected coordinates (meters), use `5` directly.

**Expression evaluation can fail silently**: The `ExpressionEvaluator` runs QGIS expressions on the C++ side. Complex expressions like `aggregate()` can return unexpected results or fail without throwing a visible error. Always check the result and log it — don't assume it worked.

**QML array properties don't trigger updates on mutation**: Modifying a QML array property in-place (e.g., using `push()`) does NOT trigger property change notifications, so the UI won't update. You must create a copy, modify the copy, and reassign:

```javascript
// WRONG — won't trigger UI updates:
plugin.selectedPoles.push(newPole)

// CORRECT — triggers property change notifications:
var poles = plugin.selectedPoles.slice()
poles.push(newPole)
plugin.selectedPoles = poles
```

**Wrap everything in try/catch**: QML/JavaScript errors inside a plugin can fail silently and leave the plugin in a broken state with no visible feedback. Wrap every function body in `try/catch` and log the error:

```javascript
function handleMapTap(screenPoint) {
    try {
        // ... all logic here ...
    } catch (e) {
        console.error("[toron_sketcher] handleMapTap failed:", e.message, e.stack)
        try { iface.mainWindow().displayToast("Erreur: " + e) } catch (e2) {}
    }
}
```

**Component.createObject can return null silently**: When creating QML components at runtime, `createObject()` can return `null` if the parent is invalid or the component has errors — and it won't throw an exception. Always check the result:

```javascript
toolbarButton = buttonComponent.createObject(null)
if (!toolbarButton) {
    console.error("[toron_sketcher] buttonComponent.createObject returned null")
}
```

---

## Dev Cycle Summary

The iterative development cycle for this plugin:

```
Edit main.qml on desktop
        |
        v
Package as .zip (or copy folder directly)
        |
        v
Transfer to device (USB / QFieldCloud / GitHub release URL)
        |
        v
Open project in QField
        |
        v
Test the plugin (tap button, tap poles, check toasts/logs)
        |
        v
Check console.log output (desktop app console, or adb logcat on mobile)
        |
        v
Identify issue --> fix code --> commit --> repeat
```

For faster iteration, use **QField desktop** to skip the transfer step entirely.
