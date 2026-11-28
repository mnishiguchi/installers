import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.ksysguard.faces as Faces
import org.kde.ksysguard.sensors as Sensors

Faces.SensorFace {
    id: root
    Layout.minimumWidth: Kirigami.Units.gridUnit * 12
    Layout.preferredWidth: Layout.minimumWidth
    contentItem: ColumnLayout {
        spacing: Kirigami.Units.smallSpacing
        Item { Layout.fillHeight: true }
        Repeater {
            model: root.controller.highPrioritySensorIds
            delegate: RowLayout {
                id: metric
                required property string modelData
                Sensors.Sensor {
                    id: sensor
                    sensorId: metric.modelData
                    updateRateLimit: root.controller.updateRateLimit
                }
                QQC2.Label {
                    text: root.controller.sensorLabels[metric.modelData] || sensor.name
                    color: root.controller.sensorColors[metric.modelData] || Kirigami.Theme.textColor
                    font.bold: true
                }
                Item { Layout.fillWidth: true }
                QQC2.Label { text: sensor.formattedValue || "\u2014" }
            }
        }
        Item { Layout.fillHeight: true }
    }
}
