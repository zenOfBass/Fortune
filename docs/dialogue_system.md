# Fortune — Dialogue System Reference

*All three phases of the dialogue system are complete as of 2026-05-19.*

---

## The Characters

In the style of Jack Vance's *Dying Earth*: archaic, darkly comic, verbose when it suits them, cryptic when it doesn't.

### Tarvosk the Brazen
- **Play style**: Aggressive, high bluff rate, folds rarely
- **Voice**: Loud, boastful, quick to taunt. Genuinely enjoys chaos. Bad at hiding a strong hand.
- **Relationship to losing**: Blames luck, the arcana, the universe — never himself.
- **Sample line**: *"The Tower? Good. I thrive in rubble."*

### Haldemar the Still
- **Play style**: Rock-solid, never bluffs, folds aggressively on weak hands
- **Voice**: Dry, sparse, slightly contemptuous. Long silences are part of his character — rare lines land hard.
- **Relationship to losing**: Accepts it without visible emotion. Describes it philosophically.
- **Sample line**: *"Expected."*

### Mercival the Oblique
- **Play style**: Ghost — middle thresholds, moderate bluffing, unpredictable
- **Voice**: Indirect, allusive, never says what he means directly. The arcana fascinate him.
- **Relationship to losing**: Treats it as interesting data.
- **Sample line**: *"The Hanged Man. How appropriate for some of us."* *(glances at no one in particular)*

---

## Design Pillars

1. **Personality-driven, not generic.** Every line should feel like it could only come from that specific character.
2. **Game-state-aware.** Lines reference the current arcana, who's winning, recent player behavior.
3. **Non-repetitive.** Cooldown + no-repeat system prevents the same line playing twice in a row or too often.
4. **Thematically grounded.** The arcana are a natural hook every round — 22 × 3 characters = 66 arcana reactions.
5. **Optional depth.** Works with a small line set and grows richer as content is added.

---

## Architecture

### Files

| File | Purpose |
|---|---|
| `scripts/dialogue_manager.gd` | Autoload Node — all selection logic, behavior tracking, mood system |
| `assets/dialogue/tarvosk.json` | Tarvosk's lines (~210 lines across all triggers) |
| `assets/dialogue/haldemar.json` | Haldemar's lines (~200 lines) |
| `assets/dialogue/mercival.json` | Mercival's lines (~200 lines) |
| `assets/dialogue/exchanges.json` | Scripted multi-character exchanges |

### JSON line format

Each character file is a flat dictionary keyed by trigger ID:

```json
{
    "arcana_revealed_18": [
        "The Moon. Someone here is hiding something.",
        "We all carry secrets. The question is whether they're worth anything."
    ],
    "player_won_round": [
        "Enjoy it. The arcana will correct this shortly.",
        "Beginner's fortune. It won't last."
    ],
    "player_won_round_humiliated": [
        "Again. Again you beat me. There must be sorcery at work.",
        "Fine. Fine. We'll see how long this holds."
    ]
}
```

Multiple lines per trigger allow random selection. The `_humiliated` / `_impressed` / `_curious` suffix variants unlock alternate pools when a character's session mood counter reaches the threshold (see Mood System below).

Lines support `{placeholder}` substitution via GDScript's `String.format()`:
- `{hand_name}` — e.g. "flush", "pair" (auto-converted to lowercase; articles handled)
- `{hand_name_a}` — "a flush", "pair" (with or without "a" depending on the hand)
- `{arcana_name}` — e.g. "The Moon"
- `{chips}` — a chip count

Lines containing a placeholder that would substitute to an empty string are skipped automatically.

### Display

`DialogueDisplay` is a PanelContainer (dark parchment background, gold border) positioned near each character's side of the table. It fades in (0.3s), holds for 4s, then fades out (0.5s).

Each speaker's name is rendered in a distinct signature color via a per-character `LabelSettings` duplicate:

| Character | Position | Color |
|---|---|---|
| Tarvosk the Brazen | Top-center | Burnt orange `#ED7521` |
| Haldemar the Still | Left | Steel blue `#6BA6D9` |
| Mercival the Oblique | Right | Violet `#B36BE6` |

---

## DialogueManager API

```gdscript
# Fire a line for a specific AI speaker. chance ∈ [0,1].
try_fire(trigger_id, speaker_idx, chance, context, require_chips)

# Pick one eligible AI at random and fire.
try_fire_any(trigger_id, chance, context, require_chips)

# Like try_fire_any but excludes one index — use for reactor triggers so winner doesn't react to themselves.
try_fire_any_except(trigger_id, exclude_idx, chance, context)

# Play a scripted multi-character exchange (async coroutine, 2.5s between steps).
# trigger_id selects from exchanges.json; falls back to "random" pool if not found.
try_fire_exchange(trigger_id)
```

All `try_fire*` calls silently no-op if:
- The trigger is on cooldown for that speaker (3-round default)
- The selected line was among the last 3 shown for that trigger
- `require_chips=true` and the speaker is eliminated
- An exchange is currently running (exchanges block single-line triggers while active)

---

## Implemented Triggers

| Trigger | Fire site | Notes |
|---|---|---|
| `game_start` | `DialogueManager` on first DEAL phase | 100%, also fires a scripted exchange |
| `arcana_revealed_N` | `table.gd _on_arcana_revealed` | 85% per arcana, `{arcana_name}` context |
| `player_won_round` | `table.gd _on_round_ended` | 85%, `{hand_name}` context |
| `ai_won_round` | `table.gd _on_round_ended` | 90%, `{hand_name}` context |
| `strong_hand_shown` | `table.gd _on_round_ended` | 95%, reactor only (Royal/Straight Flush, Four of a Kind) |
| `five_of_a_kind_shown` | `table.gd _on_round_ended` | 100%, reactor only |
| `split_pot` | `table.gd _on_round_ended` | 80% |
| `exchange` | `table.gd _on_round_ended` | 20% chance instead of normal round-end commentary |
| `last_round_announced` | `table.gd _on_last_round_announced` | 100% |
| `player_folded` | `table.gd _on_player_folded` | 70% |
| `player_went_all_in` | `table.gd _on_player_bet_changed` | 90% |
| `ai_went_all_in` | `table.gd _on_player_bet_changed` | 85%, that specific AI |
| `player_raised_aggressively` | `table.gd _on_player_raised` | 65%, raise ≥ 2× previous bet |
| `player_low_chips` | `table.gd _on_player_chips_changed` | 75%, human ≤ 20% starting chips, `{chips}` |
| `ai_low_chips` | `table.gd _on_player_chips_changed` | 70%, that AI, `{chips}` |
| `tarvosk_bluffing` | `DialogueManager` via `ai_bluffing` signal | 75%, Tarvosk only |
| `player_aggressive_pattern` | `DialogueManager` deferred 5.2s post-round | 45%, rate ≥ 0.4 raises/round, ≥ 3 rounds |
| `player_passive_pattern` | `DialogueManager` deferred 5.2s post-round | 40%, rate ≥ 0.45 folds/round, ≥ 3 rounds |
| `player_on_streak` | `DialogueManager` deferred 5.2s post-round | 60%, ≥ 2 consecutive player wins |
| `ai_on_streak` | `DialogueManager` deferred 5.2s post-round | 65%, ≥ 2 consecutive wins by same AI |
| `game_over_win` | `DialogueManager _on_game_ended` | 100%, winning AI speaks |
| `game_over_lose` | `DialogueManager _on_game_ended` | 100%, any AI reacts to player winning |

---

## Mood System

Each character accumulates a session mood counter that unlocks alternate dialogue pools when it hits 3:

| Character | Counter | What increments it |
|---|---|---|
| Tarvosk | `_tarvosk_humiliation` | Player wins at showdown |
| Haldemar | `_haldemar_impressed` | Player wins at showdown |
| Mercival | `_mercival_curiosity` | Unusual arcana (Tower/Moon/Judgement/World), split pots |

When a character's counter is at or above the threshold, `try_fire` appends a suffix to the trigger lookup before falling back to the base pool. For example, a humiliated Tarvosk will draw from `player_won_round_humiliated` instead of `player_won_round` if that key exists in his JSON file.

Counters and cooldowns reset at game end.

---

## Bluff Tell System

When Tarvosk bluffs, `ai_bluffing` fires and `try_fire("tarvosk_bluffing")` has a 75% chance to play a tell line. The flag `_tarvosk_bluff_announced` is set when a tell fires. If the player beats Tarvosk in that round's showdown, `tell_read` is emitted — reserved for future use (e.g. a UI wink, a Tarvosk reaction line).

---

## Scripted Exchanges

`exchanges.json` holds multi-character scripted sequences keyed by context:

```json
{
    "game_start": [
        [
            {"idx": 1, "line": "Another evening. Another opportunity to take your chips."},
            {"idx": 2, "line": "Indeed."}
        ]
    ],
    "random": [ ... ]
}
```

Each exchange is an array of step-objects with `idx` (speaker, 1–3) and `line`. Steps play with 2.5s gaps. While an exchange runs, all single-line `try_fire*` calls are suppressed.

Exchange cooldown: 6 rounds. Falls back to `"random"` pool if the specific trigger key is not found.
