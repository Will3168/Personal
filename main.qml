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

            // DIAGNOSTIC: discover what's available
            var tapNum = plugin.selectedPoles.length

            if (tapNum === 0) {
                // Tap 1: list FeatureListModel properties
                var modelProps = []
                for (var k in poteauxModel) {
                    modelProps.push(k)
                }
                iface.mainWindow().displayToast("Model props: " + modelProps.join(", "))
                plugin.selectedPoles = ["tap1"]
                return
            }

            if (tapNum === 1) {
                // Tap 2: list layer properties
                var layerProps = []
                for (var k2 in layer) {
                    layerProps.push(k2)
                }
                iface.mainWindow().displayToast("Layer props: " + layerProps.join(", "))
                plugin.selectedPoles = ["tap1", "tap2"]
                return
            }

            if (tapNum === 2) {
                // Tap 3: list iface methods that might help with features
                var ifaceProps = []
                for (var k3 in iface) {
                    if (("" + k3).toLowerCase().indexOf("feat") >= 0 ||
                        ("" + k3).toLowerCase().indexOf("ident") >= 0 ||
                        ("" + k3).toLowerCase().indexOf("sketc") >= 0 ||
                        ("" + k3).toLowerCase().indexOf("layer") >= 0) {
                        ifaceProps.push(k3)
                    }
                }
                iface.mainWindow().displayToast("iface (filtered): " + ifaceProps.join(", "))
                plugin.selectedPoles = []
                return
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
