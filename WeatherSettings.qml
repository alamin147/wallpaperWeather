import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "wallpaperWeather"

    StyledText {
        width: parent.width
        text: "Wallpaper Weather"
        color: Theme.surfaceText
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
    }

    ToggleSetting {
        settingKey: "enabled"
        label: "Enable effects"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "autoWeather"
        label: "Use DMS weather"
        description: "Falls back to local day/night if DMS weather has no data."
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "rain"
        label: "Manual rain"
        description: "Used only when Use DMS weather is off."
        defaultValue: false
    }

    ToggleSetting {
        settingKey: "fog"
        label: "Manual fog"
        description: "Used only when Use DMS weather is off."
        defaultValue: false
    }

    ToggleSetting {
        settingKey: "thunder"
        label: "Manual thunder"
        description: "Used only with manual rain."
        defaultValue: false
    }

    ToggleSetting {
        settingKey: "night"
        label: "Manual night"
        description: "Off means daytime when Use DMS weather is off."
        defaultValue: false
    }

    SliderSetting {
        settingKey: "intensityPercent"
        label: "Rain intensity"
        defaultValue: 100
        minimum: 20
        maximum: 200
        unit: "%"
    }

    SliderSetting {
        settingKey: "windPercent"
        label: "Rain wind"
        defaultValue: 0
        minimum: -100
        maximum: 100
        unit: "%"
    }
}
