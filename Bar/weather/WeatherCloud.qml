import QtQuick

// Облако для неба окна погоды: несколько кругов, сведённых в один слой (прозрачность без наложений).
Item {
    id: cloud

    property real size: 1
    property real unit: 1
    property color tone: "white"

    width: 160 * unit * size
    height: 64 * unit * size
    layer.enabled: true

    Rectangle { x: 0; y: cloud.height * 0.4; width: cloud.height * 0.6; height: width; radius: width / 2; color: cloud.tone }
    Rectangle { x: cloud.width * 0.2; y: 0; width: cloud.height; height: width; radius: width / 2; color: cloud.tone }
    Rectangle { x: cloud.width * 0.48; y: cloud.height * 0.2; width: cloud.height * 0.8; height: width; radius: width / 2; color: cloud.tone }
    Rectangle { x: cloud.width * 0.12; y: cloud.height * 0.55; width: cloud.width * 0.8; height: cloud.height * 0.45; radius: height / 2; color: cloud.tone }
}
