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
                  console.log("Toron Sketcher clicked")
              }
          }
      }

      Component.onCompleted: {
          toolbarButton = buttonComponent.createObject(iface.pluginsToolbar())
          iface.addItemToPluginsToolbar(toolbarButton)
          console.log("Toron Sketcher plugin loaded")
      }
  }
