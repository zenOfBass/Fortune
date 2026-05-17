# Fortune

A digital implementation of Fortune, a tarot-themed 5-card draw poker variant, built in Godot 4.6 (GDScript).

## Running the Game

1. Open the project in Godot 4.x.
2. Run the main scene (`res://scenes/main_menu.tscn`) or press F5.

## Main Menu Options

| Option | Range | Default | Description |
|---|---|---|---|
| Players | 2–4 | 4 | Total players (always 1 human + AI opponents) |
| Starting chips | 10–10,000 | 100 | Chips each player starts with |
| Ante | 1–100 | 1 | Chips each player pays into the pot before each round |
| Force arcana | — | Random | Pin a specific Major Arcana card to fire every round (useful for testing) |

## What's Implemented

- Full 5-card draw poker loop: ante → deal → bet → draw → bet → showdown
- 2–4 player support (1 human, rest AI)
- All 22 Major Arcana with their effects
- Page card rules (0-value, straight wrap, winner bonus, arcana trigger)
- Dealer rotation with on-screen label
- Automatic hand sorting by suit then rank
- Game log panel with round numbers, chip standings, pot sizes, card names at showdown, and draw details
- Card deal animations: flip reveal for the player's hand, staggered pop-in for AI hands
- Sound effects for card flip and shuffle
- Bust/elimination announcements
- Game-over screen with final standings

---

## Rules

### Setup

- There will be two decks. The 56 suited cards will form the playing deck and should be shuffled and dealt as in a normal game of poker.

- The Major Arcana will be a separate deck. Remove the _World_ card (#21) from it and split the deck into two piles as equally as possible, since there is now an odd number of cards. Insert the _World_ card back into one of the piles, and shuffle both individually. Put the pile without the _World_ card on top of the other pile to form the Major Arcana deck.

### Game Play

**Ante**

Before the cards get dealt, each player needs to add an ante to the pot. The ante amount is determined before play begins. One chip is standard.

**Dealing**

Each player is dealt five cards, one card at a time, clockwise around the table.

**Betting**

The player left of the dealer is first to make a bet or can check. Check means the player is still in the hand without increasing the bet. Once a bet is made, calling check is no longer an option. Betting moves clockwise, with players having to match any previous bets. A player can also raise the amount of a previous bet.

**Folding**

If a player does not want to bet, the player can fold their cards, and be out for the round. A folding player sacrifices their ante. Players must match the highest amount bet to stay in the round.

**Draw**

After the first round of betting, all remaining players get to discard unwanted cards from their hands. The dealer will deal each player the number of cards they discarded. Another round of betting begins with players again having to at least bet as much as any previous bets. A player then still has the option to fold.

**Showdown**

Once the betting round is over, all remaining players in the hand show their cards. The player with the highest-ranking poker hand wins all the chips in the pot. In the event of a tie the pot is split between the two players, and any remainder is lost.

### Ranking

Card and hand ranking works the same as in normal poker, with one addition being the _Page,_ who is explained below. Hand rank is listed for convenience.

**Hand rank**

- Straight Flush (five cards in sequence in the same suit)
- Four of a kind
- Full House (three of a kind with a pair)
- Flush (Five cards in the same suit)
- Straight (Five cards in sequence)
- Three of a kind
- Two pairs
- Pair
- High Card

**Card rank**

Highest to lowest – _Ace_, _King_, _Queen_, _Knight_, 10, 9, 8, 7, 6, 5, 4, 3, 2, _Page_

**The Page**

As it represents the beginning of a personal journey, the _Page_ is a "0" value card, standing behind the 2 of each suit. On a straight however, it would come before the ace; as page/0, ace, 2, 3 and 4.

The _Page_ will also change the game in two more ways:

- Winning a round while holding a _Page_ card means every other player must pay you the value of an ante as a prize — even if they were not at the table by the end of that round (i.e., folded).

- If the dealer draws a _Page_, it will use its new skills to force the dealer to draw the first card of the Major Arcana deck, read its rules, and apply its effect on every player. Only one card from that deck may be drawn each round, so if another _Page_ is revealed, it has no effect.

### The Major Arcana

Major Arcana cards will only be drawn and come into play after a _Page_ is drawn by the dealer, and its effect is immediate. The rules of that Arcana will last only during the round when it was drawn. After that round, discard the Arcana without shuffling it back into the deck.

Unless otherwise explained, the term "players" refers to anyone who still hasn't folded in that round.

- **0: The Fool** _(Blank state, beginnings, free spirit)_ – This card enters the game as a "flop", meaning any player can play as though it is in their hand. The fool is a wild card, the same as a joker in normal poker.

- **1: The Magician** _(Force of will, desire, creation)_ – Each player, in turn order, guesses a suit and opens the first card of the playing deck. If they get it right, they may add that card to their hand, keeping it open while the round lasts.

- **2: The High Priestess** _(Intuition, subconscious, inner voice)_ – All players turn a card of their choice face up. That card must be kept face up while the round lasts.

- **3: The Empress** _(Maternity, fertility, nature)_ – Players all draw a sixth card for this round.

- **4: The Emperor** _(Authority, structure, paternity)_ – In this round, _Kings_ supersede _Aces_ for card and hand ranking.

- **5: The Hierophant** _(Tradition, conformity, moral)_ – The only Arcana that is not discarded after the round ends. Instead, it is kept on the table until the next Arcana is drawn. When that happens both are discarded together, preventing the new card from having any effect whatsoever. _The Hierophant_ cannot cancel the _World_ card.

- **6: The Lovers** _(Partnership, union, choice)_ – In this round, the two best hands will split the pot. If the pot value is not equally splittable, the best hand wins the largest, rounded-up amount.

- **7: The Chariot** _(Direction, control)_ – Each player passes one of their cards, at their choice, to the player on their left.

- **8: Strength** _(Bravery, focus, inner strength)_ – In this round, the order of the values of all cards in play is inverted. 2 is the highest, and the ace is the second-lowest. The _Page_ is not affected, and still has a value of 0.

- **9: The Hermit** _(Contemplation, search for truth, inner guide)_ – Each player will only use the cards in their hand for this round.

- **10: Wheel of Fortune** _(Change, cycles, destiny)_ – Shuffle back together all the cards in play: from the player's hands and the cards from the folded players, dealing the same number of cards as before to each player. If a new _Page_ is drawn, it does not trigger a new Arcana.

- **11: Justice** _(Cause and effect, clarity, truth)_ – A player may call for any value they want to put forward as a bet, even if it is lower. Any exceeding value goes back to the players who bet extra, which prevents bluffing.

- **12: The Hanged Man** _(Sacrifice, martyrdom)_ – Any player who goes for an all-in can draw an extra card from the deck to their hand.

- **13: Death** _(End of a cycle, metamorphosis)_ – When drawn, _Death_ ends the turn. Hands are compared immediately.

- **14: Temperance** _(The middle road, patience, find meaning)_ – Players each discard one card from their hand. 3 cards are turned face-up to act as flops. Each player may choose one (and only one) of them to complete their hand.

- **15: The Devil** _(Excess, materialism)_ – If players want to raise a bet, it must be raised to at least double the original value.

- **16: The Tower** _(Sudden upheaval, disaster)_ – Half of the pot, rounded up, is lost. This money doesn't go to any player.

- **17: The Star** _(Hope, faith, healing)_ – Each player, in turn order, may change one card from their hand, with a card from the top of the playing deck.

- **18: The Moon** _(Illusion, intuitions)_ – Each player, in turn order, draws a card from the deck and cannot turn it face up or look at it. Before comparing hands, the players may exchange one of their cards for the face-down card.

- **19: The Sun** _(Joy, success, celebration)_ – When drawn, the _Sun_ ends the turn. The pot will be equally divided. If there's money left in the pot, it is lost.

- **20: Judgement** _(Awakening, renewal)_ – Every player who has folded may pay a new ante to draw five new cards and re-enter that round.

- **21: The World** _(Fulfillment, completion, wholeness)_ – When drawn, the _World_ announces the last round of the game.
