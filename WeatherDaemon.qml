import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Modules.Plugins

PluginComponent {
    id: root
    property var popoutService: null

    readonly property bool fxEnabled: pluginData.enabled !== false
    readonly property bool autoWeather: pluginData.autoWeather !== false
    readonly property bool manualRain: pluginData.rain === true
    readonly property bool manualFog: pluginData.fog === true
    readonly property bool manualThunder: pluginData.thunder === true
    readonly property bool manualNight: pluginData.night === true
    readonly property real intensity: Math.max(0.20, Math.min(2.0,
        Number(pluginData.intensityPercent === undefined ? 100 : pluginData.intensityPercent) / 100.0))
    readonly property real wind: Math.max(-1.0, Math.min(1.0,
        Number(pluginData.windPercent === undefined ? 0 : pluginData.windPercent) / 100.0))

    property int localHour: new Date().getHours()
    readonly property bool localIsDay: localHour >= 6 && localHour < 18
    readonly property bool weatherAvailable: WeatherService.weather && WeatherService.weather.available === true
    readonly property int weatherCode: weatherAvailable ? Number(WeatherService.weather.wCode) : -1
    readonly property bool isDay: autoWeather
        ? (weatherAvailable ? WeatherService.weather.isDay === true : localIsDay)
        : !manualNight

    function rainCode(code) {
        return (code >= 51 && code <= 67) || (code >= 80 && code <= 82) || code >= 95
    }

    function fogCode(code) {
        return code === 45 || code === 48
    }

    function thunderCode(code) {
        return code >= 95
    }

    readonly property bool rainOn: fxEnabled && (autoWeather ? (weatherAvailable && rainCode(weatherCode)) : manualRain)
    readonly property bool fogOn: fxEnabled && (autoWeather ? (weatherAvailable && fogCode(weatherCode)) : manualFog)
    readonly property bool thunderOn: fxEnabled && rainOn && (autoWeather ? (weatherAvailable && thunderCode(weatherCode)) : manualThunder)
    readonly property bool nightOn: fxEnabled && !isDay
    readonly property bool dayOn: fxEnabled && isDay

    property bool weatherRefHeld: false

    Component.onCompleted: {
        WeatherService.addRef()
        weatherRefHeld = true
        WeatherService.forceRefresh()
        console.info("[wallpaperWeather] v5 background service started")
    }

    Component.onDestruction: {
        if (weatherRefHeld)
            WeatherService.removeRef()
    }

    Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: root.localHour = new Date().getHours()
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            visible: root.fxEnabled
            color: "transparent"

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            WlrLayershell.namespace: "dms:wallpaper-weather"
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            mask: Region {
                item: Item {}
            }

            Item {
                id: fx
                anchors.fill: parent
                clip: true

                property real fastClock: Date.now() / 1000
                property real slowClock: Date.now() / 1000

                function rnd(i, salt) {
                    var v = Math.sin(i * 127.1 + salt * 311.7) * 43758.5453
                    return v - Math.floor(v)
                }

                function mod(v, d) {
                    return ((v % d) + d) % d
                }

                Timer {
                    interval: 40
                    repeat: true
                    running: root.rainOn
                    onTriggered: fx.fastClock = Date.now() / 1000
                }

                Timer {
                    interval: 100
                    repeat: true
                    running: root.dayOn || root.nightOn || root.fogOn
                    onTriggered: fx.slowClock = Date.now() / 1000
                }

                Rectangle {
                    anchors.fill: parent
                    visible: root.dayOn
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#20ffd98a" }
                        GradientStop { position: 0.52; color: "#0effc878" }
                        GradientStop { position: 1.0; color: "#02ffb86d" }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    visible: root.nightOn
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#6508162d" }
                        GradientStop { position: 0.52; color: "#350a1830" }
                        GradientStop { position: 1.0; color: "#5003060c" }
                    }
                }

                Item {
                    anchors.fill: parent
                    visible: root.dayOn

                    Rectangle {
                        width: Math.min(fx.width, fx.height) * 0.28
                        height: width
                        radius: width / 2
                        x: fx.width * 0.74 - width / 2
                        y: fx.height * 0.14 - height / 2
                        color: "#18ffd98a"
                    }

                    Rectangle {
                        width: Math.min(fx.width, fx.height) * 0.075
                        height: width
                        radius: width / 2
                        x: fx.width * 0.74 - width / 2
                        y: fx.height * 0.14 - height / 2
                        color: "#e8ffe4a7"
                    }

                    Repeater {
                        model: 28
                        delegate: Rectangle {
                            width: 1.5 + fx.rnd(index, 30) * 3.0
                            height: width
                            radius: width / 2
                            x: fx.rnd(index, 31) * fx.width + Math.sin(fx.slowClock * 0.2 + index) * 18
                            y: fx.mod(fx.rnd(index, 32) * fx.height - fx.slowClock * (7 + fx.rnd(index, 33) * 8), fx.height + 30) - 15
                            color: "#ffe9b5"
                            opacity: 0.10 + fx.rnd(index, 34) * 0.25
                        }
                    }
                }

                Item {
                    anchors.fill: parent
                    visible: root.nightOn

                    Repeater {
                        model: 70
                        delegate: Rectangle {
                            width: 1.2 + fx.rnd(index, 1) * 2.8
                            height: width
                            radius: width / 2
                            x: fx.rnd(index, 2) * fx.width
                            y: fx.rnd(index, 3) * fx.height * 0.42
                            color: "white"
                            opacity: 0.18 + 0.70 * (0.5 + 0.5 * Math.sin(fx.slowClock * (0.7 + fx.rnd(index, 4)) + index))
                        }
                    }

                    Rectangle {
                        width: Math.min(fx.width, fx.height) * 0.16
                        height: width
                        radius: width / 2
                        x: fx.width * 0.68 - width / 2
                        y: fx.height * 0.13 - height / 2
                        color: "#18bfe4ff"
                    }

                    Rectangle {
                        width: Math.min(fx.width, fx.height) * 0.065
                        height: width
                        radius: width / 2
                        x: fx.width * 0.68 - width / 2
                        y: fx.height * 0.13 - height / 2
                        color: "#d8d9efff"
                    }
                }

                Item {
                    anchors.fill: parent
                    visible: root.fogOn || root.rainOn

                    Rectangle {
                        width: fx.width * 1.35
                        height: fx.height * 0.18
                        x: -fx.width * 0.18 + Math.sin(fx.slowClock * 0.055) * fx.width * 0.08
                        y: fx.height * 0.34
                        radius: height / 2
                        color: root.fogOn ? "#32d7e0df" : "#18d7e0df"
                    }

                    Rectangle {
                        width: fx.width * 1.45
                        height: fx.height * 0.22
                        x: -fx.width * 0.22 + Math.sin(fx.slowClock * 0.041 + 2.1) * fx.width * 0.10
                        y: fx.height * 0.48
                        radius: height / 2
                        color: root.fogOn ? "#28bfc9c8" : "#14bfc9c8"
                    }
                }

                Item {
                    anchors.fill: parent
                    visible: root.rainOn

                    Rectangle {
                        anchors.fill: parent
                        color: "#28112631"
                    }

                    Repeater {
                        model: Math.round(90 * root.intensity)
                        delegate: Rectangle {
                            property real depth: fx.rnd(index, 4)
                            property real seedX: fx.rnd(index, 5)
                            property real seedY: fx.rnd(index, 6)
                            property real speed: 620 + depth * 1050
                            width: 1 + depth * 1.4
                            height: 14 + depth * 34
                            radius: width / 2
                            color: depth > 0.55 ? "#8fd8f4ff" : "#64c4e7f2"
                            opacity: 0.24 + depth * 0.34
                            rotation: 5 + root.wind * 18
                            x: fx.mod(seedX * fx.width + fx.fastClock * root.wind * (100 + depth * 120), fx.width + 120) - 60
                            y: fx.mod(seedY * fx.height + fx.fastClock * speed, fx.height + height + 90) - height - 45
                        }
                    }
                }

                Item {
                    id: storm
                    anchors.fill: parent
                    visible: root.thunderOn

                    Rectangle {
                        id: flash
                        anchors.fill: parent
                        color: "#effffc"
                        opacity: 0
                    }

                    SequentialAnimation {
                        id: strike
                        NumberAnimation { target: flash; property: "opacity"; to: 0.30; duration: 45 }
                        NumberAnimation { target: flash; property: "opacity"; to: 0.03; duration: 85 }
                        NumberAnimation { target: flash; property: "opacity"; to: 0.20; duration: 55 }
                        NumberAnimation { target: flash; property: "opacity"; to: 0.0; duration: 430 }
                    }

                    Timer {
                        interval: 9000
                        repeat: true
                        running: storm.visible
                        onTriggered: strike.restart()
                    }
                }
            }
        }
    }
}
