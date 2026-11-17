import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    layerNamespacePlugin: "wallpaper-weather"
    property var popoutService: null

    readonly property bool fxEnabled: pluginData.enabled !== false
    readonly property bool autoWeather: pluginData.autoWeather !== false
    readonly property bool weatherAvailable: WeatherService.weather && WeatherService.weather.available === true
    readonly property int weatherCode: weatherAvailable ? Number(WeatherService.weather.wCode) : -1
    readonly property bool isDay: weatherAvailable ? WeatherService.weather.isDay === true : true
    readonly property int intensityPercent: Number(pluginData.intensityPercent === undefined ? 100 : pluginData.intensityPercent)
    readonly property int windPercent: Number(pluginData.windPercent === undefined ? 0 : pluginData.windPercent)

    readonly property string manualPreset: {
        if (pluginData.thunder === true && pluginData.rain === true)
            return "storm"
        if (pluginData.rain === true)
            return "rain"
        if (pluginData.snow === true)
            return "snow"
        if (pluginData.fog === true)
            return "fog"
        return pluginData.night === true ? "night" : "day"
    }

    readonly property string iconName: {
        if (!fxEnabled)
            return "weather_mix";
        if (autoWeather && weatherAvailable)
            return WeatherService.getWeatherIcon(weatherCode, isDay);
        if (autoWeather)
            return "partly_cloudy_day";
        if (manualPreset === "storm")
            return "thunderstorm";
        if (manualPreset === "rain")
            return "rainy";
        if (manualPreset === "snow")
            return "cloudy_snowing";
        if (manualPreset === "fog")
            return "foggy";
        return manualPreset === "night" ? "clear_night" : "clear_day";
    }

    readonly property string pillText: {
        if (!fxEnabled)
            return "Off";
        if (autoWeather && weatherAvailable)
            return WeatherService.currentTempText(true);
        return autoWeather ? "Auto" : manualPreset.charAt(0).toUpperCase() + manualPreset.slice(1);
    }

    readonly property string statusText: {
        if (!fxEnabled)
            return "Wallpaper effects are disabled.";
        if (autoWeather && weatherAvailable)
            return WeatherService.getWeatherCondition(weatherCode) + " · " + WeatherService.currentTempText(false);
        if (autoWeather)
            return "Automatic weather is enabled. Waiting for DMS weather data.";
        return "Manual weather mode is active.";
    }

    function saveSetting(key, value) {
        if (pluginService)
            pluginService.savePluginData(pluginId, key, value)
    }

    function applyPreset(name) {
        saveSetting("autoWeather", false)
        saveSetting("rain",    name === "rain" || name === "storm")
        saveSetting("fog",     name === "fog")
        saveSetting("snow",    name === "snow")
        saveSetting("thunder", name === "storm")
        saveSetting("night",   name === "night")
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS

            DankIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: root.iconName
                size: root.iconSize
                color: root.fxEnabled ? Theme.primary : Theme.surfaceVariantText
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.pillText
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeSmall
            }
        }
    }

    verticalBarPill: Component {
        DankIcon {
            name: root.iconName
            size: root.iconSize
            color: root.fxEnabled ? Theme.primary : Theme.surfaceVariantText
        }
    }

    popoutContent: Component {
        PopoutComponent {
            id: popout
            headerText: "Wallpaper Weather"
            detailsText: root.statusText
            showCloseButton: true

            Column {
                width: parent.width
                spacing: Theme.spacingS

                DankToggle {
                    width: parent.width
                    text: "Enabled"
                    description: "Draw weather between the wallpaper and normal windows"
                    checked: root.fxEnabled
                    onToggled: checked => root.saveSetting("enabled", checked)
                }

                DankToggle {
                    width: parent.width
                    text: "Automatic weather"
                    description: "Follow the built-in DMS WeatherService"
                    checked: root.autoWeather
                    onToggled: checked => {
                        root.saveSetting("autoWeather", checked)
                        if (checked)
                            WeatherService.forceRefresh()
                    }
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingS

                    StyledText {
                        text: "Manual preset"
                        color: Theme.surfaceText
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Item { width: 1; height: 1 }

                    StyledText {
                        text: root.autoWeather ? "Auto active" : root.manualPreset
                        color: root.autoWeather ? Theme.primary : Theme.surfaceVariantText
                        font.pixelSize: Theme.fontSizeSmall
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Grid {
                    id: presetGrid
                    width: parent.width
                    columns: 3
                    columnSpacing: Theme.spacingS
                    rowSpacing: Theme.spacingS

                    Repeater {
                        model: [
                            { id: "day",   label: "Day",   icon: "clear_day" },
                            { id: "rain",  label: "Rain",  icon: "rainy" },
                            { id: "storm", label: "Storm", icon: "thunderstorm" },
                            { id: "snow",  label: "Snow",  icon: "cloudy_snowing" },
                            { id: "fog",   label: "Fog",   icon: "foggy" },
                            { id: "night", label: "Night", icon: "clear_night" }
                        ]

                        DankButton {
                            width: (presetGrid.width - presetGrid.columnSpacing * 2) / 3
                            text: modelData.label
                            iconName: modelData.icon
                            buttonHeight: 36
                            horizontalPadding: Theme.spacingS
                            backgroundColor: !root.autoWeather && root.manualPreset === modelData.id
                                ? Theme.primary
                                : Theme.surfaceContainerHigh
                            textColor: !root.autoWeather && root.manualPreset === modelData.id
                                ? Theme.onPrimary
                                : Theme.surfaceText
                            onClicked: root.applyPreset(modelData.id)
                        }
                    }
                }

                StyledText {
                    text: "Intensity  " + root.intensityPercent + "%"
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                }

                DankSlider {
                    width: parent.width
                    minimum: 20
                    maximum: 200
                    step: 5
                    unit: "%"
                    leftIcon: "water_drop"
                    value: root.intensityPercent
                    onSliderDragFinished: value => root.saveSetting("intensityPercent", value)
                }

                StyledText {
                    text: "Wind  " + (root.windPercent > 0 ? "+" : "") + root.windPercent + "%"
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                }

                DankSlider {
                    width: parent.width
                    minimum: -100
                    maximum: 100
                    step: 5
                    unit: "%"
                    leftIcon: "air"
                    value: root.windPercent
                    onSliderDragFinished: value => root.saveSetting("windPercent", value)
                }
            }
        }
    }

    popoutWidth: 420
    popoutHeight: 610
}
