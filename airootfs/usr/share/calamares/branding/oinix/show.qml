/* OINIX Linux installation slideshow */

import QtQuick 2.5
import calamares.slideshow 1.0

Presentation {
    id: presentation

    function nextSlide() {
        presentation.goToNextSlide();
    }

    Timer {
        id: advanceTimer
        interval: 20000
        running: false
        repeat: true
        onTriggered: nextSlide()
    }

    function onActivate() {
        advanceTimer.running = true;
    }

    function onLeave() {
        advanceTimer.running = false;
    }

    Slide {
        Text {
            anchors.centerIn: parent
            horizontalAlignment: Text.AlignHCenter
            width: parent.width * 0.8
            wrapMode: Text.WordWrap
            font.pixelSize: 22
            color: "#ffffff"
            text: qsTr("Welcome to OINIX Linux\n\n" +
                       "A minimal, fast, Arch-based operating system\n" +
                       "built by the Xinux community in Uzbekistan.")
        }
    }

    Slide {
        Text {
            anchors.centerIn: parent
            horizontalAlignment: Text.AlignHCenter
            width: parent.width * 0.8
            wrapMode: Text.WordWrap
            font.pixelSize: 22
            color: "#ffffff"
            text: qsTr("Rolling releases\n\n" +
                       "OINIX tracks the Arch Linux repositories, so your\n" +
                       "software stays current without reinstalling.")
        }
    }

    Slide {
        Text {
            anchors.centerIn: parent
            horizontalAlignment: Text.AlignHCenter
            width: parent.width * 0.8
            wrapMode: Text.WordWrap
            font.pixelSize: 22
            color: "#ffffff"
            text: qsTr("Xfce desktop\n\n" +
                       "A light and configurable desktop that stays out of\n" +
                       "your way, even on modest hardware.")
        }
    }

    Slide {
        Text {
            anchors.centerIn: parent
            horizontalAlignment: Text.AlignHCenter
            width: parent.width * 0.8
            wrapMode: Text.WordWrap
            font.pixelSize: 22
            color: "#ffffff"
            text: qsTr("Need help?\n\n" +
                       "Documentation and community support:\n" +
                       "https://xinux.uz")
        }
    }
}
