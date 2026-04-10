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

    // --- Feature access model ---
    // QField doesn't expose QgsVectorLayer methods like getFeatures() or
    // featureCount() to QML. Instead we use FeatureListModel, which is
    // QField's QML bridge for reading features from a layer.
    FeatureListModel {
        id: poteauxModel
    }

    // --- Logic ---

    // Find the POTEAUX layer (cached after first lookup)
    function findPoteauxLayer() {
        if (plugin.poteauxLayer) return plugin.poteauxLayer

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
                iface.mainWindow().displayToast("Couche POTEAUX introuvable")
                return
            }

            // Load features into the model
            poteauxModel.currentLayer = layer

            var count = poteauxModel.rowCount()
            if (count === 0) {
                iface.mainWindow().displayToast("Aucun feature dans POTEAUX (count=0)")
                return
            }

            // 4.3c — Build tolerance (40 pixels in map units)
            var mpp = mapSettings.mapUnitsPerPixel
            var tol = mpp * 40

            // 4.3d — Find the nearest pole
            var nearestIndex = -1
            var nearestDist = tol
            var nearestX = 0
            var nearestY = 0

            for (var i = 0; i < count; i++) {
                var modelIndex = poteauxModel.index(i, 0)

                // Try different role names to get the geometry
                var geom = poteauxModel.data(modelIndex, 257)  // Qt.UserRole + 1 often = geometry
                var feat = poteauxModel.data(modelIndex, 256)  // Qt.UserRole often = feature

                // Try to get point coordinates from the feature/geometry
                var px, py
                try {
                    if (feat && feat.geometry) {
                        var pt = feat.geometry().asPoint()
                        px = pt.x; py = pt.y
                    } else if (geom && geom.asPoint) {
                        var pt2 = geom.asPoint()
                        px = pt2.x; py = pt2.y
                    } else {
                        continue
                    }
                } catch (geoErr) {
                    continue
                }

                var dx = px - mapPoint.x
                var dy = py - mapPoint.y
                var dist = Math.sqrt(dx * dx + dy * dy)

                if (dist < nearestDist) {
                    nearestDist = dist
                    nearestDist = dist
                    nearestIndex = i
                    nearestX = px
                    nearestY = py
                }
            }

            // 4.3e — Handle result
            if (nearestIndex < 0) {
                iface.mainWindow().displayToast(
                    "Aucun poteau trouv\u00e9 \u00e0 proximit\u00e9 (count=" + count + ")"
                )
                return
            }

            // 4.3f — Get the feature name and add to selected poles
            var nameIndex = poteauxModel.index(nearestIndex, 0)
            var displayName = poteauxModel.data(nameIndex, Qt.DisplayRole)
            if (!displayName) displayName = "Poteau #" + (nearestIndex + 1)

            var poles = plugin.selectedPoles.slice()
            poles.push({
                index: nearestIndex,
                name: "" + displayName,
                x: nearestX,
                y: nearestY
            })
            plugin.selectedPoles = poles

            iface.mainWindow().displayToast(
                "Poteau " + plugin.selectedPoles.length + "/2: " + displayName
            )

            if (plugin.selectedPoles.length >= 2) {
                plugin.createToron()
            }

        } catch (e) {
            iface.mainWindow().displayToast("Erreur: " + e)
        }
    }

    // Phase 4.4 placeholder
    function createToron() {
        iface.mainWindow().displayToast(
            "2 poteaux s\u00e9lectionn\u00e9s: " +
            plugin.selectedPoles[0].name + " \u2192 " +
            plugin.selectedPoles[1].name +
            " (cr\u00e9ation toron \u00e0 impl\u00e9menter)"
        )
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
