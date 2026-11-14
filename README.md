# Lumen for iCUE LINK

An [Omarchy](https://omarchy.org) bar widget for [lumen](https://github.com/pxSean/lumen), which controls a Corsair iCUE LINK System Hub and the iCUE LINK AIO LCD screen on Linux.

<p align="center"><img src="preview.jpg" width="640" alt="An iCUE LINK AIO pump head showing lumen's graph screen: CPU and GPU temperature in one lane, RAM in another, over the Omarchy wallpaper"></p>

The bar shows a fan icon and the coolant temperature, or another reading you pick. It turns the urgent color while lumen's coolant safety override is running fans and pump at full speed.

- **Left click** opens a panel with your chosen reading, CPU and GPU temperatures, pump and fan speeds, and one-click buttons for fan profiles, AIO screen layouts and lighting presets.
- **Right click** opens the Lumen TUI.

<p align="center"><img src="docs/panel.png" width="360" alt="The Lumen panel: coolant, CPU and GPU temperatures, pump and fan speeds, and buttons for profiles, AIO screens and lighting"></p>

## Requirements

This widget is a front end only. **Install lumen first.** It's the daemon that talks to the hardware, and every reading and button in the widget goes through it.

On Arch, including Omarchy, install the [`lumen-icue`](https://aur.archlinux.org/packages/lumen-icue) package from the AUR and start its daemon:

```bash
yay -S lumen-icue
systemctl --user enable --now lumen-icued
```

Or build it yourself into `~/.local/bin`. That needs the Rust toolchain (`sudo pacman -S rust`, or [rustup](https://rustup.rs)). Build the lumen release this widget is tested with, [v0.2.0](https://github.com/pxSean/lumen/tree/v0.2.0), pinned to its exact commit:

```bash
git clone https://github.com/pxSean/lumen.git lumen &&
cd lumen &&
git checkout --detach 173839ef0cdfb40ad4a63649ad7c969b0ee6308a &&
./install.sh
```

The steps are joined with `&&` so that if the checkout of lumen v0.2.0 fails, nothing gets built. `install.sh` builds `lumen-icued`, `lumenctl` and `lumen-tui`, installs a udev rule (it asks for your password for that step), and starts `lumen-icued` as a systemd user service.

The widget also works with lumen 0.1, which named the daemon `lumend` and the TUI `lumen`.

## Install

```bash
omarchy plugin add https://github.com/pxSean/omarchy-lumen.git --enable
```

The widget goes in the right section of the bar. It has two settings, which go on its entry in `~/.config/omarchy/shell.json`:

```json
{ "id": "pxsean.lumen", "metric": "cpu.temp", "showTemp": true }
```

- `metric` picks the reading shown next to the icon and at the top of the panel. The default is `coolant.temp`. The others are `cpu.temp`, `gpu.temp`, `igpu.temp`, `cpu.load`, `gpu.load`, `igpu.load`, `mem.used`, `gpu.vram`, `gpu.power`, `pump.rpm`, `pump.duty`, `fans.rpm` and `fans.duty`. `lumenctl metrics` lists each one with its current value.
- `showTemp`: `false` shows the icon alone.

The bar picks up changes to `shell.json` as soon as you save it.

If the panel says **LUMEN NOT INSTALLED**, lumen isn't in `/usr/bin` or `~/.local/bin`; follow [Requirements](#requirements). If it says **LUMEN-ICUED NOT RUNNING**, start the daemon with `systemctl --user start lumen-icued`.

## Remove

Remove the widget:

```bash
omarchy plugin remove pxsean.lumen
```

To remove lumen as well, first stop the daemon:

```bash
systemctl --user disable --now lumen-icued
```

If you installed the AUR package:

```bash
sudo pacman -Rns lumen-icue
```

If you built it with `install.sh`:

```bash
rm ~/.local/bin/{lumen-icued,lumenctl,lumen-tui}
rm ~/.config/systemd/user/lumen-icued.service ~/.local/share/applications/lumen.desktop
sudo rm /etc/udev/rules.d/70-lumen.rules
```

Either way, your profiles and screen settings stay in `~/.config/lumen` until you delete it: `rm -r ~/.config/lumen`.

When the daemon stops, the hub goes back to its onboard fan curve, and the AIO screen goes back to Corsair's firmware screen.

## License

GPL-3.0-or-later, like lumen.
