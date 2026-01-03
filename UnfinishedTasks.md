# Unfinished Tasks & Technical Debt

This document outlines identified areas of the codebase that are marked as unfinished, deprecated, or contain placeholder logic.

## 1. Core Systems & Logic Gaps

### Character Progression (`Characters/CharacterProgression.gd`)
*   **XP Distribution (placeholder)**: The `_distribute_attribute_xp` function is currently a placeholder.
    *   **Snippet**: `# Placeholder: distribute to Might and Guile` / `# Phase 2: lookup skill's domain...`
    *   **Task**: Implement the full "Phase 2" logic which looks up a skill's domain to distribute XP to the correct attributes (e.g. Strength/Intellect) rather than just Might/Guile.
*   **Dictionary Loading (Fragility)**: The `from_dict` method cannot easily reconstruct a `Skill` resource from a dictionary alone.
    *   **Snippet**: `# Cannot reconstruct full Skill resource from dict alone easily... Need valid base resource first.`
    *   **Task**: Implement a robust Skill Database lookup to fetch the base resource using the ID before applying the saved data.

### Map & Navigation (`scripts/MapManager.gd`, `Actors/CaravanNavigator.gd`)
*   **Dynamic Grid Updates**: `MapManager.gd` contains a `pass` block in `_process` for updating registered grids other than the camera.
    *   **Snippet**: `# (For static hubs, we rely on them calling register, but if they moved we'd need loop.)`
    *   **Task**: Verify if moving Hubs/Grids are a requirements. If so, implement the update loop.
*   **Abstract Navigation Fallback**: `CaravanNavigator.gd` assumes that if a grid path fails but we are in-bounds, we should fall back to Abstract (linear) movement.
    *   **Snippet**: `# If path failed but we are in bounds... Fallback to abstract?`
    *   **Task**: This logic might cause caravans to walk through walls if the pathfinding fails for valid reasons (unreachable). Needs robustness testing.
*   **Navigation Layers**: `CaravanNavigator.gd` ignores navigation layers.
    *   **Snippet**: `# Grid pathfinding doesn't strictly use layers in this simple implementation`

## 2. Structural Hacks & Workarounds

### Overworld (`overworld.gd`)
*   ~~**Bus Scaling Fix**: There is explicit logic to handle the "6x scaling" issue when the Bus is placed inside `MapScenery`.~~
    *   **Snippet**: `# Fix Scaling: If user put Bus in MapScenery (6x), it will be huge. We must reparent it to Root...`
    *   **Task**: This indicates a scene hierarchy mismatch. Ideally, the Bus should handle its own scaling or the `MapScenery` shouldn't scale its children this way.
*   **MapManager Injection**: The code hunts for `MapManager` in multiple locations (`MapScenery/MapManager` and root `MapManager`).
    *   **Snippet**: `# Fallback checking root`
    *   **Task**: Standardize the location of `MapManager`.

## 3. Unused & Deprecated Code

### Unused Files
*   **`Hub/_Unusedv0.1Hub.gd`**: This file is explicitly named "Unused". It contains older logic for servos/consumption.
    *   **Recommendation**: Delete if no longer needed for reference to keep the repo clean.

### Empty / Placeholder Implementations
*   **`Buildings/Building.gd`**: `apply_state` is empty (`pass`).
*   **`Characters/CharacterProgression.gd`**: Signal handlers `_on_attribute_leveled` and `_on_skill_ranked_up` are empty.
*   **`overworld.gd`**: `_await_nav_ready` is marked `# Deprecated`.

## 4. Debugging Leftovers

### `scripts/MapManager.gd`
*   **Unused Variables**: `_unhandled_input` calculates `_type_name`, `_cost`, `_is_astar_solid` but never uses them because the print statement is commented out.
    *   **Snippet**: `# print("Terrain Click: ", ...)`
    *   **Task**: Uncomment the debug print or remove the calculation logic.

### `Characters/CharacterProgression.gd`
*   **Test Code**: `_test_progression` is commented out.
