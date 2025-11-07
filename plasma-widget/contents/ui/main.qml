import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    // Estado
    property bool isConnected: false
    property string deviceName: "Redragon"
    property string sinkName: ""
    property int currentVolume: 0
    property bool isMuted: false
    property bool updatingSlider: false

    preferredRepresentation: compactRepresentation

    // Executor de comandos shell
    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []

        onNewData: function(sourceName, data) {
            var exitCode = data["exit code"]
            var stdout = data["stdout"]

            if (exitCode === 0 && stdout) {
                handleCommandOutput(sourceName, stdout)
            }

            disconnectSource(sourceName)
        }

        function exec(cmd) {
            connectSource(cmd)
        }
    }

    // Handler de saídas de comandos
    function handleCommandOutput(command, output) {
        // Status command
        if (command.includes("status")) {
            // Parse: OK: device=H878 Wireless headset card=3 ...
            var deviceMatch = output.match(/device=([^\s]+(?:\s+[^\s]+)*?)\s+card=/)
            if (deviceMatch) {
                deviceName = deviceMatch[1]
                isConnected = true
                findSinkName()
            } else {
                isConnected = false
            }
        }
        // Get command
        else if (command.includes("get")) {
            var volumeMatch = output.match(/Volume:\s*(\d+)%/)
            if (volumeMatch) {
                currentVolume = parseInt(volumeMatch[1])
                isMuted = (currentVolume === 0)

                updatingSlider = true
                volumeSlider.value = currentVolume
                updatingSlider = false
            }
        }
        // Sink list
        else if (command.includes("pactl list sinks short")) {
            var lines = output.split('\n')
            for (var i = 0; i < lines.length; i++) {
                var line = lines[i]
                if (line.includes('XiiSound') || line.includes('Weltrend') ||
                    line.includes('Redragon') || line.includes('H878')) {
                    var parts = line.split(/\s+/)
                    if (parts.length >= 2) {
                        sinkName = parts[1]
                        break
                    }
                }
            }
        }
    }

    function findSinkName() {
        executable.exec("pactl list sinks short")
    }

    function updateVolume() {
        if (isConnected) {
            executable.exec("redragon-volume get")
        }
    }

    function detectDevice() {
        executable.exec("redragon-volume status")
    }

    function setVolume(volume) {
        if (isConnected) {
            executable.exec("redragon-volume " + Math.round(volume))
        }
    }

    function toggleMute() {
        if (isConnected) {
            executable.exec("redragon-volume mute")
            volumeUpdateTimer.restart()
        }
    }

    function setAsDefaultSink() {
        if (isConnected && sinkName) {
            executable.exec("pactl set-default-sink " + sinkName)
            executable.exec("notify-send 'Redragon Volume' '" + deviceName + " definido como saída padrão' -i audio-headphones")
        }
    }

    // Timer para monitoramento
    Timer {
        id: monitoringTimer
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true

        onTriggered: {
            if (isConnected) {
                updateVolume()
            } else {
                detectDevice()
            }
        }
    }

    // Timer para atualizar após mute
    Timer {
        id: volumeUpdateTimer
        interval: 100
        onTriggered: updateVolume()
    }

    // Timer para debounce do slider
    Timer {
        id: volumeChangeTimer
        interval: 20
        onTriggered: setVolume(volumeSlider.value)
    }

    // Representação compacta (ícone no painel)
    compactRepresentation: Item {
        id: compactRoot

        Layout.minimumWidth: Kirigami.Units.iconSizes.small
        Layout.minimumHeight: Kirigami.Units.iconSizes.small

        Kirigami.Icon {
            id: trayIcon
            anchors.fill: parent
            source: {
                if (currentVolume === 0 || isMuted)
                    return "audio-volume-muted-symbolic"
                else if (currentVolume < 33)
                    return "audio-volume-low-symbolic"
                else if (currentVolume < 66)
                    return "audio-volume-medium-symbolic"
                else
                    return "audio-volume-high-symbolic"
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

            onClicked: function(mouse) {
                if (mouse.button === Qt.LeftButton) {
                    root.expanded = !root.expanded
                } else if (mouse.button === Qt.MiddleButton || mouse.button === Qt.RightButton) {
                    toggleMute()
                }
            }

            onWheel: function(wheel) {
                if (!isConnected) return

                var delta = wheel.angleDelta.y > 0 ? 5 : -5
                var newVolume = Math.max(0, Math.min(100, currentVolume + delta))

                if (newVolume !== currentVolume) {
                    currentVolume = newVolume
                    isMuted = (newVolume === 0)

                    updatingSlider = true
                    volumeSlider.value = newVolume
                    updatingSlider = false

                    setVolume(newVolume)
                }
            }
        }
    }

    // Representação completa (popup)
    fullRepresentation: Item {
        Layout.preferredWidth: 300
        Layout.preferredHeight: 220

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing

            // Status compacto
            PlasmaComponents3.Label {
                id: statusLabel
                text: isConnected ? "✓ " + deviceName : "❌ Não encontrado"
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                Layout.fillWidth: true
            }

            PlasmaComponents3.Separator {
                Layout.fillWidth: true
            }

            // Volume grande
            PlasmaComponents3.Label {
                id: volumeLabel
                text: currentVolume + " %"
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.5
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                Layout.bottomMargin: Kirigami.Units.smallSpacing
            }

            PlasmaComponents3.Separator {
                Layout.fillWidth: true
            }

            // Slider
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    source: "audio-volume-low"
                    implicitWidth: Kirigami.Units.iconSizes.small
                    implicitHeight: Kirigami.Units.iconSizes.small
                }

                PlasmaComponents3.Slider {
                    id: volumeSlider
                    Layout.fillWidth: true
                    from: 0
                    to: 100
                    value: currentVolume
                    stepSize: 1

                    onMoved: {
                        if (updatingSlider) return

                        // Feedback visual imediato
                        currentVolume = Math.round(value)
                        isMuted = (currentVolume === 0)
                        volumeLabel.text = currentVolume + " %"

                        // Debounce
                        volumeChangeTimer.restart()
                    }
                }

                Kirigami.Icon {
                    source: "audio-volume-high"
                    implicitWidth: Kirigami.Units.iconSizes.small
                    implicitHeight: Kirigami.Units.iconSizes.small
                }
            }

            PlasmaComponents3.Separator {
                Layout.fillWidth: true
            }

            // Botão de mute
            PlasmaComponents3.Button {
                id: muteButton
                Layout.fillWidth: true
                text: isMuted ? "🔊 Desmutar" : "🔇 Mutar"
                onClicked: toggleMute()
            }

            // Botão para definir como saída padrão
            PlasmaComponents3.Button {
                Layout.fillWidth: true
                text: "🔊 Usar como saída de áudio"
                onClicked: setAsDefaultSink()
            }

            Item {
                Layout.fillHeight: true
            }
        }
    }

    Component.onCompleted: {
        detectDevice()
    }
}
