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
                      ? "Mode sketching actif — tappez le premier poteau"
                      : "Mode sketching actif — tappez le deuxième poteau"
                color: "white"
                font.bold: true
                font.pixelSize: 16
            }
        }
    }

    // --- Map tap capture (MouseArea overlay approach) ---
    // Signals on iface.mapCanvas() didn't fire, so we use a MouseArea placed
    // directly over the map canvas. It's only enabled when sketching is active,
    // so normal map interaction (pan/zoom) is preserved when the plugin is off.
    Component {
        id: tapCatcherComponent

        MouseArea {
            id: catcher
            anchors.fill: parent
            enabled: plugin.sketchingActive
            z: 999
            propagateComposedEvents: true

            onClicked: (mouse) => {
                plugin.handleMapTap(Qt.point(mouse.x, mouse.y))
                mouse.accepted = false
            }

            onPressed: (mouse) => {
                mouse.accepted = false
            }
        }
    }

    // --- Logic ---
    // Phase 4.3a+b — convert screen→map coords, then access POTEAUX layer
    function handleMapTap(screenPoint) {
        try {
            // 4.3a — Convert screen pixels to map coordinates
            var mapSettings = iface.mapCanvas().mapSettings
            var mapPoint = mapSettings.screenToCoordinate(screenPoint)

            // 4.3b — Find the POTEAUX layer
            // Search all layers for one whose name contains "POTEAUX"
            var allLayers = qgisProject.mapLayers()
            var layer = null
            var layerNames = []
            for (var id in allLayers) {
                var l = allLayers[id]
                layerNames.push(l.name())
                if (l.name().toUpperCase().indexOf("POTEAUX") >= 0) {
                    layer = l
                }
            }
            if (!layer) {
                iface.mainWindow().displayToast(
                    "POTEAUX introuvable. Couches: " + layerNames.join(", ")
                )
                return
            }
            var count = layer.featureCount()
            iface.mainWindow().displayToast(
                "Couche '" + layer.name() + "' trouvée! " + count + " features. Tap: " +
                mapPoint.x.toFixed(4) + ", " + mapPoint.y.toFixed(4)
            )
        } catch (e) {
            iface.mainWindow().displayToast("Erreur 4.3b: " + e)
        }
    }

    function toggleSketching() {
        if (plugin.sketchingActive) {
            // Turning OFF mid-flow: reset state
            plugin.sketchingActive = false
            plugin.selectedPoles = []
            iface.mainWindow().displayToast("Mode sketching annulé")
        } else {
            // Turning ON
            plugin.sketchingActive = true
            plugin.selectedPoles = []
            iface.mainWindow().displayToast("Mode sketching activé — sélectionnez 2 poteaux")
        }
    }

    // --- Plugin load ---
    Component.onCompleted: {
        toolbarButton = buttonComponent.createObject(null)
        iface.addItemToPluginsToolbar(toolbarButton)

        sketchingBanner = bannerComponent.createObject(iface.mainWindow().contentItem)

        // Create the tap catcher as a child of the map canvas so it overlays the map
        try {
            var mc = iface.mapCanvas()
            if (mc) {
                tapCatcher = tapCatcherComponent.createObject(mc)
                iface.mainWindow().displayToast("Plugin prêt (tap catcher OK)")
            } else {
                iface.mainWindow().displayToast("ERREUR: mapCanvas() est null")
            }
        } catch (e) {
            iface.mainWindow().displayToast("ERREUR tap catcher: " + e)
        }
    }
}
