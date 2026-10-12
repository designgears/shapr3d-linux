# Shapr3D for Linux

The Windows version of Shapr3D on Linux, as one AppImage, built on [wine-uwp](https://github.com/designgears/wine-uwp).
The AppImage carries Wine with our changes, wine-uwp's runtime and shims, and the setup app. Nothing of Microsoft's
or Shapr3D's is in this repository or in the AppImage: the setup downloads Microsoft's own Windows 11 evaluation
image on the user's machine and takes the Windows components from it, and Shapr3D comes from the `.msixbundle` the
user chooses.

wine-uwp is a submodule (`wine-uwp/`), pinned to the commit a release is built from. For development, every script
here reads `WINE_UWP`, by default the `../wine-uwp` checkout beside this one; `release.sh` always uses the submodule.

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
5. **Installing**, then **ready**: Launch, and a menu entry plus the `shapr3d:` link handler,
   which is how the browser sign-in comes back to the running app.

`wine-uwp setup [--iso FILE] [PACKAGE]` pre-fills the choices; scripted tests use that instead of the dialog. Every
finished step leaves a marker, so a closed or failed setup resumes where it stopped.

The installer draws its own UI (Slint's OpenGL renderer, with software as a fallback), so it needs no GTK or Qt.
The theme is Shapr3D's measured palette: `#202020` window, `#2C2C2C` panels, `#383838` controls, and the `#6EA1FF`
accent with dark text on it.

## Building

```
./release.sh VERSION                # the release: checks, shims, AppImage, SHA256SUMS, smoke test, all in out/VERSION
appimage/build.sh [OUTDIR]          # just an AppImage, from WINE_UWP (shims built first: wine-uwp's build.sh)
./build-dist.sh OUT                 # a host tree for development: wine-uwp's packaging/build-dist.sh plus the installer
appimage/smoke.sh APPIMAGE OUTDIR   # set an AppImage up from nothing on a private Xvfb and require Shapr3D's first screen
```

`release.sh` refuses uncommitted changes in either repository, a wine-uwp commit that is not on GitHub, and anything
`check-clean.sh` rejects. It names the file `shapr3d-linux-VERSION-x86_64.AppImage` and embeds AppImageUpdate
information pointing at this repository's GitHub releases, so `.zsync` delta updates work. The smoke test needs
`SMOKE_PACKAGE` (a Shapr3D `.msixbundle`) and `SMOKE_ISO` (a Windows 11 ISO) or `SMOKE_WINDOWS` (an already harvested
tree); `SMOKE=0` skips it.

The AppImage is built in two steps by `appimage/build.sh`. First Wine (the upstream 11.17 tarball with wine-uwp's
`wine/` laid over it and `configure` regenerated), 7-Zip, the installer and wine-uwp's runtime are built with
flatpak-builder in the freedesktop 25.08 SDK (`appimage/build-env.yml`). Nothing is exported or installed as a
Flatpak; the SDK is only there so that everything links against that runtime's glibc (2.38) rather than the build
machine's newer one. Then the result becomes the AppDir, with the runtime's Python and the few libraries hosts do not
reliably have (GnuTLS, libusb, Python's OpenSSL). It runs on Ubuntu 24.04, Debian 13, Fedora 39 and newer, and is
about 109 MB. Wine's media modules use the host's GStreamer and ffmpeg, if present, and links go back to the host's
browser with the host's own environment (`appimage/host-run`).

Build machine: `org.flatpak.Builder`, `org.freedesktop.Sdk//25.08` and its `mingw-w64` and `rust-stable` extensions
from Flathub (user installation); clang-cl, lld-link and the [xwin](https://github.com/Jake-Shadle/xwin) SDK in
`~/xwin` for the shims (build-time headers only, never shipped); Xvfb, xdotool and ImageMagick for the smoke test.
The installer's crates are fetched at build time, pinned by `Cargo.lock`.

## Keeping Microsoft's and Shapr3D's files out

`git config core.hooksPath githooks` once per clone: the pre-commit hook runs wine-uwp's `check-clean.sh`, which
refuses PE images, app packages and payload, Windows images and metadata, fonts not listed in `.clean-allow`, and
anything over 5 MB. The Inter fonts in `installer/ui/fonts` are listed there (SIL Open Font License).
