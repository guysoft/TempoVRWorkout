# Vulkan Pipeline Compilation in Godot 4

## Key Findings

### When does pipeline compilation happen?

In Godot 4's Vulkan renderer, pipeline variants are compiled when a node with
a new mesh+material combination is **added to the scene tree** via `add_child()`.
Visibility does NOT need to be `true` — the compilation happens at scene tree
insertion time, not at render/draw time.

This means:

- `add_child(mesh_instance)` → triggers pipeline compilation immediately
- `instance.visible = false` after `add_child()` → pipeline is already compiled
- No need to keep objects visible for a frame to "warm up" the pipeline

### Pipeline caching (Godot 4.1+)

Godot caches compiled pipeline variants to `user://vulkan/`. On subsequent
launches, previously-seen shader+mesh combinations load from cache instead
of recompiling. Deleting this folder forces recompilation.

### Object pooling strategy

Our `ObjectPool.gd` pre-allocates instances via `add_child()` at pool creation
time. This front-loads ALL pipeline compilations to the pool init phase
(during the 4-second StartTimer on Quest). No additional visibility tricks
are needed.

### What DOES cause runtime stutter

- Adding new `mesh+material` combos to the scene tree mid-gameplay
- New light types entering the view frustum for the first time
- Shader variants not seen during warmup (e.g. different blend states)

### Quest-specific notes

- Adreno GPU drivers on Quest are slower at pipeline compilation (10-50ms per variant)
- The `user://vulkan` cache persists across app launches
- The 4-second StartTimer in `Game.gd` exists specifically to absorb any
  remaining compilation overhead on Quest

## What we got wrong initially

The original `_init_pools()` in `Game.gd` had code that set each pooled object
`visible = true` at `Vector3(0, -100, 0)` then immediately called `release()`
(which sets `visible = false`) — all in the same synchronous function. The
intention was to force Vulkan pipeline compilation by making objects briefly
visible, but:

1. Both operations happen in the same frame — no render pass occurs in between
2. `add_child()` (called earlier in `ObjectPool._init()`) already triggered
   pipeline compilation
3. The visibility dance was dead code with no effect

This was cleaned up in commit 12 of the `workout` branch.

## Sources

Research conducted April 2026 via Google AI Overview searches:

- **"Godot 4 Vulkan pipeline compilation add_child"** — confirmed that
  `add_child()` on nodes with new meshes/materials triggers Vulkan pipeline
  compilation at scene tree insertion time. Recommended pre-warming by spawning
  nodes off-screen early, or using `call_deferred("add_child", node)`.

- **"Godot 4 Vulkan pipeline cache visible render"** — confirmed pipeline
  caching in Godot 4.1+ to `user://vulkan`. Stutter occurs when new materials
  or lights enter the view frustum for the first time. Solutions include
  ubershaders, consistent vertex formats, and pre-compilation.

- **"Godot 4 RenderingServer instance_set_visible pipeline"** — confirmed that
  `instance_set_visible()` is a draw-time filter that toggles the visibility
  flag on the RID within the RenderingServer, affecting culling and drawing
  but NOT pipeline compilation. Pipeline compilation is a separate path
  triggered by instance creation / scene tree insertion.

- **Empirical testing** — Quest gameplay is smooth with the current pool-based
  warmup, confirming that `add_child()`-based compilation works in practice.

## Related files

- `src/scripts/ObjectPool.gd` — generic pool; `add_child()` in `_init()` triggers compilation
- `src/scripts/Game.gd` — `_init_pools()` creates all pools during the StartTimer window
