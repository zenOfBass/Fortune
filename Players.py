from typing import List
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
    def __init__(self, hand = None, stack = None):
        super().__init__(hand, stack)

    def AIBettingStrategy(self, currentBet):
        # Define a threshold for different hand strengths
        strongThreshold = 0.8
        moderateThreshold = 0.5
        handStrength = random.random()  # Simulate AI's assessment of hand strength

        if handStrength > strongThreshold:
            betAmount = self.stack  # All-in with a very strong hand
            print(f"AI Player goes all-in with a very strong hand!")
        elif handStrength > moderateThreshold:
            # Moderate bet with a strong hand
            betAmount = min(currentBet * 2, self.stack)
            print(f"AI Player makes a moderate bet with a strong hand: {betAmount}")
        else:
            # Call or check with a weak hand
            betAmount = min(currentBet, self.stack)
            if betAmount == currentBet:
                print(f"AI Player calls with a weak hand: {betAmount}")
            else:
                print(f"AI Player checks with a weak hand: {betAmount}")

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