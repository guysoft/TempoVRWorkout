#!/usr/bin/env python3
"""
Push PowerBeatsVRLevels songs to Quest 2
Supports both local dev build (com.tempovr.game) and CI build (com.tempovr.ci)
"""

import subprocess
import sys
import argparse
from pathlib import Path

try:
    from rich.console import Console
    from rich.theme import Theme
    from rich.panel import Panel
except ImportError:
    print("❌ Rich library not found. Install with: pip install rich")
    sys.exit(1)

# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────

PROJECT_DIR = Path(__file__).parent.parent
POWERBEATSVR_LEVELS = PROJECT_DIR / "PowerBeatsVRLevels"

# Package names
PACKAGE_GAME = "com.tempovr.game"
PACKAGE_CI = "com.tempovr.ci"

# ─────────────────────────────────────────────────────────────────────────────
# Theme
# ─────────────────────────────────────────────────────────────────────────────

THEME = Theme({
    "success": "#12C78F",
    "error": "#EB4268",
    "warning": "#E8FE96",
    "info": "#00A4FF",
    "primary": "#6B50FF",
    "muted": "#858392",
})

console = Console(theme=THEME)

# ─────────────────────────────────────────────────────────────────────────────
# Helper Functions
# ─────────────────────────────────────────────────────────────────────────────

def success(msg: str) -> None:
    console.print(f"[success]✅[/success] {msg}")

def error(msg: str) -> None:
    console.print(f"[error]❌[/error] {msg}")

def info(msg: str) -> None:
    console.print(f"[info]💡[/info] {msg}")

def muted(msg: str) -> None:
    console.print(f"[muted]{msg}[/muted]")

def run_cmd(cmd: list[str], description: str) -> bool:
    """Run a command and return success status."""
    muted(f"  › {' '.join(cmd)}")
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            check=True
        )
        return True
    except subprocess.CalledProcessError as e:
        error(f"{description} failed")
        if e.stderr:
            console.print(f"  [error]{e.stderr}[/error]")
        return False

def check_quest_connected() -> bool:
    """Check if a Quest device is connected via ADB."""
    try:
        result = subprocess.run(
            ["adb", "devices"],
            capture_output=True,
            text=True,
            check=True
        )
        lines = result.stdout.strip().split('\n')[1:]
        devices = [line for line in lines if line.strip() and 'device' in line]
        return len(devices) > 0
    except subprocess.CalledProcessError:
        return False

# ─────────────────────────────────────────────────────────────────────────────
# Push Functions
# ─────────────────────────────────────────────────────────────────────────────

def push_songs(package_name: str) -> bool:
    """Push PowerBeatsVRLevels to Quest for specified package."""
    console.print()
    console.print(Panel.fit(
        f"📤 [primary]Pushing Songs to Quest[/primary] › [info]{package_name}[/info]",
        border_style="muted"
    ))
    
    # Check PowerBeatsVRLevels exists
    if not POWERBEATSVR_LEVELS.exists():
        error(f"PowerBeatsVRLevels directory not found: {POWERBEATSVR_LEVELS}")
        info(f"Expected location: {POWERBEATSVR_LEVELS}")
        return False
    
    # Check required subdirectories
    layouts_dir = POWERBEATSVR_LEVELS / "Layouts"
    music_dir = POWERBEATSVR_LEVELS / "music"
    playlists_file = POWERBEATSVR_LEVELS / "playlists.json"
    
    if not layouts_dir.exists():
        error(f"Layouts directory not found: {layouts_dir}")
        return False
    
    if not music_dir.exists():
        error(f"music directory not found: {music_dir}")
        return False
    
    if not playlists_file.exists():
        warning(f"playlists.json not found: {playlists_file}")
        info("Continuing without playlists.json...")
    
    # Base path on Quest
    quest_base_path = f"/storage/emulated/0/Android/data/{package_name}/files/PowerBeatsVRLevels"
    
    # Create directory structure
    info("Creating directory structure on Quest...")
    if not run_cmd(
        ["adb", "shell", "mkdir", "-p", quest_base_path],
        "Create directory structure"
    ):
        return False
    
    # Push Layouts folder
    info("Pushing Layouts folder...")
    if not run_cmd(
        ["adb", "push", str(layouts_dir), f"{quest_base_path}/"],
        "Push Layouts"
    ):
        return False
    
    # Push music folder
    info("Pushing music folder...")
    if not run_cmd(
        ["adb", "push", str(music_dir), f"{quest_base_path}/"],
        "Push music"
    ):
        return False
    
    # Push playlists.json (if exists)
    if playlists_file.exists():
        info("Pushing playlists.json...")
        if not run_cmd(
            ["adb", "push", str(playlists_file), quest_base_path],
            "Push playlists.json"
        ):
            return False
    
    success("All files pushed successfully!")
    return True

def verify_files(package_name: str) -> bool:
    """Verify files were pushed correctly."""
    console.print()
    console.print(Panel.fit(
        f"🔍 [primary]Verifying Files[/primary] › [info]{package_name}[/info]",
        border_style="muted"
    ))
    
    quest_base_path = f"/storage/emulated/0/Android/data/{package_name}/files/PowerBeatsVRLevels"
    
    # List directory
    info("Checking PowerBeatsVRLevels directory...")
    result = subprocess.run(
        ["adb", "shell", "ls", "-la", quest_base_path],
        capture_output=True,
        text=True
    )
    
    if result.returncode == 0:
        console.print()
        muted(result.stdout)
        
        # Count files
        layouts_result = subprocess.run(
            ["adb", "shell", "ls", f"{quest_base_path}/Layouts", "|", "wc", "-l"],
            capture_output=True,
            text=True
        )
        music_result = subprocess.run(
            ["adb", "shell", "ls", f"{quest_base_path}/music", "|", "wc", "-l"],
            capture_output=True,
            text=True
        )
        
        if layouts_result.returncode == 0:
            layout_count = layouts_result.stdout.strip()
            info(f"Layout files: {layout_count}")
        
        if music_result.returncode == 0:
            music_count = music_result.stdout.strip()
            info(f"Music files: {music_count}")
        
        success("Verification complete!")
        return True
    else:
        error("Failed to verify files")
        return False

# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Push PowerBeatsVRLevels songs to Quest 2",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Push to local dev build (com.tempovr.game)
  %(prog)s --game

  # Push to CI build (com.tempovr.ci)
  %(prog)s --ci

  # Push to both
  %(prog)s --game --ci

  # Verify files after pushing
  %(prog)s --game --verify
        """
    )
    
    parser.add_argument(
        "--game", "-g",
        action="store_true",
        help="Push to local dev build (com.tempovr.game)"
    )
    parser.add_argument(
        "--ci", "-c",
        action="store_true",
        help="Push to CI build (com.tempovr.ci)"
    )
    parser.add_argument(
        "--verify", "-v",
        action="store_true",
        help="Verify files after pushing"
    )
    
    args = parser.parse_args()
    
    # Banner
    console.print()
    console.print(Panel.fit(
        "🎵 [primary]TempoVR[/primary] › [info]Push Songs to Quest[/info]",
        border_style="primary"
    ))
    
    # Check if at least one target is specified
    if not args.game and not args.ci:
        error("Must specify at least one target: --game or --ci")
        parser.print_help()
        sys.exit(1)
    
    # Check Quest connection
    if not check_quest_connected():
        error("No Quest device found")
        info("Make sure your Quest is connected via USB and USB debugging is enabled")
        sys.exit(1)
    
    success("Quest device connected")
    
    # Push to specified targets
    targets = []
    if args.game:
        targets.append(("Local Dev", PACKAGE_GAME))
    if args.ci:
        targets.append(("CI Build", PACKAGE_CI))
    
    all_success = True
    
    for target_name, package_name in targets:
        console.print()
        console.rule(f"[primary]{target_name}[/primary] ({package_name})", style="muted")
        
        if not push_songs(package_name):
            all_success = False
            continue
        
        if args.verify:
            if not verify_files(package_name):
                all_success = False
    
    # Summary
    console.print()
    if all_success:
        console.print(Panel.fit(
            "✅ [success]All songs pushed successfully![/success] 🎉",
            border_style="success"
        ))
    else:
        console.print(Panel.fit(
            "[error]❌ Some operations failed[/error]",
            border_style="error"
        ))
        sys.exit(1)
    
    console.print()

if __name__ == "__main__":
    main()

