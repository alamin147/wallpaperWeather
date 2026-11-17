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
    readonly property bool manualSnow: pluginData.snow === true
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

    function snowCode(code) {
        return (code >= 71 && code <= 77) || code === 85 || code === 86
    }

    readonly property bool rainOn:    fxEnabled && (autoWeather ? (weatherAvailable && rainCode(weatherCode))    : manualRain)
    readonly property bool fogOn:     fxEnabled && (autoWeather ? (weatherAvailable && fogCode(weatherCode))     : manualFog)
    readonly property bool thunderOn: fxEnabled && rainOn && (autoWeather ? (weatherAvailable && thunderCode(weatherCode)) : manualThunder)
    readonly property bool snowOn:    fxEnabled && (autoWeather ? (weatherAvailable && snowCode(weatherCode))    : manualSnow)
    readonly property bool nightOn:   fxEnabled && !isDay
    readonly property bool dayOn:     fxEnabled && isDay

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

                // Deterministic per-particle PRNG — same seed always gives same value
                function rnd(i, salt) {
                    var v = Math.sin(i * 127.1 + salt * 311.7) * 43758.5453
                    return v - Math.floor(v)
                }

                // Always-positive modulo
                function mod(v, d) {
                    return ((v % d) + d) % d
                }

                // ── Timers ──────────────────────────────────────────────────────────
                Timer {
                    interval: 40
                    repeat: true
                    running: root.rainOn || root.snowOn
                    onTriggered: fx.fastClock = Date.now() / 1000
                }

                Timer {
                    interval: 100
                    repeat: true
                    running: root.dayOn || root.nightOn || root.fogOn
                    onTriggered: fx.slowClock = Date.now() / 1000
                }

                // ── Day background gradient ─────────────────────────────────────────
                Rectangle {
                    anchors.fill: parent
                    visible: root.dayOn
                    gradient: Gradient {
                        GradientStop { position: 0.0;  color: "#20ffd98a" }
                        GradientStop { position: 0.52; color: "#0effc878" }
                        GradientStop { position: 1.0;  color: "#02ffb86d" }
                    }
                }

                // ── Night background gradient ───────────────────────────────────────
                Rectangle {
                    anchors.fill: parent
                    visible: root.nightOn
                    gradient: Gradient {
                        GradientStop { position: 0.0;  color: "#6508162d" }
                        GradientStop { position: 0.52; color: "#350a1830" }
                        GradientStop { position: 1.0;  color: "#5003060c" }
                    }
                }

                // ── Day: sun + dust particles ───────────────────────────────────────
                Item {
                    anchors.fill: parent
                    visible: root.dayOn

                    // Outer glow corona
                    Rectangle {
                        width: Math.min(fx.width, fx.height) * 0.36
                        height: width
                        radius: width / 2
                        x: fx.width * 0.74 - width / 2
                        y: fx.height * 0.14 - height / 2
                        color: "#0cffd98a"
                    }

                    // Mid-glow
                    Rectangle {
                        width: Math.min(fx.width, fx.height) * 0.24
                        height: width
                        radius: width / 2
                        x: fx.width * 0.74 - width / 2
                        y: fx.height * 0.14 - height / 2
                        color: "#18ffd98a"
                    }

                    // Bright core disc
                    Rectangle {
                        width: Math.min(fx.width, fx.height) * 0.075
                        height: width
                        radius: width / 2
                        x: fx.width * 0.74 - width / 2
                        y: fx.height * 0.14 - height / 2
                        color: "#e8ffe4a7"
                    }

                    // Dust/pollen particles
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

                // ── Night: stars + moon ─────────────────────────────────────────────
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

                    // Moon outer glow
                    Rectangle {
                        width: Math.min(fx.width, fx.height) * 0.20
                        height: width
                        radius: width / 2
                        x: fx.width * 0.68 - width / 2
                        y: fx.height * 0.13 - height / 2
                        color: "#0fbfe4ff"
                    }

                    // Moon mid glow
                    Rectangle {
                        width: Math.min(fx.width, fx.height) * 0.13
                        height: width
                        radius: width / 2
                        x: fx.width * 0.68 - width / 2
                        y: fx.height * 0.13 - height / 2
                        color: "#20bfe4ff"
                    }

                    // Moon disc
                    Rectangle {
                        width: Math.min(fx.width, fx.height) * 0.065
                        height: width
                        radius: width / 2
                        x: fx.width * 0.68 - width / 2
                        y: fx.height * 0.13 - height / 2
                        color: "#d8d9efff"
                    }

                    // Crescent shadow — slightly offset circle that cuts into the disc
                    Rectangle {
                        property real sz: Math.min(fx.width, fx.height) * 0.065
                        width: sz * 0.88
                        height: sz * 0.88
                        radius: width / 2
                        // shift shadow to simulate crescent; amount is 28% of disc radius
                        x: fx.width * 0.68 - sz / 2 + sz * 0.28
                        y: fx.height * 0.13 - sz / 2 - sz * 0.08
                        color: root.nightOn ? "#c508162d" : "transparent"
                    }
                }

                // ── Fog ─────────────────────────────────────────────────────────────
                // Six independent wisp layers at varying Y positions, widths, heights,
                // drift speeds and phases. Smaller, thinner bands layered together
                // produce a convincing misty look instead of two fat pills.
                Item {
                    anchors.fill: parent
                    visible: root.fogOn || root.rainOn

                    // Layer 0 — wide, low-density base, drifts very slowly
                    Rectangle {
                        width: fx.width * 1.60
                        height: fx.height * (root.fogOn ? 0.08 : 0.05)
                        x: -fx.width * 0.30 + Math.sin(fx.slowClock * 0.028 + 0.0) * fx.width * 0.07
                        y: fx.height * 0.30
                        radius: height * 0.5
                        color: root.fogOn ? "#1ad7e2df" : "#0cd7e2df"
                    }

                    // Layer 1 — upper wisp, slightly narrower, faster phase
                    Rectangle {
                        width: fx.width * 1.40
                        height: fx.height * (root.fogOn ? 0.06 : 0.04)
                        x: -fx.width * 0.20 + Math.sin(fx.slowClock * 0.038 + 1.2) * fx.width * 0.09
                        y: fx.height * 0.37
                        radius: height * 0.5
                        color: root.fogOn ? "#22c8d4cc" : "#0ec8d4cc"
                    }

                    // Layer 2 — mid-screen, tallest wisp, mid density, undulates more
                    Rectangle {
                        width: fx.width * 1.55
                        height: fx.height * (root.fogOn ? 0.11 : 0.06)
                        x: -fx.width * 0.28 + Math.sin(fx.slowClock * 0.045 + 2.5) * fx.width * 0.11
                        y: fx.height * 0.44
                        radius: height * 0.5
                        color: root.fogOn ? "#28bfc9c8" : "#12bfc9c8"
                    }

                    // Layer 3 — sub-mid thin tendril, opposite phase
                    Rectangle {
                        width: fx.width * 1.30
                        height: fx.height * (root.fogOn ? 0.05 : 0.03)
                        x: -fx.width * 0.15 + Math.sin(fx.slowClock * 0.033 + 3.8) * fx.width * 0.10
                        y: fx.height * 0.53
                        radius: height * 0.5
                        color: root.fogOn ? "#1ab0c2bb" : "#0ab0c2bb"
                    }

                    // Layer 4 — lower ground-hugging bank, wide and soft
                    Rectangle {
                        width: fx.width * 1.65
                        height: fx.height * (root.fogOn ? 0.13 : 0.07)
                        x: -fx.width * 0.33 + Math.sin(fx.slowClock * 0.022 + 5.1) * fx.width * 0.08
                        y: fx.height * 0.60
                        radius: height * 0.5
                        color: root.fogOn ? "#20a8bab5" : "#0ea8bab5"
                    }

                    // Layer 5 — very faint deep-background wash, barely visible
                    Rectangle {
                        width: fx.width * 1.80
                        height: fx.height * (root.fogOn ? 0.20 : 0.10)
                        x: -fx.width * 0.40 + Math.sin(fx.slowClock * 0.016 + 0.9) * fx.width * 0.06
                        y: fx.height * 0.28
                        radius: height * 0.5
                        color: root.fogOn ? "#10d7e8e8" : "#08d7e8e8"
                    }
                }

                // ── Rain ────────────────────────────────────────────────────────────
                Item {
                    anchors.fill: parent
                    visible: root.rainOn

                    // Dark blue-purple scene overlay
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
                            // Slight per-drop color temperature variation (cooler vs warmer)
                            property real colorBias: fx.rnd(index, 40)
                            property real speed: 620 + depth * 1050
                            width: 1 + depth * 1.4
                            height: 14 + depth * 34
                            radius: width / 2
                            color: depth > 0.55
                                ? (colorBias > 0.5 ? "#8fd8f4ff" : "#8fdaeeff")
                                : (colorBias > 0.5 ? "#64c4e7f2" : "#64c0dff0")
                            opacity: 0.24 + depth * 0.34
                            rotation: 5 + root.wind * 18
                            x: fx.mod(seedX * fx.width + fx.fastClock * root.wind * (100 + depth * 120), fx.width + 120) - 60
                            y: fx.mod(seedY * fx.height + fx.fastClock * speed, fx.height + height + 90) - height - 45
                        }
                    }

                    // Splash dots at screen bottom — tiny circles that appear where
                    // drops would land, animated with the fast clock
                    Repeater {
                        model: Math.round(30 * root.intensity)
                        delegate: Rectangle {
                            property real seedX: fx.rnd(index, 50)
                            property real depth: fx.rnd(index, 51)
                            property real phase: fx.rnd(index, 52) * 6.28
                            // Pulsing opacity — appear and fade over ~0.5 s cycle
                            property real pulse: 0.5 + 0.5 * Math.sin(fx.fastClock * (3.5 + depth * 2.5) + phase)
                            width: (2 + depth * 5) * pulse
                            height: width * 0.35
                            radius: height / 2
                            color: "#a0c8e8f8"
                            opacity: 0.15 + depth * 0.25 * pulse
                            x: fx.mod(seedX * fx.width + fx.fastClock * root.wind * (60 + depth * 60), fx.width + 80) - 40
                            y: fx.height * (0.86 + depth * 0.12)
                        }
                    }
                }

                // ── Snow ────────────────────────────────────────────────────────────
                Item {
                    anchors.fill: parent
                    visible: root.snowOn

                    // Faint cold overlay
                    Rectangle {
                        anchors.fill: parent
                        color: "#120d1f2e"
                    }

                    Repeater {
                        model: Math.round(60 * root.intensity)
                        delegate: Rectangle {
                            property real seedX: fx.rnd(index, 60)
                            property real seedY: fx.rnd(index, 61)
                            property real sz:    1.5 + fx.rnd(index, 62) * 5.0
                            property real speed: 40 + fx.rnd(index, 63) * 60
                            // Gentle side-sway via low-frequency sine
                            property real swayAmp:  12 + fx.rnd(index, 64) * 20
                            property real swayFreq: 0.25 + fx.rnd(index, 65) * 0.35
                            property real swayPhase: fx.rnd(index, 66) * 6.28
                            width:  sz
                            height: sz
                            radius: sz / 2
                            color: "#e8f4ff"
                            opacity: 0.35 + fx.rnd(index, 67) * 0.45
                            x: fx.mod(seedX * fx.width  + Math.sin(fx.fastClock * swayFreq + swayPhase) * swayAmp
                                       + fx.fastClock * root.wind * 30, fx.width + 40) - 20
                            y: fx.mod(seedY * fx.height + fx.fastClock * speed, fx.height + sz + 20) - sz - 10
                        }
                    }
                }

                // ── Thunder ─────────────────────────────────────────────────────────
                Item {
                    id: storm
                    anchors.fill: parent
                    visible: root.thunderOn

                    // Full-screen flash
                    Rectangle {
                        id: flash
                        anchors.fill: parent
                        color: "#effffc"
                        opacity: 0
                    }

                    // Subtle secondary horizontal bolt tint
                    Rectangle {
                        id: bolt
                        anchors.fill: parent
                        color: "#f0f8ff"
                        opacity: 0
                    }

                    SequentialAnimation {
                        id: strike
                        // Primary flash
                        NumberAnimation { target: flash; property: "opacity"; to: 0.32; duration: 40 }
                        NumberAnimation { target: flash; property: "opacity"; to: 0.02; duration: 70 }
                        // Brief secondary echo
                        NumberAnimation { target: flash; property: "opacity"; to: 0.18; duration: 50 }
                        NumberAnimation { target: flash; property: "opacity"; to: 0.0;  duration: 400 }
                    }

                    SequentialAnimation {
                        id: boltFlash
                        PauseAnimation   { duration: 15 }
                        NumberAnimation  { target: bolt; property: "opacity"; to: 0.12; duration: 25 }
                        NumberAnimation  { target: bolt; property: "opacity"; to: 0.0;  duration: 200 }
                    }

                    // Randomise interval per strike so it doesn't feel metronomic.
                    // Uses a small property to vary between 6 s and 15 s.
                    property real nextInterval: 9000

                    Timer {
                        id: thunderTimer
                        interval: storm.nextInterval
                        repeat: false
                        running: storm.visible
                        onTriggered: {
                            // Pick a new random interval 6–15 seconds
                            storm.nextInterval = 6000 + Math.random() * 9000
                            strike.restart()
                            boltFlash.restart()
                            thunderTimer.restart()
                        }
                    }
                }
            }
        }
    }
}
