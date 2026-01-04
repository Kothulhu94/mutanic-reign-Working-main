# Unfinished Tasks & Technical Debt

This document outlines identified areas of the codebase that are marked as unfinished, deprecated, or contain placeholder logic.

## 1. Core Systems & Logic Gaps

### Character Progression (`Characters/CharacterProgression.gd`)
*   **XP Distribution (placeholder)**: The `_distribute_attribute_xp` function is currently a placeholder.
    *   **Snippet**: `# Placeholder: distribute to Might and Guile` / `# Phase 2: lookup skill's domain...`
    *   **Task**: Implement the full "Phase 2" logic which looks up a skill's domain to distribute XP to the correct attributes (e.g. Strength/Intellect) rather than just Might/Guile.

### Map & Navigation (`scripts/MapManager.gd`, `Actors/CaravanNavigator.gd`)
*   **Hub Founding Logic**: Logic for dynamically founding new Hubs is missing.
    *   **Task**: Implement `unregister_grid_source` in `MapManager` to handle Hub destruction (cleanup of `active_grids`).
    *   **Task**: Ensure new Hub instances register themselves with `MapManager` (currently handled in `_ready`, which is good) and verify placement logic.
*   **Abstract Navigation Fallback**: `CaravanNavigator.gd` assumes that if a grid path fails but we are in-bounds, we should fall back to Abstract (linear) movement.
    *   **Snippet**: `# If path failed but we are in bounds... Fallback to abstract?`
    *   **Task**: This logic might cause caravans to walk through walls if the pathfinding fails for valid reasons (unreachable). Needs robustness testing.
    *   **New Consideration**: Confirm logic properly distinguishes between "Blocked" (Wait) and "Unreachable/Void" (Fly).

## 2. Unused & Deprecated Code

### Unused Files
*   **`Hub/_Unusedv0.1Hub.gd`**: This file is explicitly named "Unused". It contains older logic for servos/consumption.
    *   **Recommendation**: Delete if no longer needed for reference to keep the repo clean.

### Empty / Placeholder Implementations
*   **`Buildings/Building.gd`**: `apply_state` is empty (`pass`).
*   **`Characters/CharacterProgression.gd`**: Signal handlers `_on_attribute_leveled` and `_on_skill_ranked_up` are empty.
*   **`overworld.gd`**: `_await_nav_ready` is marked `# Deprecated`.


