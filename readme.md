# Fortune

A tarot-infused poker game built in Godot 4.6. Face off against AI opponents at a five-card draw table where the Major Arcana can flip the rules mid-round — inverting card values, wiping the pot, ending the hand early, or bringing folded players back from the dead.

## Running the Game

1. Open the project in Godot 4.6.
2. Press **F5** or run `res://scenes/main_menu.tscn`.

## Setup Options

| Setting | Range | Default |
|---|---|---|
| Players | 2–4 | 4 |
| Starting chips | 10–10,000 | 100 |
| Ante | 1–100 | 1 |
| Force arcana | any | Random |

"Force arcana" locks a specific Major Arcana to fire every round — handy for testing a particular effect.

## Gameplay

Each round follows a standard five-card draw structure: ante in, get dealt five cards, bet, swap cards, bet again, showdown. Last player standing with chips wins the game.

**The Page** is a zero-value wildcard. It sits behind the 2 in normal play but wraps around the Ace on a straight (Page → Ace → 2 → 3 → 4). If the dealer is holding a Page when cards are dealt, it triggers the Major Arcana — drawing the top card from a separate tarot deck and applying its effect for the rest of the round.

Winning a round while holding a Page also collects a bonus ante from every other player at the table, even those who folded.

## The Major Arcana

One arcana can fire per round. Its effect lasts until the next ante phase. There are 22 cards total; The World is seeded into the back half of the deck so it never shows up too early.

| # | Card | Effect |
|---|---|---|
| 0 | The Fool | A wild card enters play as a shared flop — all players can use it as part of their hand. |
| 1 | The Magician | Each player guesses a suit and flips the top card of the deck. Guess right and keep it. |
| 2 | The High Priestess | All players reveal one card face-up. It stays visible for the rest of the round. |
| 3 | The Empress | Everyone draws a sixth card. |
| 4 | The Emperor | Kings outrank Aces this round. |
| 5 | The Hierophant | Stays on the table and cancels the next arcana drawn (except The World). |
| 6 | The Lovers | The top two hands split the pot instead of just one winner taking it all. |
| 7 | The Chariot | Everyone passes one card to the player on their left, simultaneously. |
| 8 | Strength | Card values are inverted — 2 is highest, Ace is second-lowest. The Page is unaffected. |
| 9 | The Hermit | No draw phase. Everyone plays the hand they were dealt. |
| 10 | Wheel of Fortune | All cards are shuffled back into the deck and redealt. New Pages don't trigger another arcana. |
| 11 | Justice | Bets can be any amount. Anything over the call is refunded — no bluffing with oversized raises. |
| 12 | The Hanged Man | Going all-in earns you one extra card from the deck. |
| 13 | Death | Hands are revealed immediately. No draw phase, no second betting round. |
| 14 | Temperance | Each player discards one card, then picks from three face-up flop cards to replace it. |
| 15 | The Devil | Raises must at least double the current bet. |
| 16 | The Tower | Half the pot (rounded up) is destroyed. Nobody gets it. |
| 17 | The Star | Each player may swap one card with the top of the deck, or pass. |
| 18 | The Moon | Everyone draws a secret card they can't look at. Before showdown, they may swap it into their hand. |
| 19 | The Sun | The pot splits equally among all active players. Leftovers are lost. |
| 20 | Judgement | Folded players may pay the ante to draw five fresh cards and re-enter the round. |
| 21 | The World | The next round will be the last. |

## What's in the Build

- Full five-card draw loop with AI opponents
- All 22 Major Arcana implemented and playable
- Card deal animations and sound effects
- Chip tracking, bust detection, and final standings screen
- Dealer rotation and game log
