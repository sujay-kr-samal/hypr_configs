import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: launcherWindow

    // ── System Configuration Paths ─────────────────────────────────────────
    property string colorFilePath: "/home/sujay/color.txt"

    // Default fallbacks matching wallpaper picker
    property string accentColor: "#b6c4ff"
    property string panelBgColor: "#121319"

    property bool launcherVisible: false
    property var recentIds: []

    visible: launcherVisible

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: launcherVisible
        ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.None

    // ── Dynamic Color Parser (Reads ~/color.txt) ───────────────────────────
    Process {
        id: colorProc
        command: ["cat", launcherWindow.colorFilePath]

        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text.split("\n")
                for (let i = 0; i < lines.length; i++) {
                    let line = lines[i].trim()
                    if (line.startsWith("ACTIVE=")) {
                        let val = line.split("=")[1].split(" ")[0].trim()
                        if (val.length > 0) launcherWindow.accentColor = val
                    } else if (line.startsWith("BG=")) {
                        let val = line.split("=")[1].split(" ")[0].trim()
                        if (val.length > 0) launcherWindow.panelBgColor = val
                    }
                }
            }
        }
    }

    function loadColor() {
        colorProc.running = true
    }

    // ── IPC Handler ────────────────────────────────────────────────────────
    IpcHandler {
        target: "applauncher"

        function toggle(): void {
            launcherWindow.launcherVisible = !launcherWindow.launcherVisible
        }

        function open(): void {
            launcherWindow.launcherVisible = true
        }

        function close(): void {
            launcherWindow.launcherVisible = false
        }
    }

    // ── Local Search & App List State ──────────────────────────────────────
    property string searchQuery: ""
    readonly property bool isSearching: searchQuery.trim() !== ""

    property var filteredApps: {
        var q = searchQuery.trim().toLowerCase();
        var vals = DesktopEntries.applications.values || [];

        if (q !== "") {
            return vals.filter(function (e) {
                if (e.name && e.name.toLowerCase().indexOf(q) !== -1)
                    return true;
                if (e.genericName && e.genericName.toLowerCase().indexOf(q) !== -1)
                    return true;
                if (e.keywords) {
                    for (var i = 0; i < e.keywords.length; i++) {
                        if (e.keywords[i] && e.keywords[i].toLowerCase().indexOf(q) !== -1)
                            return true;
                    }
                }
                return false;
            }).sort(function (a, b) {
                return a.name.localeCompare(b.name);
            });
        }

        var recent = launcherWindow.recentIds || [];
        return vals.slice().sort(function (a, b) {
            var ai = recent.indexOf(a.id);
            var bi = recent.indexOf(b.id);
            if (ai !== -1 && bi !== -1)
                return ai - bi;
            if (ai !== -1)
                return -1;
            if (bi !== -1)
                return 1;
            return a.name.localeCompare(b.name);
        });
    }

    // ── Execution & Navigation ─────────────────────────────────────────────
    function launchEntry(entry) {
        if (!entry) return;
        
        var list = launcherWindow.recentIds.slice();
        var idx = list.indexOf(entry.id);
        if (idx !== -1) list.splice(idx, 1);
        list.unshift(entry.id);
        launcherWindow.recentIds = list.slice(0, 10);

        entry.execute();
        launcherWindow.launcherVisible = false;
    }

    onLauncherVisibleChanged: {
        if (launcherVisible) {
            loadColor()
            searchInput.text = ""
            launcherWindow.searchQuery = ""
            grid.currentIndex = 0
            searchInput.forceActiveFocus()
        }
    }

    // ── UI Overlay Scrim ───────────────────────────────────────────────────
    MouseArea {
        anchors.fill: parent
        onClicked: launcherWindow.launcherVisible = false
    }

    // ── Solid Left Sidebar Panel ───────────────────────────────────────────
    Rectangle {
        id: panel

        anchors.left: parent.left
        anchors.leftMargin: launcherWindow.launcherVisible ? 32 : -width
        anchors.verticalCenter: parent.verticalCenter

        width: 360
        height: Math.min(parent.height * 0.75, 680)

        radius: 24
        color: launcherWindow.panelBgColor
        border.width: 1
        border.color: "#2affffff"

        scale: launcherWindow.launcherVisible ? 1.0 : 0.85
        opacity: launcherWindow.launcherVisible ? 1.0 : 0.0

        Behavior on anchors.leftMargin { 
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

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // ── Search Field ───────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                radius: 12
                color: "#181820"
                border.width: searchInput.activeFocus ? 2 : 1
                border.color: searchInput.activeFocus ? launcherWindow.accentColor : "#2affffff"

                Behavior on border.color { ColorAnimation { duration: 120 } }

                TextInput {
                    id: searchInput
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    verticalAlignment: TextInput.AlignVCenter
                    color: "#ffffff"
                    font.pixelSize: 13
                    font.family: "JetBrainsMono Nerd Font"
                    clip: true
                    focus: true

                    onTextChanged: {
                        launcherWindow.searchQuery = text
                        grid.currentIndex = 0
                    }

                    // ── Search Input Key Handler ───────────────────────────
                    Keys.onPressed: (event) => {
                        let total = grid.model.length

                        if (event.key === Qt.Key_Escape) {
                            launcherWindow.launcherVisible = false
                            event.accepted = true
                        } else if (event.key === Qt.Key_Down) {
                            if (total > 0) {
                                grid.forceActiveFocus()
                                grid.currentIndex = 0
                            }
                            event.accepted = true
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (total > 0) {
                                launcherWindow.launchEntry(grid.model[grid.currentIndex])
                            }
                            event.accepted = true
                        } else if (event.key === Qt.Key_Tab) {
                            if (total > 0) {
                                grid.forceActiveFocus()
                            }
                            event.accepted = true
                        }
                    }

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        text: "Search apps…"
                        color: "#ffffff"
                        opacity: 0.3
                        font: searchInput.font
                        visible: searchInput.text === ""
                    }
                }
            }

            // ── Application Grid (3 Columns) ───────────────────────────────
            GridView {
                id: grid

                Layout.fillWidth: true
                Layout.fillHeight: true

                cellWidth: 108
                cellHeight: 104
                clip: true

                model: launcherWindow.filteredApps

                // ── App Grid Key Handler ───────────────────────────────────
                Keys.onPressed: (event) => {
                    let total = model.length
                    if (total === 0) return

                    if (event.key === Qt.Key_Escape) {
                        launcherWindow.launcherVisible = false
                        event.accepted = true
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        launcherWindow.launchEntry(model[currentIndex])
                        event.accepted = true
                    } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
                        currentIndex = (currentIndex + 1) % total
                        event.accepted = true
                    } else if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
                        currentIndex = (currentIndex - 1 + total) % total
                        event.accepted = true
                    } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                        if (currentIndex + 3 < total) {
                            currentIndex = currentIndex + 3
                        } else {
                            currentIndex = total - 1
                        }
                        event.accepted = true
                    } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                        if (currentIndex - 3 >= 0) {
                            currentIndex = currentIndex - 3
                        } else {
                            searchInput.forceActiveFocus()
                        }
                        event.accepted = true
                    } else if (event.key === Qt.Key_Tab) {
                        searchInput.forceActiveFocus()
                        event.accepted = true
                    }
                }

                delegate: Item {
                    id: delegateItem
                    width: grid.cellWidth
                    height: grid.cellHeight

                    readonly property bool isSelected: GridView.isCurrentItem && grid.activeFocus

                    Rectangle {
                        id: card
                        anchors.fill: parent
                        anchors.margins: 4
                        radius: 16
                        color: "#181820"

                        border.width: (delegateItem.isSelected || itemMouseArea.containsMouse) ? 2 : 0
                        border.color: (delegateItem.isSelected || itemMouseArea.containsMouse) 
                            ? launcherWindow.accentColor 
                            : "transparent"

                        scale: itemMouseArea.pressed ? 0.95 : ((delegateItem.isSelected || itemMouseArea.containsMouse) ? 1.04 : 1.0)

                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 4

                            Item {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: 38
                                Layout.preferredHeight: 38

                                Image {
                                    id: appIcon
                                    anchors.fill: parent
                                    source: modelData.icon ? "image://icon/" + modelData.icon : ""
                                    sourceSize.width: 38
                                    sourceSize.height: 38
                                    smooth: true
                                    mipmap: true
                                    fillMode: Image.PreserveAspectFit
                                    visible: status === Image.Ready
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: appIcon.status !== Image.Ready
                                    text: modelData.name ? modelData.name.charAt(0).toUpperCase() : ""
                                    font {
                                        pixelSize: 16
                                        family: "JetBrainsMono Nerd Font"
                                        weight: Font.Bold
                                    }
                                    color: launcherWindow.accentColor
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.name || ""
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                font {
                                    pixelSize: 11
                                    family: "JetBrainsMono Nerd Font"
                                }
                                color: "#ffffff"
                            }
                        }

                        MouseArea {
                            id: itemMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onEntered: {
                                grid.currentIndex = index
                                grid.forceActiveFocus()
                                
                            }

                            onClicked: launcherWindow.launchEntry(modelData)
                        }
                    }
                }
            }
        }
    }
}
 