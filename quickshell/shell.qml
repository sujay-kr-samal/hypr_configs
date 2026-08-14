//@ pragma UseQApplication

import QtQuick
import Quickshell

ShellRoot {
    id: shell

    AppLauncher {
        id: appLauncher
    }

    Topbar {
        id: topbar
    }

    WallpaperPicker {
        id: wallpaperPicker
    }

    ControlCenter {
        id: controlCenter
    }

    Connections {
        target: topbar

        function onClockClicked() {
            controlCenter.toggle()
        }
    }
}