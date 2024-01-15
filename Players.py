from typing import List
from Card import Card
from collections import Counter
from dataclasses import dataclass
import random


@dataclass
class Player:
    hand: List[Card]
    stack: int

    def bet(self, amount):
        if amount > self.stack:
            raise ValueError("Insufficient chips")
        self.stack -= amount
        return amount


class AIPlayer(Player):
    def __init__(self, hand=None, stack=None):
        super().__init__(hand, stack)

    def ai_betting_strategy(self, current_bet):
        # Define a threshold for different hand strengths
        strong_threshold = 0.8
        moderate_threshold = 0.5
        hand_strength = random.random()  # Simulate AI's assessment of hand strength

        if hand_strength > strong_threshold:
            bet_amount = self.stack  # All-in with a very strong hand
            print(f"AI Player goes all-in with a very strong hand!")
        elif hand_strength > moderate_threshold:
            # Moderate bet with a strong hand
            bet_amount = min(current_bet * 2, self.stack)
            print(f"AI Player makes a moderate bet with a strong hand: {bet_amount}")
        else:
            # Call or check with a weak hand
            bet_amount = min(current_bet, self.stack)
            if bet_amount == current_bet:
                print(f"AI Player calls with a weak hand: {bet_amount}")
            else:
                print(f"AI Player checks with a weak hand: {bet_amount}")

        self.stack -= bet_amount
        return bet_amount

    @staticmethod
    def ai_discard_strategy(hand: List[Card]) -> List[int]:
        ranks = [card.rank.value for card in hand]
        rank_counts = Counter(ranks)
        for rank, count in rank_counts.items():  # If there are four cards of the same rank, keep them all
            if count == 4:
                return []
        for rank, count in rank_counts.items():  # If there are three cards of the same rank, keep them all
            if count == 3:
                return []
        if list(rank_counts.values()).count(2) == 2:  # If there are two pairs, keep them all
            return []
        discard_indices = [index for index, rank in enumerate(ranks) if
                           rank != max(ranks)]  # Otherwise, discard all but the highest card
        return discard_indices
