# Fortune — Dialogue System Design Plan

## Vision

Give the three AI characters a persistent, living presence at the table — not just opponents who bet and fold, but personalities who comment on the game, react to the player, and occasionally bicker with each other. The reference point is *Poker Night at the Inventory*: characters feel like they have opinions, history, and a stake in what's happening beyond their chip count.

The tarot/arcane setting is a major asset here. Unlike a game set in a generic poker room, Fortune has built-in thematic richness every round — a new arcana, strange rules, occult stakes. The characters should feel like they *belong* in that world.

---

## The Characters

These are character in the style of Jack Vance's *Dying Earth*, which sets a strong tonal baseline: archaic, darkly comic, verbose when it suits them, cryptic when it doesn't.

### Tarvosk the Brazen
- **Play style**: Aggressive, high bluff rate, folds rarely
- **Voice**: Loud, boastful, quick to taunt. Genuinely enjoys chaos. Probably loves the Fool arcana. Bad at hiding when he has a strong hand.
- **Relationship to losing**: Blames luck, the arcana, the universe — never himself.
- **Sample line**: *"The Tower? Good. I thrive in rubble."*

### Haldemar the Still
- **Play style**: Rock-solid, never bluffs, folds aggressively on weak hands
- **Voice**: Dry, sparse, slightly contemptuous. Speaks as if dialogue itself is beneath him. Long silences are part of his character — he shouldn't talk often, but when he does it lands.
- **Relationship to losing**: Accepts it without visible emotion. Describes it philosophically.
- **Sample line**: *"Expected."*

### Mercival the Oblique
- **Play style**: Ghost — middle thresholds, moderate bluffing, unpredictable
- **Voice**: Indirect, allusive, never says what he means directly. Possibly delighted by things others find threatening. The arcana fascinate him.
- **Relationship to losing**: Treats it as interesting data.
- **Sample line**: *"The Hanged Man. How appropriate for some of us."* *(glances at no one in particular)*

---

## Design Pillars

1. **Personality-driven, not generic.** Every line should feel like it could only come from that specific character. No filler like "Nice hand."
2. **Game-state-aware.** Lines reference what's actually happening — the current arcana, who's winning, whether the player just went all-in.
3. **Non-repetitive.** A cooldown + no-repeat system prevents the same line playing twice in a row or too frequently.
4. **Thematically grounded.** The arcana are a natural dialogue hook every single round. Each of the 22 arcana is an opportunity for character-specific reactions.
5. **Optional depth.** The system should work with a small line set and get richer as more content is added — not require hundreds of lines to feel good.

---

## Trigger Taxonomy

Events that can fire dialogue, roughly in order of importance:

### High priority (fire often, should have good coverage)
| Trigger | Notes |
|---|---|
| `arcana_revealed` | Per-arcana reactions per character. 22 arcana × 3 characters = 66 lines. High value. |
| `player_won_round` | Character reactions to losing to the player |
| `ai_won_round` | Winner gloats (or doesn't, in Haldemar's case) |
| `player_folded` | Taunt or comment |
| `player_went_all_in` | Reactions to the bet |
| `ai_went_all_in` | Self-commentary when the character goes all-in |
| `split_pot` | Rare, worth a line |

### Medium priority (flavor, fire less often)
| Trigger | Notes |
|---|---|
| `player_raised_aggressively` | Raise significantly above current bet |
| `ai_bluffing` | Internal — could fire a tell line for Tarvosk specifically |
| `strong_hand_shown` | Royal Flush, Straight Flush, Four of a Kind at showdown |
| `five_of_a_kind_shown` | Rare enough to always deserve a line |
| `last_round_announced` | Tension acknowledgment |
| `player_low_chips` | Comments on the player's stack |
| `ai_low_chips` | Self-aware stack commentary |

### Low priority (Phase 2+)
| Trigger | Notes |
|---|---|
| `inter_character` | One AI reacts to another's action |
| `player_behavior_pattern` | "You always raise on the draw phase" |
| `specific_arcana_outcome` | Chariot card passed, Magician guess correct/wrong |
| `game_start` | Opening remarks |
| `game_over` | Closing remarks |

---

## Dialogue Architecture

### Data format (proposed)

Each character gets a dialogue file (`scripts/dialogue/voivode.gd`, etc.) with a dictionary keyed by trigger ID:

```gdscript
const LINES := {
    "arcana_revealed_7":  # The Chariot
        ["Pass a card? Gladly — I have nothing worth keeping.",
         "The Chariot moves forward. Unlike some at this table."],
    "player_won_round":
        ["Enjoy it. The arcana will correct this shortly.",
         "Beginner's fortune. It won't last."],
    # ...
}
```

Multiple lines per trigger allow random selection. This format is easy to author and extend without touching engine code.

### Selection system

A `DialogueManager` autoload handles:
- **Cooldown per trigger**: same trigger can't fire within N rounds
- **No-repeat**: tracks last N lines shown, won't repeat them
- **Priority queue**: high-priority triggers preempt low-priority ones if both fire at once
- **Chance roll**: not every trigger fires every time (prevents overwhelming the player)

### Display

**Resolved.** Each character gets a `DialogueDisplay` panel (speaker name + dialogue text) that:
- Is positioned near their side of the table (`_reposition_dialogue()` in `table.gd`)
- Renders the speaker name in a distinct signature color via a per-character `LabelSettings` duplicate

| Character | Screen position | Color |
|---|---|---|
| Tarvosk the Brazen | top-center | Burnt orange `#ED7521` |
| Haldemar the Still | left | Steel blue `#6BA6D9` |
| Mercival the Oblique | right | Violet `#B36BE6` |

The box fades in (0.3s), holds for 4s, then fades out (0.5s).

---

## Phased Implementation Plan

### Phase 1 — Foundation *(start here)*
**Goal**: Characters feel alive. Every round has at least one voiced moment.

- `DialogueManager` autoload with cooldown + no-repeat logic
- Dialogue files for all three characters
- Coverage: `arcana_revealed` (all 22), `player_won_round`, `ai_won_round`, `player_folded`, `player_went_all_in`
- Basic display UI (portrait + text, auto-dismiss after a few seconds)
- ~15–20 lines per character to start

**Deliverable**: The table never feels silent. Every arcana has a reaction. Wins and folds get commentary.

### Phase 2 — Context awareness
**Goal**: Lines reference what's actually happening, not just the event type.

- Lines that embed game state: arcana name, chip counts, hand names, "last round" flag
- Medium-priority triggers: strong hands at showdown, stack commentary, specific arcana outcomes
- Expand line count to ~40–50 per character

**Deliverable**: Characters feel like they're watching the same game you are.

### Phase 3 — Dynamic behavior
**Goal**: Characters react to patterns, not just events.

- Player behavior tracking: aggression score, fold frequency, bluff detection
- Inter-character dialogue (Tarvosk taunts Haldemar; Haldemar ignores him)
- Character-to-character relationships that evolve across a session
- Potentially: "tells" — Tarvosk drops hints when bluffing, Mercival says something cryptic before a big win

**Deliverable**: The table has a social dynamic. Feels like *Poker Night*.

---

1. **Inter-character dialogue in Phase 1?** Even one or two exchanges between Tarvosk and Haldemar in Phase 1 would do a lot. Low technical cost if the trigger system is built right.

2. **Arcana commentary scope**: Should characters have lines for all 22 arcana in Phase 1, or just the most common/impactful ones? Full coverage is the high-value play but requires more writing upfront.

---

## Content Scope Reference

| Phase | Lines per character | Total lines | Estimated writing effort |
|---|---|---|---|
| Phase 1 | ~40 | ~120 | A few focused sessions |
| Phase 2 | +30 | ~210 | Ongoing, add as you play |
| Phase 3 | +20 + dynamic | ~270+ | Ongoing |

Poker Night at the Inventory had roughly 300–500 lines per character including VO. 120 lines across three characters is a comfortable Phase 1 target that feels rich without being overwhelming to write.
