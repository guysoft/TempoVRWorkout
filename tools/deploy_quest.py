#!/usr/bin/env python3
"""
Deploy TempoVR to Meta Quest 2
Exports the Godot project and pushes to connected Quest headset.
"""

import subprocess
import sys
import time
from pathlib import Path

try:
    from rich.console import Console
    from rich.theme import Theme
    from rich.panel import Panel
except ImportError:
    print("❌ Rich library not found. Install with: pip install rich")
    sys.exit(1)

try:
    import yaml
except ImportError:
    print("❌ PyYAML library not found. Install with: pip install pyyaml")
    sys.exit(1)

# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────

# Paths relative to this script
TOOLS_DIR = Path(__file__).parent
PROJECT_DIR = TOOLS_DIR.parent / "src"
CONFIG_FILE = TOOLS_DIR / "config.yaml"
CONFIG_EXAMPLE = TOOLS_DIR / "config.yaml.example"

# Load user config
def load_config() -> dict:
    """Load configuration from config.yaml."""
    if not CONFIG_FILE.exists():
        print(f"❌ Configuration file not found: {CONFIG_FILE}")
        print(f"   Copy {CONFIG_EXAMPLE.name} to {CONFIG_FILE.name} and customize it:")
        print(f"   cp {CONFIG_EXAMPLE} {CONFIG_FILE}")
        sys.exit(1)
    
    with open(CONFIG_FILE, 'r') as f:
        config = yaml.safe_load(f)
    
    if not config or 'godot_cmd' not in config:
        print(f"❌ Invalid config: 'godot_cmd' not found in {CONFIG_FILE}")
        sys.exit(1)
    
    return config

_config = load_config()

APK_PATH = PROJECT_DIR / "out" / "tempovr.apk"
EXPORT_PRESET = "Meta Quest 2"
PACKAGE_NAME = "com.tempovr.game"
GODOT_CMD = _config['godot_cmd']

# ─────────────────────────────────────────────────────────────────────────────
# Crush Theme
# ─────────────────────────────────────────────────────────────────────────────

CRUSH_THEME = Theme({
    # Status colors
    "success": "#12C78F",      # Guac
    "error": "#EB4268",        # Sriracha
    "warning": "#E8FE96",      # Zest
    "info": "#00A4FF",         # Malibu
    
    # UI colors
    "primary": "#6B50FF",      # Charple
    "secondary": "#FF60FF",    # Dolly
    "tertiary": "#68FFD6",     # Bok
    "accent": "#E8FE96",       # Zest
    
    # Text colors
    "muted": "#858392",        # Squid
    "subtle": "#605F6B",       # Oyster
    "highlight": "#F1EFEF",    # Salt
    
    # Content colors
    "coral": "#FF577D",        # Coral
    "julep": "#00FFB2",        # Julep
    "cumin": "#BF976F",        # Cumin
})

console = Console(theme=CRUSH_THEME)

# ─────────────────────────────────────────────────────────────────────────────
# Status Functions
# ─────────────────────────────────────────────────────────────────────────────

def success(msg: str) -> None:
    console.print(f"[success]✅[/success] {msg}")

def error(msg: str) -> None:
    console.print(f"[error]❌[/error] {msg}")

def warning(msg: str) -> None:
    console.print(f"[warning]⚠️[/warning] {msg}")

def info(msg: str) -> None:
    console.print(f"[info]💡[/info] {msg}")

def muted(msg: str) -> None:
    console.print(f"[muted]{msg}[/muted]")

def step_progress(current: int, total: int) -> str:
    """Generate visual progress indicator."""
    filled = "●" * current
    empty = "○" * (total - current)
    return f"[success]{filled}[/success][muted]{empty}[/muted]"

# ─────────────────────────────────────────────────────────────────────────────
# Command Execution
# ─────────────────────────────────────────────────────────────────────────────

def run_cmd(cmd: list[str], description: str, capture: bool = False) -> subprocess.CompletedProcess:
    """Run a command with nice output."""
    muted(f"  › {' '.join(cmd)}")
    try:
        result = subprocess.run(
            cmd,
            capture_output=capture,
            text=True,
            check=True
        )
        return result
    except subprocess.CalledProcessError as e:
        error(f"{description} failed with exit code {e.returncode}")
        if e.stderr:
            console.print(f"[error]{e.stderr}[/error]")
        raise

def check_command_exists(cmd: str) -> bool:
    """Check if a command exists in PATH."""
    try:
        subprocess.run(["which", cmd], capture_output=True, check=True)
        return True
    except subprocess.CalledProcessError:
        return False

# ─────────────────────────────────────────────────────────────────────────────
# Deploy Steps
# ─────────────────────────────────────────────────────────────────────────────

def check_prerequisites() -> bool:
    """Check that required tools are available."""
    console.print()
    console.print(Panel.fit(
        "🔍 [primary]Checking Prerequisites[/primary]",
        border_style="muted"
    ))
    
    all_ok = True
    
    # Check Godot
    if check_command_exists(GODOT_CMD):
        success(f"Godot found: [cumin]{GODOT_CMD}[/cumin]")
    else:
        error(f"Godot not found in PATH: [cumin]{GODOT_CMD}[/cumin]")
        all_ok = False
    
    # Check ADB
    if check_command_exists("adb"):
        success("ADB found")
    else:
        error("ADB not found in PATH")
        all_ok = False
    
    # Check project exists
    if PROJECT_DIR.exists():
        success(f"Project found: [cumin]{PROJECT_DIR}[/cumin]")
    else:
        error(f"Project not found: [cumin]{PROJECT_DIR}[/cumin]")
        all_ok = False
    
    # Check OpenXR Vendors plugin (required for VR)
    openxr_plugin = PROJECT_DIR / "addons" / "godotopenxrvendors"
    openxr_android_bin = openxr_plugin / ".bin" / "android" / "template_debug" / "arm64" / "libgodotopenxrvendors.so"
    if openxr_plugin.exists():
        if openxr_android_bin.exists():
            success(f"OpenXR Vendors plugin found with Android binaries")
        else:
            warning(f"OpenXR Vendors plugin found but Android binaries missing")
            info(f"Expected: [cumin]{openxr_android_bin}[/cumin]")
            info("VR mode may not work. Ensure OpenXR Vendors plugin is fully installed.")
            info("Download from: https://github.com/GodotVR/godot_openxr_vendors/releases")
    else:
        warning(f"OpenXR Vendors plugin not found: [cumin]{openxr_plugin}[/cumin]")
        info("VR mode will not work without this plugin.")
        info("Download from: https://github.com/GodotVR/godot_openxr_vendors/releases")
        all_ok = False
    
    return all_ok


def check_quest_connected() -> bool:
    """Check if a Quest device is connected via ADB."""
    console.print()
    console.print(Panel.fit(
        "🎮 [primary]Checking Quest Connection[/primary]",
        border_style="muted"
    ))
    
    try:
        result = subprocess.run(
            ["adb", "devices"],
            capture_output=True,
            text=True,
            check=True
        )
        
        lines = result.stdout.strip().split('\n')[1:]  # Skip header
        devices = [line for line in lines if line.strip() and 'device' in line]
        
        if devices:
            device_id = devices[0].split()[0]
            success(f"Quest connected: [info]{device_id}[/info]")
            return True
        else:
            error("No Quest device found")
            info("Make sure your Quest is connected via USB and USB debugging is enabled")
            return False
            
    except subprocess.CalledProcessError as e:
        error(f"Failed to check devices: {e}")
        return False


def export_project(release: bool = False) -> bool:
    """Export the Godot project to APK."""
    build_type = "Release" if release else "Debug"
    console.print()
    console.print(Panel.fit(
        f"📦 [primary]Exporting Project[/primary] › [info]Meta Quest 2[/info] ([warning]{build_type}[/warning])",
        border_style="muted"
    ))
    
    # Ensure output directory exists
    APK_PATH.parent.mkdir(parents=True, exist_ok=True)
    
    # Remove old APK if exists
    if APK_PATH.exists():
        APK_PATH.unlink()
        muted(f"  › Removed old APK")
    
    info(f"Exporting to: [cumin]{APK_PATH}[/cumin]")
    info(f"Using preset: [info]{EXPORT_PRESET}[/info]")
    console.print()
    
    start_time = time.time()
    
    try:
        # Run Godot export
        export_flag = "--export-release" if release else "--export-debug"
        cmd = [
            GODOT_CMD,
            "--headless",
            "--path", str(PROJECT_DIR),
            export_flag, EXPORT_PRESET,
            str(APK_PATH)
        ]
        
        muted(f"  › {' '.join(cmd)}")
        console.print()
        
        # Run with live output
        process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True
        )
        
        # Stream output
        for line in process.stdout:
            line = line.rstrip()
            if line:
                if "ERROR" in line.upper():
                    console.print(f"  [error]{line}[/error]")
                elif "WARNING" in line.upper():
                    console.print(f"  [warning]{line}[/warning]")
                else:
                    console.print(f"  [muted]{line}[/muted]")
        
        process.wait()
        
        elapsed = time.time() - start_time
        
        # Check if APK was created (Godot may crash on shutdown but still succeed)
        if not APK_PATH.exists():
            error(f"Export failed - APK was not created (exit code {process.returncode})")
            return False
        
        # Warn if Godot crashed but export succeeded
        if process.returncode != 0:
            warning(f"Godot exited with code {process.returncode} but APK was created")
        
        apk_size = APK_PATH.stat().st_size / (1024 * 1024)
        console.print()
        success(f"Export complete in [info]{elapsed:.1f}s[/info]")
        info(f"APK size: [julep]{apk_size:.1f} MB[/julep]")
        return True
        
    except Exception as e:
        error(f"Export failed: {e}")
        return False


def uninstall_app() -> bool:
    """Uninstall the app from Quest device."""
    console.print()
    console.print(Panel.fit(
        "🗑️  [primary]Uninstalling Existing App[/primary]",
        border_style="warning"
    ))
    
    warning(f"This will remove [info]{PACKAGE_NAME}[/info] and all its data!")
    console.print()
    
    try:
        cmd = ["adb", "uninstall", PACKAGE_NAME]
        muted(f"  › {' '.join(cmd)}")
        
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
        )
        
        if result.returncode != 0:
            # Check if app wasn't installed (that's OK)
            if "not found" in result.stderr.lower() or "does not exist" in result.stderr.lower():
                info("App not installed, nothing to uninstall")
                return True
            else:
                error(f"Uninstall failed")
                if result.stderr:
                    console.print(f"  [error]{result.stderr}[/error]")
                if result.stdout:
                    console.print(f"  [muted]{result.stdout}[/muted]")
                return False
        
        success("App uninstalled")
        return True
        
    except Exception as e:
        error(f"Uninstall failed: {e}")
        return False


def push_to_quest(force: bool = False) -> bool:
    """Push the APK to the Quest device."""
    console.print()
    console.print(Panel.fit(
        "📤 [primary]Pushing to Quest[/primary]",
        border_style="muted"
    ))
    
    if not APK_PATH.exists():
        error(f"APK not found: [cumin]{APK_PATH}[/cumin]")
        return False
    
    # Uninstall first if force flag is set
    if force:
        if not uninstall_app():
            return False
        console.print()
    
    info(f"Installing: [cumin]{APK_PATH.name}[/cumin]")
    console.print()
    
    start_time = time.time()
    
    try:
        cmd = ["adb", "install", "-r", "-g", str(APK_PATH)]
        muted(f"  › {' '.join(cmd)}")
        
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
        )
        
        elapsed = time.time() - start_time
        
        if result.returncode != 0:
            error(f"Install failed")
            if result.stderr:
                console.print(f"  [error]{result.stderr}[/error]")
            if result.stdout:
                console.print(f"  [muted]{result.stdout}[/muted]")
            
            # Check for signature mismatch error
            if "INSTALL_FAILED_UPDATE_INCOMPATIBLE" in result.stderr or "signatures do not match" in result.stderr:
                console.print()
                warning("Signature mismatch detected!")
                info("Use [info]--force[/info] flag to uninstall existing app first")
                info("Note: This will remove all saved data")
            
            return False
        
        console.print()
        success(f"Installed in [info]{elapsed:.1f}s[/info]")
        return True
        
    except Exception as e:
        error(f"Push failed: {e}")
        return False


def launch_app() -> bool:
    """Launch the app on the Quest."""
    console.print()
    console.print(Panel.fit(
        "🚀 [primary]Launching App[/primary]",
        border_style="muted"
    ))
    
    try:
        cmd = [
            "adb", "shell", "am", "start",
            "-n", f"{PACKAGE_NAME}/com.godot.game.GodotApp"
        ]
        muted(f"  › {' '.join(cmd)}")
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode == 0:
            success(f"Launched [info]{PACKAGE_NAME}[/info]")
            return True
        else:
            warning("App may have launched with warnings")
            if result.stderr:
                muted(f"  {result.stderr}")
            return True  # Often still works
            
    except Exception as e:
        error(f"Launch failed: {e}")
        return False


# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────

def main():
    import argparse
    
    parser = argparse.ArgumentParser(
        description="Deploy TempoVR to Meta Quest 2"
    )
    parser.add_argument(
        "--skip-export", "-s",
        action="store_true",
        help="Skip export, just push existing APK"
    )
    parser.add_argument(
        "--no-launch", "-n",
        action="store_true",
        help="Don't launch app after install"
    )
    parser.add_argument(
        "--export-only", "-e",
        action="store_true",
        help="Only export, don't push to device"
    )
    parser.add_argument(
        "--release", "-r",
        action="store_true",
        help="Export release build (requires keystore setup)"
    )
    parser.add_argument(
        "--force", "-f",
        action="store_true",
        help="Force install by uninstalling existing app first (removes saved data)"
    )
    
    args = parser.parse_args()
    
    # Banner
    console.print()
    console.print(Panel.fit(
        "🎮 [primary]TempoVR[/primary] › [info]Quest 2 Deployment[/info]",
        border_style="primary"
    ))
    
    steps = []
    if not args.skip_export:
        steps.append(("Export", lambda: export_project(release=args.release)))
    if not args.export_only:
        steps.append(("Push", lambda: push_to_quest(force=args.force)))
        if not args.no_launch:
            steps.append(("Launch", launch_app))
    
    # Prerequisites check
    if not check_prerequisites():
        console.print()
        error("Prerequisites not met")
        sys.exit(1)
    
    # Check Quest connection (if we need to push)
    if not args.export_only:
        if not check_quest_connected():
            sys.exit(1)
    
    # Execute steps
    total_steps = len(steps)
    
    for i, (name, func) in enumerate(steps, 1):
        progress = step_progress(i, total_steps)
        console.print()
        console.rule(
            f"[primary]⟦ {i}/{total_steps} ⟧[/primary] [info]{name}[/info]",
            style="muted"
        )
        
        if not func():
            console.print()
            console.print(Panel.fit(
                f"[error]❌ Deployment failed at step: {name}[/error]",
                border_style="error"
            ))
            sys.exit(1)
    
    # Success
    console.print()
    console.print(Panel.fit(
        "✅ [success]Deployment complete![/success] 🎉",
        border_style="success"
    ))
    console.print()


if __name__ == "__main__":
    main()

