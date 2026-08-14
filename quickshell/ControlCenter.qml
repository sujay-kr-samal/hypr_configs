import QtQuick
import QtQuick.Layouts
import QtMultimedia
import QtQuick.Controls 2.15
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Mpris

PanelWindow {
    id: root

    // =========================================================
    // WINDOW CONFIGURATION
    // =========================================================

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "control-center"
    WlrLayershell.exclusiveZone: 0

    anchors {
        bottom: true
        left: true
        right: true
        top: true
    }

    implicitWidth: 860
    implicitHeight: 620

    color: "transparent"

    // =========================================================
    // STATE PROPERTIES
    // =========================================================

    property bool opened: false
    property int page: 0 
    property int pendingPowerAction: -1
    property bool isRecording: false
    property bool isMuted: false
    property bool isMicMuted: false

    property string activePreset: "Flat"
    property bool isPlaying: true
    property real trackProgress: 0.61

    // Real EasyEffects EQ values in dB. These are NOT CAVA values.
    property var eqData: ({
        b1: 0, b2: 0, b3: 0, b4: 0, b5: 0,
        b6: 0, b7: 0, b8: 0, b9: 0, b10: 0,
        preset: "Flat",
        pending: false
    })
    readonly property var eqLabels: ["31", "63", "125", "250", "500", "1k", "2k", "4k", "8k", "16k"]
    readonly property var eqPresets: ({
        "Flat":    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        "Bass":    [5, 7, 5, 2, 1, 0, 0, 0, 1, 2],
        "Treble":  [-2, -1, 0, 1, 2, 3, 4, 5, 6, 6],
        "Vocal":   [-2, -1, 1, 3, 5, 5, 4, 2, 1, 0],
        "Pop":     [2, 4, 2, 0, 1, 2, 4, 2, 1, 2],
        "Rock":    [5, 4, 2, -1, -2, -1, 2, 4, 5, 6],
        "Jazz":    [3, 3, 1, 1, 1, 1, 2, 1, 2, 3],
        "Classic": [0, 1, 2, 2, 2, 2, 1, 2, 3, 4]
    })

    // =========================================================
    // LIVE AUDIO SPECTRUM (CAVA)
    // =========================================================

    // Path to the cava config we generate at startup. Change `method`
    // inside writeCavaConfig() to "pipewire" if you are not running
    // PipeWire's pulse-compat layer.
    property string cavaConfigPath: "/tmp/quickshell-control-center-cava.conf"
    property string eqScript: (Quickshell.env("HOME") || "/home/sujay") + "/.config/quickshell/scripts/music/equalizer.sh"
    // True once cava is running AND has sent at least one real frame.
    // Used to suppress manual bar dragging / presets while live data
    // is flowing, since they'd get overwritten on the next frame anyway.
    property bool cavaActive: false
    property var spectrumBands: []

    // =========================================================
    // SYSTEM MONITOR CONFIGURATION
    // =========================================================
    property string sysMonScript: (Quickshell.env("HOME") || "/home/sujay") + "/.config/quickshell/scripts/sys-mon.py"
    property real cpuUsage: 0.0
    property real ramUsage: 0.0
    property real gpuUsage: 0.0
    property real vramUsage: 0.0
    property real memUsed: 0.0
    property real memTotal: 0.0
    property real vramUsed: 0.0
    property real vramTotal: 0.0

    // =========================================================
    // VIDEO CONFIGURATION (DASHBOARD BACKGROUND VIDEO)
    // =========================================================

    property string mediaPath: "/home/sujay/Pictures/V1.mp4"

    readonly property string mediaUrl:
        root.mediaPath.startsWith("/")
        ? "file://" + root.mediaPath
        : root.mediaPath

    // =========================================================
    // MPRIS MEDIA PLAYER SELECTION (FOR MUSIC PAGE)
    // =========================================================

    

    // Automatically finds an active player (Prefers Spotify, falls back to any available player)
    property MprisPlayer activeMprisPlayer: {
        var players = Mpris.players.values;
        if (players.length === 0) return null;
        
        for (var i = 0; i < players.length; i++) {
            if (players[i].identity && players[i].identity.toLowerCase().includes("spotify")) {
                return players[i];
            }
        }
        return players[0];
    }

    onActiveMprisPlayerChanged: {
        root.fetchLyrics()
    }

    Connections {
        target: root.activeMprisPlayer
        ignoreUnknownSignals: true
        function onTrackTitleChanged() {
            root.fetchLyrics()
        }
        function onTrackArtistChanged() {
            root.fetchLyrics()
        }
    }

    // =========================================================
    // MPRIS PROGRESS DISPLAY
    // =========================================================

    // Separate UI position so the Music page updates once per second even
    // when the MPRIS backend does not emit a positionChanged signal every second.
    property real mprisDisplayPosition: 0
    property string mprisTrackKey: ""

    function syncMprisPosition() {
        var player = root.activeMprisPlayer

        if (!player) {
            root.mprisDisplayPosition = 0
            root.mprisTrackKey = ""
            return
        }

        var length = Number(player.length) || 0
        var actual = Math.max(0, Number(player.position) || 0)
        var key = (player.identity || "") + "|" +
                  (player.trackTitle || "") + "|" +
                  (player.trackArtist || "") + "|" +
                  length

        // New track/player: always take the exact MPRIS position.
        if (root.mprisTrackKey !== key) {
            root.mprisTrackKey = key
            root.mprisDisplayPosition = actual
            return
        }

        // MPRIS is authoritative. If it reports a position that differs
        // noticeably (seek, track change, external control), snap to it.
        if (Math.abs(actual - root.mprisDisplayPosition) > 2.0) {
            root.mprisDisplayPosition = actual
        } else if (player.playbackState === MprisPlaybackState.Playing) {
            // Keep the visible counter moving once per second between MPRIS
            // position updates, just like Spotify's elapsed-time display.
            root.mprisDisplayPosition = Math.min(
                length > 0 ? length : root.mprisDisplayPosition + 1,
                root.mprisDisplayPosition + 1
            )
        } else {
            // Paused/stopped: show the exact player position.
            root.mprisDisplayPosition = actual
        }
    }

    Timer {
        id: mprisProgressTimer
        interval: 1000
        repeat: true
        running: root.opened && root.page === 1
        triggeredOnStart: true
        onTriggered: root.syncMprisPosition()
    }

    // =========================================================
    // FUNCTIONS
    // =========================================================

    // Writes a 10-band cava config matching eqLabels/eqBands so raw
    // output can be dropped straight into root.eqBands.
    function writeCavaConfig() {
        var config =
            "[general]\n" +
            "bars = 10\n" +
            "framerate = 60\n" +
            "sensitivity = 100\n" +
            "\n" +
            "[input]\n" +
            "method = pulse\n" +
            "source = auto\n" +
            "\n" +
            "[output]\n" +
            "method = raw\n" +
            "raw_target = /dev/stdout\n" +
            "data_format = ascii\n" +
            "ascii_max_range = 255\n" +
            "bar_delimiter = 59\n" +
            "frame_delimiter = 10\n" +
            "channels = mono\n"

        Quickshell.execDetached([
            "bash",
            "-c",
            "cat > '" + root.cavaConfigPath + "' << 'CAVACFG'\n" + config + "CAVACFG"
        ])
    }

    // Parses one raw cava frame ("<n0>;<n1>;...;<n9>;") into 0..1 band values.
    function handleCavaLine(line) {
        if (!line || line.length === 0)
            return

        var parts = line.split(";")
        var bands = []

        for (var i = 0; i < parts.length; i++) {
            if (parts[i] === "")
                continue

            var raw = parseInt(parts[i], 10)

            if (isNaN(raw))
                continue

            bands.push(Math.max(0, Math.min(1, raw / 255)))
        }

        if (bands.length > 0) {
            console.log("Parsed CAVA bands count:", bands.length, "cavaActive:", root.cavaActive)
            root.cavaActive = true
            root.spectrumBands = bands
        }
    }

    property double lastEqUpdate: 0

    Process {
        id: eqProcess
        command: ["bash", "-c", "'" + root.eqScript + "' get"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                if (Date.now() - root.lastEqUpdate < 2000) return;
                try {
                    var parsed = JSON.parse(text)
                    root.eqData = parsed
                    if (parsed.preset)
                        root.activePreset = parsed.preset
                } catch (e) {
                    console.log("EQ state parse error:", e)
                }
            }
        }
    }

    function refreshEq() {
        eqProcess.command = ["bash", "-c", "'" + root.eqScript + "' get"]
        eqProcess.running = true
    }

    Process {
        id: volumeQueryProcess
        command: ["bash", "-c", "pactl get-sink-volume @DEFAULT_SINK@ | grep -Po '\\d+(?=%)' | head -n 1"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (typeof volumeMouseArea !== "undefined" && volumeMouseArea.pressed) return;
                var vol = parseInt(text.trim())
                if (!isNaN(vol)) {
                    volumeBar.value = vol / 100.0
                }
            }
        }
    }

    function refreshVolume() {
        volumeQueryProcess.running = true
    }

    Process {
        id: brightnessQueryProcess
        command: ["bash", "-c", "brightnessctl get"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (typeof brightnessMouseArea !== "undefined" && brightnessMouseArea.pressed) return;
                var val = parseInt(text.trim())
                if (!isNaN(val)) {
                    brightnessBar.value = val / 100.0
                }
            }
        }
    }

    function refreshBrightness() {
        brightnessQueryProcess.running = true
    }

    Process {
        id: muteQueryProcess
        command: ["bash", "-c", "pactl get-sink-mute @DEFAULT_SINK@"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.isMuted = text.includes("yes")
            }
        }
    }

    function refreshMute() {
        muteQueryProcess.running = true
    }

    Process {
        id: micMuteQueryProcess
        command: ["bash", "-c", "pactl get-source-mute @DEFAULT_SOURCE@"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.isMicMuted = text.includes("yes")
            }
        }
    }

    function refreshMicMute() {
        micMuteQueryProcess.running = true
    }

    function setEqBand(index, gain) {
        var v = Math.max(-12, Math.min(12, Math.round(Number(gain) * 10) / 10))
        var copy = Object.assign({}, root.eqData)
        copy["b" + (index + 1)] = v
        copy.preset = "Custom"
        copy.pending = true
        root.eqData = copy
        root.activePreset = "Custom"
        root.lastEqUpdate = Date.now()

        Quickshell.execDetached([
            "bash",
            "-c",
            "'" + root.eqScript + "' set_band '" + (index + 1) + "' '" + v + "'"
        ])
    }

    function applyEq() {
        root.lastEqUpdate = Date.now()
        Quickshell.execDetached(["bash", "-c", "'" + root.eqScript + "' apply"])
        var copy = Object.assign({}, root.eqData)
        copy.pending = false
        root.eqData = copy
    }

    function applyEqPreset(name) {
        root.lastEqUpdate = Date.now()
        Quickshell.execDetached(["bash", "-c", "'" + root.eqScript + "' preset '" + name + "'"])
        root.activePreset = name
        var values = root.eqPresets[name]
        if (values) {
            var copy = Object.assign({}, root.eqData)
            for (var i = 0; i < 10; i++)
                copy["b" + (i + 1)] = values[i]
            copy.preset = name
            copy.pending = false
            root.eqData = copy
        }
    }

    function eqGain(index) {
        var value = Number(root.eqData["b" + (index + 1)])
        return isNaN(value) ? 0 : value
    }

    function toggle() {
        root.opened = !root.opened

        if (root.opened) {
            root.pendingPowerAction = -1
        }

        root.updateMedia()
    }

    function closePanel() {
        root.opened = false
        root.pendingPowerAction = -1

        // Pause BOTH video players when the dashboard closes.
        // The music-page video used to keep playing in the background.
        mediaPlayer.pause()
        secondaryMediaPlayer.pause()
    }

    function updateMedia() {
        if (root.opened && root.page === 0) {
            mediaPlayer.play()
        } else {
            mediaPlayer.pause()
        }

        updateSecondaryMedia()
    }

    function updateSecondaryMedia() {
        // Keep the music page lightweight: do not keep a second full video
        // decoder and buffer set up alongside the dashboard video.
        // The interactive music content is already handled by the waveform UI.
        if (secondaryMediaPlayer) {
            secondaryMediaPlayer.pause()
        }
    }

    onOpenedChanged: {
        if (!root.opened) {
            mediaPlayer.pause()
            secondaryMediaPlayer.pause()
            mprisProgressTimer.stop()
        } else {
            root.updateMedia()
            root.refreshVolume()
            root.refreshBrightness()
            root.refreshMute()
            root.refreshMicMute()
            if (root.page === 1) {
                root.syncMprisPosition()
                mprisProgressTimer.restart()
                root.fetchLyrics()
            }
        }
    }

    onPageChanged: {
        root.updateMedia()
        if (root.opened && root.page === 1) {
            root.syncMprisPosition()
            mprisProgressTimer.restart()
            root.fetchLyrics()
        } else {
            mprisProgressTimer.stop()
        }
    }

    visible:
        root.opened || panel.opacity > 0.01

    // =========================================================
    // COLOR PALETTE & DYNAMIC SYNC PROPERTIES
    // =========================================================

    property string colorFilePath: "file:///home/sujay/color.txt"

    property color accent: "#b6c4ff"
    property color background: "#121319"

    property color surface: "#211a1f"
    property color surface2: "#2d242a"
    property color surface3: "#392f37"

    property color textPrimary: "#e3e1ea"
    property color textSecondary: "#444652"

    property color danger: "#ff6b81"
    property color success: "#a6e3a1"
    property color warning: "#f9e2af"

    readonly property string fontFamily:
        "JetBrainsMono Nerd Font"

    // =========================================================
    // ROBUST COLOR LOADER
    // =========================================================

    function applyColors(content) {
        if (typeof content === "function") {
            try { content = content() } catch (e) { return }
        }
        if (typeof content !== "string" || !content)
            return

        console.log("Applying colors from text:\n", content)
        var lines = content.split("\n")

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()

            if (!line || line.startsWith("#"))
                continue

            var parts = line.split("=")

            if (parts.length < 2)
                continue

            var key = parts[0].trim().toUpperCase()
            var value = parts.slice(1).join("=").trim()

            if (value.length > 0 && value.charAt(0) !== "#") {
                value = "#" + value
            }

            if (key === "ACTIVE" ||
                key === "ACCENT" ||
                key === "PRIMARY") {

                root.accent = value

            } else if (key === "BG" ||
                       key === "BACKGROUND") {

                root.background = value
                root.surface = Qt.lighter(value, 1.3)
                root.surface2 = Qt.lighter(value, 1.6)
                root.surface3 = Qt.lighter(value, 2.0)

            } else if (key === "TEXT" ||
                       key === "TEXTPRIMARY") {

                root.textPrimary = value

            } else if (key === "INACTIVE" ||
                       key === "TEXTSECONDARY" ||
                       key === "SUBTEXT") {

                root.textSecondary = value
            }
        }
    }

    // =========================================================
    // POWER ACTIONS
    // =========================================================

    property var powerActions: [
        {
            icon: "󰐥",
            label: "Shutdown",
            description: "Turn off the system",
            cmd: "systemctl poweroff"
        },
        {
            icon: "󰜉",
            label: "Restart",
            description: "Restart the system",
            cmd: "systemctl reboot"
        },
        {
            icon: "󰤄",
            label: "Suspend",
            description: "Suspend the system",
            cmd: "systemctl suspend"
        },
        {
            icon: "󰍃",
            label: "Logout",
            description: "End your session",
            cmd: "hyprctl dispatch exit"
        }
    ]

    Timer {
        id: powerTimer

        interval: 3000
        running: root.pendingPowerAction !== -1
        repeat: false

        onTriggered: {
            root.pendingPowerAction = -1
        }
    }

    // =========================================================
    // NAVIGATION ITEMS
    // =========================================================

    property var navItems: [
        {
            icon: "󰕮",
            label: "Dashboard"
        },
        {
            icon: "󰎆",
            label: "Music"
        },
        {
            icon: "󰓅",
            label: "Performance"
        },
        {
            icon: "󰂚",
            label: "Notifications"
        }
    ]

    // =========================================================
    // MEDIA PLAYER BACKEND (FOR DASHBOARD BACKGROUND VIDEO)
    // =========================================================

    MediaPlayer {
        id: mediaPlayer

        source:
            root.mediaUrl

        loops:
            MediaPlayer.Infinite

        videoOutput:
            videoOutput

        audioOutput: AudioOutput {
            id: mediaAudioOutput

            volume: 1.0
            muted: true
        }

        onErrorOccurred: {
            console.warn(
                "Control Center media error:",
                errorString
            )
        }

        onMediaStatusChanged: {
            if (root.opened &&
                root.page === 0 &&
                mediaStatus === MediaPlayer.LoadedMedia) {

                play()
            }
        }
    }

    // =========================================================
    // LIVE AUDIO SPECTRUM PROCESS (CAVA)
    // =========================================================

    Process {
        id: cavaProcess

        command: [
            "bash",
            "-c",
            "cat > '" + root.cavaConfigPath + "' << 'CAVACFG'\n" +
            "[general]\n" +
            "bars = 36\n" +
            "framerate = 60\n" +
            "sensitivity = 100\n" +
            "\n" +
            "[input]\n" +
            "method = pipewire\n" +
            "source = auto\n" +
            "\n" +
            "[output]\n" +
            "method = raw\n" +
            "raw_target = /dev/stdout\n" +
            "data_format = ascii\n" +
            "ascii_max_range = 255\n" +
            "bar_delimiter = 59\n" +
            "frame_delimiter = 10\n" +
            "channels = mono\n" +
            "CAVACFG\n" +
            "exec cava -p '" + root.cavaConfigPath + "'"
        ]

        running: root.opened && root.page === 1

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => root.handleCavaLine(line)
        }

        onRunningChanged: {
            if (!running) {
                root.cavaActive = false
                root.spectrumBands = []
            }
        }

        onExited: (exitCode, exitStatus) => {
            root.cavaActive = false
            console.warn("cava exited:", exitCode, exitStatus)
        }
    }

    // =========================================================
    // SLIDER SYNC TIMER
    // =========================================================

    Timer {
        id: sliderSyncTimer
        interval: 350
        running: root.opened
        repeat: true
        onTriggered: {
            root.refreshVolume()
            root.refreshBrightness()
            root.refreshMute()
            root.refreshMicMute()
        }
    }

    // =========================================================
    // SYSTEM MONITOR PROCESS
    // =========================================================

    Process {
        id: sysMonProcess

        command: [
            "python3",
            "-u",
            root.sysMonScript
        ]

        running: root.opened && root.page === 2

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                try {
                    var data = JSON.parse(line);
                    root.cpuUsage = data.cpu;
                    root.ramUsage = data.mem;
                    root.gpuUsage = data.gpu;
                    root.vramUsage = data.vram;
                    root.memUsed = data.mem_used_gb;
                    root.memTotal = data.mem_total_gb;
                    root.vramUsed = data.vram_used_gb;
                    root.vramTotal = data.vram_total_gb;
                } catch (e) {
                    console.log("Error parsing system monitor output:", e);
                }
            }
        }

        onRunningChanged: {
            if (!running) {
                root.cpuUsage = 0.0;
                root.ramUsage = 0.0;
                root.gpuUsage = 0.0;
                root.vramUsage = 0.0;
                root.memUsed = 0.0;
                root.memTotal = 0.0;
                root.vramUsed = 0.0;
                root.vramTotal = 0.0;
            }
        }

        onExited: (exitCode, exitStatus) => {
            console.warn("sys-mon exited:", exitCode, exitStatus)
        }
    }

    // =========================================================
    // LYRICS FETCH PROCESS & FUNCTION
    // =========================================================

    Process {
        id: lyricsFetchProcess
        command: []
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(text.trim())
                    if (data.error) {
                        musicPage.lyricsRaw = data.error
                        musicPage.lyricsLines = []
                        musicPage.lyricsSynced = false
                    } else {
                        musicPage.lyricsRaw = ""
                        musicPage.lyricsLines = data.lines || []
                        musicPage.lyricsSynced = !!data.synced
                    }
                } catch (e) {
                    musicPage.lyricsRaw = "Error parsing lyrics"
                    musicPage.lyricsLines = []
                    musicPage.lyricsSynced = false
                }
                root.updateActiveLine()
            }
        }
    }

    function fetchLyrics() {
        var player = root.activeMprisPlayer
        if (!player) {
            musicPage.lyricsRaw = "No media player"
            musicPage.lyricsLines = []
            musicPage.lyricsSynced = false
            return
        }
        var title = player.trackTitle || ""
        var artist = player.trackArtist || ""
        if (title === "" || title === "No Track Playing") {
            musicPage.lyricsRaw = "No track playing"
            musicPage.lyricsLines = []
            musicPage.lyricsSynced = false
            return
        }
        musicPage.lyricsRaw = "Loading lyrics..."
        musicPage.lyricsLines = []
        musicPage.lyricsSynced = false
        lyricsFetchProcess.command = [
            "python3",
            (Quickshell.env("HOME") || "/home/sujay") + "/.config/quickshell/scripts/music/lyrics.py",
            artist,
            title
        ]
        lyricsFetchProcess.running = true
    }

    function updateActiveLine() {
        if (!musicPage.lyricsSynced || musicPage.lyricsLines.length === 0) {
            musicPage.activeLineIndex = -1
            return
        }
        var pos = root.mprisDisplayPosition
        var activeIndex = 0
        for (var i = 0; i < musicPage.lyricsLines.length; i++) {
            if (pos >= musicPage.lyricsLines[i].time) {
                activeIndex = i
            } else {
                break
            }
        }
        musicPage.activeLineIndex = activeIndex
    }

    onMprisDisplayPositionChanged: {
        root.updateActiveLine()
    }

    // =========================================================
    // CLICK OUTSIDE TO CLOSE
    // =========================================================

    MouseArea {
        anchors.fill: parent
        enabled: root.opened
        onClicked: {
            root.closePanel()
        }
    }

    // =========================================================
    // MAIN PANEL WINDOW
    // =========================================================

    Rectangle {
        id: panel

        width: 830
        height: 590

        anchors.horizontalCenter:
            parent.horizontalCenter

        anchors.bottom:
            parent.bottom

        anchors.bottomMargin:
            15

        y:
            root.opened
            ? parent.height - height - 15
            : parent.height + 40

        opacity:
            root.opened
            ? 1
            : 0

        scale:
            root.opened
            ? 1
            : 0.96

        radius: 24

        color:
            root.background

        border.width:
            1

        border.color:
            Qt.lighter(root.surface3, 1.3)

        clip:
            true

        focus:
            root.opened

        Keys.onEscapePressed: {
            root.closePanel()
        }

        MouseArea {
            anchors.fill: parent
            onClicked: (mouse) => mouse.accepted = true
            onPressed: (mouse) => mouse.accepted = true
            onReleased: (mouse) => mouse.accepted = true
            onWheel: (wheel) => wheel.accepted = true
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 240
                easing.type: Easing.OutCubic
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: 320
                easing.type: Easing.OutBack
            }
        }

        // =====================================================
        // MAIN LAYOUT
        // =====================================================

        ColumnLayout {
            anchors.fill: parent

            anchors.margins: 14

            spacing: 12

            // =================================================
            // NAVIGATION BAR
            // =================================================

            Rectangle {
                Layout.fillWidth: true

                Layout.preferredHeight: 50

                radius: 18

                color:
                    root.surface

                border.width:
                    1

                border.color:
                    "#18ffffff"

                RowLayout {
                    anchors.fill: parent

                    anchors.leftMargin: 6
                    anchors.rightMargin: 6

                    spacing: 4

                    Repeater {
                        model:
                            root.navItems

                        Rectangle {
                            id: navigationItem

                            Layout.fillWidth:
                                true

                            Layout.preferredHeight:
                                38

                            Layout.alignment:
                                Qt.AlignCenter

                            radius:
                                12

                            readonly property bool selected:
                                root.page === index

                            color:
                                selected
                                ? root.surface3
                                : navigationMouse.containsMouse
                                  ? root.surface2
                                  : "transparent"

                            border.width:
                                selected ? 1 : 0

                            border.color:
                                "#35ffffff"

                            Behavior on color {
                                ColorAnimation { duration: 150 }
                            }

                            MouseArea {
                                id: navigationMouse

                                anchors.fill:
                                    parent

                                hoverEnabled:
                                    true

                                cursorShape:
                                    Qt.PointingHandCursor

                                onClicked: {
                                    root.page = index
                                }
                            }

                            RowLayout {
                                anchors.centerIn:
                                    parent

                                spacing:
                                    6

                                Text {
                                    text:
                                        modelData.icon

                                    font.family:
                                        root.fontFamily

                                    font.pixelSize:
                                        18

                                    color:
                                        navigationItem.selected
                                        ? root.accent
                                        : root.textSecondary
                                }

                                Text {
                                    text:
                                        modelData.label

                                    font.family:
                                        root.fontFamily

                                    font.pixelSize:
                                        11

                                    font.bold:
                                        navigationItem.selected

                                    color:
                                        navigationItem.selected
                                        ? root.textPrimary
                                        : root.textSecondary
                                }
                            }
                        }
                    }
                }
            }

            // =================================================
            // CONTENT CONTAINER
            // =================================================

            Item {
                Layout.fillWidth:
                    true

                Layout.fillHeight:
                    true

                // =================================================
                // 0: DASHBOARD
                // =================================================

                Item {
                    id: dashboardPage

                    anchors.fill:
                        parent

                    visible:
                        root.page === 0

                    Item {
                        id: videoArea

                        anchors.fill:
                            parent

                        clip:
                            true

                        layer.enabled:
                            true

                        VideoOutput {
                            id: videoOutput

                            anchors.fill:
                                parent

                            visible:
                                root.opened &&
                                root.page === 0

                            fillMode:
                                VideoOutput.Stretch
                        }

                        // VIDEO MUTE BUTTON (Top Right Corner)
                        Rectangle {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 12
                            width: 32
                            height: 32
                            radius: 16
                            color: mediaAudioOutput.muted ? root.surface3 : "#80161215"
                            border.width: 1
                            border.color: mediaAudioOutput.muted ? root.danger : "#35ffffff"

                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: mediaAudioOutput.muted ? "󰝟" : "󰕾"
                                font.family: root.fontFamily
                                font.pixelSize: 14
                                color: mediaAudioOutput.muted ? root.danger : root.accent
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    mediaAudioOutput.muted = !mediaAudioOutput.muted
                                }
                            }
                        }

                        Rectangle {
                            id: controlsOverlay

                            anchors.left:
                                parent.left

                            anchors.right:
                                parent.right

                            anchors.bottom:
                                parent.bottom

                            anchors.margins:
                                14

                            height:
                                160

                            radius:
                                20

                            color:
                                "#e8161215"

                            border.width:
                                1

                            border.color:
                                "#35ffffff"

                            RowLayout {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14
                                anchors.topMargin: 12
                                height: 46
                                spacing: 8

                                // WIFI
                                Rectangle {
                                    id: wifiTile
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 14
                                    property bool active: true
                                    color: active ? root.surface3 : wifiMouse.containsMouse ? root.surface3 : root.surface2
                                    border.width: active ? 2 : 1
                                    border.color: active ? root.accent : "#25ffffff"

                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰤨"
                                        font.family: root.fontFamily
                                        font.pixelSize: 24
                                        color: wifiTile.active ? root.accent : root.textSecondary
                                    }

                                    MouseArea {
                                        id: wifiMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            wifiTile.active = !wifiTile.active
                                            Quickshell.execDetached(["bash", "-c", "nmcli radio wifi toggle"])
                                        }
                                    }
                                }

                                // BLUETOOTH
                                Rectangle {
                                    id: bluetoothTile
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 14
                                    property bool active: false
                                    color: active ? root.surface3 : bluetoothMouse.containsMouse ? root.surface3 : root.surface2
                                    border.width: active ? 2 : 1
                                    border.color: active ? root.accent : "#25ffffff"

                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰂯"
                                        font.family: root.fontFamily
                                        font.pixelSize: 24
                                        color: bluetoothTile.active ? root.accent : root.textSecondary
                                    }

                                    MouseArea {
                                        id: bluetoothMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            bluetoothTile.active = !bluetoothTile.active
                                            Quickshell.execDetached(["bash", "-c", bluetoothTile.active ? "rfkill unblock bluetooth" : "rfkill block bluetooth"])
                                        }
                                    }
                                }

                                // SCREEN RECORD
                                Rectangle {
                                    id: recordTile
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 14
                                    color: root.isRecording ? root.surface3 : recordMouse.containsMouse ? root.surface3 : root.surface2
                                    border.width: root.isRecording ? 2 : 1
                                    border.color: root.isRecording ? root.danger : "#25ffffff"

                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰻃"
                                        font.family: root.fontFamily
                                        font.pixelSize: 24
                                        color: root.isRecording ? root.danger : root.textSecondary
                                    }

                                    MouseArea {
                                        id: recordMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.isRecording = !root.isRecording
                                            if (root.isRecording) {
                                                Quickshell.execDetached(["bash", "-c", "wf-recorder -f ~/Videos/recording_$(date +%Y%m%d_%H%M%S).mp4"])
                                            } else {
                                                Quickshell.execDetached(["bash", "-c", "pkill wf-recorder"])
                                            }
                                        }
                                    }
                                }

                                // MUTE
                                Rectangle {
                                    id: muteTile
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 14
                                    color: root.isMuted ? root.surface3 : muteMouse.containsMouse ? root.surface3 : root.surface2
                                    border.width: root.isMuted ? 2 : 1
                                    border.color: root.isMuted ? root.danger : "#25ffffff"

                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: root.isMuted ? "󰝟" : "󰕾"
                                        font.family: root.fontFamily
                                        font.pixelSize: 24
                                        color: root.isMuted ? root.danger : root.textSecondary
                                    }

                                    MouseArea {
                                        id: muteMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.isMuted = !root.isMuted
                                            Quickshell.execDetached(["bash", "-c", root.isMuted ? "pactl set-sink-mute @DEFAULT_SINK@ 1" : "pactl set-sink-mute @DEFAULT_SINK@ 0"])
                                        }
                                    }
                                }

                                // MIC MUTE
                                Rectangle {
                                    id: micMuteTile
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 14
                                    color: root.isMicMuted ? root.surface3 : micMuteMouse.containsMouse ? root.surface3 : root.surface2
                                    border.width: root.isMicMuted ? 2 : 1
                                    border.color: root.isMicMuted ? root.danger : "#25ffffff"

                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: root.isMicMuted ? "󰍭" : "󰍬"
                                        font.family: root.fontFamily
                                        font.pixelSize: 24
                                        color: root.isMicMuted ? root.danger : root.textSecondary
                                    }

                                    MouseArea {
                                        id: micMuteMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.isMicMuted = !root.isMicMuted
                                            Quickshell.execDetached(["bash", "-c", root.isMicMuted ? "pactl set-source-mute @DEFAULT_SOURCE@ 1" : "pactl set-source-mute @DEFAULT_SOURCE@ 0"])
                                        }
                                    }
                                }

                                // SETTINGS
                                Rectangle {
                                    id: settingsTile
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 14
                                    color: root.page === 4 ? root.surface3 : settingsMouse.containsMouse ? root.surface3 : root.surface2
                                    border.width: root.page === 4 ? 2 : 1
                                    border.color: root.page === 4 ? root.accent : "#25ffffff"

                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰒓"
                                        font.family: root.fontFamily
                                        font.pixelSize: 24
                                        color: root.page === 4 ? root.accent : root.textSecondary
                                    }

                                    MouseArea {
                                        id: settingsMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: { root.page = 4 }
                                    }
                                }

                                // POWER
                                Rectangle {
                                    id: powerTileBtn
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 14
                                    color: root.page === 5 ? root.surface3 : powerBtnMouse.containsMouse ? root.surface3 : root.surface2
                                    border.width: root.page === 5 ? 2 : 1
                                    border.color: root.page === 5 ? root.danger : "#25ffffff"

                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰐥"
                                        font.family: root.fontFamily
                                        font.pixelSize: 24
                                        color: root.page === 5 ? root.danger : root.textSecondary
                                    }

                                    MouseArea {
                                        id: powerBtnMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.page = 5
                                            root.pendingPowerAction = -1
                                        }
                                    }
                                }
                            }

                            // Volume Slider
                            Column {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: brightnessRow.top
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14
                                anchors.bottomMargin: 8
                                spacing: 4

                                RowLayout {
                                    width: parent.width
                                    spacing: 7
                                    Text { text: "󰕾"; font.family: root.fontFamily; font.pixelSize: 15; color: root.accent }
                                    Text { text: "Volume"; font.family: root.fontFamily; font.pixelSize: 10; font.bold: true; color: root.textPrimary }
                                    Item { Layout.fillWidth: true }
                                    Text { text: Math.round(volumeBar.value * 100) + "%"; font.family: root.fontFamily; font.pixelSize: 9; color: root.textSecondary }
                                }

                                Rectangle {
                                    id: volumeBar
                                    width: parent.width
                                    height: 8
                                    radius: 4
                                    color: root.surface2
                                    property real value: 0.65

                                    Rectangle {
                                        width: parent.width * parent.value
                                        height: parent.height
                                        radius: 4
                                        gradient: Gradient {
                                                     orientation: Gradient.Horizontal
                                                     GradientStop { position: 0.0; color: root.accent }
                                                     GradientStop { position: 1.0; color: "#e0e7ff" }
                                                 }
                                        Behavior on width { NumberAnimation { duration: 40; easing.type: Easing.OutQuad } }
                                    }

                                    Rectangle {
                                        width: 14
                                        height: 14
                                        radius: 7
                                        x: Math.max(0, Math.min(parent.width - width, parent.width * parent.value - width / 2))
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: root.textPrimary
                                        border.width: 2
                                        border.color: root.accent
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onPressed: function(mouse) {
                                            volumeBar.value = Math.max(0, Math.min(1, mouse.x / volumeBar.width))
                                            Quickshell.execDetached(["bash", "-c", "pactl set-sink-volume @DEFAULT_SINK@ " + Math.round(volumeBar.value * 100) + "%"])
                                        }
                                        onPositionChanged: function(mouse) {
                                            if (!pressed) return
                                            volumeBar.value = Math.max(0, Math.min(1, mouse.x / volumeBar.width))
                                            Quickshell.execDetached(["bash", "-c", "pactl set-sink-volume @DEFAULT_SINK@ " + Math.round(volumeBar.value * 100) + "%"])
                                        }
                                        onWheel: function(wheel) {
                                            var step = wheel.angleDelta.y > 0 ? 0.05 : -0.05
                                            volumeBar.value = Math.max(0, Math.min(1, volumeBar.value + step))
                                            Quickshell.execDetached(["bash", "-c", "pactl set-sink-volume @DEFAULT_SINK@ " + Math.round(volumeBar.value * 100) + "%"])
                                        }
                                    }
                                }
                            }

                            // Brightness Slider
                            Column {
                                id: brightnessRow
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14
                                anchors.bottomMargin: 10
                                spacing: 4

                                RowLayout {
                                    width: parent.width
                                    spacing: 7
                                    Text { text: "󰃠"; font.family: root.fontFamily; font.pixelSize: 15; color: root.accent }
                                    Text { text: "Brightness"; font.family: root.fontFamily; font.pixelSize: 10; font.bold: true; color: root.textPrimary }
                                    Item { Layout.fillWidth: true }
                                    Text { text: Math.round(brightnessBar.value * 100) + "%"; font.family: root.fontFamily; font.pixelSize: 9; color: root.textSecondary }
                                }

                                Rectangle {
                                    id: brightnessBar
                                    width: parent.width
                                    height: 8
                                    radius: 4
                                    color: root.surface2
                                    property real value: 0.80

                                    Rectangle {
                                        width: parent.width * parent.value
                                        height: parent.height
                                        radius: 4
                                        gradient: Gradient {
                                                     orientation: Gradient.Horizontal
                                                     GradientStop { position: 0.0; color: root.accent }
                                                     GradientStop { position: 1.0; color: "#e0e7ff" }
                                                 }
                                        Behavior on width { NumberAnimation { duration: 40; easing.type: Easing.OutQuad } }
                                    }

                                    Rectangle {
                                        width: 14
                                        height: 14
                                        radius: 7
                                        x: Math.max(0, Math.min(parent.width - width, parent.width * parent.value - width / 2))
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: root.textPrimary
                                        border.width: 2
                                        border.color: root.accent
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onPressed: function(mouse) {
                                            brightnessBar.value = Math.max(0, Math.min(1, mouse.x / brightnessBar.width))
                                            Quickshell.execDetached(["bash", "-c", "brightnessctl set " + Math.round(brightnessBar.value * 100) + "%"])
                                        }
                                        onPositionChanged: function(mouse) {
                                            if (!pressed) return
                                            brightnessBar.value = Math.max(0, Math.min(1, mouse.x / brightnessBar.width))
                                            Quickshell.execDetached(["bash", "-c", "brightnessctl set " + Math.round(brightnessBar.value * 100) + "%"])
                                        }
                                        onWheel: function(wheel) {
                                            var step = wheel.angleDelta.y > 0 ? 0.05 : -0.05
                                            brightnessBar.value = Math.max(0, Math.min(1, brightnessBar.value + step))
                                            Quickshell.execDetached(["bash", "-c", "brightnessctl set " + Math.round(brightnessBar.value * 100) + "%"])
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // =================================================
                // 1: MUSIC (INTEGRATED WITH MPRIS FOR SPOTIFY ETC.)
                // =================================================

                Item {
                    id: musicPage
                    property string lyricsRaw: ""
                    property var lyricsLines: []
                    property bool lyricsSynced: false
                    property int activeLineIndex: -1

                    anchors.fill:
                        parent

                    visible:
                        root.page === 1

                    RowLayout {
                        anchors.fill: parent
                        spacing: 12

                        // Left Side: MPRIS Music Player Control Panel
                        Rectangle {
                            Layout.fillHeight: true
                            Layout.preferredWidth: parent.width * 0.55
                            radius: 20
                            color: root.surface
                            border.width: 1
                            border.color: "#20ffffff"
                            clip: true

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 12

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 14

                                    Rectangle {
                                        id: vinylArt
                                        width: 120
                                        height: 120
                                        radius: 16
                                        color: root.surface2
                                        border.width: 2
                                        border.color: root.accent
                                        clip: true

                                        Image {
                                            anchors.fill: parent
                                            source: root.activeMprisPlayer && root.activeMprisPlayer.trackArtUrl ? root.activeMprisPlayer.trackArtUrl : ""
                                            fillMode: Image.PreserveAspectCrop
                                        }

                                        // Fallback icon if no album art exists
                                        Text {
                                            anchors.centerIn: parent
                                            visible: !root.activeMprisPlayer || !root.activeMprisPlayer.trackArtUrl
                                            text: "󰎆"
                                            font.family: root.fontFamily
                                            font.pixelSize: 36
                                            color: root.textSecondary
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        spacing: 8

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2
                                            Text {
                                                text: root.activeMprisPlayer ? (root.activeMprisPlayer.trackTitle || "No Track Playing") : "No Media Player"
                                                font.family: root.fontFamily
                                                font.pixelSize: 14
                                                font.bold: true
                                                color: root.textPrimary
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                            RowLayout {
                                                spacing: 6
                                                Text {
                                                    text: root.activeMprisPlayer ? (root.activeMprisPlayer.trackArtist || "Unknown Artist") : "Offline"
                                                    font.family: root.fontFamily
                                                    font.pixelSize: 10
                                                    color: root.textSecondary
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                                Text {
                                                    text: root.activeMprisPlayer ? ("VIA " + (root.activeMprisPlayer.identity || "App")) : ""
                                                    font.family: root.fontFamily
                                                    font.pixelSize: 9
                                                    font.italic: true
                                                    color: root.textSecondary
                                                }
                                            }
                                        }

                                        // Track Progress Bar (Linked to MPRIS position)
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 3

                                            Rectangle {
                                                id: progressSliderBg
                                                Layout.fillWidth: true
                                                height: 6
                                                radius: 3
                                                color: root.surface2

                                                Rectangle {
                                                    width: parent.width * (root.activeMprisPlayer && root.activeMprisPlayer.length > 0 ? root.mprisDisplayPosition / root.activeMprisPlayer.length : 0)
                                                    height: parent.height
                                                    radius: 3
                                                    color: root.accent
                                                    Behavior on width { NumberAnimation { duration: 40 } }
                                                }

                                                Rectangle {
                                                    width: 12
                                                    height: 12
                                                    radius: 6
                                                    x: Math.max(0, Math.min(parent.width - width, parent.width * (root.activeMprisPlayer && root.activeMprisPlayer.length > 0 ? root.mprisDisplayPosition / root.activeMprisPlayer.length : 0) - width / 2))
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    color: root.textPrimary
                                                    border.width: 2
                                                    border.color: root.accent
                                                }

                                                MouseArea {
                                                    id: progressSliderMouse
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onPressed: (mouse) => {
                                                        if (root.activeMprisPlayer && root.activeMprisPlayer.length > 0) {
                                                            var posRatio = Math.max(0, Math.min(1, mouse.x / progressSliderBg.width))
                                                            root.activeMprisPlayer.position = root.activeMprisPlayer.length * posRatio
                                                             root.mprisDisplayPosition = root.activeMprisPlayer.position
                                                        }
                                                    }
                                                    onPositionChanged: (mouse) => {
                                                        if (pressed && root.activeMprisPlayer && root.activeMprisPlayer.length > 0) {
                                                            var posRatio = Math.max(0, Math.min(1, mouse.x / progressSliderBg.width))
                                                            root.activeMprisPlayer.position = root.activeMprisPlayer.length * posRatio
                                                             root.mprisDisplayPosition = root.activeMprisPlayer.position
                                                        }
                                                    }
                                                }
                                            }

                                            RowLayout {
                                                Layout.fillWidth: true
                                                Text { 
                                                    text: {
                                                        if (!root.activeMprisPlayer) return "00:00"
                                                        var pos = root.mprisDisplayPosition
                                                        var m = Math.floor(pos / 60)
                                                        var s = Math.floor(pos % 60)
                                                        return (m < 10 ? "0" + m : m) + ":" + (s < 10 ? "0" + s : s)
                                                    }
                                                    font.family: root.fontFamily; font.pixelSize: 9; color: root.textSecondary 
                                                }
                                                Item { Layout.fillWidth: true }
                                                Text { 
                                                    text: {
                                                        if (!root.activeMprisPlayer) return "--:--"
                                                        var dur = root.activeMprisPlayer.length
                                                        var m = Math.floor(dur / 60)
                                                        var s = Math.floor(dur % 60)
                                                        return dur > 0 ? ((m < 10 ? "0" + m : m) + ":" + (s < 10 ? "0" + s : s)) : "--:--"
                                                    }
                                                    font.family: root.fontFamily; font.pixelSize: 9; color: root.textSecondary 
                                                }
                                            }
                                        }

                                        // Playback Control Buttons (Previous, Play/Pause, Next)
                                        RowLayout {
                                            Layout.alignment: Qt.AlignHCenter
                                            spacing: 24

                                            Text {
                                                text: "󰒮"
                                                font.family: root.fontFamily
                                                font.pixelSize: 18
                                                color: root.textPrimary
                                                MouseArea { 
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        if (root.activeMprisPlayer) root.activeMprisPlayer.previous()
                                                    }
                                                }
                                            }

                                            Rectangle {
                                                width: 36
                                                height: 36
                                                radius: 18
                                                color: root.accent

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: root.activeMprisPlayer && root.activeMprisPlayer.playbackState === MprisPlaybackState.Playing ? "󰏤" : "󰐊"
                                                    font.family: root.fontFamily
                                                    font.pixelSize: 18
                                                    color: root.background
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        if (root.activeMprisPlayer) root.activeMprisPlayer.togglePlaying()
                                                    }
                                                }
                                            }

                                            Text {
                                                text: "󰒭"
                                                font.family: root.fontFamily
                                                font.pixelSize: 18
                                                color: root.textPrimary
                                                MouseArea { 
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        if (root.activeMprisPlayer) root.activeMprisPlayer.next()
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 1
                                    color: "#20ffffff"
                                }

                                ColumnLayout {
                                     Layout.fillWidth: true
                                     Layout.fillHeight: true
                                     spacing: 12

                                    RowLayout {
                                         Layout.fillWidth: true

                                         Text {
                                             text: "󰎈 Audio Spectrum"
                                             font.family: root.fontFamily
                                             font.pixelSize: 12
                                             font.bold: true
                                             color: root.textPrimary
                                         }

                                         Item { Layout.fillWidth: true }

                                         Text {
                                             text: root.cavaActive ? "Live (PipeWire)" : "Standby"
                                             font.family: root.fontFamily
                                             font.pixelSize: 10
                                             color: root.cavaActive ? root.accent : root.textSecondary
                                         }
                                     }

                                     Item {
                                         Layout.fillWidth: true
                                         Layout.fillHeight: true

                                         Canvas {
                                             id: circularVisualizerCanvas
                                             anchors.centerIn: parent
                                             width: Math.min(parent.width - 10, parent.height - 10, 260)
                                             height: width

                                             property var bands: root.spectrumBands
                                             property color accentColor: root.accent
                                             property color textSecColor: root.textSecondary
                                             property color surfaceCol: root.surface2
                                             property color textPrimColor: root.textPrimary

                                             onBandsChanged: requestPaint()
                                             onAccentColorChanged: requestPaint()
                                             onTextSecColorChanged: requestPaint()
                                             onWidthChanged: requestPaint()
                                             onHeightChanged: requestPaint()

                                             Connections {
                                                 target: root
                                                 function onSpectrumBandsChanged() {
                                                     circularVisualizerCanvas.requestPaint()
                                                 }
                                             }

                                             onPaint: {
                                                var ctx = getContext("2d");
                                                console.log("Canvas onPaint. Bands length:", bands ? bands.length : 0, "width:", width);
                                                ctx.clearRect(0, 0, width, height);

                                                 var cx = width / 2;
                                                 var cy = height / 2;
                                                 var maxR = width / 2 - 2;
                                                 var innerR = maxR * 0.55;
                                                 var maxBarLen = maxR - innerR - 6;

                                                 var bList = bands && bands.length > 0 ? bands : [];
                                                 var count = bList.length > 0 ? bList.length : 36;

                                                 // 1. Central background glow / disc
                                                 ctx.save();
                                                 ctx.beginPath();
                                                 ctx.arc(cx, cy, innerR - 10, 0, 2 * Math.PI);
                                                 ctx.fillStyle = surfaceCol.toString();
                                                 ctx.globalAlpha = 0.25;
                                                 ctx.fill();
                                                 ctx.restore();

                                                 // 2. Inner precision ticks (60 tick marks around dial)
                                                 ctx.save();
                                                 ctx.strokeStyle = textSecColor.toString();
                                                 ctx.globalAlpha = 0.35;
                                                 ctx.lineWidth = 1.0;
                                                 for (var t = 0; t < 60; t++) {
                                                     var tickAngle = (t * 6.0) * Math.PI / 180.0;
                                                     var rStartTick = innerR - 14;
                                                     var rEndTick = innerR - (t % 5 === 0 ? 6 : 10);
                                                     var tx1 = cx + rStartTick * Math.cos(tickAngle);
                                                     var ty1 = cy + rStartTick * Math.sin(tickAngle);
                                                     var tx2 = cx + rEndTick * Math.cos(tickAngle);
                                                     var ty2 = cy + rEndTick * Math.sin(tickAngle);
                                                     ctx.beginPath();
                                                     ctx.moveTo(tx1, ty1);
                                                     ctx.lineTo(tx2, ty2);
                                                     ctx.stroke();
                                                 }
                                                 ctx.restore();

                                                 // 3. Inner dashed accent ring
                                                 ctx.save();
                                                 ctx.beginPath();
                                                 ctx.arc(cx, cy, innerR - 4, 0, 2 * Math.PI);
                                                 ctx.strokeStyle = accentColor.toString();
                                                 ctx.lineWidth = 1.5;
                                                 ctx.globalAlpha = 0.45;
                                                 ctx.setLineDash([5, 5]);
                                                 ctx.stroke();
                                                 ctx.restore();

                                                 // 4. Main solid accent ring
                                                 ctx.save();
                                                 ctx.beginPath();
                                                 ctx.arc(cx, cy, innerR, 0, 2 * Math.PI);
                                                 ctx.strokeStyle = accentColor.toString();
                                                 ctx.lineWidth = 2.0;
                                                 ctx.globalAlpha = 0.95;
                                                 ctx.stroke();
                                                 ctx.restore();

                                                 // 5. Radial Audio Spectrum Bars (360° around ring)
                                                 ctx.save();
                                                 var angleStep = (2 * Math.PI) / count;
                                                 var startAngle = -Math.PI / 2; // Top start

                                                 for (var i = 0; i < count; i++) {
                                                     var rawVal = (bList.length > 0 && bList[i] !== undefined) ? bList[i] : 0.0;
                                                     var val = Math.max(0.02, Math.min(1.0, rawVal));
                                                     var angle = startAngle + i * angleStep;

                                                     var r1 = innerR + 4;
                                                     var r2 = r1 + val * maxBarLen;

                                                     var x1 = cx + r1 * Math.cos(angle);
                                                     var y1 = cy + r1 * Math.sin(angle);
                                                     var x2 = cx + r2 * Math.cos(angle);
                                                     var y2 = cy + r2 * Math.sin(angle);

                                                     ctx.beginPath();
                                                     ctx.moveTo(x1, y1);
                                                     ctx.lineTo(x2, y2);
                                                     ctx.strokeStyle = accentColor.toString();
                                                     ctx.lineWidth = 2.2;
                                                     ctx.lineCap = "round";
                                                     ctx.globalAlpha = Math.max(0.3, Math.min(1.0, val * 1.2));
                                                     ctx.stroke();
                                                 }
                                                 ctx.restore();
                                             }
                                         }

                                         // Center Icon / Waveform symbol
                                         Text {
                                             anchors.centerIn: parent
                                             text: root.cavaActive ? "󰎈" : "󰓃"
                                             font.family: root.fontFamily
                                             font.pixelSize: 26
                                             color: root.accent
                                             opacity: root.cavaActive ? 0.9 : 0.4
                                         }
                                     }
                                 }
                             }
                         }

                        // Right Side: Spotify-style Lyrics (and nothing else)
                        Rectangle {
                            Layout.fillHeight: true
                            Layout.fillWidth: true
                            radius: 20
                            color: root.surface
                            border.width: 1
                            border.color: "#20ffffff"
                            clip: true

                            MediaPlayer {
                                id: secondaryMediaPlayer
                                source: ""
                                loops: MediaPlayer.Infinite
                            }

                            ListView {
                                id: lyricsListView
                                anchors.fill: parent
                                anchors.margins: 28
                                clip: true
                                model: musicPage.lyricsLines.length > 0 ? musicPage.lyricsLines : [{"text": (musicPage.lyricsRaw ? musicPage.lyricsRaw : (root.activeMprisPlayer ? "No lyrics available" : "No media player"))}]
                                spacing: 20

                                Behavior on contentY {
                                    NumberAnimation {
                                        duration: 450
                                        easing.type: Easing.OutCubic
                                    }
                                }

                                delegate: Item {
                                    width: ListView.view ? ListView.view.width : parent.width
                                    height: lyricText.implicitHeight

                                    Text {
                                        id: lyricText
                                        width: parent.width
                                        wrapMode: Text.Wrap
                                        text: modelData.text
                                        font.family: root.fontFamily
                                        
                                        readonly property bool isActive: musicPage.lyricsSynced && index === musicPage.activeLineIndex
                                        
                                        font.pixelSize: isActive ? 22 : 17
                                        font.bold: true
                                        color: isActive ? root.accent : root.textPrimary
                                        opacity: isActive ? 1.0 : (musicPage.lyricsSynced ? 0.45 : 0.9)
                                        
                                        Behavior on font.pixelSize { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                                        Behavior on color { ColorAnimation { duration: 280 } }
                                        Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                                    }
                                }

                                Connections {
                                    target: musicPage
                                    function onActiveLineIndexChanged() {
                                        if (musicPage.lyricsSynced && musicPage.activeLineIndex >= 0) {
                                            lyricsListView.positionViewAtIndex(musicPage.activeLineIndex, ListView.Center)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // =================================================
                // 2: PERFORMANCE
                // =================================================

                Item {
                    id: performancePage

                    anchors.fill:
                        parent

                    visible:
                        root.page === 2

                    ColumnLayout {
                        anchors.fill:
                            parent

                        spacing:
                            12

                        Text {
                            text:
                                "Performance"

                            font.family:
                                root.fontFamily

                            font.pixelSize:
                                22

                            font.bold:
                                true

                            color:
                                root.textPrimary
                        }

                        RowLayout {
                            Layout.fillWidth:
                                true

                            Layout.preferredHeight:
                                145

                            spacing:
                                12

                            Repeater {
                                model: [
                                    ["󰍛", "CPU"],
                                    ["󰘚", "RAM"],
                                    ["󰢮", "GPU"]
                                ]

                                Rectangle {
                                    Layout.fillWidth:
                                        true

                                    Layout.fillHeight:
                                        true

                                    radius:
                                        18

                                    clip: true

                                     gradient: Gradient {
                                          GradientStop { position: 0.0; color: root.surface2 }
                                          GradientStop { position: 1.0; color: root.surface }
                                      }
                                     border.width:
                                         1

                                     border.color: "#25b6c4ff"

                                     // Visual background progress fill matching the usage percentage
                                     Rectangle {
                                         anchors.bottom: parent.bottom
                                         anchors.left: parent.left
                                         anchors.right: parent.right
                                         height: {
                                             var usage = 0.0;
                                             if (index === 0) usage = root.cpuUsage;
                                             else if (index === 1) usage = root.ramUsage;
                                             else if (index === 2) usage = root.gpuUsage;
                                             return parent.height * usage;
                                         }
                                         color: "#18b6c4ff" // Subtle overlay with 10% opacity

                                         Behavior on height {
                                             NumberAnimation { duration: 300; easing.type: Easing.OutQuad }
                                         }
                                     }

                                     Column {
                                        anchors.centerIn:
                                            parent

                                        spacing:
                                            6

                                        Text {
                                            anchors.horizontalCenter:
                                                parent.horizontalCenter

                                            text:
                                                modelData[0]

                                            font.family:
                                                root.fontFamily

                                            font.pixelSize:
                                                30

                                            color:
                                                root.accent
                                        }

                                        Text {
                                            anchors.horizontalCenter:
                                                parent.horizontalCenter

                                            text:
                                                modelData[1]

                                            font.family:
                                                root.fontFamily

                                            font.pixelSize:
                                                10

                                            color:
                                                root.textSecondary
                                        }

                                        Text {
                                            anchors.horizontalCenter:
                                                parent.horizontalCenter

                                            text: {
                                                if (index === 0) return Math.round(root.cpuUsage * 100) + "%"
                                                if (index === 1) return root.memUsed.toFixed(1) + "/" + root.memTotal.toFixed(1) + " GB"
                                                if (index === 2) return Math.round(root.gpuUsage * 100) + "%"
                                                return "0%"
                                            }

                                            font.family:
                                                root.fontFamily

                                            font.pixelSize:
                                                index === 1 ? 14 : 20

                                            font.bold:
                                                true

                                            color:
                                                root.textPrimary
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth:
                                true

                            Layout.fillHeight:
                                true

                            radius:
                                18

                            color:
                                root.surface

                            Column {
                                anchors.fill:
                                    parent

                                anchors.margins:
                                    20

                                spacing:
                                    16

                                Text {
                                    text:
                                        "System Load"

                                    font.family:
                                        root.fontFamily

                                    font.pixelSize:
                                        14

                                    font.bold:
                                        true

                                    color:
                                        root.textPrimary
                                }

                                Repeater {
                                    model: [
                                        "CPU",
                                        "Memory",
                                        "GPU",
                                        "VRAM"
                                    ]

                                    RowLayout {
                                        width:
                                            parent.width

                                        spacing:
                                            12

                                        Text {
                                            Layout.preferredWidth:
                                                65

                                            text:
                                                modelData

                                            font.family:
                                                root.fontFamily

                                            font.pixelSize:
                                                9

                                            color:
                                                root.textSecondary
                                        }

                                        Rectangle {
                                            Layout.fillWidth:
                                                true

                                            height:
                                                8

                                            radius:
                                                4

                                            color:
                                                root.surface3

                                            Rectangle {
                                                width: {
                                                    var val = 0.0
                                                    if (index === 0) val = root.cpuUsage
                                                    else if (index === 1) val = root.ramUsage
                                                    else if (index === 2) val = root.gpuUsage
                                                    else if (index === 3) val = root.vramUsage
                                                    return parent.width * val
                                                }

                                                height:
                                                    parent.height

                                                radius:
                                                    4

                                                gradient: Gradient {
                                                     orientation: Gradient.Horizontal
                                                     GradientStop { position: 0.0; color: root.accent }
                                                     GradientStop { position: 1.0; color: "#e0e7ff" }
                                                 }
                                            }
                                        }

                                        Text {
                                            Layout.preferredWidth:
                                                (index === 1 || index === 3) ? 75 : 40

                                            text: {
                                                if (index === 0) return Math.round(root.cpuUsage * 100) + "%"
                                                if (index === 1) return root.memUsed.toFixed(1) + "/" + root.memTotal.toFixed(1) + " GB"
                                                if (index === 2) return Math.round(root.gpuUsage * 100) + "%"
                                                if (index === 3) return root.vramUsed.toFixed(1) + "/" + root.vramTotal.toFixed(1) + " GB"
                                                return "0%"
                                            }

                                            font.family:
                                                root.fontFamily

                                            font.pixelSize:
                                                8

                                            horizontalAlignment:
                                                Text.AlignRight

                                            color:
                                                root.textSecondary
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // =================================================
                // 3: NOTIFICATIONS
                // =================================================

                Item {
                    id: notificationsPage

                    anchors.fill:
                        parent

                    visible:
                        root.page === 3

                    Rectangle {
                        anchors.fill:
                            parent

                        radius:
                            20

                        color:
                            root.surface

                        Column {
                            anchors.centerIn:
                                parent

                            spacing:
                                10

                            Text {
                                anchors.horizontalCenter:
                                    parent.horizontalCenter

                                text:
                                    "󰂚"

                                font.family:
                                    root.fontFamily

                                font.pixelSize:
                                    58

                                color:
                                    root.accent
                            }

                            Text {
                                anchors.horizontalCenter:
                                    parent.horizontalCenter

                                text:
                                    "No notifications"

                                font.family:
                                    root.fontFamily

                                font.pixelSize:
                                    12

                                color:
                                    root.textSecondary
                            }
                        }
                    }
                }

                // =================================================
                // 4: SETTINGS
                // =================================================

                Item {
                    id: settingsPage

                    anchors.fill:
                        parent

                    visible:
                        root.page === 4

                    ColumnLayout {
                        anchors.fill:
                            parent

                        spacing:
                            12

                        Text {
                            text:
                                "Settings"

                            font.family:
                                root.fontFamily

                            font.pixelSize:
                                22

                            font.bold:
                                true

                            color:
                                root.textPrimary
                        }

                        GridLayout {
                            Layout.fillWidth:
                                true

                            Layout.fillHeight:
                                true

                            columns:
                                2

                            rowSpacing:
                                12

                            columnSpacing:
                                12

                            Repeater {
                                model: [
                                    { icon: "󰌌", title: "Keybindings", desc: "Configure shortcuts" },
                                    { icon: "󰉼", title: "Appearance", desc: "Themes and colors" },
                                    { icon: "󰖩", title: "Network", desc: "Connections and Wi-Fi" },
                                    { icon: "󰂯", title: "Bluetooth", desc: "Paired devices" }
                                ]

                                Rectangle {
                                    Layout.fillWidth:
                                        true

                                    Layout.preferredHeight:
                                        90

                                    radius:
                                        18

                                    color:
                                        root.surface

                                    border.width:
                                        1

                                    border.color:
                                        "#20ffffff"

                                    RowLayout {
                                        anchors.centerIn:
                                            parent

                                        spacing:
                                            14

                                        Text {
                                            text:
                                                modelData.icon

                                            font.family:
                                                root.fontFamily

                                            font.pixelSize:
                                                26

                                            color:
                                                root.accent
                                        }

                                        ColumnLayout {
                                            spacing:
                                                2

                                            Text {
                                                text:
                                                    modelData.title

                                                font.family:
                                                    root.fontFamily

                                                font.pixelSize:
                                                    12

                                                font.bold:
                                                    true

                                                color:
                                                    root.textPrimary
                                            }

                                            Text {
                                                text:
                                                    modelData.desc

                                                font.family:
                                                    root.fontFamily

                                                font.pixelSize:
                                                    8

                                                color:
                                                    root.textSecondary
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // =================================================
                // 5: POWER
                // =================================================

                Item {
                    id: powerPage

                    anchors.fill:
                        parent

                    visible:
                        root.page === 5

                    ColumnLayout {
                        anchors.centerIn:
                            parent

                        width:
                            500

                        spacing:
                            14

                        Text {
                            Layout.alignment:
                                Qt.AlignHCenter

                            text:
                                "Power"

                            font.family:
                                root.fontFamily

                            font.pixelSize:
                                24

                            font.bold:
                                true

                            color:
                                root.textPrimary
                        }

                        Text {
                            Layout.alignment:
                                Qt.AlignHCenter

                            text:
                                root.pendingPowerAction === -1
                                ? "Choose a system action"
                                : "Click again to confirm"

                            font.family:
                                root.fontFamily

                            font.pixelSize:
                                10

                            color:
                                root.pendingPowerAction === -1
                                ? root.textSecondary
                                : root.warning
                        }

                        GridLayout {
                            Layout.fillWidth:
                                true

                            columns:
                                2

                            rowSpacing:
                                12

                            columnSpacing:
                                12

                            Repeater {
                                model:
                                    root.powerActions

                                Rectangle {
                                    id: powerTile

                                    Layout.fillWidth:
                                        true

                                    Layout.preferredHeight:
                                        100

                                    radius:
                                        18

                                    readonly property bool pending:
                                        root.pendingPowerAction === index

                                    readonly property bool dangerAction:
                                        index === 0 ||
                                        index === 1

                                    color:
                                        pending
                                        ? root.surface3
                                        : powerMouse.containsMouse
                                          ? root.surface2
                                          : root.surface

                                    border.width:
                                        pending
                                        ? 2
                                        : 1

                                    border.color:
                                        pending
                                        ? root.danger
                                        : "#25ffffff"

                                    MouseArea {
                                        id: powerMouse

                                        anchors.fill:
                                            parent

                                        hoverEnabled:
                                            true

                                        cursorShape:
                                            Qt.PointingHandCursor

                                        onClicked: {

                                            if (powerTile.pending) {

                                                Quickshell.execDetached([
                                                    "bash",
                                                    "-c",
                                                    modelData.cmd
                                                ])

                                                root.pendingPowerAction =
                                                    -1

                                                root.closePanel()

                                            } else {

                                                root.pendingPowerAction =
                                                    index

                                                powerTimer.restart()
                                            }
                                        }
                                    }

                                    RowLayout {
                                        anchors.centerIn:
                                            parent

                                        spacing:
                                            14

                                        Text {
                                            text:
                                                modelData.icon

                                            font.family:
                                                root.fontFamily

                                            font.pixelSize:
                                                29

                                            color:
                                                powerTile.dangerAction
                                                ? root.danger
                                                : root.accent
                                        }

                                        ColumnLayout {
                                            spacing:
                                                2

                                            Text {
                                                text:
                                                    powerTile.pending
                                                    ? "Confirm?"
                                                    : modelData.label

                                                font.family:
                                                    root.fontFamily

                                                font.pixelSize:
                                                    12

                                                font.bold:
                                                    true

                                                color:
                                                    root.textPrimary
                                            }

                                            Text {
                                                text:
                                                    modelData.description

                                                font.family:
                                                    root.fontFamily

                                                font.pixelSize:
                                                    8

                                                color:
                                                    root.textSecondary
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // =========================================================
    // FILE LOADER
    // =========================================================

    FileView {
        id: colorFile

        path: root.colorFilePath 
        watchChanges: true
        printErrors: true

        onFileChanged: {
            reload()
            root.applyColors(colorFile.text)
        }

        onLoaded: {
            root.applyColors(colorFile.text())
        }
    }

    // =========================================================
    // INITIALIZATION
    // =========================================================

    Component.onCompleted: {
        root.applyColors(colorFile.text)
        root.writeCavaConfig()
        root.refreshEq()
        root.refreshVolume()
        root.refreshBrightness()
        root.refreshMute()
        root.refreshMicMute()

        if (root.opened && root.page === 0)
            root.updateMedia()
    }
}
