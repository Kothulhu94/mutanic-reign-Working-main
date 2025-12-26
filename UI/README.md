# Hub Menu System

This system provides a popup UI for hub interactions, including a main menu and market interface that pauses the game during use.

## Features

1. **First-time popup**: When the player Bus enters a hub area for the first time, a menu automatically appears
2. **Click interaction**: After the first visit, the menu only appears when clicking directly on the hub
3. **Game pause**: The entire game (time, movement, input) pauses when menus are open
4. **Market access**: Players can view hub inventory and prices through the market interface

## Setup Instructions

### 1. Add UI Instances to Your Scene

In your main scene (e.g., `overworld.tscn`):

1. Add a `CanvasLayer` node for UI (to ensure it renders on top)
2. Add `HubMenuUI` instance as a child of the CanvasLayer
3. Add `MarketUI` instance as a child of the CanvasLayer

Example hierarchy:
```
Overworld (Node2D)
├── Hub (Node2D)
│   └── ClickAndFade (Area2D)
├── Bus (CharacterBody2D)
├── UILayer (CanvasLayer)
│   ├── HubMenuUI (Control)
│   └── MarketUI (Control)
```

### 2. Connect UI to Hubs

For each Hub in your scene:

1. Select the Hub node
2. In the Inspector, find the exported properties:
   - `Hub Menu Ui`: Drag and drop the HubMenuUI instance
   - `Market Ui`: Drag and drop the MarketUI instance

This connects the UI to each hub so they can display the menus.

### 3. Verify Timekeeper Autoload

Ensure Timekeeper is configured as an autoload singleton:

1. Go to **Project → Project Settings → Autoload**
2. Verify `Timekeeper` is listed with path: `res://singletons/Timekeeper.gd`
3. Verify the node path is: `/root/Timekeeper`

## How It Works

### Flow Diagram

```
Bus enters Hub ClickAndFade area
         ↓
    First visit?
    ├── YES → Show HubMenuUI automatically
    │         (Pause game, show menu)
    │         Player can:
    │         - Enter Market → Show MarketUI
    │         - Leave → Resume game
    │
    └── NO → Allow pass-through
              Player can still click hub directly
              to show menu
```

### Game Pause Mechanism

When any UI menu opens:

1. `HubMenuUI.open_menu()` or `MarketUI.open_market()` calls `Timekeeper.pause()`
2. Timekeeper sets `running = false` and emits `paused` signal
3. All systems listen to the `paused` signal:
   - **Bus**: Stops movement (`_is_paused = true`)
   - **Overworld**: Ignores mouse input (`_is_paused = true`)
   - **Hub economy**: Stops ticking (Timekeeper no longer emits tick)

When UI closes:

1. `close_menu()` or `close_market()` calls `Timekeeper.resume()`
2. Timekeeper sets `running = true` and emits `resumed` signal
3. All systems resume normal operation

### Hub Menu Options

Currently implemented:
- **Enter Market**: Opens the MarketUI to view hub inventory

Future options can be added to `HubMenuUI.tscn`:
- Trade goods
- Recruit units
- Accept quests
- View hub status
- etc.

## Code Reference

### Key Files

| File | Purpose |
|------|---------|
| `UI/HubMenuUI.gd` | Main hub menu controller |
| `UI/HubMenuUI.tscn` | Main hub menu scene |
| `UI/MarketUI.gd` | Market interface controller |
| `UI/MarketUI.tscn` | Market interface scene |
| `Hub/Hub.gd` | Hub logic with menu management (lines 244-285) |
| `Hub/ClickAndFade.gd` | Bus detection and click handling |
| `Actors/bus.gd` | Bus movement with pause support |
| `singletons/Timekeeper.gd` | Game time with pause/resume |
| `overworld.gd` | Input handling with pause support |

### Signals

**Timekeeper**:
- `paused()` - Emitted when game pauses
- `resumed()` - Emitted when game resumes

**HubMenuUI**:
- `menu_closed()` - Emitted when menu is closed
- `market_opened()` - Emitted when player selects "Enter Market"

**MarketUI**:
- `market_closed()` - Emitted when market is closed

**ClickAndFade**:
- `hub_clicked()` - Emitted when player clicks on the hub area
- `actor_entered(actor)` - Emitted when any actor enters
- `actor_exited(actor)` - Emitted when any actor exits

### Public API

**Hub.gd**:
```gdscript
# Shows the hub menu
func _show_hub_menu() -> void

# Check if node is the player Bus
func _is_bus(node: Node) -> bool
```

**Timekeeper.gd**:
```gdscript
# Pauses game time
func pause() -> void

# Resumes game time
func resume() -> void
```

**ClickAndFade.gd**:
```gdscript
# Returns true if Bus is currently in the area
func is_bus_inside() -> bool

# Returns the Bus node if inside, null otherwise
func get_bus_node() -> Node
```

## Extending the System

### Adding New Menu Options

1. Open `UI/HubMenuUI.tscn` in the editor
2. Add a new Button to the `OptionsContainer` VBoxContainer
3. Connect the button's `pressed` signal to a new method in `HubMenuUI.gd`:

```gdscript
func _on_recruit_pressed() -> void:
    # Your logic here
    close_menu()
```

### Adding Player Inventory Trading

To allow buying/selling between player and hub:

1. Create a player inventory system (similar to HubStates.inventory)
2. Update `MarketUI.gd` to add Buy/Sell buttons
3. Implement transaction logic in Hub.gd:

```gdscript
func player_buy_item(item_id: StringName, amount: int) -> bool:
    # Check hub has stock
    # Deduct from hub inventory
    # Add to player inventory
    # Deduct player money
    return true

func player_sell_item(item_id: StringName, amount: int) -> bool:
    # Check player has stock
    # Deduct from player inventory
    # Add to hub inventory
    # Add player money
    return true
```

## Troubleshooting

### Menu doesn't appear when entering hub

1. Check that `hub_menu_ui` is assigned in Hub Inspector
2. Verify ClickAndFade has a CollisionShape2D configured
3. Ensure Bus scene path matches: `res://Actors/Bus.tscn`
4. Check console for warning: "Hub X has no HubMenuUI assigned"

### Game doesn't pause

1. Verify Timekeeper is configured as autoload at `/root/Timekeeper`
2. Check that Bus and Overworld connect to pause/resume signals in `_ready()`
3. Look for connection errors in console output

### Menu doesn't close with ESC key

1. Verify `ui_cancel` action is defined in Input Map
2. Check that `set_process_input(true)` is called in UI `_ready()`

### Market shows empty inventory

1. Verify hub has items in `state.inventory` Dictionary
2. Check that hub economy is ticking (producing/consuming goods)
3. Ensure `item_prices` is populated via `_update_item_prices()`

## Architecture Notes

This system follows the Mutant Reign architecture guidelines:

- **Separation of Concerns**: UI (Control nodes) separate from game logic (Hub.gd)
- **Signal-Based**: Components communicate via signals, not direct calls
- **Type-Safe**: All variables explicitly typed (Godot 4.5 syntax)
- **Resource-Driven**: Hub state persists via HubStates Resource
- **Performance-Conscious**: Minimal overhead when menus closed

The pause system is centralized through Timekeeper to ensure all game systems can be paused/resumed consistently.
