import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

Item {
    id: root

    required property var categoryModel
    required property string title
    required property real iconSize
    required property real smallIconSize
    required property real cardSize
    required property int categoryIndex
    
    property bool isExpanded: false
    property real parentWidth: 0
    signal toggleExpand()

    property bool breezeStyle: typeof(Plasmoid) !== 'undefined' ? (Plasmoid.configuration.breezeStyle ?? true) : true
    property int animDuration: typeof(Plasmoid) !== 'undefined' ? (Plasmoid.configuration.animationSpeed ?? 200) : 200
    property int configIconSize: typeof(Plasmoid) !== 'undefined' ? (Plasmoid.configuration.iconSize ?? 48) : 48
    property bool configShowLabels: typeof(Plasmoid) !== 'undefined' ? (Plasmoid.configuration.showLabelsInTiles ?? true) : true

    // Grid sizing calculations
    property real cellW: Kirigami.Units.gridUnit * 6
    property real cellH: cellW + 30
    property int gridCols: Math.max(1, Math.floor((parentWidth - 40) / cellW))
    property int gridRows: categoryModel ? Math.ceil(categoryModel.count / gridCols) : 0
    property real gridContentHeight: gridRows * cellH

    // Total expanded height calculation
    property real expandedHeight: cardSize + 40 + gridContentHeight

    // The dimensions of this specific delegate bounds
    width: isExpanded ? parentWidth : cardSize
    height: isExpanded ? expandedHeight : cardSize + 30

    // Prevent implicit animations from glitching when layout shrinks
    clip: true

    property bool isHovered: hoverArea.containsMouse

    Rectangle {
        id: bg
        anchors.fill: parent
        // When collapsed, the rectangle is square (doesn't cover the title)
        anchors.bottomMargin: root.isExpanded ? 0 : 30
        
        color: root.isExpanded 
            ? Qt.rgba(Kirigami.Theme.backgroundColor.r, Kirigami.Theme.backgroundColor.g, Kirigami.Theme.backgroundColor.b, 0.95) 
            : (root.isHovered 
                ? (breezeStyle ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.2) : Kirigami.Theme.hoverColor)
                : (breezeStyle ? "transparent" : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.05)))
        radius: 12
        border.color: root.isExpanded 
            ? Kirigami.Theme.highlightColor 
            : (breezeStyle ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.3) : "transparent")
        border.width: root.isExpanded ? 2 : (breezeStyle ? 1 : 0)
        
        Behavior on color { ColorAnimation { duration: animDuration } }
        Behavior on anchors.bottomMargin { NumberAnimation { duration: animDuration; easing.type: Easing.OutCubic } }

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
                if (root.categoryModel && root.categoryModel.count > 0) {
                     root.toggleExpand()
                }
            }
        }

        // --- Expanded State Content ---
        
        // Custom Close Button and Title
        Item {
            id: headerArea
            width: parent.width
            height: 40 // Thinner header
            opacity: root.isExpanded ? 1 : 0
            visible: opacity > 0
            anchors.top: parent.top
            
            Behavior on opacity { NumberAnimation { duration: animDuration } }
            
            Text {
                text: root.title
                anchors.left: parent.left
                anchors.leftMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                font.bold: true
                color: Kirigami.Theme.textColor
                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
            }
            
            ToolButton {
                icon.name: "window-close"
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: 10
                implicitWidth: 24
                implicitHeight: 24
                onClicked: root.toggleExpand()
            }
            
            Rectangle {
                width: parent.width - 40
                height: 1
                color: Kirigami.Theme.highlightColor
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                opacity: 0.15
            }
        }

        // Inner Grid (Expanded mode)
        GridView {
            id: innerGrid
            width: parent.width - 40
            height: root.gridContentHeight
            anchors.top: headerArea.bottom
            anchors.topMargin: Kirigami.Units.largeSpacing
            anchors.horizontalCenter: parent.horizontalCenter
            
            interactive: false // Height fits all items
            cellWidth: root.cellW
            cellHeight: root.cellH
            
            opacity: root.isExpanded ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: animDuration } }
            
            model: root.categoryModel
            
            delegate: Item {
                width: innerGrid.cellWidth
                height: innerGrid.cellHeight
                
                id: staggeredItem
                required property int index
                required property string display
                required property var decoration
                
                property bool isHovered: itemHoverArea.containsMouse
                
                // --- Animation Logic for Transition from Collapsed to Expanded ---
                // Items 0-3 are visible in collapsed state.
                // We want them to animate from their collapsed positions.
                
                readonly property bool isInitialItem: index < 4
                
                // Initial positions (offsets relative to final expanded position)
                // This is a rough estimation since we don't have absolute coordinates easily
                property real startX: {
                    if (!isInitialItem) return 0
                    // In collapsed, it's a 2x2 grid centered.
                    // Let's just use a fixed offset to make it look like it's expanding from center.
                    var col = index % 2
                    var row = Math.floor(index / 2)
                    return (col - 0.5) * 50
                }
                property real startY: {
                    if (!isInitialItem) return -100 // Header height offset roughly
                    var row = Math.floor(index / 2)
                    return (row - 0.5) * 50 - 100
                }

                opacity: root.isExpanded ? 1 : 0
                
                transform: Translate {
                    id: staggeredTranslate
                    x: root.isExpanded ? 0 : staggeredItem.startX
                    y: root.isExpanded ? 0 : staggeredItem.startY
                    
                    Behavior on x { NumberAnimation { duration: root.animDuration; easing.type: Easing.OutBack } }
                    Behavior on y { NumberAnimation { duration: root.animDuration; easing.type: Easing.OutBack } }
                }

                readonly property int staggerDelay: isInitialItem ? 0 : (index - 3) * 50

                SequentialAnimation {
                    running: root.isExpanded
                    PauseAnimation { duration: Math.max(0, staggeredItem.staggerDelay) }
                    NumberAnimation {
                        target: staggeredItem
                        property: "opacity"
                        to: 1
                        duration: 200
                    }
                }

                // Reset state when closed
                onVisibleChanged: {
                    if (!root.isExpanded) {
                        staggeredItem.opacity = 0;
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    color: breezeStyle 
                        ? (isHovered ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.2) : "transparent")
                        : (isHovered ? Kirigami.Theme.highlightColor : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.2))
                    opacity: 1
                    border.width: 0 // Remove borders as requested
                    radius: Kirigami.Units.smallSpacing
                    Behavior on color { ColorAnimation { duration: animDuration } }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 5
                    width: parent.width
                    
                    Kirigami.Icon {
                        source: decoration
                        width: root.configIconSize
                        height: width
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    
                    Text {
                        text: display
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        color: Kirigami.Theme.textColor
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    }
                }
                
                MouseArea {
                    id: itemHoverArea
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.RightButton) {
                            localContextMenu.actionItem = {
                                display: display,
                                decoration: decoration,
                                matchId: display, // App name
                                category: root.title,
                                triggerFunc: function() {
                                    if (root.categoryModel && root.categoryModel.trigger) {
                                        root.categoryModel.trigger(index, "", null)
                                        try { Plasmoid.expanded = false; } catch(e) {}
                                    }
                                }
                            };
                            localContextMenu.popup();
                        } else {
                            if (root.categoryModel && root.categoryModel.trigger) {
                                root.categoryModel.trigger(index, "", null)
                                try { Plasmoid.expanded = false; } catch(e) {}
                            }
                        }
                    }
                }
            }
        }

        // --- Collapsed State Content ---
        
        Item {
            id: collapsedContent
            width: root.cardSize
            height: root.cardSize
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            opacity: root.isExpanded ? 0 : 1
            visible: opacity > 0
            
            Behavior on opacity { NumberAnimation { duration: animDuration } }

            Grid {
                anchors.centerIn: parent
                columns: 2
                spacing: 10
                
                Component {
                    id: itemDelegate
                    Item {
                        width: (root.cardSize - 30) / 2
                        height: width
                        
                        Column {
                            anchors.centerIn: parent
                            spacing: 2
                            width: parent.width
                            
                            Kirigami.Icon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                source: modelDataDecoration
                                width: root.iconSize
                                height: root.iconSize
                            }

                            Text {
                                text: modelDataDisplay
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                font.pixelSize: Kirigami.Theme.smallFont.pixelSize * 0.8
                                color: Kirigami.Theme.textColor
                                maximumLineCount: 1
                                visible: text !== "" && Plasmoid.configuration.showLabelsInTiles
                            }
                        }
                    }
                }

                Loader {
                    sourceComponent: itemDelegate
                    visible: root.categoryModel?.count > 0
                    property string modelDataDecoration: visible ? root.categoryModel.data(root.categoryModel.index(0, 0), Qt.DecorationRole) : ""
                    property string modelDataDisplay: visible ? root.categoryModel.data(root.categoryModel.index(0, 0), Qt.DisplayRole) : ""
                }

                Loader {
                    sourceComponent: itemDelegate
                    visible: root.categoryModel?.count > 1
                    property string modelDataDecoration: visible ? root.categoryModel.data(root.categoryModel.index(1, 0), Qt.DecorationRole) : ""
                    property string modelDataDisplay: visible ? root.categoryModel.data(root.categoryModel.index(1, 0), Qt.DisplayRole) : ""
                }

                Loader {
                    sourceComponent: itemDelegate
                    visible: root.categoryModel?.count > 2
                    property string modelDataDecoration: visible ? root.categoryModel.data(root.categoryModel.index(2, 0), Qt.DecorationRole) : ""
                    property string modelDataDisplay: visible ? root.categoryModel.data(root.categoryModel.index(2, 0), Qt.DisplayRole) : ""
                }

                Item {
                    width: (root.cardSize - 30) / 2
                    height: width
                    visible: root.categoryModel?.count > 3
                    
                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        width: parent.width
                        visible: root.categoryModel?.count <= 4 && root.categoryModel?.count > 3

                        Kirigami.Icon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            source: parent.visible ? root.categoryModel.data(root.categoryModel.index(3, 0), Qt.DecorationRole) : ""
                            width: root.iconSize
                            height: root.iconSize
                        }
                        
                        Text {
                            text: parent.visible ? root.categoryModel.data(root.categoryModel.index(3, 0), Qt.DisplayRole) : ""
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            font.pixelSize: Kirigami.Theme.smallFont.pixelSize * 0.8
                            color: Kirigami.Theme.textColor
                            maximumLineCount: 1
                            visible: text !== "" && root.configShowLabels
                        }
                    }
                    
                    Grid {
                        anchors.centerIn: parent
                        visible: root.categoryModel?.count > 4
                        columns: 2
                        spacing: 2
                        
                        Repeater {
                            model: 4
                            delegate: Kirigami.Icon {
                                required property int index
                                property int itemIndex: 3 + index
                                visible: root.categoryModel?.count > itemIndex
                                source: visible ? root.categoryModel.data(root.categoryModel.index(itemIndex, 0), Qt.DecorationRole) : ""
                                width: root.smallIconSize
                                height: root.smallIconSize
                            }
                        }
                    }
                }
            }
        }
    }
    
    // External Title below the card when collapsed
    Text {
        id: externalTitle
        text: root.title
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        opacity: root.isExpanded ? 0 : 1
        visible: opacity > 0
        
        font.bold: true
        color: Kirigami.Theme.textColor
        font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
        elide: Text.ElideRight
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        
        Behavior on opacity { NumberAnimation { duration: animDuration } }
    }
    
    AppContextMenu {
        id: localContextMenu
    }
}
