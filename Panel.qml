import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "gladimdim.hardware.info"
  ipcTarget: "gladimdim.hardware.info"
  manageIpc: false

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color accent: Color.accent
  readonly property color urgent: Color.urgent
  readonly property color muted: Color.muted
  readonly property color dim: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.65)
  readonly property color cardBg: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.05)
  readonly property color cardBorder: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.12)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  property var hwData: null
  property int activeTab: 2 // 0: System, 1: CPU, 2: Memory, 3: Storage, 4: Devices, 5: Capabilities
  property string copyStatus: ""

  readonly property var tabs: [
    { name: "System", icon: "󰌢" },
    { name: "CPU", icon: "" },
    { name: "Memory", icon: "󰘚" },
    { name: "Storage", icon: "󰋊" },
    { name: "Devices", icon: "󰍹" },
    { name: "Capabilities", icon: "󰞌" }
  ]

  function refresh() {
    if (!collectorProc.running) {
      collectorProc.running = true
    }
  }

  function parseData(raw) {
    try {
      var parsed = JSON.parse(raw)
      if (parsed && parsed.cpu) {
        hwData = parsed
      }
    } catch (e) {
      console.log("Error parsing hardware data:", e)
    }
  }

  function copyToClipboard() {
    if (!hwData) return
    copyProc.command = ["wl-copy", JSON.stringify(hwData, null, 2)]
    copyProc.running = true
    copyStatus = "Copied JSON to clipboard!"
    copyTimer.restart()
  }

  onOpenedChanged: {
    if (opened) {
      refresh()
    }
  }

  Component.onCompleted: {
    refresh()
  }

  Timer {
    id: copyTimer
    interval: 2500
    onTriggered: root.copyStatus = ""
  }

  Timer {
    interval: 3000
    running: root.opened
    repeat: true
    onTriggered: root.refresh()
  }

  readonly property string scriptPath: String(Qt.resolvedUrl("collect.py")).replace(/^file:\/\//, "")

  Process {
    id: collectorProc
    command: ["python3", root.scriptPath]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseData(text)
    }
  }

  Process {
    id: copyProc
  }

  IpcHandler {
    target: "gladimdim.hardware.info"
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function setTab(idx: int): void { root.activeTab = idx }
    function refresh(): void { root.refresh() }
  }

  // ======================== TAB COMPONENTS ========================
  Component {
    id: loadingComp
    Item {
      width: parent.width
      implicitHeight: Style.space(120)
      Column {
        anchors.centerIn: parent
        spacing: Style.space(8)
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: ""
          color: root.accent
          font.family: root.fontFamily
          font.pixelSize: Style.font.display
        }
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "Probing hardware devices..."
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }
      }
    }
  }

  // ----------------------------------------------------
  // TAB 0: SYSTEM & MOTHERBOARD
  // ----------------------------------------------------
  Component {
    id: tabSystemComp
    Column {
      width: parent.width
      spacing: Style.space(12)

      PanelSectionHeader {
        text: "MOTHERBOARD & BIOS"
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      CardBox {
        TablePair { label: "Manufacturer"; value: root.hwData ? root.hwData.dmi.board_vendor : "—" }
        TablePair { label: "Board Model"; value: root.hwData ? root.hwData.dmi.board_name : "—" }
        TablePair { label: "Board Version"; value: root.hwData ? root.hwData.dmi.board_version : "—" }
        TablePair { label: "BIOS Vendor"; value: root.hwData ? root.hwData.dmi.bios_vendor : "—" }
        TablePair { label: "BIOS Version"; value: root.hwData ? root.hwData.dmi.bios_version : "—" }
        TablePair { label: "Release Date"; value: root.hwData ? root.hwData.dmi.bios_date : "—" }
      }

      PanelSectionHeader {
        text: "SYSTEM & CHASSIS"
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      CardBox {
        TablePair { label: "Product Name"; value: root.hwData ? root.hwData.dmi.product_name : "—" }
        TablePair { label: "Product Family"; value: root.hwData ? root.hwData.dmi.product_family : "—" }
        TablePair { label: "Chassis Type"; value: root.hwData ? root.hwData.dmi.chassis_desc : "—" }
        TablePair { label: "Hostname"; value: root.hwData ? root.hwData.os.hostname : "—" }
        TablePair { label: "Operating System"; value: root.hwData ? root.hwData.os.distro : "—" }
        TablePair { label: "Kernel Version"; value: root.hwData ? root.hwData.os.kernel : "—" }
        TablePair { label: "System Uptime"; value: root.hwData ? root.hwData.os.uptime : "—" }
      }
    }
  }

  // ----------------------------------------------------
  // TAB 1: CPU / PROCESSOR
  // ----------------------------------------------------
  Component {
    id: tabCpuComp
    Column {
      width: parent.width
      spacing: Style.space(12)

      PanelSectionHeader {
        text: "PROCESSOR SPECIFICATIONS"
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      CardBox {
        TablePair { label: "Model Name"; value: root.hwData ? root.hwData.cpu.model : "—" }
        TablePair { label: "Architecture"; value: root.hwData ? root.hwData.cpu.arch : "—" }
        TablePair { label: "Vendor ID"; value: root.hwData ? root.hwData.cpu.vendor : "—" }
        TablePair {
          label: "Topology"
          value: root.hwData ? (root.hwData.cpu.cores + " Cores / " + root.hwData.cpu.threads + " Threads (" + root.hwData.cpu.sockets + " Socket)") : "—"
        }
        TablePair {
          label: "Base / Max Clock"
          value: root.hwData ? (root.hwData.cpu.base_mhz + " MHz Base / " + root.hwData.cpu.max_mhz + " MHz Max") : "—"
        }
        TablePair {
          label: "Governor / Driver"
          value: root.hwData ? (root.hwData.cpu.governor + " (" + root.hwData.cpu.driver + ")") : "—"
        }
        TablePair {
          label: "Load Averages"
          value: root.hwData && root.hwData.cpu.load_avg ? root.hwData.cpu.load_avg.join(", ") : "—"
        }
      }

      PanelSectionHeader {
        text: "CACHE HIERARCHY"
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      CardBox {
        TablePair { label: "L1 Data Cache"; value: root.hwData ? root.hwData.cpu.caches.l1d : "—" }
        TablePair { label: "L1 Instruction Cache"; value: root.hwData ? root.hwData.cpu.caches.l1i : "—" }
        TablePair { label: "L2 Cache"; value: root.hwData ? root.hwData.cpu.caches.l2 : "—" }
        TablePair { label: "L3 Shared Cache"; value: root.hwData ? root.hwData.cpu.caches.l3 : "—" }
      }

      PanelSectionHeader {
        text: "PER-CORE FREQUENCIES (MHz)"
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      CardBox {
        Repeater {
          model: root.hwData && root.hwData.cpu ? root.hwData.cpu.core_freqs_mhz : []
          Row {
            required property var modelData
            required property int index
            width: parent.width
            spacing: Style.space(8)

            Text {
              text: "Core " + index
              width: Style.space(60)
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }

            Rectangle {
              width: parent.width - Style.space(140)
              height: Style.space(8)
              radius: height / 2
              color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
              anchors.verticalCenter: parent.verticalCenter

              Rectangle {
                height: parent.height
                radius: parent.radius
                color: root.accent
                width: {
                  var maxMhz = root.hwData && root.hwData.cpu ? Number(root.hwData.cpu.max_mhz) || 4700 : 4700
                  return Math.min(parent.width, Math.max(parent.height, parent.width * (Number(modelData) / maxMhz)))
                }
              }
            }

            Text {
              text: modelData + " MHz"
              width: Style.space(60)
              horizontalAlignment: Text.AlignRight
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }
          }
        }
      }
    }
  }

  // ----------------------------------------------------
  // TAB 2: MEMORY / RAM
  // ----------------------------------------------------
  Component {
    id: tabMemoryComp
    Column {
      width: parent.width
      spacing: Style.space(12)

      PanelSectionHeader {
        text: "SYSTEM MEMORY USAGE"
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      CardBox {
        Item {
          width: parent.width
          implicitHeight: Math.max(ramLabel.implicitHeight, ramVal.implicitHeight)
          Text {
            id: ramLabel
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "RAM Usage"
            color: root.foreground
            font.family: root.fontFamily
            font.bold: true
            font.pixelSize: Style.font.body
          }
          Text {
            id: ramVal
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.hwData ? (root.hwData.memory.used_gb + " GB / " + root.hwData.memory.total_gb + " GB (" + root.hwData.memory.used_pct + "%)") : "—"
            color: root.hwData && root.hwData.memory.used_pct > 85 ? root.urgent : root.foreground
            font.family: root.fontFamily
            font.bold: true
            font.pixelSize: Style.font.bodySmall
          }
        }

        Rectangle {
          width: parent.width
          height: Style.space(8)
          radius: height / 2
          color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)

          Rectangle {
            height: parent.height
            radius: parent.radius
            color: root.hwData && root.hwData.memory.used_pct > 85 ? root.urgent : root.accent
            width: Math.min(parent.width, Math.max(parent.height, parent.width * ((root.hwData ? root.hwData.memory.used_pct : 0) / 100)))
          }
        }

        TablePair { label: "Available Memory"; value: root.hwData ? (root.hwData.memory.avail_gb + " GB") : "—" }
        TablePair { label: "Cached / Buffers"; value: root.hwData ? (root.hwData.memory.cached_gb + " GB / " + root.hwData.memory.buffers_mb + " MB") : "—" }
        TablePair { label: "Free Memory"; value: root.hwData ? (root.hwData.memory.free_gb + " GB") : "—" }
      }

      PanelSectionHeader {
        text: "SWAP / ZRAM"
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      CardBox {
        Item {
          width: parent.width
          implicitHeight: Math.max(swapLabel.implicitHeight, swapVal.implicitHeight)
          Text {
            id: swapLabel
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Swap Usage"
            color: root.foreground
            font.family: root.fontFamily
            font.bold: true
            font.pixelSize: Style.font.body
          }
          Text {
            id: swapVal
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.hwData ? (root.hwData.memory.swap_used_gb + " GB / " + root.hwData.memory.swap_total_gb + " GB (" + root.hwData.memory.swap_used_pct + "%)") : "—"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
        }

        Rectangle {
          width: parent.width
          height: Style.space(8)
          radius: height / 2
          color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)

          Rectangle {
            height: parent.height
            radius: parent.radius
            color: root.accent
            width: Math.min(parent.width, Math.max(0, parent.width * ((root.hwData ? root.hwData.memory.swap_used_pct : 0) / 100)))
          }
        }

        TablePair { label: "Swap Free"; value: root.hwData ? (root.hwData.memory.swap_free_gb + " GB") : "—" }
      }

      PanelSectionHeader {
        text: "MEMORY MODULES & CHANNELS"
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      CardBox {
        Text {
          visible: root.hwData && root.hwData.memory.array_summary !== ""
          text: root.hwData ? root.hwData.memory.array_summary : ""
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.italic: true
        }

        Repeater {
          model: root.hwData && root.hwData.memory ? root.hwData.memory.modules : []
          Row {
            required property var modelData
            width: parent.width
            spacing: Style.space(8)

            Text {
              text: modelData.slot
              width: parent.width * 0.40
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
            }

            Text {
              text: modelData.type + " • " + modelData.size
              width: parent.width * 0.32
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }

            Text {
              text: modelData.speed
              width: parent.width * 0.24
              horizontalAlignment: Text.AlignRight
              color: root.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: true
            }
          }
        }
      }
    }
  }

  // ----------------------------------------------------
  // TAB 3: STORAGE / SSD
  // ----------------------------------------------------
  Component {
    id: tabStorageComp
    Column {
      width: parent.width
      spacing: Style.space(12)

      PanelSectionHeader {
        text: "PHYSICAL DRIVES"
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      Repeater {
        model: root.hwData && root.hwData.storage ? root.hwData.storage.disks : []
        CardBox {
          required property var modelData
          Item {
            width: parent.width
            implicitHeight: Math.max(modelTag.implicitHeight, sizeTag.implicitHeight)
            Text {
              id: modelTag
              text: "󰋊 " + modelData.model
              color: root.foreground
              font.family: root.fontFamily
              font.bold: true
              font.pixelSize: Style.font.body
              anchors.left: parent.left
              anchors.right: sizeTag.left
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              elide: Text.ElideRight
            }
            Text {
              id: sizeTag
              text: modelData.size
              color: root.accent
              font.family: root.fontFamily
              font.bold: true
              font.pixelSize: Style.font.body
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
            }
          }
          TablePair { label: "Device Node"; value: "/dev/" + modelData.name }
          TablePair { label: "Interface / Transport"; value: modelData.tran ? modelData.tran : "SATA/Block" }
          TablePair { label: "Serial Number"; value: modelData.serial }
          TablePair {
            visible: modelData.tran === "NVME" && root.hwData.sensors.nvme_temp_c !== null
            label: "Drive Temperature"
            value: root.hwData ? root.hwData.sensors.nvme_temp_c + "°C" : "—"
          }
        }
      }

      PanelSectionHeader {
        text: "MOUNTED FILESYSTEMS & PARTITIONS"
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      CardBox {
        Repeater {
          model: root.hwData && root.hwData.storage ? root.hwData.storage.mounts : []
          Column {
            required property var modelData
            required property int index
            width: parent.width
            spacing: Style.space(4)

            Item {
              width: parent.width
              implicitHeight: Math.max(mpLabel.implicitHeight, mpUsage.implicitHeight)
              Text {
                id: mpLabel
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.mountpoint
                color: root.foreground
                font.family: root.fontFamily
                font.bold: true
                font.pixelSize: Style.font.bodySmall
              }
              Text {
                id: mpUsage
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.used + " / " + modelData.size + " (" + modelData.use_pct + ")"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
            }

            Rectangle {
              width: parent.width
              height: Style.space(6)
              radius: height / 2
              color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)

              Rectangle {
                height: parent.height
                radius: parent.radius
                color: root.accent
                width: {
                  var pct = parseFloat(modelData.use_pct) || 0
                  return Math.min(parent.width, Math.max(0, parent.width * (pct / 100)))
                }
              }
            }

            Item {
              width: parent.width
              implicitHeight: Math.max(devDesc.implicitHeight, freeDesc.implicitHeight)
              Text {
                id: devDesc
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Dev: " + modelData.device + " • " + modelData.fstype
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
              Text {
                id: freeDesc
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "Free: " + modelData.avail
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
            }

            Rectangle {
              width: parent.width
              height: 1
              color: root.cardBorder
              visible: index < (root.hwData.storage.mounts.length - 1)
            }
          }
        }
      }
    }
  }

  // ----------------------------------------------------
  // TAB 4: DEVICES / PERIPHERALS
  // ----------------------------------------------------
  Component {
    id: tabDevicesComp
    Column {
      width: parent.width
      spacing: Style.space(12)

      PanelSectionHeader {
        text: "GRAPHICS & DISPLAY"
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      CardBox {
        Repeater {
          model: root.hwData && root.hwData.devices ? root.hwData.devices.gpus : []
          TablePair {
            required property var modelData
            label: "GPU Device"
            value: modelData.name
          }
        }
      }

      PanelSectionHeader {
        text: "NETWORK INTERFACES"
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      CardBox {
        Repeater {
          model: root.hwData && root.hwData.devices ? root.hwData.devices.network : []
          TablePair {
            required property var modelData
            label: "Adapter"
            value: modelData.name
          }
        }
      }

      PanelSectionHeader {
        text: "AUDIO CONTROLLERS"
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      CardBox {
        Repeater {
          model: root.hwData && root.hwData.devices ? root.hwData.devices.audio : []
          TablePair {
            required property var modelData
            label: "Audio"
            value: modelData.name
          }
        }
      }
    }
  }

  // ----------------------------------------------------
  // TAB 5: CAPABILITIES & SECURITY
  // ----------------------------------------------------
  Component {
    id: tabCapabilitiesComp
    Column {
      width: parent.width
      spacing: Style.space(12)

      PanelSectionHeader {
        text: "VECTOR & SIMD INSTRUCTIONS"
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      CardBox {
        Flow {
          width: parent.width
          spacing: Style.space(6)
          Repeater {
            model: root.hwData && root.hwData.cpu && root.hwData.cpu.capabilities ? root.hwData.cpu.capabilities.simd : []
            CapBadge {
              required property var modelData
              name: modelData.name
              supported: modelData.supported
            }
          }
        }
      }

      PanelSectionHeader {
        text: "CRYPTOGRAPHY ACCELERATION"
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      CardBox {
        Flow {
          width: parent.width
          spacing: Style.space(6)
          Repeater {
            model: root.hwData && root.hwData.cpu && root.hwData.cpu.capabilities ? root.hwData.cpu.capabilities.crypto : []
            CapBadge {
              required property var modelData
              name: modelData.name
              supported: modelData.supported
            }
          }
        }
      }

      PanelSectionHeader {
        text: "VIRTUALIZATION & PRIVILEGE"
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      CardBox {
        Flow {
          width: parent.width
          spacing: Style.space(6)
          Repeater {
            model: root.hwData && root.hwData.cpu && root.hwData.cpu.capabilities ? root.hwData.cpu.capabilities.virtualization.concat(root.hwData.cpu.capabilities.security) : []
            CapBadge {
              required property var modelData
              name: modelData.name
              supported: modelData.supported
            }
          }
        }
      }

      PanelSectionHeader {
        text: "HARDWARE VULNERABILITIES & MITIGATIONS"
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      CardBox {
        Repeater {
          model: root.hwData && root.hwData.cpu ? root.hwData.cpu.vulnerabilities : []
          Row {
            required property var modelData
            width: parent.width
            spacing: Style.space(6)

            Text {
              text: modelData.name
              width: parent.width * 0.35
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              elide: Text.ElideRight
            }

            Text {
              text: modelData.status
              width: parent.width * 0.62
              color: modelData.is_mitigated ? root.accent : root.urgent
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }
          }
        }
      }
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "" // CPU icon
    tooltipText: "Hardware Details — CPU, RAM, Motherboard, Storage"
    onPressed: function(b) {
      if (b === Qt.RightButton) {
        root.refresh()
      } else {
        root.toggle()
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(580))
    contentHeight: panel.fittedContentHeight(Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onMoveRequested: function(dx, dy) {
        if (dx !== 0) {
          var n = root.tabs.length
          root.activeTab = (root.activeTab + dx + n) % n
        }
      }
      onTextKey: function(t) {
        if (t >= "1" && t <= "6") root.activeTab = parseInt(t) - 1
        else if (t === "r" || t === "R") root.refresh()
        else if (t === "c" || t === "C") root.copyToClipboard()
      }

      Column {
        id: mainCol
        anchors.fill: parent
        spacing: Style.space(10)

        // ======================== HERO HEADER ========================
        Item {
          width: parent.width
          implicitHeight: Math.max(heroIcon.implicitHeight, heroInfo.implicitHeight, heroActions.implicitHeight)

          Text {
            id: heroIcon
            text: ""
            color: root.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.display
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
          }

          Column {
            id: heroInfo
            anchors.left: heroIcon.right
            anchors.leftMargin: Style.space(12)
            anchors.right: heroActions.left
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              text: "Hardware Details"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
            }

            Text {
              text: {
                if (!root.hwData) return "Scanning hardware..."
                var dmi = root.hwData.dmi || {}
                var os = root.hwData.os || {}
                return (dmi.product_name || dmi.board_name || "Linux PC") + " • " + (os.distro || "Omarchy")
              }
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
              width: parent.width
            }
          }

          Row {
            id: heroActions
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(6)

            Button {
              iconText: "󰆏"
              tooltipText: "Copy JSON summary (press 'c')"
              foreground: root.foreground
              fontFamily: root.fontFamily
              fontSize: Style.font.caption
              onClicked: root.copyToClipboard()
            }

            Button {
              iconText: "󰑐"
              tooltipText: "Refresh hardware stats (press 'r')"
              foreground: root.foreground
              fontFamily: root.fontFamily
              fontSize: Style.font.caption
              onClicked: root.refresh()
            }
          }
        }

        // ======================== QUICK GLANCE STATS PILLS ========================
        Row {
          width: parent.width
          spacing: Style.space(8)
          visible: root.hwData !== null

          readonly property real pillW: (width - spacing * 3) / 4

          QuickPill {
            width: parent.pillW
            icon: ""
            label: "CPU Temp"
            value: root.hwData && root.hwData.sensors && root.hwData.sensors.cpu_temp_c !== null
              ? root.hwData.sensors.cpu_temp_c + "°C" : "—"
            highlightColor: root.hwData && root.hwData.sensors && root.hwData.sensors.cpu_temp_c > 80 ? root.urgent : root.foreground
          }

          QuickPill {
            width: parent.pillW
            icon: "󰈐"
            label: "Fan Speed"
            value: root.hwData && root.hwData.sensors && root.hwData.sensors.fan_rpm !== null
              ? root.hwData.sensors.fan_rpm + " RPM" : "—"
          }

          QuickPill {
            width: parent.pillW
            icon: "󰘚"
            label: "RAM Used"
            value: root.hwData && root.hwData.memory ? root.hwData.memory.used_pct + "%" : "—"
            highlightColor: root.hwData && root.hwData.memory && root.hwData.memory.used_pct > 85 ? root.urgent : root.foreground
          }

          QuickPill {
            width: parent.pillW
            icon: "󰋊"
            label: "Root Disk"
            value: {
              if (!root.hwData || !root.hwData.storage || !root.hwData.storage.mounts) return "—"
              for (var i = 0; i < root.hwData.storage.mounts.length; i++) {
                if (root.hwData.storage.mounts[i].mountpoint === "/") return root.hwData.storage.mounts[i].use_pct
              }
              return "—"
            }
          }
        }

        // Copy feedback banner
        Rectangle {
          visible: root.copyStatus !== ""
          width: parent.width
          implicitHeight: Style.space(24)
          radius: Style.cornerRadius
          color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.15)
          border.width: 1
          border.color: root.accent

          Text {
            anchors.centerIn: parent
            text: root.copyStatus
            color: root.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
          }
        }

        // ======================== CATEGORY TABS ========================
        Row {
          id: tabRow
          width: parent.width
          spacing: Style.space(4)

          readonly property real tabWidth: (width - spacing * (root.tabs.length - 1)) / root.tabs.length

          Repeater {
            model: root.tabs
            Button {
              required property var modelData
              required property int index
              width: tabRow.tabWidth
              iconText: modelData.icon
              text: modelData.name
              fontSize: Style.font.caption
              foreground: root.foreground
              fontFamily: root.fontFamily
              selected: root.activeTab === index
              bordered: true
              horizontalPadding: Style.space(2)
              verticalPadding: Style.space(5)
              onClicked: root.activeTab = index
            }
          }
        }

        PanelSeparator {
          foreground: root.foreground
        }

        // ======================== SCROLLABLE CONTENT ========================
        Flickable {
          id: scrollArea
          width: parent.width
          height: panel.contentHeight - mainCol.spacing * 5 - heroInfo.implicitHeight - tabRow.height - Style.space(60)
          contentWidth: width
          contentHeight: loader.implicitHeight
          clip: true
          boundsBehavior: Flickable.StopAtBounds

          Loader {
            id: loader
            width: parent.width
            sourceComponent: {
              if (root.hwData === null) return loadingComp
              switch (root.activeTab) {
                case 0: return tabSystemComp
                case 1: return tabCpuComp
                case 2: return tabMemoryComp
                case 3: return tabStorageComp
                case 4: return tabDevicesComp
                case 5: return tabCapabilitiesComp
                default: return tabSystemComp
              }
            }
          }
        }
      }
    }
  }

  // ======================== REUSABLE UI COMPONENTS ========================
  component QuickPill: Rectangle {
    property string icon: ""
    property string label: ""
    property string value: ""
    property color highlightColor: root.foreground

    implicitHeight: Style.space(42)
    radius: Style.cornerRadius
    color: root.cardBg
    border.width: 1
    border.color: root.cardBorder

    Column {
      anchors.centerIn: parent
      spacing: 1

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(4)
        Text {
          text: icon
          color: highlightColor
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
        Text {
          text: value
          color: highlightColor
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
        }
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: label
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption - 2
      }
    }
  }

  component CardBox: Rectangle {
    default property alias content: innerCol.children
    width: parent.width
    implicitHeight: innerCol.implicitHeight + Style.space(16)
    radius: Style.cornerRadius
    color: root.cardBg
    border.width: 1
    border.color: root.cardBorder

    Column {
      id: innerCol
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: Style.space(8)
      spacing: Style.space(6)
    }
  }

  component TablePair: Item {
    id: pairItem
    property string label: ""
    property string value: ""

    width: parent.width
    implicitHeight: Math.max(pairLabel.implicitHeight, pairVal.implicitHeight)

    Text {
      id: pairLabel
      text: pairItem.label
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      anchors.left: parent.left
      anchors.top: parent.top
      width: Math.min(Style.space(170), parent.width * 0.35)
      elide: Text.ElideRight
      wrapMode: Text.NoWrap
    }

    Text {
      id: pairVal
      text: pairItem.value
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      font.bold: true
      horizontalAlignment: Text.AlignRight
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.left: pairLabel.right
      anchors.leftMargin: Style.space(10)
      wrapMode: Text.Wrap
      elide: Text.ElideRight
      maximumLineCount: 2
    }
  }

  component CapBadge: Rectangle {
    property string name: ""
    property bool supported: false

    implicitWidth: capRow.implicitWidth + Style.space(12)
    implicitHeight: Style.space(22)
    radius: height / 2
    color: supported ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.12) : Qt.rgba(root.dim.r, root.dim.g, root.dim.b, 0.08)
    border.width: 1
    border.color: supported ? root.accent : Qt.rgba(root.dim.r, root.dim.g, root.dim.b, 0.2)

    Row {
      id: capRow
      anchors.centerIn: parent
      spacing: Style.space(4)

      Text {
        text: supported ? "✓" : "✗"
        color: supported ? root.accent : root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
      }

      Text {
        text: name
        color: supported ? root.foreground : root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: supported
      }
    }
  }
}
