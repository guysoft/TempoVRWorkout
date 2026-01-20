#!/usr/bin/env python3
"""
Patch BeatSaver level info.dat to only include ExpertPlus difficulty.
Used by CI/CD and get_deps.sh to prepare pre-shipped levels.
"""
import json
import sys


def patch_info(path):
    with open(path, 'r') as f:
        info = json.load(f)
    
    # Fix song filename (BeatSaver uses .egg, we rename to .ogg)
    info['_songFilename'] = 'song.ogg'
    
    # Keep only ExpertPlus difficulty
    for beatmap_set in info.get('_difficultyBeatmapSets', []):
        beatmap_set['_difficultyBeatmaps'] = [
            d for d in beatmap_set['_difficultyBeatmaps']
            if d['_difficulty'] == 'ExpertPlus'
        ]
    
    with open(path, 'w') as f:
        json.dump(info, f, indent=2)
    
    print(f"Patched {path} to ExpertPlus only")


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: patch_level_info.py <info.dat path>")
        sys.exit(1)
    patch_info(sys.argv[1])

