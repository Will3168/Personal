import QtQuick
import QtQuick.Controls
import org.qfield
import org.qgis
import Theme

Item {
    id: plugin

    property var toolbarButton: null

    Component {
        id: buttonComponent

        QfToolButton {
            id: sketcherButton
            iconSource: "icon.svg"
            bgcolor: Theme.darkGray
            round: true

            onClicked: {
                iface.mainMessageLog().logMessage("Sketcher", "Button clicked!")
            }
        }
    }

    Component.onCompleted: {
        toolbarButton = buttonComponent.createObject(null)
        iface.addItemToPluginsToolbar(toolbarButton)
    }
}