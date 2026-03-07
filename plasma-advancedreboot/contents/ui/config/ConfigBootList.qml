import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as Plasma5Support
import QtQml.Models

Item {
    id: page
    
    property string title: i18n("Boot List")
    
    property string cfg_customEntryRules: "[]"
    property string cfg_customEntryRulesDefault: "[]"
    property string cfg_cachedBootEntries: ""
    property string cfg_cachedBootEntriesDefault: ""
    
    // Dummy properties for KCM compatibility
    property double cfg_backgroundOpacity
    property double cfg_backgroundOpacityDefault
    property string cfg_cachedBootloader
    property string cfg_cachedBootloaderDefault
    property int cfg_edgeMargin
    property int cfg_edgeMarginDefault
    property int cfg_listItemHeight
    property int cfg_listItemHeightDefault
    property int cfg_viewMode
    property int cfg_viewModeDefault
    
    onCfg_cachedBootEntriesChanged: refreshModel()
    onCfg_customEntryRulesChanged: refreshModel()
    
    ListModel {
        id: bootListModel
    }
    
    // Internal function to combine cache + current rules on tab load
    function refreshModel() {
        bootListModel.clear()
        if (cfg_cachedBootEntries === "") return
        try {
            var entries = JSON.parse(cfg_cachedBootEntries)
            var rules = []
            if (cfg_customEntryRules !== "" && cfg_customEntryRules !== "[]") {
                rules = JSON.parse(cfg_customEntryRules)
            }
            
            var rulesMap = {}
            for (var r=0; r<rules.length; r++) {
               rulesMap[rules[r].id] = rules[r]
            }
            
            var addedIds = {}
            
            // 1. Add customized components in sorted order
            for (var i=0; i<rules.length; i++) {
                var rule = rules[i]
                var found = null
                for(var e=0; e<entries.length; e++) {
                   if (entries[e].id === rule.id) {
                      found = entries[e]
                      break
                   }
                }
                
                if (found) {
                   bootListModel.append({
                       id: found.id,
                       originalTitle: found.title,
                       titleToDisplay: rule.customTitle ? rule.customTitle : found.title,
                       isHidden: rule.isHidden !== undefined ? rule.isHidden : false,
                       customIcon: rule.customIcon ? rule.customIcon : ""
                   })
                   addedIds[found.id] = true
                }
            }
            // 2. Add remaining uncustomized
            for (var j=0; j<entries.length; j++) {
                if (!addedIds[entries[j].id]) {
                   bootListModel.append({
                       id: entries[j].id,
                       originalTitle: entries[j].title,
                       titleToDisplay: entries[j].title,
                       isHidden: false,
                       customIcon: ""
                   })
                }
            }
        } catch(e) { console.error("ConfigBootList: Error loading lists - " + e) }
    }
    
    Component.onCompleted: refreshModel()
    
    function saveRules() {
        var rules = []
        for (var i=0; i<bootListModel.count; i++) {
            var item = bootListModel.get(i)
            rules.push({
                id: item.id,
                isHidden: item.isHidden,
                customTitle: item.titleToDisplay !== item.originalTitle ? item.titleToDisplay : "",
                customIcon: item.customIcon,
                orderIndex: i
            })
        }
        page.cfg_customEntryRules = JSON.stringify(rules)
    }

    ColumnLayout {
         anchors.fill: parent
         anchors.margins: Kirigami.Units.largeSpacing
         spacing: Kirigami.Units.smallSpacing

         Label {
             Layout.fillWidth: true
             text: i18n("Reorder entries by dragging. Configure visibility and custom names.")
             color: Kirigami.Theme.disabledTextColor
             wrapMode: Text.WordWrap
         }

         ListView {
             id: entryListView
             Layout.fillWidth: true
             Layout.fillHeight: true
             clip: true
             model: bootListModel
             
             delegate: Item {
                 id: delegateRoot
                 width: ListView.view.width
                 height: Kirigami.Units.iconSizes.huge
                 
                 property bool isUpdating: false
                 
                 Rectangle {
                     anchors.fill: parent
                     anchors.margins: 4
                     color: Kirigami.Theme.backgroundColor
                     border.color: Kirigami.Theme.disabledTextColor
                     radius: 4
                     opacity: model.isHidden ? 0.6 : 1.0
                     
                     RowLayout {
                         anchors.fill: parent
                         anchors.margins: Kirigami.Units.smallSpacing
                         
                         // Drag Handle
                         Kirigami.Icon {
                             Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                             Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                             source: "drag-handle"
                             
                             MouseArea {
                                 anchors.fill: parent
                                 cursorShape: Qt.SizeVerCursor
                             }
                         }
                         
                         // Icon button (Feature idea: click to select custom icon)
                         Button {
                             Layout.minimumWidth: Kirigami.Units.iconSizes.medium
                             icon.name: model.customIcon !== "" ? model.customIcon : "system-run"
                             flat: true
                         }
                         
                         // Title Field
                         TextField {
                             Layout.fillWidth: true
                             text: model.titleToDisplay
                             placeholderText: model.originalTitle
                             onEditingFinished: {
                                 if (!delegateRoot.isUpdating) {
                                     bootListModel.setProperty(index, "titleToDisplay", text)
                                     saveRules()
                                 }
                             }
                         }
                         
                         // Visibility Toggle
                         ToolButton {
                             icon.name: model.isHidden ? "view-hidden" : "view-visible"
                             onClicked: {
                                 bootListModel.setProperty(index, "isHidden", !model.isHidden)
                                 saveRules()
                             }
                         }
                     }
                 }
             }
         }
         
         RowLayout {
             Layout.fillWidth: true
             Item { Layout.fillWidth: true }
             Button {
                 text: i18n("Restore Defaults")
                 icon.name: "edit-undo"
                 onClicked: {
                     page.cfg_customEntryRules = "[]"
                     refreshModel()
                 }
             }
         }
    }
}
