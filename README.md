# Enhanced Ubuntu Terminal

Turn a fresh Ubuntu terminal into a practical, readable, and customizable
developer environment without configuring every tool by hand.

![Full Ubuntu desktop preview](assets/fullscrenn.png)

![Fastfetch and Starship preview](assets/terminal_fastfetch.png)

## What this project does

`install.sh` is an interactive Ubuntu setup script. You choose what to install;
everything is optional and every wizard question defaults to **No**.

It can configure:

| Component | Purpose |
| --- | --- |
| **Ptyxis** | Change the opacity of an existing Ptyxis profile |
| **Kitty** | Install an alternative terminal emulator |
| **Zsh + Oh My Zsh** | Replace the basic interactive shell experience |
| **Starship** | Add the styled prompt included in this repository |
| **Fastfetch** | Show system information with a bundled image |
| **JetBrainsMono Nerd Font** | Render prompt and Fastfetch icons correctly |
| **Zsh plugins** | Add command suggestions and syntax highlighting |
| **Fcitx5 + Unikey** | Provide Vietnamese input support |
| **Flatpak + Flathub** | Optionally install Flatpak applications |

The script also exposes optional system update, Snap removal, GNOME Software,
and cleanup actions. These are not enabled by default.

## What is Ubuntu's default terminal?

There is no single answer for every Ubuntu release.

- Ubuntu Desktop 25.10 introduced **Ptyxis** as part of its modernized default
  application set. See the
  [Ubuntu 25.10 desktop roadmap](https://discourse.ubuntu.com/t/ubuntu-desktop-25-10-the-questing-quokka-roadmap/61159).
- Ubuntu releases may still have GNOME Terminal, GNOME Console, Kitty, or
  another emulator installed.
- On Ubuntu 25.04 and later, the default is the terminal opened by
  `Ctrl` + `Alt` + `T` and is selected through Ubuntu's XDG terminal mechanism.
  See the official
  [Ubuntu default-terminal guide](https://ubuntu.com/desktop/docs/en/26.04/how-to/change-the-default-terminal/).

This project does **not** replace the default terminal automatically:

- Choosing Ptyxis only changes its opacity.
- Choosing Kitty installs Kitty but leaves the default-terminal decision to you.
- Choosing “Do nothing” leaves the current terminal untouched.

## Why customize it?

Ubuntu's default terminal is already stable and sufficient for normal shell
work. This setup is useful when you want:

- a prompt that shows the current directory, Git branch, language runtime, and
  time without remembering extra commands;
- command suggestions and syntax highlighting while typing;
- consistent Nerd Font icons;
- a quick system overview when opening Zsh;
- a transparent Ptyxis profile or Kitty as an alternative emulator;
- the same setup across multiple Ubuntu machines.

This is a convenience setup, not a performance requirement. If the stock
terminal already fits your workflow, keep it.

## Pros and trade-offs

### Advantages

- Interactive and opt-in: skip anything you do not need.
- Reuses Ubuntu packages where available.
- Skips packages that are already installed.
- Includes matching Starship, Fastfetch, font, and image configuration.
- Supports `--dry-run` before changing the machine.
- Records newly installed items for a managed rollback.

### Trade-offs

- More shell startup output and slightly more startup work.
- Nerd Font symbols may render as squares until the terminal font is selected.
- Oh My Zsh and Starship installers are downloaded from their upstream sites.
- Package availability varies between Ubuntu versions.
- Removing Snap, running a full upgrade, autoremove, or cache cleanup cannot be
  fully reversed.
- Kitty is installed as an alternative; it is not automatically made default.

## Requirements

- Ubuntu or an Ubuntu-based system with `apt`
- A normal user account with `sudo` access
- An internet connection
- Bash 4 or later
- A GNOME desktop session for Ptyxis opacity changes

Do not run the whole script with `sudo`. The script requests elevated access
only for system operations.

## Quick start

```bash
git clone https://github.com/ngoctanz/perf-ptyxis-ubuntu.git
cd perf-ptyxis-ubuntu
chmod +x install.sh
./install.sh
```

Running without options opens the wizard. Review all selected actions before
the final confirmation.

## Preview first

Use a dry run to inspect commands without applying the selected changes:

```bash
./install.sh --dry-run --full
```

`--dry-run` still performs read-only system checks and creates a log file in
your home directory.

## Common setups

Install the recommended terminal appearance stack:

```bash
./install.sh --desktop-stack
```

This installs JetBrainsMono Nerd Font, Fastfetch, Zsh, Oh My Zsh, the Zsh
plugins, and Starship.

Install the desktop stack plus Kitty:

```bash
./install.sh --full
```

Configure only Ptyxis transparency:

```bash
./install.sh --ptyxis-opacity 0.75
```

Accepted opacity values are from `0.20` to `1.00`. Lower values are more
transparent.

Reset Ptyxis opacity:

```bash
./install.sh --reset-ptyxis-opacity
```

Install only Kitty:

```bash
./install.sh --install-kitty
```

Show every available option:

```bash
./install.sh --help
```

## Fastfetch customization

The bundled Fastfetch files are:

```text
fastfetch/
├── config.jsonc
└── assets/
    └── bg_terminal.png
```

Install the bundled configuration and image:

```bash
./install.sh --install-fastfetch
```

Use another image:

```bash
./install.sh \
  --install-fastfetch \
  --fastfetch-image /absolute/path/to/image.png
```

The installer copies the image into the active XDG configuration directory and
writes the resulting path into `config.jsonc`. The top-level `assets/`
directory contains README screenshots only.

## Make Kitty the default terminal

Ubuntu 25.04 and later can use the XDG terminal list:

```bash
mkdir -p "$HOME/.config"
printf '%s\n' 'kitty.desktop' > "$HOME/.config/ubuntu-xdg-terminals.list"
```

To use Ptyxis instead:

```bash
printf '%s\n' 'org.gnome.Ptyxis.desktop:new-window' \
  > "$HOME/.config/ubuntu-xdg-terminals.list"
```

This file is specific to the standard Ubuntu GNOME desktop. Other desktop
environments can use a different configuration mechanism.

## Rollback

Preview rollback first:

```bash
./install.sh --uninstall --dry-run
```

Then run it:

```bash
./install.sh --uninstall
```

Rollback restores recorded Fastfetch, Starship, Zsh, Fcitx5 autostart, previous
login shell, and Ptyxis settings. It removes files and packages recorded as
newly installed by this script.

> [!CAUTION]
> Run uninstall with the same `XDG_CONFIG_HOME` value used during installation.
> The current release recalculates config paths during rollback. Changing that
> value can target the wrong Fastfetch or Starship directory. This is tracked in
> [issue #1](https://github.com/ngoctanz/perf-ptyxis-ubuntu/issues/1).

The following actions cannot be reliably reversed:

- a system update or full upgrade;
- deleted Snap applications and Snap data;
- `apt autoremove`;
- package and journal cache cleanup;
- Flatpak unused-runtime cleanup.

## Troubleshooting

### Icons appear as squares

Log out and back in, then select **JetBrainsMono Nerd Font** in the active
terminal profile.

### Zsh is installed but Bash still opens

Log out and back in after installation. Check the configured shell with:

```bash
getent passwd "$USER" | cut -d: -f7
```

### Fastfetch does not display the image

Confirm that Chafa and the copied image exist:

```bash
command -v chafa
find "${XDG_CONFIG_HOME:-$HOME/.config}/fastfetch" -maxdepth 2 -type f
```

### Ptyxis opacity is skipped

The command requires Ptyxis, its GSettings schema, a valid profile, and an
active desktop session. Open Ptyxis once to create a profile, then retry:

```bash
./install.sh --ptyxis-opacity 0.75
```

### A package is reported as unavailable

Refresh APT metadata and retry:

```bash
sudo apt update
```

Some packages are not available on every supported Ubuntu release.

## Project layout

```text
.
├── install.sh
├── configs/
│   └── starship.toml
├── fastfetch/
│   ├── config.jsonc
│   └── assets/
│       └── bg_terminal.png
└── assets/
    ├── terminal_fastfetch.png
    └── fullscrenn.png
```

## Security notes

Read `install.sh` and use `--dry-run` before installation. The shell stack
downloads the official Oh My Zsh and Starship install scripts over HTTPS, but
the current project does not pin their versions or verify release checksums.

Never run shell installers from forks or modified copies you do not trust.

## Contributing

Bug reports and focused pull requests are welcome. Include:

- Ubuntu version;
- desktop environment;
- the exact command used;
- the relevant `enhanced-terminal-*.log` output;
- whether the failure also occurs with `--dry-run`.
