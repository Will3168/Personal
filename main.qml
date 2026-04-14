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

    // --- Cached layer reference ---
    property var poteauxLayer: null

    // --- References to objects created at runtime ---
    property var toolbarButton: null
    property var sketchingBanner: null
    property var tapCatcher: null

    // --- Expression evaluator for geometry access ---
    ExpressionEvaluator {
        id: exprEval
    }

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

    // --- Sketching mode banner ---
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

            onClicked: {
                plugin.handleMapTap(Qt.point(mouseX, mouseY))
            }
        }
    }

    // --- Logic ---

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
            } catch (e) {}
        }
        return null
    }

    function handleMapTap(screenPoint) {
        try {
            // 4.3a — Convert screen pixels to map coordinates
            var mapSettings = iface.mapCanvas().mapSettings
            var mapPoint = mapSettings.screenToCoordinate(screenPoint)
            var tapX = mapPoint.x
            var tapY = mapPoint.y

            // 4.3b — Find the POTEAUX layer
            var layer = findPoteauxLayer()
            if (!layer) {
                iface.mainWindow().displayToast("Couche POTEAUX introuvable")
                return
            }

            // 4.3c — Find nearest pole
            // Diagnostic pass: check what getFeature returns and what ExpressionEvaluator gives us
            exprEval.layer = layer

            // STRATEGY: use QGIS aggregate() expression passed to evaluate().
            // Runs on C++ side with full geometry access, returns a single fid.
            // Tolerance: 5 meters ≈ 0.000045 degrees at ~46° latitude
            var tolerance = 0.000045
            var layerName = layer.name
            var filterExpr = "distance($geometry, make_point(" + tapX + "," + tapY + ")) < " + tolerance

            // aggregate() returns the min fid of features matching the filter.
            // Note: inside aggregate(), the sub-expression is a string — use single quotes.
            var aggExpr = "aggregate(layer:='" + layerName +
                          "', aggregate:='min', expression:='$id', filter:='" +
                          filterExpr + "')"

            var nearestFid = -1
            var aggResult = "?"
            try {
                exprEval.layer = layer
                aggResult = exprEval.evaluate(aggExpr)
                var n = Number(aggResult)
                if (!isNaN(n) && n > 0) {
                    nearestFid = n
                }
            } catch(e) {
                aggResult = "err:" + e
            }

            iface.mainWindow().displayToast(
                "tap=" + tapX.toFixed(4) + "," + tapY.toFixed(4) +
                " | layer='" + layerName + "'" +
                " | agg=" + aggResult +
                " fid=" + nearestFid
            )

            if (nearestFid < 0) {
                return
            }

            // Get the pole name for the selected feature
            var nearestName = ""
            var feat = layer.getFeature(nearestFid)
            if (feat) {
                nearestName = feat.attribute("nom_poteau_civique") || ("fid=" + nearestFid)
            }

            // Placeholders (we can fetch real x/y later when building geometry)
            var nearestX = tapX
            var nearestY = tapY

            // Check not selecting same pole twice
            if (plugin.selectedPoles.length === 1 && plugin.selectedPoles[0].fid === nearestFid) {
                iface.mainWindow().displayToast("Même poteau — choisissez un autre")
                return
            }

            var poles = plugin.selectedPoles.slice()
            poles.push({
                fid: nearestFid,
                name: "" + nearestName,
                x: nearestX,
                y: nearestY
            })
            plugin.selectedPoles = poles

            iface.mainWindow().displayToast(
                "Poteau " + plugin.selectedPoles.length + "/2: " + nearestName
            )

            // If we have 2 poles, create the toron
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
            "2 poteaux: " +
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
