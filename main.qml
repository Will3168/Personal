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
        console.log("[toron_sketcher] handleMapTap screenPoint=", screenPoint.x, screenPoint.y)
        try {
            // 4.3a — Convert screen pixels to map coordinates
            var mapSettings = iface.mapCanvas().mapSettings
            var mapPoint = mapSettings.screenToCoordinate(screenPoint)
            var tapX = mapPoint.x
            var tapY = mapPoint.y
            console.log("[toron_sketcher] tap mapCoord=", tapX, tapY)

            // 4.3b — Find the POTEAUX layer
            var layer = findPoteauxLayer()
            if (!layer) {
                console.warn("[toron_sketcher] POTEAUX layer not found")
                iface.mainWindow().displayToast("Couche POTEAUX introuvable")
                return
            }
            console.log("[toron_sketcher] layer found:", layer.name)

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
            console.error("[toron_sketcher] handleMapTap failed:", e.message, e.stack)
            try { iface.mainWindow().displayToast("Erreur: " + e) } catch (e2) {}
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
        console.log("[toron_sketcher] toggleSketching called, currently active=", plugin.sketchingActive)
        try {
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
        } catch (e) {
            console.error("[toron_sketcher] toggleSketching failed:", e.message, e.stack)
        }
    }

    // --- Plugin load ---
    Component.onCompleted: {
        console.log("[toron_sketcher] Component.onCompleted starting")

        try {
            toolbarButton = buttonComponent.createObject(null)
            if (!toolbarButton) {
                console.error("[toron_sketcher] buttonComponent.createObject returned null")
            } else {
                console.log("[toron_sketcher] toolbarButton created")
            }
            iface.addItemToPluginsToolbar(toolbarButton)
            console.log("[toron_sketcher] toolbar button added")
        } catch (e) {
            console.error("[toron_sketcher] toolbar setup failed:", e.message, e.stack)
        }

        try {
            sketchingBanner = bannerComponent.createObject(iface.mainWindow().contentItem)
            if (!sketchingBanner) {
                console.warn("[toron_sketcher] sketchingBanner is null after createObject")
            } else {
                console.log("[toron_sketcher] sketching banner created")
            }
        } catch (e) {
            console.error("[toron_sketcher] banner setup failed:", e.message, e.stack)
        }

        try {
            var mc = iface.mapCanvas()
            if (mc) {
                tapCatcher = tapCatcherComponent.createObject(mc)
                console.log("[toron_sketcher] tap catcher installed on map canvas")
                iface.mainWindow().displayToast("Sketcher de torons pr\u00eat")
            } else {
                console.error("[toron_sketcher] iface.mapCanvas() returned null")
                iface.mainWindow().displayToast("ERREUR: mapCanvas() est null")
            }
        } catch (e) {
            console.error("[toron_sketcher] map canvas setup failed:", e.message, e.stack)
            try { iface.mainWindow().displayToast("ERREUR: " + e) } catch (e2) {}
        }

        console.log("[toron_sketcher] Component.onCompleted finished")
    }
}
