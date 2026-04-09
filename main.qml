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
    property var mapCanvasRef: null

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

    // --- Map tap capture (DEBUG: brute-force signal detection) ---
    // Listen to several possible signals to find which one the map canvas actually emits.
    // Once we know the right one, delete the others.
    Connections {
        target: plugin.mapCanvasRef

        function onClicked(point) {
            iface.mainWindow().displayToast("clicked fired!")
            console.log("[Sketcher DEBUG] onClicked fired", point)
            if (plugin.sketchingActive) plugin.handleMapTap(point)
        }

        function onMapClicked(point) {
            iface.mainWindow().displayToast("mapClicked fired!")
            console.log("[Sketcher DEBUG] onMapClicked fired", point)
            if (plugin.sketchingActive) plugin.handleMapTap(point)
        }

        function onCanvasClicked(point) {
            iface.mainWindow().displayToast("canvasClicked fired!")
            console.log("[Sketcher DEBUG] onCanvasClicked fired", point)
            if (plugin.sketchingActive) plugin.handleMapTap(point)
        }

        function onLongPressed(point) {
            iface.mainWindow().displayToast("longPressed fired!")
            console.log("[Sketcher DEBUG] onLongPressed fired", point)
            if (plugin.sketchingActive) plugin.handleMapTap(point)
        }

        function onPressed(point) {
            iface.mainWindow().displayToast("pressed fired!")
            console.log("[Sketcher DEBUG] onPressed fired", point)
            if (plugin.sketchingActive) plugin.handleMapTap(point)
        }

        function onReleased(point) {
            iface.mainWindow().displayToast("released fired!")
            console.log("[Sketcher DEBUG] onReleased fired", point)
            if (plugin.sketchingActive) plugin.handleMapTap(point)
        }

        function onTapped(point) {
            iface.mainWindow().displayToast("tapped fired!")
            console.log("[Sketcher DEBUG] onTapped fired", point)
            if (plugin.sketchingActive) plugin.handleMapTap(point)
        }
    }

    // --- Logic ---
    function handleMapTap(point) {
        // Placeholder for Phase 4.3 (spatial query)
        // `point` should be a screen or map coordinate depending on the signal
        iface.mainWindow().displayToast("Tap détecté: " + point.x + ", " + point.y)
        console.log("[Sketcher] Map tap at:", point.x, point.y,
                    "| selectedPoles.length =", plugin.selectedPoles.length)
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

        // --- DIAGNOSTICS ---
        console.log("[Sketcher DEBUG] ================================")
        console.log("[Sketcher DEBUG] Plugin loaded")
        console.log("[Sketcher DEBUG] iface =", iface)
        console.log("[Sketcher DEBUG] iface.mapCanvas =", iface.mapCanvas)
        try {
            var mc = iface.mapCanvas()
            console.log("[Sketcher DEBUG] iface.mapCanvas() =", mc)
            console.log("[Sketcher DEBUG] typeof =", typeof mc)
            if (mc) {
                console.log("[Sketcher DEBUG] mc.toString =", mc.toString())
                // Try to list properties/signals
                for (var k in mc) {
                    console.log("[Sketcher DEBUG]   member:", k)
                }
            } else {
                console.log("[Sketcher DEBUG] mapCanvas() returned null/undefined")
            }
            plugin.mapCanvasRef = mc
            console.log("[Sketcher DEBUG] mapCanvasRef set to", plugin.mapCanvasRef)
        } catch (e) {
            console.log("[Sketcher DEBUG] ERROR calling mapCanvas():", e)
            iface.mainWindow().displayToast("ERROR: " + e)
        }
        console.log("[Sketcher DEBUG] ================================")

        iface.mainWindow().displayToast("Plugin loaded — check log")
    }
}
