# ✦ GNOME to macOS Transformation for Fedora

A calm, refined, and fully automated setup suite to transform your GNOME desktop on **Fedora Linux** into a polished macOS-styled workspace.

---

## 🌟 Features

- **Automated Fedora Package Setup**: Installs `gnome-tweaks`, `git`, and GNOME Extension Manager with safe privilege handling.
- **MacTahoe Themes**: Deploys `MacTahoe-Dark-blue`, `MacTahoe-Dark-blue-hdpi`, and `MacTahoe-Dark-blue-xhdpi` to `~/.themes` and `~/.local/share/themes`.
- **Liquid Glass V2**: Clones and installs the [Liquid Glass V2](https://github.com/RuntimeFlash/Liquid-Glass-V2.git) extension into `~/.local/share/gnome-shell/extensions/`.
- **Full Extension & Preference Sync**: Automated dconf export/restore preserving your exact layout, dock, animations, blur, lockscreen, and shell tweaks.
- **Calm & Beautiful CLI**: Gentle nord/pastel colored interface with step-by-step progress and interactive prompts.

---

## 🚀 Quick Start

### 1. Clone or Navigate to the Repository
```bash
cd ~/Code/"Gnome To Macos"
```

### 2. Run the Setup Script
```bash
./setup.sh
```

The script will:
1. Safely request `sudo` credentials once for package installations.
2. Install `gnome-tweaks`, `git`, and Extension Manager.
3. Synchronize extension preferences.
4. Clone and deploy **Liquid Glass V2** and other configured GNOME extensions.
5. Deploy **MacTahoe** themes and apply styling.
6. Open **GNOME Tweaks** for visual confirmation and offer a graceful session logout.

---

## 💾 Backing Up Future Tweaks

Whenever you adjust extension configurations, dock settings, or UI tweaks in the future, save them back into the repository with a single command:

```bash
./backup-configs.sh
```

This updates all files inside `Extensions-Configs/` so your repository stays in sync.

---

## 📁 Repository Structure

```text
.
├── setup.sh                 # Master installation & transformation script
├── backup-configs.sh        # Quick exporter for GNOME & extension settings
├── Mactahoe-Theme/          # MacTahoe GTK & Shell themes (Standard, HDPI, XHDPI)
│   ├── MacTahoe-Dark-blue
│   ├── MacTahoe-Dark-blue-hdpi
│   └── MacTahoe-Dark-blue-xhdpi
├── Extensions-Configs/      # dconf backups and extension lists
│   ├── extensions.dconf
│   ├── interface-settings.dconf
│   ├── wm-settings.dconf
│   ├── shell-settings.dconf
│   └── extensions-list.txt
└── README.md                # Documentation and guide
```

---

## 🎨 Setting Up in GNOME Tweaks

If you wish to manually inspect or change appearance settings:
1. Open **GNOME Tweaks** (or press `Y` at the end of `./setup.sh`).
2. Navigate to the **Appearance** tab:
   - **Applications / Legacy Applications**: `MacTahoe-Dark-blue`
   - **Cursor**: `MacTahoe-light`
   - **Icons**: `MacTahoe-light`
   - **Shell**: `MacTahoe-Dark-blue` *(Requires User Themes extension)*
3. Navigate to **Window Titlebars**:
   - Placement: **Left** (macOS style)
