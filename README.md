# TempoVRWorkout

A VR rhythm workout game built with Godot Engine using OpenXR. Play Beat Saber and PowerBeatsVR maps on Quest, SteamVR, and other OpenXR runtimes.

## Features

- **VR gameplay** using OpenXR (Quest native, SteamVR, and other runtimes)
- **Workout** This game is intended to make you workouy, mechanics based on PowerBeatsVR ones. You hit balls, and not slash them like in beatsaber.
- **Beat Saber compatibility** - plays custom maps from [BeatSaver](https://beatsaver.com)
- **PowerBeatsVR map format** - converts and plays PowerBeatsVR levels
- **Offline-first** - no internet required after install
- **Pre-shipped songs** - Unity and Monody included in official builds
- **Loads PowerBeatsVR playlists** - Supports loading of a playlist in the format used in PowerBeatsVR.

## Download

Official builds are published to [GitHub Releases](https://github.com/guysoft/TempoVRWorkout/releases).

### Windows

1. Download `Windows.zip` from the latest release
2. Extract to a folder
3. Run `TempoVR.exe`

### Linux

1. Download `Linux.zip` from the latest release
2. Extract and run the executable
3. **Note**: Copy `libopenxr_loader.so.1` from your distribution to the game folder if needed

### Meta Quest

1. Download `Android-Quest.zip` from the latest release
2. Extract the APK
3. Sideload via ADB: `adb install -r TempoVR.apk` (or use Quest's file manager)

## Pre-shipped Songs

Official builds include the following songs (ExpertPlus difficulty):

| Song | Artist | Mapper | BeatSaver |
|------|--------|--------|-----------|
| Unity | TheFatRat | Timeweaver | [a908](https://beatsaver.com/maps/a908) |
| Monody (ft. Laura Brehm) | TheFatRat | Timeweaver | [a907](https://beatsaver.com/maps/a907) |

You can add more songs by downloading maps from [BeatSaver](https://beatsaver.com) and placing them in the `Levels` folder next to the executable.

## Creating a Release

To publish a new version:

```bash
git tag v1.0.0
git push origin v1.0.0
```

CI will build for all platforms and attach the artifacts to the GitHub Release.

## Community

Join our [Discord](https://discord.gg/xkbAszgKcd) for support and discussion.

---

## Developer Setup

### Prerequisites

- [Godot 4.6+](https://godotengine.org/download) (standard version, not .NET)
- Python 3 (for level patching script)
- curl, unzip (for dependency download)

### Quick Start

1. Clone the repository:
   ```bash
   git clone https://github.com/guysoft/TempoVRWorkout.git
   cd TempoVRWorkout
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
- Git tags starting with `v` (creates a GitHub Release with all platform artifacts)

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
- jennissary (joey): [BeatSaver #19614](https://beatsaver.com/maps/19614)
