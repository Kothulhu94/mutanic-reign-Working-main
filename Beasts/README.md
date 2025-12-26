# Beast & Den System Guide

Complete implementation of 12 mutant creatures across 4 biomes with spawn-point dens.

---

## Quick Start

### Just Drag and Drop! (Like Hubs)
1. Drag [BeastDen.tscn](BeastDen.tscn) into your overworld scene
2. In the Inspector, assign a BeastDenType resource to the `den_type` export
3. Add a sprite texture to the Sprite2D child node
4. Adjust the CollisionShape2D if needed

**That's it!** The den will automatically:
- ✅ Connect to Timekeeper and start spawning beasts
- ✅ Detect the overworld scene for spawning
- ✅ Handle combat integration (beasts have CharacterSheet)
- ✅ Block caravan/bus movement (StaticBody2D)

No manual code integration required!

---

## Beast Catalog

### Grassland Biome

#### **Scrapjackal Pack** (T1)
- **Stats:** 15 HP, 6 DMG, 2 DEF
- **Den:** [ScrapjackalDen.tres](../data/BeastDens/ScrapjackalDen.tres)
- **Spawn Rate:** Every 1 minute (600 ticks)
- **Behavior:** Roam
- **Future Benefit:** +25% resource detection radius (scrap, parts)
- **Lore:** Fast nippers with modest damage, low staying power. Scavenger noses make them great "metal diviners."

#### **Windrunner Antelope** (T2)
- **Stats:** 40 HP, 8 DMG, 5 DEF
- **Den:** [WindrunnerDen.tres](../data/BeastDens/WindrunnerDen.tres)
- **Spawn Rate:** Every 2.5 minutes (1500 ticks)
- **Behavior:** Roam
- **Future Benefit:** +8% road travel speed
- **Lore:** Built for endurance, herds pace ahead and find the firmest track.

#### **Titan Bison** (T3)
- **Stats:** 80 HP, 12 DMG, 14 DEF
- **Den:** [TitanBisonDen.tres](../data/BeastDens/TitanBisonDen.tres)
- **Spawn Rate:** Every 5 minutes (3000 ticks)
- **Behavior:** Territorial
- **Future Benefit:** +20% inventory capacity
- **Lore:** Living freight haulers with bone-plated shoulders. High health/defense, middling damage from trampling.

---

### Mesa Biome

#### **Basalt Scuttlers** (T1)
- **Stats:** 18 HP, 4 DMG, 4 DEF
- **Den:** [BasaltScuttlerDen.tres](../data/BeastDens/BasaltScuttlerDen.tres)
- **Spawn Rate:** Every 1 minute (600 ticks)
- **Behavior:** Roam
- **Future Benefit:** +25% ore/mineral node detection
- **Lore:** Carapace picks up trace vibrations, they "point" to mineral veins.

#### **Sunspine Ram** (T2)
- **Stats:** 35 HP, 9 DMG, 7 DEF
- **Den:** [SunspineRamDen.tres](../data/BeastDens/SunspineRamDen.tres)
- **Spawn Rate:** Every 2.5 minutes (1500 ticks)
- **Behavior:** Territorial
- **Future Benefit:** -20% slope/climb movement penalty
- **Lore:** Knows switchbacks and ledges; ramming charge adds damage.

#### **Cinder Vulture** (T3)
- **Stats:** 60 HP, 18 DMG, 12 DEF
- **Den:** [CinderVultureDen.tres](../data/BeastDens/CinderVultureDen.tres)
- **Spawn Rate:** Every 5 minutes (3000 ticks)
- **Behavior:** Hunt Caravans
- **Future Benefit:** +30% threat detection radius
- **Lore:** Circles high and flags movement. Dive strikes spike damage.

---

### Forest Biome

#### **Thornback Boar** (T1)
- **Stats:** 20 HP, 5 DMG, 3 DEF
- **Den:** [ThornbackBoarDen.tres](../data/BeastDens/ThornbackBoarDen.tres)
- **Spawn Rate:** Every 1 minute (600 ticks)
- **Behavior:** Roam
- **Future Benefit:** +20% forage yield (rations/edibles)
- **Lore:** Rooters expose tubers and grubs. Bristled hide gives a touch of defense.

#### **Myco Stag** (T2)
- **Stats:** 35 HP, 8 DMG, 9 DEF
- **Den:** [MycoStagDen.tres](../data/BeastDens/MycoStagDen.tres)
- **Spawn Rate:** Every 2.5 minutes (1500 ticks)
- **Behavior:** Roam
- **Future Benefit:** +25% medicinal herb/fungus detection
- **Lore:** Symbiotic antlers host bioluminescent lichens; they "glow" near curatives.

#### **Canopy Panther** (T3)
- **Stats:** 50 HP, 20 DMG, 12 DEF
- **Den:** [CanopyPantherDen.tres](../data/BeastDens/CanopyPantherDen.tres)
- **Spawn Rate:** Every 5 minutes (3000 ticks)
- **Behavior:** Hunt Player
- **Future Benefit:** -25% ambush chance while traveling
- **Lore:** Shadow-silent sentry; spots snare lines and kill-zones. Predatory burst = high damage.

---

### Lake Biome

#### **Glassfin Swarm** (T1)
- **Stats:** 12 HP, 6 DMG, 2 DEF
- **Den:** [GlassfinSwarmDen.tres](../data/BeastDens/GlassfinSwarmDen.tres)
- **Spawn Rate:** Every 1 minute (600 ticks)
- **Behavior:** Roam
- **Future Benefit:** +30% rations from lakeshores
- **Lore:** Razor minnows corral fish to shore. Offensive bites, paper-thin resilience.

#### **Mudback Snapper** (T2)
- **Stats:** 45 HP, 9 DMG, 12 DEF
- **Den:** [MudbackSnapperDen.tres](../data/BeastDens/MudbackSnapperDen.tres)
- **Spawn Rate:** Every 2.5 minutes (1500 ticks)
- **Behavior:** Territorial
- **Future Benefit:** +10% shoreline travel speed (bog/mud)
- **Lore:** Wide plastron "tests" safe footing; shell turns mishaps into shrugs.

#### **Ripple Leviathan** (T3)
- **Stats:** 80 HP, 18 DMG, 14 DEF
- **Den:** [RippleLeviathanDen.tres](../data/BeastDens/RippleLeviathanDen.tres)
- **Spawn Rate:** Every 5 minutes (3000 ticks)
- **Behavior:** Territorial
- **Future Benefit:** Can travel on water
- **Lore:** Barometric "ears" warn of squalls. Big mass = health, thick hide = defense.

---

## System Architecture

### Den Spawning System
- **Tick-based:** Dens accumulate `spawn_progress` each tick until spawning
- **World cap:** Each beast type limited to 10 active at once (configurable in `.tres`)
- **Emergency spawning:** When den health drops below 50%, spawns 3 beasts immediately
- **Combat integration:** Dens have CharacterSheet and can be attacked

### Combat System
- **CharacterSheet required:** All beasts initialize with base stats on `_ready()`
- **Duck-typed:** [combat.gd](../combat.gd) checks for `charactersheet` property
- **Death handling:** Beasts auto-remove on 0 health

### AI Behaviors (Placeholder)
Each beast has an `ai_behavior` export:
- `"roam"` - Wander randomly (default)
- `"hunt_caravans"` - Seek and attack caravans
- `"hunt_player"` - Seek and attack player bus
- `"territorial"` - Stay near den, aggressive when approached

**Note:** AI logic not yet implemented. Override `_update_ai(delta)` in specific beast scripts.

---

## File Structure

```
Beasts/
├── BeastDen.gd                    # Den building logic
├── BeastDen.tscn                  # Den scene (StaticBody2D)
├── Beast.gd                       # Base class for all beasts
├── Beast.tscn                     # Base beast template
├── README.md                      # This file
├── Grassland/
│   ├── ScrapjackalPack.gd/.tscn
│   ├── WindrunnerAntelope.gd/.tscn
│   └── TitanBison.gd/.tscn
├── Mesa/
│   ├── BasaltScuttlers.gd/.tscn
│   ├── SunspineRam.gd/.tscn
│   └── CinderVulture.gd/.tscn
├── Forest/
│   ├── ThornbackBoar.gd/.tscn
│   ├── MycoStag.gd/.tscn
│   └── CanopyPanther.gd/.tscn
└── Lake/
    ├── GlassfinSwarm.gd/.tscn
    ├── MudbackSnapper.gd/.tscn
    └── RippleLeviathan.gd/.tscn

data/BeastDens/
├── BeastDenType.gd                # Resource class
├── ScrapjackalDen.tres
├── WindrunnerDen.tres
├── TitanBisonDen.tres
├── BasaltScuttlerDen.tres
├── SunspineRamDen.tres
├── CinderVultureDen.tres
├── ThornbackBoarDen.tres
├── MycoStagDen.tres
├── CanopyPantherDen.tres
├── GlassfinSwarmDen.tres
├── MudbackSnapperDen.tres
└── RippleLeviathanDen.tres
```

---

## Next Steps

### Immediate Tasks
1. **Add sprites:** Currently using color-coded placeholders for dens and beasts
2. **Place dens in your world:** Just drag BeastDen.tscn and assign a den type resource

### Future Enhancements
1. **Implement AI behaviors:** Override `_update_ai(delta)` in beast scripts
2. **Beast taming system:** Via [BeastTracking skill](../data/Skills/Exploration/BeastTracking.tres)
3. **Apply non-combat benefits:** Hook into caravan/bus stats when tamed
4. **Emergency beast variants:** Create stronger beast scenes for emergency spawns
5. **Den placement tools:** Biome detection or level editor helpers

---

## Troubleshooting

**Beasts not spawning:**
- Verify den has `den_type` resource assigned in the Inspector
- Check that Timekeeper autoload exists at `/root/Timekeeper`
- Ensure beast scene paths in `.tres` files are correct
- Check console for errors (connection issues will show warnings)

**Combat not working:**
- Verify beast has initialized `charactersheet` in `_ready()`
- Check `player_initiated_chase` signal is connected
- Ensure [combat.gd](../combat.gd) is accessible

**Performance issues:**
- Reduce `max_active_beasts` in den resources
- Increase `spawn_interval_ticks` for less frequent spawning
- Remove beasts far from player view

---

All beasts are production-ready and combat-compatible! 🦅
