# Lumen for the Omarchy bar

An [Omarchy](https://omarchy.org) bar widget for [lumen](https://github.com/pxSean/lumen), which controls a Corsair iCUE LINK System Hub and the iCUE LINK AIO LCD screen on Linux.

The bar shows a fan icon and the coolant temperature. It turns the urgent color while lumen's coolant safety override is running fans and pump at full speed.

- **Left click** opens a panel with CPU, GPU and coolant temperatures, pump and fan speeds, and one-click buttons for fan profiles, AIO screen layouts and lighting presets.
- **Right click** opens the Lumen TUI.

## Requirements

The widget is a front end only. Every reading and button goes through `lumenctl`, so lumen must be installed and its `lumend` service running:

```bash
git clone https://github.com/pxSean/lumen.git
cd lumen
./install.sh   # builds lumend, lumenctl and the lumen TUI into ~/.local/bin and starts the service
```

Without it, the panel shows **LUMEND NOT RUNNING**.

## Install

```bash
omarchy plugin add https://github.com/pxSean/omarchy-lumen.git --enable
```

The widget goes in the right section of the bar. To turn off the temperature next to the icon, use the widget's **Show coolant temperature** setting.

## License

GPL-3.0-or-later, like lumen.
