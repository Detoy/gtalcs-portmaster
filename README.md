# GTA: Liberty City Stories — PortMaster

![Platform](https://img.shields.io/badge/platform-PortMaster-6f42c1)
![Architecture](https://img.shields.io/badge/architecture-AArch64-1f6feb)
![Game files](https://img.shields.io/badge/game%20files-not%20included-success)

An unofficial, community-tested PortMaster compatibility port of the Android
release of **Grand Theft Auto: Liberty City Stories** for AArch64 handhelds.

The port includes the compatibility runtime and installer only. You must supply
files from your own legally purchased Android copy.

## What works

- Full interactive gameplay with sound effects and radio
- Autosave and manual saves across restarts
- PlayStation-position face-button layout
- Tested first mission with smooth performance
- Automatic extraction of user-supplied Android game files

## Install

1. Download `gtalcs.zip` from [Releases](../../releases/latest).
2. Install the ZIP through PortMaster.
3. Copy these files from your legitimate Android **2.4.379 ARM64** installation
   into `roms/ports/gtalcs/gamedata/`:
   - `base.apk`
   - `split_config.arm64_v8a.apk`
   - `split_data_main.apk`
4. Launch the game. The first start verifies and extracts the required data.

A complete APKS, APKM or XAPK bundle containing those splits is also accepted.
Source archives are retained.

### Optional desktop extractor

If the APK files are already on your computer, you can prepare the SD card
before launching:

```bash
./extract_lcs.sh /path/to/apk-files \
  /path/to/SD/roms/ports/gtalcs/gamefiles
```

### Radio music from a rooted phone

Run this on a computer with Android platform tools installed and the rooted
phone connected:

```bash
LCS_CONFIRM_OWNERSHIP=yes \
  ./extract_music_from_rooted_android.sh \
  /path/to/SD/roms/ports/gtalcs/gamedata
```

Launch the port again after extraction. Never upload or redistribute
`data_music.wad`.

## Controls

The physical buttons follow PlayStation positions:

| Handheld | PlayStation | Main use |
|---|---|---|
| B | Cross | Sprint, accelerate, skip |
| A | Circle | Attack, fire |
| Y | Square | Jump |
| X | Triangle | Enter or exit vehicle |

Press **Start + Back/Select** to leave the game.

## Support

Open a [bug report](../../issues/new?template=bug_report.yml) with:

- exact handheld model and RAM;
- firmware/CFW name and version;
- clear reproduction steps; and
- `roms/ports/gtalcs/logs/launcher.log`.

Do **not** upload APKs, WADs, shared libraries, saves, recovery phrases or
wallet private keys. R36-family clones vary substantially, so exact hardware
and firmware details matter.

## Support the project

If this port was useful and you would like to leave a tip:

- **Bitcoin (BTC):** `bc1qvysq3csh5nzpspg6p6f0zx6572sxjxnp5sqnyd`
- **Solana (SOL):** `BM4CMnt3QYJaa9P6578D1PXVXgQRAmfTzw3ZoiCb66wF`
- **ETH / USDT:** `0x4873931867af49E291290E0674404d3B0161Dcf1`
  — Ethereum network/ERC-20 only

Always verify the complete address and network before sending.

## Legal

This project is not affiliated with or endorsed by Rockstar Games, Take-Two
Interactive, PortMaster or their affiliates. Grand Theft Auto and related
names, trademarks, software and assets belong to their respective owners.
No Rockstar game files are included or hosted here.

The helpers are intended only for files from a user's own legally obtained
installation.

## License

The original software and documentation in this repository are available
under the [MIT License](LICENSE). The licence does not grant rights to
Rockstar Games, Take-Two Interactive, their trademarks, or any third-party
game files and assets.
