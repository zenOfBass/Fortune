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

def CreateDeck() -> List[Card]:
    return [Card(suit, rank) for suit in Suit for rank in Rank]

async def ShuffleDeck(deck: List[Card]) -> List[Card]:
    await asyncio.sleep(0)  # simulating asynchronous behavior
    random.shuffle(deck)
    return deck

async def DealCards(gameState: GameState, numCards: int) -> List[Card]:
    newCards = []
    for _ in range(numCards):
        card = gameState.deck.pop()
        newCards.append(card)
    return newCards

def RankHand(hand: List[Card]) -> Tuple[int, List[int]]:
    ranks = [card.rank.value for card in hand]
    
    if set(ranks) == {0, 10, 11, 12, 13}:                 # Convert placeholder back to 0 for Page
        ranks.remove(0)
        ranks.append(-1)                                  # Add a placeholder for Page (to be converted to 0 later)
    ranks.sort(reverse=True)                              # Sort ranks in descending order
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
        return (8, ranks)  # Four of a Kind
    elif max(rankCounts.values()) == 3 and len(rankCounts) == 2:
        return (7, ranks)  # Full House
    elif isFlush:
        return (6, ranks)  # Flush
    elif isStraight:
        return (5, ranks)  # Straight
    elif max(rankCounts.values()) == 3:
        return (4, ranks)  # Three of a Kind
    elif list(rankCounts.values()).count(2) == 2:
        return (3, ranks)  # Two Pair
    elif list(rankCounts.values()).count(2) == 1:
        return (2, ranks)  # One Pair
    else:
        return (1, ranks)  # High Card

async def DrawCards(gameState: GameState, playerIdx: int, discardIndices: List[int]) -> None:
    playerHand = gameState.players[playerIdx]
    for index in sorted(discardIndices, reverse=True):
        del playerHand[index]
    newCards = await DealCards(gameState, len(discardIndices))
    gameState.players[playerIdx] = playerHand + newCards

def AIDiscardStrategy(hand: List[Card]) -> List[int]: # Define a basic AI strategy for discarding cards
    ranks = [card.rank.value for card in hand]
    rankCounts = Counter(ranks)
    for rank, count in rankCounts.items(): # If there are four cards of the same rank, keep them all
        if count == 4:
            return []
    for rank, count in rankCounts.items(): # If there are three cards of the same rank, keep them all
        if count == 3:
            return []
    if list(rankCounts.values()).count(2) == 2: # If there are two pairs, keep them all
        return []
    discardIndices = [index for index, rank in enumerate(ranks) if rank != max(ranks)] # Otherwise, discard all but the highest card
    return discardIndices

async def AIPlayer(gameState: GameState, playerIdx: int) -> None:
    playerHand = gameState.players[playerIdx]
    discardIndices = AIDiscardStrategy(playerHand)
    await DrawCards(gameState, playerIdx, discardIndices)

async def PlayGame(numPlayers: int) -> None:
    while True:
        # currentPhase = GamePhase.ANTE
        deck = await ShuffleDeck(CreateDeck())
        gameState = GameState(deck=deck, players=[[] for _ in range(numPlayers)])
        for i in range(numPlayers):
            gameState.players[i] = await DealCards(gameState, 5)
        for i, playerHand in enumerate(gameState.players):
            print(f"Player {i + 1}'s hand: {', '.join(str(card) for card in playerHand)}")

        for i in range(numPlayers):
            if i == numPlayers - 1:
                await AIPlayer(gameState, i) # AI dealer's turn
            else:
                while True:
                    discardIndices = input(f"Player {i + 1}, enter the indices of the cards to discard (0-4, separated by spaces): ")
                    discardIndices = discardIndices.split()
                    try:
                        discardIndices = [int(index) for index in discardIndices]
                        if all(0 <= index <= 4 for index in discardIndices):
                            break
                        else:
                            print("Invalid input. Please enter numbers between 0 and 4.")
                    except ValueError:
                        print("Invalid input. Please enter valid numbers separated by spaces.")
                await DrawCards(gameState, i, discardIndices)

        for i, playerHand in enumerate(gameState.players):
            print(f"Player {i + 1}'s final hand: {', '.join(str(card) for card in playerHand)}")
        handRanks = [RankHand(hand) for hand in gameState.players]
        maxRank = max(handRanks)
        winnerIdx = handRanks.index(maxRank)
        print(f"Player {winnerIdx + 1} wins with a {', '.join(str(card) for card in gameState.players[winnerIdx])}!")
        # playAgain = input("Do you want to play another round? (yes/no): ")
        # if playAgain.lower() != 'yes':
        #    break

if __name__ == "__main__":
    while True:
        numPlayers = input("Enter the number of players (2-4): ")
        while not numPlayers.isdigit() or not (2 <= int(numPlayers) <= 4):
            print("Invalid input. Please enter a valid number between 2 and 4.")
            numPlayers = input("Enter the number of players (2-4): ")
        asyncio.run(PlayGame(int(numPlayers)))

        replay = input("Do you want to play another game? (yes/no): ")
        if replay.lower() != 'yes':
            break