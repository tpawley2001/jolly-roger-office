# Jolly Roger Office

A pirate-themed, all-in-one office suite for Windows and Linux, from [Hillyard Tech](https://hillyard-tech.com/jolly-roger).

| App | For | Opens |
| --- | --- | --- |
| **Captain's Log** | documents | .docx, .docm, .dotx, .doc, .odt, .rtf, .md |
| **Plunder Ledger** | spreadsheets | .xlsx, .xlsm, .xls, .ods, .csv |
| **Broadside** | presentations | .pptx, .pptm, .ppsx, .potx |

The **Jolly Roger Office** launcher is the suite's start page, where you open the three apps.

> **Early preview.** This is a work in progress. We test it against thousands of real Word, Excel
> and PowerPoint files, and it isn't at Office parity yet. Expect rough edges, and keep a backup
> copy of anything important you open with it.

## Download

Get the latest build from [Releases](https://github.com/tpawley2001/jolly-roger-office/releases) or
from [hillyard-tech.com/jolly-roger](https://hillyard-tech.com/jolly-roger).

- **Windows 10/11 (64-bit):** `JollyRogerOffice-Setup-<version>.exe`. The installer is per-user
  and doesn't need admin rights. It adds the suite to "Open with" for Office and OpenDocument
  files, and it **doesn't** change your default apps. The installer isn't code-signed yet, so
  Windows SmartScreen may warn you: click **More info → Run anyway**.
- **Linux (x86_64):** `jolly-roger-office-<version>-linux-x86_64.tar.gz`. Unpack it and run
  `./install.sh` (add `--copy` to install into `~/.local/opt`, or `--uninstall` to remove it). No
  root needed.

`SHA256SUMS.txt` on each release lists the checksums.

## Source

The suite is four Rust programs. Each one is a fork of an
[ArtCraft](https://github.com/storytold) Crafting App, and our work is on the `pirate` branch:

| Program | Source (branch `pirate`) | Based on |
| --- | --- | --- |
| Jolly Roger Office launcher | [tpawley2001/craft-launcher](https://github.com/tpawley2001/craft-launcher/tree/pirate) | storytold/craft-launcher |
| Captain's Log | [tpawley2001/wordcraft](https://github.com/tpawley2001/wordcraft/tree/pirate) | storytold/wordcraft |
| Plunder Ledger | [tpawley2001/gridcraft](https://github.com/tpawley2001/gridcraft/tree/pirate) | storytold/gridcraft |
| Broadside | [tpawley2001/deckcraft](https://github.com/tpawley2001/deckcraft/tree/pirate) | storytold/deckcraft |

This repository holds the packaging: the Linux bundle, the Windows installer (NSIS), and the
release notes.

### Building

You need Rust (stable), `git`, `python3`, and on Linux the usual GUI and audio dev packages
(`libasound2-dev`, `libxkbcommon-dev`, `libwayland-dev`, `pkg-config`). The Windows installer is
cross-compiled on Linux and also needs `mingw-w64`, `nsis`, and Python's Pillow.

```sh
git clone https://github.com/tpawley2001/jolly-roger-office
cd jolly-roger-office
for r in craft-launcher wordcraft gridcraft deckcraft; do
  git clone --single-branch -b pirate https://github.com/tpawley2001/$r
done
bundle/build.sh            # Linux bundle   -> bundle/out/jolly-roger-office-<ver>-linux-x86_64.tar.gz
bundle/build-windows.sh    # Windows Setup  -> bundle/out/JollyRogerOffice-Setup-<ver>.exe
```

The comments at the top of each script list its options (build only some apps, build a working
tree instead of the committed branch, and so on).

## License

Jolly Roger Office is licensed under the [MIT License](LICENSE-MIT) or the
[Apache License 2.0](LICENSE-APACHE), at your option. That's the same terms as the ArtCraft
Crafting Apps it is based on. Each program's own repository keeps its full notices and
third-party attributions, and the installers ship them in a `licenses` folder.

Jolly Roger Office is not affiliated with or endorsed by ArtCraft or Microsoft. Word, Excel and
PowerPoint are trademarks of Microsoft Corporation. They are named here only to describe file
compatibility.
