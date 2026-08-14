import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.SystemTray

PanelWindow {
    id: barWindow

    signal clockClicked()

    // =========================================================
    // WINDOW
    // =========================================================

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: 50

    color: "#00000000"

    // =========================================================
    // FONT & COLORS
    // =========================================================

    readonly property string fontFamily:
        "JetBrainsMono Nerd Font"

    property string colorFilePath:
        "/home/sujay/color.txt"

    property color bgPill:
        "#1e1e1e"

    property color textMain:
        "#ffffff"

    property color activeAccent:
        "#ffffff"

    property color inactiveWorkspace:
        "#2c2c2c"

    property color mutedColor:
        "#ff6b6b"

    readonly property color textMuted:
        "#b8b8b8"

    readonly property color darkText:
        "#24191b"

    // =========================================================
    // COLOR FILE
    // =========================================================

    FileView {
        id: colorFileView

        path: barWindow.colorFilePath

        watchChanges: true

        onFileChanged: {
            reload()
        }

        onLoaded: {
            var raw = colorFileView.text()

            if (typeof raw !== "string")
                return

            raw = raw.trim()

            if (raw.length === 0)
                return

            var lines = raw.split("\n")

            for (var i = 0; i < lines.length; i++) {

                var line = lines[i].trim()

                if (line.length === 0)
                    continue

                if (line.charAt(0) === "#")
                    continue

                var parts = line.split("=")

                if (parts.length < 2)
                    continue

                var key = parts[0].trim()

                var value = parts
                    .slice(1)
                    .join("=")
                    .trim()

                if (value.length === 0)
                    continue

                if (value.charAt(0) !== "#")
                    value = "#" + value

                switch (key) {

                case "TEXT":
                    barWindow.textMain = value
                    break

                case "ACTIVE":
                    barWindow.activeAccent = value
                    break

                case "INACTIVE":
                    barWindow.inactiveWorkspace = value
                    break
                }
            }
        }
    }

    // =========================================================
    // CENTER OVERLAY
    // =========================================================

    property string centerMode:
        "clock"

    property string notificationText:
        ""

    property int notificationCount:
        0

    property int brightnessLevel:
        100

    Timer {
        id: resetCenterTimer

        interval: 2500

        repeat: false

        onTriggered: {
            barWindow.centerMode = "clock"
        }
    }

    function showCenterOverlay(mode) {
        barWindow.centerMode = mode
        resetCenterTimer.restart()
    }

    function showNotification(msg) {
        barWindow.notificationText = msg
        showCenterOverlay("notification")
    }

    // =========================================================
    // SYSTEM STATE
    // =========================================================

    property string wifiState:
        "connected"

    property string btState:
        "connected"

    property bool audioMuted:
        false

    property int audioVolume:
        100

    property bool micMuted:
        false

    // =========================================================
    // STATUS PARSER
    // =========================================================

    function parseStatusLine(line) {

        if (typeof line !== "string")
            return

        line = line.trim()

        if (line.length === 0)
            return

        var parts = line.split(":")

        if (parts.length < 2)
            return

        var key = parts[0].trim()

        // -----------------------------------------------------
        // WIFI
        // -----------------------------------------------------

        if (key === "WIFI") {

            barWindow.wifiState =
                parts.slice(1).join(":").trim()

            return
        }

        // -----------------------------------------------------
        // BLUETOOTH
        // -----------------------------------------------------

        if (key === "BT") {

            barWindow.btState =
                parts.slice(1).join(":").trim()

            return
        }

        // -----------------------------------------------------
        // AUDIO
        // -----------------------------------------------------

        if (key === "AUDIO") {

            var newVol =
                Math.max(
                    0,
                    Math.min(
                        100,
                        parseInt(parts[1]) || 0
                    )
                )

            var newMute =
                parts.length > 2 &&
                parts[2].trim() === "true"

            if (
                barWindow.audioVolume !== newVol ||
                barWindow.audioMuted !== newMute
            ) {

                barWindow.audioVolume =
                    newVol

                barWindow.audioMuted =
                    newMute

                barWindow.showCenterOverlay(
                    "volume"
                )
            }

            return
        }

        // -----------------------------------------------------
        // MICROPHONE
        // -----------------------------------------------------

        if (key === "MIC") {

            barWindow.micMuted =
                parts.slice(1).join(":").trim() === "true"

            return
        }

        // -----------------------------------------------------
        // BRIGHTNESS
        // -----------------------------------------------------

        if (key === "BRIGHTNESS") {

            var newBright =
                Math.max(
                    0,
                    Math.min(
                        100,
                        parseInt(parts[1]) || 0
                    )
                )

            if (
                barWindow.brightnessLevel !==
                newBright
            ) {

                barWindow.brightnessLevel =
                    newBright

                barWindow.showCenterOverlay(
                    "brightness"
                )
            }

            return
        }

        // -----------------------------------------------------
        // SWAYNC
        // -----------------------------------------------------

        if (key === "SWAYNC") {

            var jsonStr = parts.slice(1).join(":").trim()
            try {
                var data = JSON.parse(jsonStr)
                barWindow.notificationCount = parseInt(data.text) || 0
            } catch(e) {}

            return
        }
    }

    // =========================================================
    // STATUS MONITOR
    // =========================================================

    Process {
        id: statusMonitor

        running: true

        command: [
            "bash",
            "-c",
            "
            get_audio_status() {
                if command -v wpctl >/dev/null 2>&1; then
                    wpctl get-volume @DEFAULT_AUDIO_SINK@ |
                    awk '{
                        vol = int($2 * 100);
                        muted = ($3 == \"[MUTED]\") ? \"true\" : \"false\";
                        print \"AUDIO:\" vol \":\" muted
                    }'

                    wpctl get-volume @DEFAULT_AUDIO_SOURCE@ |
                    awk '{
                        muted = ($3 == \"[MUTED]\") ? \"true\" : \"false\";
                        print \"MIC:\" muted
                    }'
                fi
            }

            get_net_status() {
                if ! command -v nmcli >/dev/null 2>&1; then
                    return
                fi

                WIFI_STATE=$(nmcli radio wifi 2>/dev/null)

                if [ \"$WIFI_STATE\" = \"disabled\" ]; then
                    echo \"WIFI:disabled\"
                elif nmcli -t -f TYPE,STATE dev 2>/dev/null | grep -q \"wifi:connected\"; then
                    echo \"WIFI:connected\"
                else
                    echo \"WIFI:disconnected\"
                fi

                if command -v bluetoothctl >/dev/null 2>&1; then
                    if ! bluetoothctl show 2>/dev/null | grep -q \"Powered: yes\"; then
                        echo \"BT:disabled\"
                    elif bluetoothctl info 2>/dev/null | grep -q \"Connected: yes\"; then
                        echo \"BT:connected\"
                    else
                        echo \"BT:on\"
                    fi
                fi
            }

            get_brightness() {
                if command -v brightnessctl >/dev/null 2>&1; then
                    brightnessctl -m 2>/dev/null |
                    awk -F, '{
                        gsub(/%/, \"\", $4);
                        print \"BRIGHTNESS:\" $4
                    }'
                fi
            }

            PIPE=/tmp/swaync_quickshell.pipe
            [ -p \"$PIPE\" ] || mkfifo \"$PIPE\" 2>/dev/null || true

            get_audio_status
            get_net_status
            get_brightness

            {
                pactl subscribe 2>/dev/null &
                nmcli monitor 2>/dev/null &
                udevadm monitor --subsystem-match=backlight 2>/dev/null &
                if command -v swaync-client >/dev/null 2>&1; then
                    swaync-client -swb 2>/dev/null | while read -r line; do
                        echo \"SWAYNC:$line\"
                    done &
                fi
                while true; do
                    if read -r line < \"$PIPE\"; then
                        echo \"$line\"
                    fi
                done &
                wait
            } | while IFS= read -r event; do
                case \"$event\" in
                    *sink*|*source*|*server*)
                        get_audio_status
                        ;;
                    *wifi*|*wireless*|*bluetooth*|*adapter*)
                        get_net_status
                        ;;
                    *backlight*)
                        get_brightness
                        ;;
                    NOTIF:*)
                        printf '%s\n' \"$event\"
                        ;;
                    SWAYNC:*)
                        printf '%s\n' \"$event\"
                        ;;
                esac
            done
            "
        ]

        stdout: SplitParser {

            onRead: function(data) {
                if (typeof data !== "string")
                    return

                var line = data.trim()

                if (!line)
                    return

                if (line.indexOf("NOTIF:") === 0) {
                    var parts = line.split(":")
                    var msg = parts.slice(1).join(":").trim()
                    barWindow.showNotification(msg)
                    return
                }

                barWindow.parseStatusLine(line)
            }
        }
    }

    // =========================================================
    // CLOCK
    // =========================================================

    property string currentTime:
        Qt.formatDateTime(
            new Date(),
            "hh:mm:ss A"
        )

    property string currentDate:
        Qt.formatDateTime(
            new Date(),
            "dddd, MMM d"
        )

    Timer {

        interval: 1000

        running: true

        repeat: true

        triggeredOnStart: true

        onTriggered: {

            barWindow.currentTime =
                Qt.formatDateTime(
                    new Date(),
                    "hh:mm:ss A"
                )

            barWindow.currentDate =
                Qt.formatDateTime(
                    new Date(),
                    "dddd, MMM d"
                )
        }
    }

    // =========================================================
    // BASE PILL
    // =========================================================

    component BasePill: Rectangle {

        color:
            barWindow.bgPill

        radius: 14

        border.width: 1

        border.color:
            barWindow.bgPill

        implicitHeight: 38
    }

    // =========================================================
    // MAIN LAYOUT
    // =========================================================

    RowLayout {

        id: mainLayout

        anchors.fill: parent

        anchors.leftMargin: 10

        anchors.rightMargin: 10

        anchors.topMargin: 6

        anchors.bottomMargin: 6

        spacing: 7

        // =====================================================
        // WORKSPACES
        // =====================================================

        BasePill {

            id: workspacePill

            Layout.preferredWidth: 270

            Row {

                anchors.centerIn: parent

                spacing: 2

                Repeater {

                    model: 9

                    Rectangle {

                        required property int index

                        property bool active:
                            Hyprland.focusedWorkspace &&
                            Hyprland.focusedWorkspace.id ===
                                index + 1

                        width:
                            active ? 28 : 25

                        height: 28

                        radius: 8

                        color:
                            active
                            ? barWindow.activeAccent
                            : barWindow.inactiveWorkspace

                        opacity:
                            active ? 1.0 : 0.65

                        Behavior on color {

                            ColorAnimation {
                                duration: 120
                            }
                        }

                        Behavior on width {

                            NumberAnimation {
                                duration: 120
                            }
                        }

                        Behavior on opacity {

                            NumberAnimation {
                                duration: 120
                            }
                        }

                        Text {

                            anchors.centerIn: parent

                            text:
                                index + 1

                            font.family:
                                barWindow.fontFamily

                            font.pixelSize: 11

                            font.bold: true

                            color:
                                active
                                ? barWindow.darkText
                                : barWindow.textMain
                        }

                        MouseArea {

                            anchors.fill: parent

                            cursorShape:
                                Qt.PointingHandCursor

                            onClicked: {

                                var targetId =
                                    index + 1

                                var ws =
                                    Hyprland
                                    .workspaces
                                    .values
                                    .find(
                                        function(w) {
                                            return w.id ===
                                                targetId
                                        }
                                    )

                                if (ws)
                                    ws.activate()
                            }
                        }
                    }
                }
            }
        }

        // =====================================================
        // EMPTY SPACE
        // =====================================================

        Item {
            Layout.fillWidth: true
        }

        // =====================================================
        // CLOCK
        // =====================================================

        BasePill {

            id: clockPill

            Layout.preferredWidth: 210

            MouseArea {

                anchors.fill: parent

                cursorShape:
                    Qt.PointingHandCursor

                onClicked: {
                    barWindow.clockClicked()
                }
            }

            // -------------------------------------------------
            // NOTIFICATION BADGE
            // -------------------------------------------------

            Row {

                anchors.right: parent.right

                anchors.rightMargin: 16

                anchors.verticalCenter: parent.verticalCenter

                spacing: 4

                visible:
                    barWindow.notificationCount > 0 &&
                    barWindow.centerMode === "clock"

                Text {

                    text: "󰂚"

                    font.family:
                        barWindow.fontFamily

                    font.pixelSize: 12

                    font.bold: true

                    color:
                        barWindow.activeAccent
                }

                Text {

                    text:
                        barWindow.notificationCount.toString()

                    font.family:
                        barWindow.fontFamily

                    font.pixelSize: 11

                    font.bold: true

                    color:
                        barWindow.textMain
                }
            }

            // -------------------------------------------------
            // CLOCK
            // -------------------------------------------------

            Column {

                anchors.centerIn: parent

                visible:
                    barWindow.centerMode ===
                    "clock"

                spacing: 0

                Text {

                    anchors.horizontalCenter:
                        parent.horizontalCenter

                    text:
                        barWindow.currentTime

                    font.family:
                        barWindow.fontFamily

                    font.pixelSize: 15

                    font.bold: true

                    color:
                        barWindow.textMain
                }

                Text {

                    anchors.horizontalCenter:
                        parent.horizontalCenter

                    text:
                        barWindow.currentDate

                    font.family:
                        barWindow.fontFamily

                    font.pixelSize: 10

                    font.bold: true

                    color:
                        barWindow.textMuted
                }
            }

            // -------------------------------------------------
            // VOLUME
            // -------------------------------------------------

            RowLayout {

                anchors.centerIn: parent

                visible:
                    barWindow.centerMode ===
                    "volume"

                spacing: 8

                width:
                    parent.width - 24

                Text {

                    text:
                        barWindow.audioMuted
                        ? "󰝟"
                        : "󰕾"

                    font.family:
                        barWindow.fontFamily

                    font.pixelSize: 16

                    color:
                        barWindow.audioMuted
                        ? barWindow.mutedColor
                        : barWindow.activeAccent
                }

                Rectangle {

                    Layout.fillWidth: true

                    height: 6

                    radius: 3

                    color:
                        barWindow.inactiveWorkspace

                    Rectangle {

                        width:
                            parent.width *
                            (
                                Math.max(
                                    0,
                                    Math.min(
                                        100,
                                        barWindow.audioVolume
                                    )
                                ) / 100
                            )

                        height:
                            parent.height

                        radius: 3

                        color:
                            barWindow.activeAccent
                    }
                }

                Text {

                    text:
                        barWindow.audioVolume +
                        "%"

                    font.family:
                        barWindow.fontFamily

                    font.pixelSize: 11

                    font.bold: true

                    color:
                        barWindow.textMain
                }
            }

            // -------------------------------------------------
            // BRIGHTNESS
            // -------------------------------------------------

            RowLayout {

                anchors.centerIn: parent

                visible:
                    barWindow.centerMode ===
                    "brightness"

                spacing: 8

                width:
                    parent.width - 24

                Text {

                    text:
                        "󰃠"

                    font.family:
                        barWindow.fontFamily

                    font.pixelSize: 16

                    color:
                        barWindow.activeAccent
                }

                Rectangle {

                    Layout.fillWidth: true

                    height: 6

                    radius: 3

                    color:
                        barWindow.inactiveWorkspace

                    Rectangle {

                        width:
                            parent.width *
                            (
                                Math.max(
                                    0,
                                    Math.min(
                                        100,
                                        barWindow.brightnessLevel
                                    )
                                ) / 100
                            )

                        height:
                            parent.height

                        radius: 3

                        color:
                            barWindow.activeAccent
                    }
                }

                Text {

                    text:
                        barWindow.brightnessLevel +
                        "%"

                    font.family:
                        barWindow.fontFamily

                    font.pixelSize: 11

                    font.bold: true

                    color:
                        barWindow.textMain
                }
            }

            // -------------------------------------------------
            // NOTIFICATION
            // -------------------------------------------------

            Text {

                anchors.centerIn: parent

                visible:
                    barWindow.centerMode ===
                    "notification"

                width:
                    clockPill.width - 24

                text:
                    barWindow.notificationText

                font.family:
                    barWindow.fontFamily

                font.pixelSize: 11

                font.bold: true

                color:
                    barWindow.textMain

                horizontalAlignment:
                    Text.AlignHCenter

                elide:
                    Text.ElideRight

                maximumLineCount: 1
            }
        }

        // =====================================================
        // EMPTY SPACE
        // =====================================================

        Item {
            Layout.fillWidth: true
        }

        // =====================================================
        // SYSTEM TRAY
        // =====================================================

        BasePill {

            id: trayPill

            visible:
                trayRepeater.count > 0

            /*
             * IMPORTANT:
             *
             * Do NOT use trayRow.implicitWidth here.
             *
             * That creates:
             *
             * trayPill width
             *      -> trayRow width
             *      -> implicitWidth
             *      -> trayPill width
             *
             * which can cause the QQuickItem polish loop.
             */

            Layout.preferredWidth:
                16 +
                (
                    trayRepeater.count * 24
                ) +
                (
                    Math.max(
                        0,
                        trayRepeater.count - 1
                    ) * 6
                )

            Layout.minimumWidth:
                16

            Layout.maximumWidth:
                16 +
                (
                    trayRepeater.count * 24
                ) +
                (
                    Math.max(
                        0,
                        trayRepeater.count - 1
                    ) * 6
                )

            Row {

                id: trayRow

                anchors.centerIn: parent

                spacing: 6

                Repeater {

                    id: trayRepeater

                    model:
                        SystemTray.items

                    delegate: Item {

                        required property SystemTrayItem modelData

                        width: 24

                        height: 24

                        QsMenuAnchor {

                            id: menuAnchor

                            menu:
                                modelData.menu

                            /*
                             * Anchor the tray menu to this
                             * tray icon instead of manually
                             * calling modelData.display().
                             */

                            anchor.item:
                                trayIcon
                        }

                        Image {

                            id: trayIcon

                            anchors.fill: parent

                            anchors.margins: 2

                            source:
                                modelData.icon || ""

                            smooth: true

                            fillMode:
                                Image.PreserveAspectFit
                        }

                        Text {

                            anchors.centerIn:
                                parent

                            visible:
                                trayIcon.status !==
                                Image.Ready

                            text:
                                (
                                    modelData.title ||
                                    modelData.id ||
                                    "App"
                                ).charAt(0)
                                .toUpperCase()

                            font.family:
                                barWindow.fontFamily

                            font.pixelSize: 11

                            font.bold: true

                            color:
                                barWindow.textMain
                        }

                        MouseArea {

                            anchors.fill:
                                parent

                            acceptedButtons:
                                Qt.LeftButton |
                                Qt.RightButton

                            cursorShape:
                                Qt.PointingHandCursor

                            onClicked:
                                function(mouse) {

                                    // ---------------------------------
                                    // LEFT CLICK
                                    // ---------------------------------

                                    if (
                                        mouse.button ===
                                        Qt.LeftButton
                                    ) {

                                        if (
                                            modelData.hasMenu
                                        ) {

                                            menuAnchor.open()

                                        } else {

                                            modelData.activate()
                                        }

                                        return
                                    }

                                    // ---------------------------------
                                    // RIGHT CLICK
                                    // ---------------------------------

                                    if (
                                        mouse.button ===
                                        Qt.RightButton
                                    ) {

                                        if (
                                            modelData.hasMenu
                                        ) {

                                            menuAnchor.open()

                                        } else {

                                            modelData.secondaryActivate()
                                        }
                                    }
                                }
                        }
                    }
                }
            }
        }

        // =====================================================
        // WIFI
        // =====================================================

        BasePill {

            id: wifiPill

            Layout.preferredWidth: 42

            Text {

                anchors.centerIn:
                    parent

                text:

                    barWindow.wifiState ===
                    "connected"

                    ? "󰤨"

                    : (
                        barWindow.wifiState ===
                        "disconnected"

                        ? "󰤩"

                        : "󰤦"
                    )

                font.family:
                    barWindow.fontFamily

                font.pixelSize: 28

                color:

                    barWindow.wifiState ===
                    "disabled"

                    ? barWindow.mutedColor

                    : barWindow.textMain
            }

            MouseArea {

                anchors.fill:
                    parent

                cursorShape:
                    Qt.PointingHandCursor

                onClicked: {

                    console.log(
                        "WiFi clicked"
                    )
                }
            }
        }

        // =====================================================
        // BLUETOOTH
        // =====================================================

        BasePill {

            id: bluetoothPill

            Layout.preferredWidth: 42

            Text {

                anchors.centerIn:
                    parent

                text:

                    barWindow.btState ===
                    "connected"

                    ? "󰥈"

                    : (
                        barWindow.btState ===
                        "on"

                        ? "󰂯"

                        : "󰂲"
                    )

                font.family:
                    barWindow.fontFamily

                font.pixelSize: 20

                color:

                    barWindow.btState ===
                    "disabled"

                    ? barWindow.mutedColor

                    : barWindow.textMain
            }

            MouseArea {

                anchors.fill:
                    parent

                cursorShape:
                    Qt.PointingHandCursor

                onClicked: {

                    console.log(
                        "Bluetooth clicked"
                    )
                }
            }
        }

        // =====================================================
        // MICROPHONE
        // =====================================================

        BasePill {

            id: microphonePill

            Layout.preferredWidth: 42

            Text {

                anchors.centerIn:
                    parent

                text:
                    barWindow.micMuted
                    ? "󰍭"
                    : "󰍬"

                font.family:
                    barWindow.fontFamily

                font.pixelSize: 20

                color:
                    barWindow.micMuted
                    ? barWindow.mutedColor
                    : barWindow.textMain
            }

            MouseArea {

                anchors.fill:
                    parent

                cursorShape:
                    Qt.PointingHandCursor

                onClicked: {

                    console.log(
                        "Microphone clicked"
                    )
                }
            }
        }

        // =====================================================
        // VOLUME
        // =====================================================

        BasePill {

            id: volumePill

            Layout.preferredWidth: 42

            Text {

                anchors.centerIn:
                    parent

                text: {

                    if (
                        barWindow.audioMuted
                    )
                        return "󰝟"

                    if (
                        barWindow.audioVolume >
                        50
                    )
                        return "󰕾"

                    if (
                        barWindow.audioVolume >
                        0
                    )
                        return "󰕿"

                    return "󰕿"
                }

                font.family:
                    barWindow.fontFamily

                font.pixelSize: 22

                color:
                    barWindow.audioMuted
                    ? barWindow.mutedColor
                    : barWindow.textMain
            }

            MouseArea {

                anchors.fill:
                    parent

                cursorShape:
                    Qt.PointingHandCursor

                onClicked: {

                    console.log(
                        "Volume clicked"
                    )
                }
            }
        }

        // =====================================================
        // BATTERY
        // =====================================================

        BasePill {

            id: batteryPill

            Layout.preferredWidth: 42

            Text {

                anchors.centerIn:
                    parent

                text:
                    "󰁹"

                font.family:
                    barWindow.fontFamily

                font.pixelSize: 20

                color:
                    barWindow.activeAccent
            }
        }
    }
}