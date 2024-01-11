from dataclasses import dataclass
from typing import List, Tuple
from collections import Counter
from Card import Card
from GamePhase import GamePhase
from Observer import Observer, Subject
from Players import Player


@dataclass
class GameState(Observer):
    deck: List[Card]         # Defines a property 'deck' of type List[Card]. This will store the deck of cards in the game.
    players: List[Player]    # Defines a property 'players' of type List[List[Card]]. This will store the hands of all players.
    pot: int                 # Integer value representing the total chips in the pot
    gamePhase: GamePhase
    numPlayers: int
    activePlayers: List[int] # List of integers representing the indices of active players

    def Update(self, subject: Subject, newPhase: str) -> None:
        self.gamePhase = newPhase
        return

    def RankHand(hand: List[Card]) -> Tuple[int, List[int]]:
        ranks = [card.rank.value for card in hand]
        if set(ranks) == {0, 10, 11, 12, 13}:                 # Convert placeholder back to 0 for Page
            ranks.remove(0)
            ranks.append(-1)                                  # Add a placeholder for Page (to be converted to 0 later)
        ranks.sort(reverse = True)                              # Sort ranks in descending order
        ranks = [rank if rank != -1 else 0 for rank in ranks] # Convert placeholder back to 0 for Page
        suits = [card.suit for card in hand]
        rankCounts = Counter(ranks)
        isFlush = len(set(suits)) == 1
        isStraight = len(set(ranks)) == 5 and max(ranks) - min(ranks) == 4
        if isFlush and isStraight:
            if max(ranks) == 14:
                return (10, ranks) # Royal Flush
            else:
                return (9, ranks)  # Straight Flush
        elif max(rankCounts.values()) == 4:
            return (8, ranks)      # Four of a Kind
        elif max(rankCounts.values()) == 3 and len(rankCounts) == 2:
            return (7, ranks)      # Full House
        elif isFlush:
            return (6, ranks)      # Flush
        elif isStraight:
            return (5, ranks)      # Straight
        elif max(rankCounts.values()) == 3:
            return (4, ranks)      # Three of a Kind
        elif list(rankCounts.values()).count(2) == 2:
            return (3, ranks)      # Two Pair
        elif list(rankCounts.values()).count(2) == 1:
            return (2, ranks)      # One Pair
        else:
            return (1, ranks)      # High Card