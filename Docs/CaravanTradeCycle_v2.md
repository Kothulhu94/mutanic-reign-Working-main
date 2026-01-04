# Caravan Trade Cycle Documentation
## "The Garage System" Update (v2.0)

This document outlines the complete lifecycle of a Caravan in the new "Garage" system, covering the flow from initial request to clocking out.

### 1. The Trigger (The Job Offer)
The cycle begins when the **Overworld** detects that a Hub has a significant surplus of a specific resource (e.g., Food).
- **Source:** `Overworld._try_spawn_caravan_from_hub`
- **Action:** Calls `hub.request_trade_run(CaravanType)` instead of spawning immediately.

### 2. The Garage Selection (Hub.gd)
The Hub manages its fleet. It attempts to fill the job request efficiently.
- **Pass 1 (The Specialist):** Checks `idle_fleet` for a veteran whose native type matches the job (e.g., a dedicated Food Merchant).
  - *Result:* Perfect match found? Deploy immediately.
- **Pass 2 (The Warm Body):** If no specialist is idle, it grabs the **first available** veteran from `idle_fleet`.
  - *Result:* A Luxury Merchant might be assigned a Food Run. They keep their stats (Carry Cap, Speed) but are ordered to trade Food.
- **Pass 3 (New Hire):** If the garage (`idle_fleet`) is empty, a `caravan_spawn_requested` signal is emitted.
  - *Result:* Overworld spawns a fresh Caravan, registers it with the Hub, and it immediately enters the fleet.

### 3. Clocking In (Deployment)
The chosen Caravan (Veteran or New) is activated.
- **Method:** `caravan.start_mission(job_type)`
- **Visuals:** `refresh_visuals()` is called to update sprites to match their native type (identity preservation).
- **Overrides:** The `job_type` is stored as `current_mission_type` and passed to the Trading System as a `mission_override`.
- **State Transition:** `IDLE` -> `BUYING_AT_HOME`

### 4. Purchasing Logic (CaravanTradingSystem.gd)
The Caravan attempts to load cargo using a smart **2-Phase Purchasing Algorithm**.
- **Phase 1: The Mission (Priority)**
  - It attempts to buy goods defined by the **Job Type** (e.g., Food tags).
  - It prioritizes these orders above all else.
- **Phase 2: Opportunity Buying (Bonus)**
  - If the Caravan still has **Capacity** and **Money (>10 Pacs)** after Phase 1:
  - It scans the **entire** Hub inventory.
  - For each item, it performs a **Global Market Check**:
    - *Check:* Does ANY foreign hub currently offer a sell price > 110% of the buying price?
    - *Action:* If YES, it buys the item to fill space.
  - *Result:* A Food Merchant might leave with 80% Grain and 20% Medicine because they noticed a profit opportunity.

### 5. The Journey (Active Duty)
- **Routing:** If cargo was acquired, it finds a target hub (`trading_system.find_next_destination`).
- **State:** `TRAVELING`. The Caravan moves physically across the map.

### 6. Trade Execution (Destinations)
Upon arrival at a target hub:
- **Evaluation (`EVALUATING_TRADE`):**
  - Checks current prices.
  - If profitable (>10% margin), transitions to `SELLING`.
  - If NOT profitable, it calculates a route to the *next* hub immediately.
- **Selling (`SELLING`):**
  - Sells only profitable items.
  - Awards XP (Profit + Volume bonuses).
  - Transitions to `RETURNING_HOME`.

### 7. Return & Clock Out
The Caravan returns to its Home Hub.
- **Arrival (`_arrive_at_home`):**
  - **Dumping:** Any unsold cargo is forcibly deposited back into the Hub's inventory.
    - *Cooldown:* A 5-minute export cooldown is applied to these items to prevent immediate re-export loops.
  - **Accounting:**
    - XP awarded for the trip.
    - 10% Income Tax paid to the Hub's treasury.
  - **Clock Out:**
    - Signal `mission_complete` is emitted.
    - `Hub` receives signal:
      - Adds Caravan to `idle_fleet`.
      - Hides Caravan (`visible = false`).
    - Caravan enters `IDLE` state (Passive Mode).

### Summary of Improvements
- **Persistence:** Caravans retain XP and levels between runs.
- **Flexibility:** Any idle caravan can take any job (Warm Body logic).
- **Intelligence:** They now perform opportunistic "side hustles" alongside their main orders.
- **Efficiency:** Failed sales result in cooldowns, preventing "death spirals" of trying to sell unwanted goods.
