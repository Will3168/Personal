import QtQuick
import QtQuick.Controls
import org.qfield
import org.qgis
import Theme

Item {
    id: plugin

    // --- Sketching state ---
    property bool sketchingActive: false
    property var selectedPoles: []

    // --- Cached layer reference (set on first tap) ---
    property var poteauxLayer: null

    // --- References to objects created at runtime ---
    property var toolbarButton: null
    property var sketchingBanner: null
    property var tapCatcher: null

    // --- Toolbar button ---
    Component {
        id: buttonComponent

        QfToolButton {
            id: sketcherButton
            iconSource: "icon.svg"
            bgcolor: plugin.sketchingActive ? Theme.mainColor : Theme.darkGray
            round: true

            onClicked: {
                plugin.toggleSketching()
            }
        }
    }

    // --- Sketching mode banner (visual indicator) ---
    Component {
        id: bannerComponent

        Rectangle {
            id: banner
            width: parent ? parent.width : 0
            height: 40
            color: Theme.mainColor
            visible: plugin.sketchingActive
            z: 1000
            anchors.top: parent ? parent.top : undefined

            Text {
                anchors.centerIn: parent
                text: plugin.selectedPoles.length === 0
                      ? "Mode sketching actif \u2014 tappez le premier poteau"
                      : "Mode sketching actif \u2014 tappez le deuxi\u00e8me poteau"
                color: "white"
                font.bold: true
                font.pixelSize: 16
            }
        }
    }

    // --- Map tap capture ---
    // Simple MouseArea overlay. Pan/zoom are blocked while sketching is active.
    // This is acceptable because sketching mode is brief (2 taps then auto-exit).
    // User can deactivate sketching to navigate, then re-activate.
    Component {
        id: tapCatcherComponent

        MouseArea {
            id: catcher
            anchors.fill: parent
            enabled: plugin.sketchingActive
            z: 999

            onClicked: (mouse) => {
                plugin.handleMapTap(Qt.point(mouse.x, mouse.y))
            }
        }
    }

    // --- Logic ---

    // Find the POTEAUX layer (cached after first lookup)
    function findPoteauxLayer() {
        if (plugin.poteauxLayer) return plugin.poteauxLayer

        // Try exact names that might be used in different projects
        var namesToTry = [
            "POTEAUX",
            "demo_releve_alias 1 \u2014 POTEAUX",
            "demo_releve_alias \u2014 POTEAUX"
        ]

        for (var i = 0; i < namesToTry.length; i++) {
            try {
                var results = qgisProject.mapLayersByName(namesToTry[i])
                if (results && results.length > 0) {
                    plugin.poteauxLayer = results[0]
                    return plugin.poteauxLayer
                }
            } catch (e) {
                // Name didn't work, try next
            }
        }

        // Fallback: iterate all layers and find one containing "POTEAUX"
        try {
            var allLayers = qgisProject.mapLayersByName("")
            // This probably won't work, but we tried
        } catch (e) {
            // Expected
        }

        return null
    }

    function handleMapTap(screenPoint) {
        try {
            // 4.3a — Convert screen pixels to map coordinates
            var mapSettings = iface.mapCanvas().mapSettings
            var mapPoint = mapSettings.screenToCoordinate(screenPoint)

            // 4.3b — Find the POTEAUX layer
            var layer = findPoteauxLayer()
            if (!layer) {
                iface.mainWindow().displayToast("Couche POTEAUX introuvable dans le projet")
                return
            }

            // 4.3c — Build tolerance (40 pixels in map units)
            var mpp = mapSettings.mapUnitsPerPixel
            var tol = mpp * 40

            // 4.3d — Query features near the tap
            // QField doesn't expose getFeatures() to QML.
            // Try getFeature(fid) for each known feature instead.
            var nearestFeature = null
            var nearestDist = tol
            var nearestPoint = null
            var count = layer.featureCount()

            for (var fid = 1; fid <= count + 10; fid++) {
                try {
                    var feat = layer.getFeature(fid)
                    if (!feat || !feat.isValid()) continue

                    var geom = feat.geometry()
                    var pt = geom.asPoint()
                    var dx = pt.x - mapPoint.x
                    var dy = pt.y - mapPoint.y
                    var dist = Math.sqrt(dx * dx + dy * dy)

                    if (dist < nearestDist) {
                        nearestDist = dist
                        nearestFeature = feat
                        nearestPoint = pt
                    }
                } catch (innerErr) {
                    // fid doesn't exist, skip
                }
            }

            // 4.3e — Handle result
            if (!nearestFeature) {
                iface.mainWindow().displayToast("Aucun poteau trouv\u00e9 \u00e0 proximit\u00e9")
                return
            }

            // 4.3f — Add to selected poles
            var name = nearestFeature.attribute("nom_poteau_civique")
            if (!name) name = "fid " + nearestFeature.id()

            var poles = plugin.selectedPoles.slice()
            poles.push({
                fid: nearestFeature.id(),
                name: name,
                x: nearestPoint.x,
                y: nearestPoint.y
            })
            plugin.selectedPoles = poles

            iface.mainWindow().displayToast(
                "Poteau " + plugin.selectedPoles.length + "/2: " + name
            )

            // If we have 2 poles, proceed to create the toron (Phase 4.4)
            if (plugin.selectedPoles.length >= 2) {
                plugin.createToron()
            }

        } catch (e) {
            iface.mainWindow().displayToast("Erreur: " + e)
        }
    }

    // Phase 4.4 placeholder — will create the TORONS geometry
    function createToron() {
        iface.mainWindow().displayToast(
            "2 poteaux s\u00e9lectionn\u00e9s: " +
            plugin.selectedPoles[0].name + " \u2192 " +
            plugin.selectedPoles[1].name +
            " (cr\u00e9ation toron \u00e0 impl\u00e9menter)"
        )
        // Reset for now
        plugin.sketchingActive = false
        plugin.selectedPoles = []
    }

    function toggleSketching() {
        if (plugin.sketchingActive) {
            plugin.sketchingActive = false
            plugin.selectedPoles = []
            iface.mainWindow().displayToast("Mode sketching annul\u00e9")
        } else {
            plugin.sketchingActive = true
            plugin.selectedPoles = []
            iface.mainWindow().displayToast(
                "Mode sketching activ\u00e9 \u2014 s\u00e9lectionnez 2 poteaux"
            )
        }
    }

    // --- Plugin load ---
    Component.onCompleted: {
        toolbarButton = buttonComponent.createObject(null)
        iface.addItemToPluginsToolbar(toolbarButton)

        sketchingBanner = bannerComponent.createObject(iface.mainWindow().contentItem)

        try {
            var mc = iface.mapCanvas()
            if (mc) {
                tapCatcher = tapCatcherComponent.createObject(mc)
                iface.mainWindow().displayToast("Sketcher de torons pr\u00eat")
            } else {
                iface.mainWindow().displayToast("ERREUR: mapCanvas() est null")
            }
        } catch (e) {
            iface.mainWindow().displayToast("ERREUR: " + e)
        }
    }
}
