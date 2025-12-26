## Mutanic Reign — Copilot / AI Agent Hints

These short instructions help an AI agent be productive in this Godot-based game repo.

1) Big picture
- Project is a Godot 4.x game (project.godot uses features `"4.5", "Forward Plus"`).
- Two main gameplay verticals: overworld (top-down) and combat (first-person/battle scenes).
- Key entry points: `overworld.tscn`, `Battle.tscn` and `run/main_scene` configured in `project.godot`.

2) Singletons / architecture
- Global state and managers are autoloaded (see `[autoload]` in `project.godot`). Important names:
  - `GameState`, `Timekeeper`, `SceneLoader`, `ProgressionManager`, `CombatManager` (bound to `combat.gd`), `SaveManager`, `TroopDatabase`, `Skills`.
- When adding global behavior, register it as an autoload and use `res://singletons` or `Autoloads/` as appropriate.

3) Data and resource patterns
- Domain data is stored as Godot resources (e.g., `data/SkillDatabase.tres`) and loaded via `preload("res://...")` (see `Autoloads/Skills.gd`).
- Validation at startup is common (e.g., `database.validate()` and `push_error(...)`). Preserve that pattern when adding new resources.

4) Code & naming conventions
- GDScript with type hints is used widely (e.g., `func _ready() -> void`). Keep type annotations.
- Files are PascalCase for scenes and scripts (e.g., `AloeGarden.gd` / `AloeGarden.tscn`). Resource ids use interned StringNames (e.g., `&"quality_tools"`).
- Pair scene + script: many scene scripts exist alongside `.tscn` files in the same directory (Buildings/, Actors/, UI/). Edit both when changing behavior.

5) Tests & debugging
- Tests live under `tests/` as GDScript nodes (example: `tests/test_save_load.gd`). They are not a CI harness — attach the script to a small test scene and run it in the Godot editor.
- Common debug patterns: `print()` for console output, `push_error()` for runtime validation failures, and `await get_tree().process_frame` to let singletons initialize.

6) Search examples to locate behavior
- Look for usages of autoload names to find flows: `ProgressionManager.register_character`, `GameState.save_game("user://...")`, `Skills.get_skill(...)`, `CombatManager` (maps to `combat.gd`).
- To find domain data, search for `preload("res://data/SkillDatabase.tres")` or `.tres` resources in `data/`.

7) Minimal developer workflow notes
- Open the project with Godot 4.x editor (Project -> Open). Play tests or scenes from the editor.
- Quick test run (if Godot is on PATH) — open project editor from shell (Windows PowerShell):
  ```powershell
  godot --path . -e   # open editor in current repo (requires godot in PATH)
  ```
  If Godot is not in PATH, use the platform-specific Godot executable and pass `--path <repo>`.

8) What the AI should NOT assume
- There is no automated, repo-level unit-test CI harness. Tests under `tests/` are manual scene-run tests.
- Avoid changing autoload names or `project.godot` entries without confirming expected scene/script UIDs.

If anything here is unclear or you'd like me to expand examples (e.g., list common search queries or scaffold a test scene), tell me which area to expand.
