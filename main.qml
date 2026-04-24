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

    // --- Cached layer references ---
    property var poteauxLayer: null
    property var toronsLayer: null

    // --- QField's built-in attribute form drawer (looked up at load time) ---
    property var overlayFeatureFormDrawer: null

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

    function findToronsLayer() {
        if (plugin.toronsLayer) return plugin.toronsLayer

        var namesToTry = [
            "TORONS",
            "demo_releve_alias 1 \u2014 TORONS",
            "demo_releve_alias \u2014 TORONS"
        ]

        for (var i = 0; i < namesToTry.length; i++) {
            try {
                var results = qgisProject.mapLayersByName(namesToTry[i])
                if (results && results.length > 0) {
                    plugin.toronsLayer = results[0]
                    return plugin.toronsLayer
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

            // 4.3c — Collect fids + coords via aggregate(), then find nearest in JS.
            exprEval.layer = layer
            exprEval.project = qgisProject
            var tolerance = 0.000045
            var layerName = layer.name

            function evalExpr(expr) {
                try {
                    exprEval.expressionText = expr
                    return exprEval.evaluate()
                } catch (e) { return null }
            }

            var idsRaw = evalExpr(
                "aggregate(layer:='" + layerName +
                "', aggregate:='concatenate', expression:=to_string(\"fid\"), concatenator:='|')"
            )
            var xsRaw = evalExpr(
                "aggregate(layer:='" + layerName +
                "', aggregate:='concatenate', expression:=to_string(x($geometry)), concatenator:='|')"
            )
            var ysRaw = evalExpr(
                "aggregate(layer:='" + layerName +
                "', aggregate:='concatenate', expression:=to_string(y($geometry)), concatenator:='|')"
            )

            var idsStr = idsRaw == null ? "" : String(idsRaw)
            var xsStr  = xsRaw  == null ? "" : String(xsRaw)
            var ysStr  = ysRaw  == null ? "" : String(ysRaw)

            var ids = idsStr ? idsStr.split("|") : []
            var xs  = xsStr  ? xsStr.split("|")  : []
            var ys  = ysStr  ? ysStr.split("|")  : []
            var n = Math.min(ids.length, xs.length, ys.length)

            console.log("[toron_sketcher] agg n=" + n +
                        " first: id=" + ids[0] + " x=" + xs[0] + " y=" + ys[0])

            var nearestFid = -1
            var nearestX = NaN, nearestY = NaN
            var bestDistSq = Infinity
            for (var i = 0; i < n; i++) {
                var px = Number(xs[i])
                var py = Number(ys[i])
                if (isNaN(px) || isNaN(py)) continue

                var dx = px - tapX
                var dy = py - tapY
                var dsq = dx * dx + dy * dy
                if (dsq < bestDistSq) {
                    bestDistSq = dsq
                    nearestFid = Number(ids[i])
                    nearestX = px
                    nearestY = py
                }
            }

            var bestDist = Math.sqrt(bestDistSq)
            var distStr = isFinite(bestDist) ? bestDist.toFixed(6) : "inf"

            if (nearestFid < 0 || bestDist > tolerance) {
                iface.mainWindow().displayToast(
                    "n=" + n +
                    " idsRaw[0:30]=" + idsStr.substring(0, 30) +
                    " xsRaw[0:30]=" + xsStr.substring(0, 30) +
                    " tap=(" + tapX.toFixed(2) + "," + tapY.toFixed(2) + ")"
                )
                return
            }

            iface.mainWindow().displayToast(
                "n=" + n + " fid=" + nearestFid + " d=" + distStr
            )

            // Get the pole name for the selected feature
            var nearestName = ""
            var feat = layer.getFeature(nearestFid)
            if (feat) {
                nearestName = feat.attribute("nom_poteau_civique") || ("fid=" + nearestFid)
            }

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

    function createToron() {
        try {
            var toronsLayer = findToronsLayer()
            if (!toronsLayer) {
                iface.mainWindow().displayToast("Couche TORONS introuvable")
                return
            }

            var p1 = plugin.selectedPoles[0]
            var p2 = plugin.selectedPoles[1]

            var wkt = "MULTILINESTRING((" +
                      p1.x + " " + p1.y + ", " +
                      p2.x + " " + p2.y + "))"
            console.log("[toron_sketcher] creating toron:", wkt)

            var geometry = GeometryUtils.createGeometryFromWkt(wkt)
            var feature = FeatureUtils.createBlankFeature(toronsLayer.fields, geometry)

            if (!plugin.overlayFeatureFormDrawer) {
                plugin.overlayFeatureFormDrawer = iface.findItemByObjectName("overlayFeatureFormDrawer")
            }
            if (!plugin.overlayFeatureFormDrawer) {
                iface.mainWindow().displayToast("Form drawer introuvable")
                return
            }

            plugin.overlayFeatureFormDrawer.featureModel.currentLayer = toronsLayer
            plugin.overlayFeatureFormDrawer.featureModel.feature = feature
            plugin.overlayFeatureFormDrawer.featureModel.resetAttributes(true)
            plugin.overlayFeatureFormDrawer.state = "Add"
            plugin.overlayFeatureFormDrawer.open()

            plugin.sketchingActive = false
            plugin.selectedPoles = []
        } catch (e) {
            console.error("[toron_sketcher] createToron failed:", e.message, e.stack)
            try { iface.mainWindow().displayToast("Erreur toron: " + e) } catch (e2) {}
        }
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
