import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Lumen: coolant temperature in the bar, and a panel with quick controls for
// lumend. Everything goes through `lumenctl`, so the panel holds no state of
// its own beyond the last status snapshot.
// Left click: panel · right click: Lumen TUI · Enter in the panel: Lumen TUI.

Panel {
  id: root
  moduleName: "sfinkel.lumen"
  ipcTarget: "sfinkel.lumen"
  manageIpc: false

  // The shell's PATH may not include ~/.local/bin, so call the binaries directly.
  readonly property string home: Quickshell.env("HOME")
  readonly property string ctl: home + "/.local/bin/lumenctl"
  readonly property string tui: home + "/.local/bin/lumen"

  property var st: null
  property bool online: false
  readonly property bool showTemp: String(setting("showTemp", true)) !== "false"

  readonly property string fanGlyph: "󰈐"
  readonly property var coolant: st ? st.sensors.coolant : null
  readonly property bool critical: !!(st && st.critical)

  // Button models are only replaced when their contents change: each status poll
  // yields fresh arrays, and handing those to a Repeater would recreate every button
  // (resetting its highlight) every poll.
  property var layouts: []
  property var profileList: []

  function syncModels() {
    var out = []
    var screens = st && st.active.lcd.screens ? st.active.lcd.screens : []
    for (var i = 0; i < screens.length; i++)
      out.push({ mode: screens[i].name, label: screens[i].name.charAt(0).toUpperCase() + screens[i].name.slice(1) })
    out.push({ mode: "cycle", label: "Cycle" })
    out.push({ mode: "firmware", label: "Corsair" })
    if (JSON.stringify(out) !== JSON.stringify(layouts)) layouts = out
    var profiles = st ? st.profiles : []
    if (JSON.stringify(profiles) !== JSON.stringify(profileList)) profileList = profiles
  }

  // Presets apply to the `*` target; per-device overrides in the TUI still win.
  readonly property var lightingPresets: [
    { label: "Theme", args: ["light", "*", "static", "-c", "theme"], type: "static", color: "theme" },
    { label: "Accent", args: ["light", "*", "static", "-c", "theme:accent"], type: "static", color: "theme:accent" },
    { label: "Wave", args: ["light", "*", "wave"], type: "wave" },
    { label: "Rainbow", args: ["light", "*", "rainbow"], type: "rainbow" },
    { label: "Temp", args: ["light", "*", "temperature"], type: "temperature" },
    { label: "Off", args: ["light", "*", "off"], type: "off" }
  ]

  function deg(t, digits) {
    return (t === null || t === undefined) ? "--" : Number(t).toFixed(digits || 0) + "°"
  }

  function pct(v) {
    return (v === null || v === undefined) ? "--" : Math.round(v) + "%"
  }

  function zones() {
    var out = []
    if (!st) return out
    for (var i = 0; i < st.devices.length; i++)
      out = out.concat(st.devices[i].zones || [])
    return out
  }

  readonly property var pump: {
    var z = zones()
    for (var i = 0; i < z.length; i++) if (z[i].kind === "aio" || z[i].kind === "pump") return z[i]
    return null
  }

  readonly property string fanSummary: {
    var z = zones().filter(function(f) { return f.kind === "fan" && f.rpm !== null })
    if (z.length === 0) return "--"
    var rpm = 0, duty = 0
    for (var i = 0; i < z.length; i++) { rpm += z[i].rpm; duty += (z[i].duty || 0) }
    return z.length + "× " + Math.round(rpm / z.length) + " rpm · " + Math.round(duty / z.length) + "%"
  }

  readonly property var starLighting: st && st.active.lighting ? st.active.lighting["*"] : null

  function presetActive(p) {
    var l = starLighting
    if (!l || l.type !== p.type) return false
    return p.color === undefined || l.color === p.color
  }

  readonly property string barTooltip: {
    if (!online) return "Lumen: lumend is not running"
    return "Coolant " + deg(coolant, 1) + " · CPU " + deg(st.sensors.cpu) + " · GPU " + deg(st.sensors.gpu)
      + (critical ? " · CRITICAL: fans at 100%" : "")
      + "\nProfile " + st.profile + " · right click for Lumen"
  }

  function parse(text) {
    try {
      st = JSON.parse(text)
      online = true
      syncModels()
    } catch (e) {
      online = false
    }
  }

  function run(args) {
    if (actionProc.running) return
    actionProc.command = [root.ctl].concat(args)
    actionProc.running = true
  }

  function openTui() {
    Quickshell.execDetached(["omarchy-launch-tui", "--app-id=TUI.float", root.tui])
    root.close()
  }

  Process {
    id: statusProc
    command: [root.ctl, "status", "--json"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.parse(text) }
    onExited: function(code) { if (code !== 0) root.online = false }
  }

  Process {
    id: actionProc
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (text.trim() !== "") console.warn("lumen", text.trim())
    }
    onExited: statusProc.running = true
  }

  // The bar shows the coolant temperature, so poll even while the panel is closed.
  Timer {
    interval: root.opened ? 1500 : 5000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!statusProc.running) statusProc.running = true
  }

  IpcHandler {
    // A hidden copy of each bar widget is created for measurement; only the
    // mounted one may own the IPC target.
    enabled: root.bar !== null
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
  }

  readonly property bool textMode: showTemp && online && coolant !== null && !button.vertical
  readonly property real openPanelIndicatorWidth: textMode ? button.glyphPaintedWidth : 0

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.textMode ? root.fanGlyph + " " + Math.round(root.coolant) + "°" : root.fanGlyph
    slotSize: Style.bar.iconSlot * (root.textMode ? 2.2 : 1)
    active: root.critical
    dimmed: !root.online
    tooltipText: root.barTooltip
    onPressed: function(b) {
      if (b === Qt.RightButton) root.openTui()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(400))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onActivateRequested: root.openTui()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(14)

        // ---------- Hero: icon · title/status · coolant ----------
        Item {
          width: parent.width
          implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight, heroTemp.implicitHeight)

          Text {
            id: heroIcon
            textFormat: Text.PlainText
            text: root.fanGlyph
            color: root.critical ? root.bar.urgent : root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.display
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            RotationAnimation on rotation {
              running: root.opened && root.online
              loops: Animation.Infinite
              from: 0; to: 360
              duration: root.pump && root.pump.duty ? Math.max(600, 6000 - root.pump.duty * 50) : 6000
            }
          }

          Column {
            id: heroLabels
            anchors.left: heroIcon.right
            anchors.leftMargin: Style.space(14)
            anchors.right: heroTemp.left
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              text: "Lumen"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              textFormat: Text.PlainText
              text: !root.online ? "LUMEND NOT RUNNING"
                : root.critical ? "COOLANT CRITICAL · FANS 100%"
                : ("Liquid · " + root.st.profile + " profile").toUpperCase()
              color: root.critical || !root.online ? root.bar.urgent : Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
              elide: Text.ElideRight
              width: parent.width
            }
          }

          Text {
            id: heroTemp
            textFormat: Text.PlainText
            text: root.deg(root.coolant, 1)
            color: root.critical ? root.bar.urgent : root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.displayLarge
            font.bold: true
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
          }
        }

        // ---------- Stats ----------
        Row {
          visible: root.online
          width: parent.width
          spacing: Style.space(20)

          Column {
            width: (parent.width - parent.spacing) / 2
            spacing: Style.spacing.labelGap
            InfoPair { label: "CPU"; value: root.st ? root.deg(root.st.sensors.cpu) + " · " + root.pct(root.st.sensors.cpu_load) : "" }
            InfoPair { label: "GPU"; value: root.st ? root.deg(root.st.sensors.gpu) + " · " + root.pct(root.st.sensors.gpu_load) : "" }
          }

          Column {
            width: (parent.width - parent.spacing) / 2
            spacing: Style.spacing.labelGap
            InfoPair { label: "Pump"; value: root.pump ? (root.pump.rpm || "--") + " rpm · " + root.pct(root.pump.duty) : "--" }
            InfoPair { label: "Fans"; value: root.fanSummary }
          }
        }

        // ---------- Profiles ----------
        PanelSeparator { visible: root.online; foreground: root.bar.foreground }

        ButtonSection {
          visible: root.online
          title: "PROFILE"
          columns: Math.max(1, Math.min(4, root.profileList.length))
          model: root.profileList
          labelOf: function(p) { return String(p).charAt(0).toUpperCase() + String(p).slice(1) }
          isActive: function(p) { return root.st && root.st.profile === p }
          onPicked: function(p) { root.run(["profile", p]) }
        }

        // ---------- AIO screen ----------
        PanelSeparator { visible: root.online && !!root.st.lcd; foreground: root.bar.foreground }

        ButtonSection {
          visible: root.online && !!root.st.lcd
          title: "AIO SCREEN"
          columns: 4
          model: root.layouts
          labelOf: function(l) { return l.label }
          isActive: function(l) { return root.st && root.st.active.lcd.show === l.mode }
          onPicked: function(l) { root.run(["lcd", l.mode]) }
        }

        // ---------- Lighting ----------
        PanelSeparator { visible: root.online; foreground: root.bar.foreground }

        ButtonSection {
          visible: root.online
          title: "LIGHTING · EVERYTHING"
          columns: 3
          model: root.lightingPresets
          labelOf: function(p) { return p.label }
          isActive: function(p) { return root.presetActive(p) }
          onPicked: function(p) { root.run(p.args) }
        }

        PanelSeparator { foreground: root.bar.foreground }

        Button {
          width: parent.width
          iconText: "󰒓"
          text: "Open Lumen"
          fontSize: Style.font.bodySmall
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY + Style.space(2)
          bordered: true
          onClicked: root.openTui()
        }
      }
    }
  }

  // A titled grid of buttons. `model` items are mapped through labelOf/isActive.
  component ButtonSection: Column {
    id: section
    property string title: ""
    property int columns: 4
    property var model: []
    property var labelOf: function(item) { return String(item) }
    property var isActive: function(item) { return false }
    signal picked(var item)

    width: parent.width
    spacing: Style.space(10)

    PanelSectionHeader {
      text: section.title
      foreground: root.bar.foreground
      fontFamily: root.bar.fontFamily
    }

    Flow {
      id: flow
      width: parent.width
      spacing: Style.space(6)
      readonly property real cellWidth: (width - spacing * (section.columns - 1)) / section.columns

      Repeater {
        model: section.model
        Button {
          required property var modelData
          width: flow.cellWidth
          text: section.labelOf(modelData)
          fontSize: Style.font.bodySmall
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY + Style.space(2)
          bordered: true
          active: section.isActive(modelData)
          onClicked: section.picked(modelData)
        }
      }
    }
  }

  component InfoPair: Row {
    property string label: ""
    property string value: ""

    width: parent.width
    spacing: Style.space(8)

    InfoLabel { text: label }
    Item { width: Math.max(0, parent.width - parent.children[0].implicitWidth - parent.children[2].implicitWidth - parent.spacing * 2); height: 1 }
    InfoValue { text: value }
  }

  component InfoLabel: Text {
    textFormat: Text.PlainText
    color: root.bar.foreground
    opacity: 0.6
    font.family: root.bar.fontFamily
    font.pixelSize: Style.font.bodySmall
  }

  component InfoValue: Text {
    textFormat: Text.PlainText
    color: root.bar.foreground
    font.family: root.bar.fontFamily
    font.pixelSize: Style.font.bodySmall
  }
}
