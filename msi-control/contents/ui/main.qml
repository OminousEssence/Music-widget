import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

PlasmoidItem {
    id: root

    Plasmoid.icon: "laptop-symbolic"

    MsiEcModel {
        id: msiModel
    }

    // Helper maps
    readonly property var shiftModeInfo: ({
        "eco":     { label: i18n("Eco"),     desc: i18n("Power Saving") },
        "comfort": { label: i18n("Comfort"), desc: i18n("Balanced") },
        "sport":   { label: i18n("Sport"),   desc: i18n("High Performance") },
        "turbo":   { label: i18n("Turbo"),   desc: i18n("Overclocking") }
    })

    readonly property var fanModeInfo: ({
        "auto":     { label: i18n("Auto"),     desc: i18n("Adaptive") },
        "silent":   { label: i18n("Silent"),   desc: i18n("Fan Disabled") },
        "basic":    { label: i18n("Basic"),    desc: i18n("Fixed Speed") },
        "advanced": { label: i18n("Advanced"), desc: i18n("Custom Curve") }
    })

    readonly property var kbdBacklightLabels: [
        i18n("Off"), i18n("Low"), i18n("Mid"), i18n("Full")
    ]

    // ─── Compact: Tray Icon ───
    compactRepresentation: TrayIcon {
        cpuTemp: msiModel.cpuTemp
        gpuTemp: msiModel.gpuTemp
        isAvailable: msiModel.isAvailable
        MouseArea {
            anchors.fill: parent
            onClicked: root.expanded = !root.expanded
        }
    }

    // ─── Full: Popup ───
    fullRepresentation: PlasmaExtras.Representation {
        implicitWidth: Kirigami.Units.gridUnit * 22
        implicitHeight: Kirigami.Units.gridUnit * 32

        header: PlasmaExtras.PlasmoidHeading {
            RowLayout {
                anchors.fill: parent
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    source: "laptop-symbolic"
                    Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                    Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Kirigami.Heading {
                        text: i18n("MSI Control Center")
                        level: 4
                        Layout.fillWidth: true
                    }

                    PlasmaComponents.Label {
                        text: msiModel.isAvailable ? i18n("msi-ec Active") : i18n("msi-ec Not Found")
                        color: msiModel.isAvailable ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.negativeTextColor
                        font: Kirigami.Theme.smallFont
                    }
                }
            }
        }

        contentItem: Item {

            // ═══════════════════════════════════════
            //  PAGE 1: Permission Gate (shown when not ready)
            // ═══════════════════════════════════════

            ColumnLayout {
                id: permissionGatePage
                anchors.fill: parent
                anchors.margins: Kirigami.Units.gridUnit
                visible: msiModel.permissionStatus !== "ready"
                spacing: Kirigami.Units.largeSpacing * 2

                Item { Layout.fillHeight: true }

                Kirigami.Icon {
                    source: msiModel.permissionStatus === "needs_relogin" ? "dialog-information" : "security-high-symbolic"
                    Layout.preferredWidth: Kirigami.Units.iconSizes.huge
                    Layout.preferredHeight: Kirigami.Units.iconSizes.huge
                    Layout.alignment: Qt.AlignHCenter
                    color: msiModel.permissionStatus === "needs_relogin"
                        ? Kirigami.Theme.positiveTextColor
                        : Kirigami.Theme.neutralTextColor
                }

                Kirigami.Heading {
                    text: {
                        if (!msiModel.isAvailable)
                            return i18n("Driver Not Found")
                        if (msiModel.permissionStatus === "needs_relogin")
                            return i18n("Almost Ready!")
                        return i18n("Permission Required")
                    }
                    level: 3
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }

                PlasmaComponents.Label {
                    text: {
                        if (!msiModel.isAvailable)
                            return i18n("The msi-ec kernel module is not loaded.\nMake sure it is installed and loaded:\n\nsudo modprobe msi-ec")
                        if (msiModel.permissionStatus === "needs_relogin")
                            return i18n("Permissions have been configured successfully.\nPlease log out and log back in to activate.")
                        return i18n("System permissions are needed to control\nyour MSI laptop settings.\n\nThis will create a system group and install\nudev rules for secure access. (One-time setup)")
                    }
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    opacity: 0.8
                }

                // Setup button (only for needs_setup state)
                QQC2.Button {
                    visible: msiModel.isAvailable && msiModel.permissionStatus === "needs_setup"
                    Layout.alignment: Qt.AlignHCenter
                    icon.name: "dialog-password"
                    text: msiModel.setupInProgress ? i18n("Running Setup...") : i18n("Grant Permissions")
                    enabled: !msiModel.setupInProgress
                    onClicked: msiModel.setupPermissions()
                }

                // Logout button (double-click to confirm)
                QQC2.Button {
                    id: logoutBtn
                    visible: msiModel.permissionStatus === "needs_relogin"
                    Layout.alignment: Qt.AlignHCenter
                    icon.name: "system-log-out"

                    property bool confirmPending: false

                    text: confirmPending ? i18n("Click Again to Log Out") : i18n("Log Out")

                    Timer {
                        id: confirmTimer
                        interval: 3000
                        onTriggered: logoutBtn.confirmPending = false
                    }

                    onClicked: {
                        if (confirmPending) {
                            // Second click — execute logout
                            msiModel.execLogout()
                        } else {
                            // First click — ask confirmation
                            confirmPending = true
                            confirmTimer.restart()
                        }
                    }
                }

                Item { Layout.fillHeight: true }
            }

            // ═══════════════════════════════════════
            //  PAGE 2: Full Controls (shown when ready)
            // ═══════════════════════════════════════

            QQC2.ScrollView {
                anchors.fill: parent
                visible: msiModel.permissionStatus === "ready"
                QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff

                Kirigami.FormLayout {
                    id: formLayout
                    width: parent.width

                    // ── System Metrics ──

                    Kirigami.Separator {
                        Kirigami.FormData.isSection: true
                        Kirigami.FormData.label: i18n("System Metrics")
                        visible: msiModel.hasCpuTemp || msiModel.hasGpuTemp || msiModel.hasCpuFan || msiModel.hasGpuFan
                    }

                    RowLayout {
                        Kirigami.FormData.label: i18n("Battery:")
                        spacing: Kirigami.Units.smallSpacing

                        QQC2.ProgressBar {
                            Layout.fillWidth: true
                            from: 0; to: 100
                            value: msiModel.batteryPercentage
                        }

                        QQC2.Label {
                            text: msiModel.batteryPercentage + "%"
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 2.5
                            horizontalAlignment: Text.AlignRight
                        }
                    }

                    QQC2.Label {
                        Kirigami.FormData.label: i18n("Status:")
                        text: {
                            if (msiModel.batteryStatus === "Discharging") return i18n("Discharging")
                            if (msiModel.batteryStatus === "Charging") return i18n("Charging")
                            if (msiModel.batteryStatus === "Full") return i18n("Full")
                            if (msiModel.batteryStatus === "Not charging") return i18n("Not Charging")
                            return msiModel.batteryStatus
                        }
                    }

                    RowLayout {
                        visible: msiModel.hasCpuTemp
                        Kirigami.FormData.label: i18n("CPU Temp:")
                        spacing: Kirigami.Units.smallSpacing

                        QQC2.ProgressBar {
                            Layout.fillWidth: true
                            from: 0; to: 100
                            value: msiModel.cpuTemp
                            palette.highlight: msiModel.cpuTemp >= 85
                                ? Kirigami.Theme.negativeTextColor
                                : (msiModel.cpuTemp >= 70 ? Kirigami.Theme.neutralTextColor : Kirigami.Theme.positiveTextColor)
                        }

                        QQC2.Label {
                            text: msiModel.cpuTemp + "°C"
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 2.5
                            horizontalAlignment: Text.AlignRight
                        }
                    }

                    RowLayout {
                        visible: msiModel.hasGpuTemp
                        Kirigami.FormData.label: i18n("GPU Temp:")
                        spacing: Kirigami.Units.smallSpacing

                        QQC2.ProgressBar {
                            Layout.fillWidth: true
                            from: 0; to: 100
                            value: msiModel.gpuTemp
                            palette.highlight: msiModel.gpuTemp >= 85
                                ? Kirigami.Theme.negativeTextColor
                                : (msiModel.gpuTemp >= 70 ? Kirigami.Theme.neutralTextColor : Kirigami.Theme.positiveTextColor)
                        }

                        QQC2.Label {
                            text: msiModel.gpuTemp + "°C"
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 2.5
                            horizontalAlignment: Text.AlignRight
                        }
                    }

                    QQC2.Label {
                        visible: msiModel.hasCpuFan
                        Kirigami.FormData.label: i18n("CPU Fan:")
                        text: msiModel.cpuFan + " RPM"
                    }

                    QQC2.Label {
                        visible: msiModel.hasGpuFan
                        Kirigami.FormData.label: i18n("GPU Fan:")
                        text: msiModel.gpuFan + " RPM"
                    }

                    // ── Keyboard Backlight ──

                    Kirigami.Separator {
                        visible: msiModel.hasKbdBacklight
                        Kirigami.FormData.isSection: true
                        Kirigami.FormData.label: i18n("Keyboard Backlight")
                    }

                    RowLayout {
                        visible: msiModel.hasKbdBacklight
                        Kirigami.FormData.label: kbdBacklightLabels[msiModel.kbdBacklight] || i18n("Off")
                        spacing: Kirigami.Units.smallSpacing

                        QQC2.Slider {
                            Layout.fillWidth: true
                            from: 0; to: 3; stepSize: 1
                            value: msiModel.kbdBacklight
                            onMoved: msiModel.setKbdBacklight(value)
                        }
                    }

                    // ── Controls ──

                    Kirigami.Separator {
                        Kirigami.FormData.isSection: true
                        Kirigami.FormData.label: i18n("Controls")
                        visible: msiModel.hasCoolerBoost || msiModel.hasSuperBattery ||
                                 msiModel.hasFnKey || msiModel.hasWinKey ||
                                 msiModel.hasWebcam || msiModel.hasWebcamBlock ||
                                 msiModel.hasUsbPower
                    }

                    QQC2.Switch {
                        visible: msiModel.hasCoolerBoost
                        Kirigami.FormData.label: i18n("Cooler Boost:")
                        checked: msiModel.coolerBoost
                        onToggled: msiModel.setCoolerBoost(checked)
                    }

                    QQC2.Switch {
                        visible: msiModel.hasSuperBattery
                        Kirigami.FormData.label: i18n("Super Battery:")
                        checked: msiModel.superBattery
                        onToggled: msiModel.setSuperBattery(checked)
                    }

                    QQC2.Switch {
                        visible: msiModel.hasFnKey
                        Kirigami.FormData.label: i18n("FN Key Swap:")
                        checked: msiModel.fnKeySwap
                        onToggled: msiModel.setFnKeySwap(checked)
                    }

                    QQC2.Switch {
                        visible: msiModel.hasWinKey
                        Kirigami.FormData.label: i18n("Win Key Swap:")
                        checked: msiModel.winKeySwap
                        onToggled: msiModel.setWinKeySwap(checked)
                    }

                    QQC2.Switch {
                        visible: msiModel.hasWebcam
                        Kirigami.FormData.label: i18n("Webcam:")
                        checked: msiModel.webcamEnabled
                        onToggled: msiModel.setWebcam(checked)
                    }

                    QQC2.Switch {
                        visible: msiModel.hasWebcamBlock
                        Kirigami.FormData.label: i18n("Webcam Block:")
                        checked: msiModel.webcamBlocked
                        onToggled: msiModel.setWebcamBlock(checked)
                    }

                    QQC2.Switch {
                        visible: msiModel.hasUsbPower
                        Kirigami.FormData.label: i18n("USB Power Share:")
                        checked: msiModel.usbPower
                        onToggled: msiModel.setUsbPower(checked)
                    }

                    // ── Shift Mode (Dynamic) ──

                    Kirigami.Separator {
                        visible: msiModel.hasShiftMode && msiModel.availableShiftModes.length > 0
                        Kirigami.FormData.isSection: true
                        Kirigami.FormData.label: i18n("Shift Mode")
                    }

                    Repeater {
                        model: msiModel.availableShiftModes

                        QQC2.RadioButton {
                            required property string modelData
                            visible: msiModel.hasShiftMode
                            Kirigami.FormData.label: {
                                var info = shiftModeInfo[modelData]
                                return info ? info.label : modelData
                            }
                            text: {
                                var info = shiftModeInfo[modelData]
                                return info ? info.desc : ""
                            }
                            checked: msiModel.shiftMode === modelData
                            onClicked: msiModel.setShiftMode(modelData)
                        }
                    }

                    // ── Fan Mode (Dynamic) ──

                    Kirigami.Separator {
                        visible: msiModel.hasFanMode && msiModel.availableFanModes.length > 0
                        Kirigami.FormData.isSection: true
                        Kirigami.FormData.label: i18n("Fan Mode")
                    }

                    Repeater {
                        model: msiModel.availableFanModes

                        QQC2.RadioButton {
                            required property string modelData
                            visible: msiModel.hasFanMode
                            Kirigami.FormData.label: {
                                var info = fanModeInfo[modelData]
                                return info ? info.label : modelData
                            }
                            text: {
                                var info = fanModeInfo[modelData]
                                return info ? info.desc : ""
                            }
                            checked: msiModel.fanMode === modelData
                            onClicked: msiModel.setFanMode(modelData)
                        }
                    }

                    // ── Basic Fan Speed (only in basic mode) ──

                    Kirigami.Separator {
                        visible: msiModel.fanMode === "basic" && (msiModel.hasCpuBasicFanSpeed || msiModel.hasGpuBasicFanSpeed)
                        Kirigami.FormData.isSection: true
                        Kirigami.FormData.label: i18n("Fan Speed Control")
                    }

                    RowLayout {
                        visible: msiModel.fanMode === "basic" && msiModel.hasCpuBasicFanSpeed
                        Kirigami.FormData.label: i18n("CPU Fan:")
                        spacing: Kirigami.Units.smallSpacing

                        QQC2.Slider {
                            id: cpuFanSlider
                            Layout.fillWidth: true
                            from: 0; to: 100; stepSize: 5
                            value: msiModel.cpuBasicFanSpeed
                            onMoved: msiModel.setCpuBasicFanSpeed(value)
                        }

                        QQC2.Label {
                            text: Math.round(cpuFanSlider.value) + "%"
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 2.5
                            horizontalAlignment: Text.AlignRight
                        }
                    }

                    RowLayout {
                        visible: msiModel.fanMode === "basic" && msiModel.hasGpuBasicFanSpeed
                        Kirigami.FormData.label: i18n("GPU Fan:")
                        spacing: Kirigami.Units.smallSpacing

                        QQC2.Slider {
                            id: gpuFanSlider
                            Layout.fillWidth: true
                            from: 0; to: 100; stepSize: 5
                            value: msiModel.gpuBasicFanSpeed
                            onMoved: msiModel.setGpuBasicFanSpeed(value)
                        }

                        QQC2.Label {
                            text: Math.round(gpuFanSlider.value) + "%"
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 2.5
                            horizontalAlignment: Text.AlignRight
                        }
                    }

                    // ── Battery Strategy ──

                    Kirigami.Separator {
                        visible: msiModel.hasBatteryThreshold
                        Kirigami.FormData.isSection: true
                        Kirigami.FormData.label: i18n("Battery Strategy")
                    }

                    QQC2.RadioButton {
                        visible: msiModel.hasBatteryThreshold
                        Kirigami.FormData.label: i18n("Mobility")
                        text: i18n("90% → 100%")
                        checked: msiModel.batteryLimit === 100
                        onClicked: msiModel.setBatteryThresholds("90", "100")
                    }

                    QQC2.RadioButton {
                        visible: msiModel.hasBatteryThreshold
                        Kirigami.FormData.label: i18n("Balanced")
                        text: i18n("70% → 80%")
                        checked: msiModel.batteryLimit === 80
                        onClicked: msiModel.setBatteryThresholds("70", "80")
                    }

                    QQC2.RadioButton {
                        visible: msiModel.hasBatteryThreshold
                        Kirigami.FormData.label: i18n("Life Span")
                        text: i18n("50% → 60%")
                        checked: msiModel.batteryLimit === 60
                        onClicked: msiModel.setBatteryThresholds("50", "60")
                    }

                    // ── System Info ──

                    Kirigami.Separator {
                        Kirigami.FormData.isSection: true
                        Kirigami.FormData.label: i18n("System Info")
                    }

                    QQC2.Label {
                        Kirigami.FormData.label: i18n("EC Build:")
                        text: msiModel.fwDate || "—"
                        font: Kirigami.Theme.smallFont
                        opacity: 0.7
                    }

                    QQC2.Label {
                        Kirigami.FormData.label: i18n("EC Version:")
                        text: msiModel.fwVersion || "—"
                        font: Kirigami.Theme.smallFont
                        opacity: 0.7
                    }

                    QQC2.Label {
                        Kirigami.FormData.label: i18n("Driver:")
                        text: msiModel.isAvailable ? i18n("msi-ec Detected") : i18n("Not Found")
                        font: Kirigami.Theme.smallFont
                        color: msiModel.isAvailable ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.negativeTextColor
                        opacity: 0.7
                    }
                }
            }
        }
    }
}
