import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: pickerWindow

    // EDIT THESE for your system — must match wallpaper-set.sh
    property string wallpaperDir: "/home/sujay/Pictures/Wallpapers/"
    property string scriptPath: "/home/sujay/.config/quickshell/scripts/wallpaper-set.sh"
    property string colorFilePath: "/home/sujay/color.txt"

    // Default fallbacks if parsing color.txt fails
    property string accentColor: "#b6c4ff"
    property string panelBgColor: "#141414"

    property bool pickerVisible: false
    property var wallpapers: []

    visible: pickerVisible

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: pickerVisible
        ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.None

    // =========================================================
    // DYNAMIC COLOR PARSER (Extracts ACTIVE= and BG= from file)
    // =========================================================

    Process {
        id: colorProc
        command: ["cat", pickerWindow.colorFilePath]

        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text.split("\n")
                for (let i = 0; i < lines.length; i++) {
                    let line = lines[i].trim()
                    if (line.startsWith("ACTIVE=")) {
                        let val = line.split("=")[1].split(" ")[0].trim()
                        if (val.length > 0) pickerWindow.accentColor = val
                    } else if (line.startsWith("BG=")) {
                        let val = line.split("=")[1].split(" ")[0].trim()
                        if (val.length > 0) pickerWindow.panelBgColor = val
                    }
                }
            }
        }
    }

    function loadColor() {
        colorProc.running = true
    }

    // =========================================================
    // IPC — toggle/open/close from a Hyprland keybind
    // =========================================================

    IpcHandler {
        target: "wallpaper"

        function toggle(): void {
            pickerWindow.pickerVisible = !pickerWindow.pickerVisible
        }

        function open(): void {
            pickerWindow.pickerVisible = true
        }

        function close(): void {
            pickerWindow.pickerVisible = false
        }
    }

    // =========================================================
    // LIST WALLPAPERS ON DISK
    // =========================================================

    Process {
        id: findProc

        command: [
            "find", pickerWindow.wallpaperDir, "-maxdepth", "1", "-type", "f",
            "(",
                "-iname", "*.jpg", "-o",
                "-iname", "*.jpeg", "-o",
                "-iname", "*.png", "-o",
                "-iname", "*.webp",
            ")"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                pickerWindow.wallpapers = this.text
                    .trim()
                    .split("\n")
                    .filter(function(line) { return line.length > 0 })
                    .sort()
            }
        }
    }

    function refresh() {
        findProc.running = true
        loadColor()
    }

    onPickerVisibleChanged: {
        if (pickerVisible) {
            refresh()
            grid.forceActiveFocus()
            grid.currentIndex = 0
        }
    }

    // =========================================================
    // APPLY A WALLPAPER
    // =========================================================

    Process {
        id: applyProc
        command: []
    }

    function applyWallpaper(path) {
        if (!path) return
        applyProc.command = [pickerWindow.scriptPath, path]
        applyProc.running = true
        pickerVisible = false
    }

    // =========================================================
    // UI
    // =========================================================

    // Transparent Scrim — click outside to close
    MouseArea {
        anchors.fill: parent
        onClicked: pickerWindow.pickerVisible = false
    }

    // Right Sidebar Panel
    Rectangle {
        id: panel

        anchors.right: parent.right
        anchors.rightMargin: pickerWindow.pickerVisible ? 32 : -width
        anchors.verticalCenter: parent.verticalCenter

        width: 232
        height: Math.min(parent.height * 0.75, 680)

        radius: 24
        color: pickerWindow.panelBgColor
        border.width: 1
        border.color: "#2affffff"

        scale: pickerWindow.pickerVisible ? 1.0 : 0.85
        opacity: pickerWindow.pickerVisible ? 1.0 : 0.0

        Behavior on anchors.rightMargin { 
            NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.1 } 
        }
        Behavior on scale { 
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic } 
        }
        Behavior on opacity { 
            NumberAnimation { duration: 180 } 
        }
        Behavior on color { 
            ColorAnimation { duration: 150 } 
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        GridView {
            id: grid

            anchors.fill: parent
            anchors.margins: 16

            cellWidth: 200
            cellHeight: 132
            clip: true
            focus: true

            model: pickerWindow.wallpapers

            Keys.onPressed: (event) => {
                let total = model.length
                if (total === 0) return

                if (event.key === Qt.Key_Escape) {
                    pickerWindow.pickerVisible = false
                    event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                    pickerWindow.applyWallpaper(model[currentIndex])
                    event.accepted = true
                } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                    currentIndex = (currentIndex + 1) % total
                    event.accepted = true
                } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                    currentIndex = (currentIndex - 1 + total) % total
                    event.accepted = true
                }
            }

            delegate: Item {
                id: delegateItem
                width: grid.cellWidth
                height: grid.cellHeight

                readonly property bool isSelected: GridView.isCurrentItem

                Rectangle {
                    id: card
                    anchors.fill: parent
                    anchors.margins: 6
                    radius: 16
                    color: "#181820"

                    // Dynamic border color using parsed ACTIVE color
                    border.width: (delegateItem.isSelected || itemMouseArea.containsMouse) ? 2 : 0
                    border.color: (delegateItem.isSelected || itemMouseArea.containsMouse) 
                        ? pickerWindow.accentColor 
                        : "transparent"

                    scale: itemMouseArea.pressed ? 0.95 : (delegateItem.isSelected || itemMouseArea.containsMouse ? 1.04 : 1.0)

                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    // Soft mask container for rounded wallpaper images
                    Item {
                        id: imageContainer
                        anchors.fill: parent
                        anchors.margins: card.border.width

                        Rectangle {
                            id: maskRect
                            anchors.fill: parent
                            radius: card.radius - card.border.width
                            visible: false
                        }

                        Image {
                            id: img
                            anchors.fill: parent
                            source: "file://" + modelData
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            visible: false
                        }

                        OpacityMask {
                            anchors.fill: parent
                            source: img
                            maskSource: maskRect
                        }
                    }

                    MouseArea {
                        id: itemMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onEntered: grid.currentIndex = index
                        onClicked: pickerWindow.applyWallpaper(modelData)
                    }
                }
            }
        } 
    }
}