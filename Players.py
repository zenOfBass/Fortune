from ast import List
from Card import Card
from collections import Counter
from dataclasses import dataclass
import random


@dataclass
class Player:
    hand: List[Card]
    stack: int

    def Bet(self, amount):
        if amount > self.stack:
            raise ValueError("Insufficient chips")
        self.stack -= amount
        return amount

class AIPlayer(Player):
    def __init__(self, hand, stack):
        super().__init__(hand, stack)

    def Bet(self, currentBet):
        strongThreshold = 0.8                  # Define a threshold for different hand strengths (for testing purposes)
        moderateThreshold = 0.5
        handStrength = random.random()         # Simulate AI's assessment of hand strength (for testing purposes)
        if handStrength > strongThreshold:
            betAmount = self.stack             # All-in with a very strong hand
        elif handStrength > moderateThreshold:
            betAmount = currentBet * 2         # Moderate bet with a strong hand
        else:
            betAmount = currentBet             # Call or check with a weak hand
        betAmount = min(betAmount, self.stack) # Ensure the AI doesn't bet more than it has
        self.stack -= betAmount
        return betAmount

    @staticmethod
    def AIDiscardStrategy(hand: List[Card]) -> List[int]:
        ranks = [card.rank.value for card in hand]
        rankCounts = Counter(ranks)
        for rank, count in rankCounts.items():      # If there are four cards of the same rank, keep them all
            if count == 4:
                return []
        for rank, count in rankCounts.items():      # If there are three cards of the same rank, keep them all
            if count == 3:
                return []
        if list(rankCounts.values()).count(2) == 2: # If there are two pairs, keep them all
            return []
        discardIndices = [index for index, rank in enumerate(ranks) if rank != max(ranks)] # Otherwise, discard all but the highest card
        return discardIndices