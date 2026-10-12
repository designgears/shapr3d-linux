# Shapr3D for Linux

The Windows version of Shapr3D, packaged for Linux on [wine-uwp](../wine-uwp): a setup app, a Flatpak, an AppImage
and a Bottles runner. Nothing of Microsoft's or Shapr3D's is in this repository or in what it builds. The Windows
components come from Microsoft's own Windows 11 evaluation image, which the setup downloads on the user's machine,
and Shapr3D comes from the `.msixbundle` the user chooses.

The engine - our Wine source, `wineuwp`, the shims, and the runtime scripts (`harvest`, `new-prefix`, `install-app`,
the `wine-uwp` command) - is in the wine-uwp repository. Every build here reads a wine-uwp checkout: `WINE_UWP`, by
default `../wine-uwp` beside this one. Builds go to that checkout's `uwp-bin/` (its `UWP_BIN`), which is where
flatpak-builder keeps its cache.

## What the user sees

The installer (`installer/`, Rust + [Slint](https://slint.dev), styled after Shapr3D's own UI; screenshots in
`docs/screenshots/installer/`) walks through:

1. **Welcome**: the three steps.
2. **Windows components**: download from Microsoft (7.1 GB, resumable), or use an ISO already at hand. It checks
   free space, and deletes the image afterwards unless asked to keep it.
3. **Preparing**:
   - download and SHA-256 check;
   - extraction of about 2,700 files, plus the five framework packages Shapr3D declares;
   - the Wine prefix, component registration, and Microsoft's public symbols for the private addresses `wineuwp`
     looks up.

   Each step shows its state and progress (speed, time left), with the tools' output behind "Show details".
4. **Package**: the user picks Shapr3D's `.msixbundle` in their desktop's own file dialog (the portal). The
   installer shows the app's icon, version, publisher and whether every framework it needs is present.
5. **Installing**, then **ready**: Launch, and (outside the Flatpak) a menu entry plus the `shapr3d:` link handler,
   which is how the browser sign-in comes back to the running app.

`wine-uwp setup [--iso FILE] [PACKAGE]` pre-fills the choices; scripted tests use that instead of the dialog. Every
finished step leaves a marker, so a closed or failed setup resumes where it stopped.

The installer draws its own UI (Slint's OpenGL renderer, with software as a fallback), so it needs no GTK or Qt.
The theme is Shapr3D's measured palette: `#202020` window, `#2C2C2C` panels, `#383838` controls, and the `#6EA1FF`
accent with dark text on it.

## Building

```
(cd ../wine-uwp && ./build.sh)    # the shims and wineuwp-launch.exe (clang-cl, xwin SDK)
./build-dist.sh OUT               # a host tree: wine-uwp's packaging/build-dist.sh plus the installer
flatpak/build.sh --install        # Flatpak: Wine 11.17 + wine-uwp's wine/ and the installer, freedesktop 25.08 SDK
appimage/build.sh                 # $UWP_BIN/appimage/wine-uwp-x86_64.AppImage from that Flatpak build
bottles/make-runner.sh            # $UWP_BIN/bottles/wine-uwp-11.17.tar.xz from that Flatpak build
```

The Flatpak build needs `org.flatpak.Builder`, `org.freedesktop.Sdk//25.08` and its `mingw-w64` and
`rust-stable` extensions from Flathub (user installation). The installer's crates are fetched at build time, pinned
by `Cargo.lock`. Wine comes from the upstream tarball with wine-uwp's `wine/` laid over it and `configure`
regenerated.

The shims are built on the host (they need the Windows SDK headers) and go in as files. The runner and the AppImage
are both made from the Flatpak's `/app`, so they link against the freedesktop runtime rather than the host's newer
glibc. That lets the runner work inside Bottles' sandbox, and the AppImage run on distributions with glibc 2.38 or
newer. The AppImage (109 MB) bundles only what hosts do not reliably have: GnuTLS, libusb, Python's OpenSSL and the
like. Wine's media modules use the host's GStreamer and ffmpeg, if present, and URLs go back to the host's browser
with the host's own environment (`appimage/host-run`).

For Bottles, see wine-uwp's `packaging/README.md`.

## Keeping Microsoft's and Shapr3D's files out

`git config core.hooksPath githooks` once per clone: the pre-commit hook runs wine-uwp's `check-clean.sh`, which
refuses PE images, app packages and payload, Windows images and metadata, fonts not listed in `.clean-allow`, and
anything over 5 MB. The Inter fonts in `installer/ui/fonts` are listed there (SIL Open Font License).
