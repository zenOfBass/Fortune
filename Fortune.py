import asyncio
import random
from collections import Counter
from dataclasses import dataclass
from enum import Enum, auto
from typing import List, Tuple

class Suit(Enum):
    SWORDS = " of Swords"
    CUPS = " of Cups"
    PENTACLES = " of Pentacles"
    WANDS = " of Wands"

class Rank(Enum):
    PAGE = 0
    TWO = 2
    THREE = 3
    FOUR = 4
    FIVE = 5
    SIX = 6
    SEVEN = 7
    EIGHT = 8
    NINE = 9
    TEN = 10
    KNIGHT = 11
    QUEEN = 12
    KING = 13
    ACE = 14

@dataclass
class Card:
    suit: Suit
    rank: Rank

    def __str__(self):
        return f"{self.rank.name.capitalize()}{self.suit.value}"

@dataclass
class GameState:
    deck: List[Card]
    players: List[List[Card]]

# @dataclass
# class GamePhase(Enum):
#     ANTE = auto()
#     BETTING = auto()
#     DRAW = auto()
#     SHOWDOWN = auto()

def create_deck() -> List[Card]:
    return [Card(suit, rank) for suit in Suit for rank in Rank]

async def shuffle_deck(deck: List[Card]) -> List[Card]:
    await asyncio.sleep(0)  # simulating asynchronous behavior
    random.shuffle(deck)
    return deck

async def deal_cards(game_state: GameState, num_cards: int) -> List[Card]:
    new_cards = []
    for _ in range(num_cards):
        card = game_state.deck.pop()
        new_cards.append(card)
    return new_cards

def rank_hand(hand: List[Card]) -> Tuple[int, List[int]]:
    ranks = [card.rank.value for card in hand]
    
    if set(ranks) == {0, 10, 11, 12, 13}:                 # Convert placeholder back to 0 for Page
        ranks.remove(0)
        ranks.append(-1)                                  # Add a placeholder for Page (to be converted to 0 later)
    ranks.sort(reverse=True)                              # Sort ranks in descending order
    ranks = [rank if rank != -1 else 0 for rank in ranks] # Convert placeholder back to 0 for Page

    suits = [card.suit for card in hand]
    rank_counts = Counter(ranks)
    is_flush = len(set(suits)) == 1
    is_straight = len(set(ranks)) == 5 and max(ranks) - min(ranks) == 4

    if is_flush and is_straight:
        if max(ranks) == 14:
            return (10, ranks) # Royal Flush
        else:
            return (9, ranks)  # Straight Flush
    elif max(rank_counts.values()) == 4:
        return (8, ranks)  # Four of a Kind
    elif max(rank_counts.values()) == 3 and len(rank_counts) == 2:
        return (7, ranks)  # Full House
    elif is_flush:
        return (6, ranks)  # Flush
    elif is_straight:
        return (5, ranks)  # Straight
    elif max(rank_counts.values()) == 3:
        return (4, ranks)  # Three of a Kind
    elif list(rank_counts.values()).count(2) == 2:
        return (3, ranks)  # Two Pair
    elif list(rank_counts.values()).count(2) == 1:
        return (2, ranks)  # One Pair
    else:
        return (1, ranks)  # High Card

async def draw_cards(game_state: GameState, player_idx: int, discard_indices: List[int]) -> None:
    player_hand = game_state.players[player_idx]
    for index in sorted(discard_indices, reverse=True):
        del player_hand[index]
    new_cards = await deal_cards(game_state, len(discard_indices))
    game_state.players[player_idx] = player_hand + new_cards

def ai_discard_strategy(hand: List[Card]) -> List[int]: # Define a basic AI strategy for discarding cards
    ranks = [card.rank.value for card in hand]
    rank_counts = Counter(ranks)
    for rank, count in rank_counts.items(): # If there are four cards of the same rank, keep them all
        if count == 4:
            return []
    for rank, count in rank_counts.items(): # If there are three cards of the same rank, keep them all
        if count == 3:
            return []
    if list(rank_counts.values()).count(2) == 2: # If there are two pairs, keep them all
        return []
    discard_indices = [index for index, rank in enumerate(ranks) if rank != max(ranks)] # Otherwise, discard all but the highest card
    return discard_indices

async def ai_player(game_state: GameState, player_idx: int) -> None:
    player_hand = game_state.players[player_idx]
    discard_indices = ai_discard_strategy(player_hand)
    await draw_cards(game_state, player_idx, discard_indices)

async def play_game(num_players: int) -> None:
    while True:
        # current_phase = GamePhase.ANTE
        deck = await shuffle_deck(create_deck())
        game_state = GameState(deck=deck, players=[[] for _ in range(num_players)])

        for i in range(num_players):
            game_state.players[i] = await deal_cards(game_state, 5)
        for i, player_hand in enumerate(game_state.players):
            print(f"Player {i + 1}'s hand: {', '.join(str(card) for card in player_hand)}")

        for i in range(num_players):
            if i == num_players - 1:
                await ai_player(game_state, i) # AI dealer's turn
            else:
                while True:
                    discard_indices = input(f"Player {i + 1}, enter the indices of the cards to discard (0-4, separated by spaces): ")
                    discard_indices = discard_indices.split()
                    try:
                        discard_indices = [int(index) for index in discard_indices]
                        if all(0 <= index <= 4 for index in discard_indices):
                            break
                        else:
                            print("Invalid input. Please enter numbers between 0 and 4.")
                    except ValueError:
                        print("Invalid input. Please enter valid numbers separated by spaces.")
                await draw_cards(game_state, i, discard_indices)

        for i, player_hand in enumerate(game_state.players):
            print(f"Player {i + 1}'s final hand: {', '.join(str(card) for card in player_hand)}")
        hand_ranks = [rank_hand(hand) for hand in game_state.players]
        max_rank = max(hand_ranks)
        winner_idx = hand_ranks.index(max_rank)
        print(f"Player {winner_idx + 1} wins with a {', '.join(str(card) for card in game_state.players[winner_idx])}!")
        # play_again = input("Do you want to play another round? (yes/no): ")
        # if play_again.lower() != 'yes':
        #    break

if __name__ == "__main__":
    while True:
        num_players = input("Enter the number of players (2-4): ")
        while not num_players.isdigit() or not (2 <= int(num_players) <= 4):
            print("Invalid input. Please enter a valid number between 2 and 4.")
            num_players = input("Enter the number of players (2-4): ")
        asyncio.run(play_game(int(num_players)))

        replay = input("Do you want to play another game? (yes/no): ")
        if replay.lower() != 'yes':
            break
