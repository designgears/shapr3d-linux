<h1 align="center">Shapr3D for Linux</h1>

<p align="center">
  Run the Windows version of <a href="https://www.shapr3d.com">Shapr3D</a> on Linux, as an AppImage or a Flatpak.
</p>

<p align="center">
  <a href="https://github.com/designgears/shapr3d-linux/releases/latest"><b>Download</b></a> ·
  <a href="#getting-started">Getting started</a> ·
  <a href="#troubleshooting">Troubleshooting</a> ·
  <a href="#building-from-source">Building</a>
</p>

<p align="center">
  <img src="docs/screenshots/shapr3d-editor.png" alt="Shapr3D modelling on Linux" width="820">
</p>

> **Beta.** Modelling, sketching, cloud sync, sign-in and export (STL, PDF drawings) work.
> Expect rough edges. This is an unofficial project, not affiliated with or supported by Shapr3D.

## Requirements

- 64-bit Linux with glibc 2.38 or newer: Ubuntu 24.04, Debian 13, Fedora 39 or anything more recent
- A GPU with working **Vulkan** drivers
- About **11 GB** of free disk space during setup, 4 GB afterwards
- A Shapr3D account, and the **Shapr3D for Windows** download: `Shapr3D.Package.appinstaller` from
  [shapr3d.com](https://www.shapr3d.com/download/get-started-with-shapr3d/windows) (a small file; the setup fetches Shapr3D itself)

## Getting started

1. **Download** from the [latest release](https://github.com/designgears/shapr3d-linux/releases/latest), either:
   - the **AppImage** (`shapr3d-linux-<version>-x86_64.AppImage`): one file, runs anywhere;
   - or the **Flatpak** (`shapr3d-linux-<version>-x86_64.flatpak`): sandboxed, installed like any Flatpak app.
2. **Start it.**
   - AppImage: make it executable and run it:
     ```sh
     chmod +x shapr3d-linux-*-x86_64.AppImage
     ./shapr3d-linux-*-x86_64.AppImage
     ```
   - Flatpak: install it, then open *Shapr3D for Linux* from your applications menu:
     ```sh
     flatpak install --user shapr3d-linux-*-x86_64.flatpak
     ```
3. **Follow the setup.** It runs once and takes 10-15 minutes, most of it the download:
   - **Windows components:** Shapr3D needs parts of Windows that Linux doesn't have. The setup downloads
     Microsoft's free Windows 11 evaluation image (7.1 GB) straight from Microsoft, takes out the few
     thousand files it needs, and deletes the image. You can also point it at a Windows 11 ISO you already have.
   - **Shapr3D:** choose the `Shapr3D.Package.appinstaller` you downloaded from
     [shapr3d.com](https://www.shapr3d.com/download/get-started-with-shapr3d/windows). The setup downloads Shapr3D
     from Shapr3D's server straight into place (about 1.8 GB). A `.msixbundle` works too.
4. **Launch Shapr3D** and sign in. Your browser opens to log in; when it asks to open Shapr3D, allow it, and
   you are signed in.

<p align="center">
  <img src="docs/screenshots/installer/1-welcome.png" alt="The setup" width="640">
</p>

The setup adds **Shapr3D** to your applications menu, which starts it directly and is also what lets the browser
hand the sign-in back. Opening the AppImage again (or *Setup* on the Flatpak's menu entry) shows the launcher:
Launch, and Update.

## Good to know

- **Nothing is installed system-wide.** Everything lives in `~/.local/share/wine-uwp`, or for the Flatpak in
  `~/.var/app/io.github.designgears.Shapr3DLinux`.
- **Your files:** Shapr3D's open and save dialogs start in your Documents folder. Its own projects sync to
  your Shapr3D cloud account as usual.
- **Updating Shapr3D:** the launcher checks Shapr3D's server and offers **Update to** the new version when there
  is one: one click, and your sign-in and projects stay. **Update…** also takes a newer `.appinstaller` or
  `.msixbundle` by hand. Close Shapr3D first.
- **Updating Shapr3D for Linux:** the AppImage carries update information, so
  [AppImageUpdate](https://github.com/AppImageCommunity/AppImageUpdate) and AppImage managers such as Gear Lever
  can update it in place. For the Flatpak, install the new release's file with `flatpak install --user --reinstall`.
- **Nothing of Microsoft's or Shapr3D's is in the download.** The AppImage and the Flatpak hold only open-source code; the
  Windows components come from Microsoft and Shapr3D from your own installer, on your machine.

## Uninstalling

**AppImage:** delete it, then remove its data and menu entries:

```sh
rm -rf ~/.local/share/wine-uwp
rm -f ~/.local/share/applications/wine-uwp-shapr3d*.desktop
```

**Flatpak:**

```sh
flatpak uninstall --user --delete-data io.github.designgears.Shapr3DLinux
```

## Troubleshooting

**Shapr3D's window stays blank, or it closes right away.** Check that Vulkan works: `vulkaninfo --summary` should
list your GPU. After a kernel or graphics driver update, reboot before trying again. With the Flatpak on NVIDIA, also run `flatpak update`: Flatpak apps need
a driver extension matching your installed NVIDIA driver version.

**Signing in opens a second Shapr3D window, or nothing happens.** The browser hands the sign-in back through a
`shapr3d:` link. With the AppImage, open it again: that re-registers the menu entry and the link handler. Use only one of the AppImage and the Flatpak: whichever registered last receives
`shapr3d:` links (`xdg-mime query default x-scheme-handler/shapr3d` names it).

**The setup stopped halfway.** Start it again; it resumes where it stopped, including a partial download.

**Something else.** Logs are in `~/.local/share/wine-uwp/logs` (Flatpak:
`~/.var/app/io.github.designgears.Shapr3DLinux/data/wine-uwp/logs`). Please
[open an issue](https://github.com/designgears/shapr3d-linux/issues) with the log and what you were doing.

## How it works

Shapr3D for Windows is a packaged Windows Store (UWP) app, which plain Wine cannot run.
[wine-uwp](https://github.com/designgears/wine-uwp) is a patched Wine that can: it adds the app-package model,
composition, and the Windows Runtime pieces such apps need, and runs Microsoft's own UI frameworks on top. This
repository is the product around it: the setup app, the AppImage and the Flatpak.

## Building from source

```sh
git clone --recurse-submodules https://github.com/designgears/shapr3d-linux
cd shapr3d-linux
./release.sh 0.0.1-dev
```

`release.sh` builds the Flatpak and the AppImage from the pinned `wine-uwp` submodule into `out/<version>/`, with
checksums, and smoke-tests both: an empty setup on a private X display must reach Shapr3D's first screen. It needs:

- [flatpak-builder](https://flathub.org/apps/org.flatpak.Builder) with `org.freedesktop.Sdk//25.08` and its
  `mingw-w64` and `rust-stable` extensions. One build in that SDK makes both packages, which is also why the AppImage
  runs on older distributions (glibc 2.38).
- clang-cl, lld-link and the Windows SDK headers from [xwin](https://github.com/Jake-Shadle/xwin) in `~/xwin`,
  for wine-uwp's helper DLLs. They are only used to build, never shipped.
- For the smoke test: Xvfb, xdotool, ImageMagick, and `SMOKE_PACKAGE` (a Shapr3D `.appinstaller` or `.msixbundle`) plus
  `SMOKE_ISO` (a Windows 11 ISO) or `SMOKE_WINDOWS` (an already extracted tree). `SMOKE=0` skips it.

| | |
| --- | --- |
| `installer/` | the setup app, in Rust and [Slint](https://slint.dev) |
| `flatpak/` | the build in the freedesktop SDK (`build.sh`) and the Flatpak's manifest and metadata |
| `appimage/` | the AppImage, packed from that build (`build.sh`), and the smoke test |
| `release.sh` | a versioned, tested release |
| `build-dist.sh` | an unpackaged build for development on your own machine |
| `wine-uwp/` | the engine, as a submodule |

For development against a wine-uwp checkout beside this one, the scripts use `../wine-uwp` (or `WINE_UWP`) instead
of the submodule. Enable the commit hook once per clone with `git config core.hooksPath githooks`: it refuses
Microsoft's files and large binaries.
