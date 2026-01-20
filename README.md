# TempoVR

A VR rhythm game built with Godot Engine using OpenXR. Originally a game jam entry for Go Godot 2, now being developed into a full game.

Features:
- VR gameplay using OpenXR (works with Quest, SteamVR, and other OpenXR runtimes)
- WebXR support for browser-based VR
- Unique time-slowdown mechanic during gameplay
- Compatible with Beat Saber custom maps from [BeatSaver](https://beatsaver.com)

## Download

- **Nightly builds**: [GitHub Releases](https://github.com/guysoft/EnergySource/releases)
- **Stable version**: [itch.io](https://guysoft.itch.io/tempovr)

## Pre-shipped Songs

Official builds include the following songs (ExpertPlus difficulty):

| Song | Artist | Mapper | BeatSaver |
|------|--------|--------|-----------|
| Unity | TheFatRat | Timeweaver | [a908](https://beatsaver.com/maps/a908) |
| Monody (ft. Laura Brehm) | TheFatRat | Timeweaver | [a907](https://beatsaver.com/maps/a907) |

You can add more songs by downloading maps from [BeatSaver](https://beatsaver.com) and placing them in the `Levels` folder.

## Community

Join our [Discord](https://discord.gg/xkbAszgKcd) for support and discussion.

---

## Developer Setup

### Prerequisites

- [Godot 4.5+](https://godotengine.org/download) (standard version, not .NET)
- Python 3 (for level patching script)
- curl, unzip (for dependency download)

### Quick Start

1. Clone the repository:
   ```bash
   git clone https://github.com/guysoft/EnergySource.git
   cd EnergySource
   ```

2. Download dependencies and pre-shipped levels:
   ```bash
   ./get_deps.sh
   ```

3. Open the project in Godot:
   ```bash
   godot --path src --editor
   ```

4. Run `GameManager.tscn` to play

### Non-VR Development Mode

To run without a VR headset for debugging:

1. Open `src/scripts/GameVariables.gd`
2. Set `ENABLE_VR` to `false`

---

## Building

### Automated Builds (CI/CD)

The project uses GitHub Actions to automatically build for:
- **Windows** (release)
- **Linux** (release)
- **Android Quest** (debug APK)

Builds are triggered on:
- Push to `main`, `develop`, `ci-workflow`, or `workout` branches
- Pull requests to `main` or `workout`
- Git tags starting with `v` (creates a GitHub Release)

See [`.github/workflows/build-on-push.yml`](.github/workflows/build-on-push.yml) for details.

### Manual Export

1. Open the project in Godot
2. Go to **Project > Export**
3. Select a preset (Windows, Linux, or Android Quest)
4. Click **Export Project**

For Android Quest builds, you need:
- JDK 17
- Android SDK with build-tools 34.0.0 and NDK 23.2.8568313

---

## Known Issues

### Linux
For Linux builds, copy `libopenxr_loader.so.1` from your distribution to the game folder.

---

## Credits

**Developers:**
- Rainer Weston
- Guy Sheffer

**Pre-shipped Music:**
- TheFatRat - Unity, Monody (mapped by Timeweaver)

**Test Level:**
- jennissary (joey): [BeatSaver #19614](https://beatsaver.com/maps/19614)
