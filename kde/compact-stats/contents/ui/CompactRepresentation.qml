import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.ksysguard.faces as Faces
import org.kde.ksysguard.sensors as Sensors

Faces.CompactSensorFace {
    id: root
    Layout.minimumWidth: root.horizontalFormFactor ? row.implicitWidth : root.defaultMinimumSize
    Layout.preferredWidth: root.horizontalFormFactor ? row.implicitWidth : -1
    Layout.maximumWidth: root.horizontalFormFactor ? row.implicitWidth : -1
    contentItem: RowLayout {
        id: row
        spacing: Kirigami.Units.smallSpacing * 2
        Repeater {
            model: root.controller.highPrioritySensorIds
            delegate: RowLayout {
                id: metric
                required property string modelData
                spacing: Kirigami.Units.smallSpacing
                readonly property bool percentage: modelData === "cpu/all/usage" || modelData === "memory/physical/applicationPercent"
                Sensors.Sensor {
                    id: sensor
                    sensorId: metric.modelData
                    updateRateLimit: root.controller.updateRateLimit
                }
                QQC2.Label {
                    text: root.controller.sensorLabels[metric.modelData] || sensor.shortName
                    color: root.controller.sensorColors[metric.modelData] || Kirigami.Theme.textColor
                    font.bold: true
                    Layout.alignment: Qt.AlignVCenter
                }
                TextMetrics {
                    id: reserve
                    font: reading.font
                    text: metric.percentage ? "100%" : "99.9 MiB/s"
                }
                QQC2.Label {
                    id: reading
                    text: sensor.formattedValue ? (metric.percentage ? Math.round(Number(sensor.value)) + "%" : sensor.formattedValue) : "\u2014"
                    Layout.minimumWidth: Math.max(reserve.advanceWidth, implicitWidth)
                    Layout.preferredWidth: Layout.minimumWidth
                    Layout.alignment: Qt.AlignVCenter
                }
                RowLayout {
                    visible: metric.modelData === "cpu/all/usage"
                    spacing: 2
                    Layout.alignment: Qt.AlignVCenter
                    Repeater {
                        model: metric.modelData === "cpu/all/usage" ? [CORE_MODEL_PLACEHOLDER] : []
                        delegate: Rectangle {
                            id: coreBar
                            required property string modelData
                            Layout.preferredWidth: Math.max(3, Math.round(Kirigami.Units.gridUnit / 4))
                            Layout.preferredHeight: Math.max(8, Math.min(Kirigami.Units.gridUnit, root.height - 4))
                            radius: 1
                            color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.13)
                            readonly property bool available: coreSensor.formattedValue !== "" && coreSensor.formattedValue !== undefined && coreSensor.value !== null && coreSensor.value !== undefined && isFinite(Number(coreSensor.value))
                            readonly property real fraction: available ? Math.max(0, Math.min(1, Number(coreSensor.value) / 100)) : 0
                            Sensors.Sensor {
                                id: coreSensor
                                sensorId: coreBar.modelData
                                updateRateLimit: root.controller.updateRateLimit
                            }
                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width
                                height: parent.height * coreBar.fraction
                                radius: 1
                                color: root.controller.sensorColors["cpu/all/usage"] || Kirigami.Theme.textColor
                            }
                        }
                    }
                }
            }
        }
    }
}
