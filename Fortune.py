import asyncio
import random
import sys
from Players import Player, AIPlayer
from Card import Card, Suit, Rank
from collections import Counter
from dataclasses import dataclass
from enum import Enum, auto
from typing import List, Tuple


@dataclass
class GamePhase(Enum):
    ANTE = auto()
    DEALING = auto()
    BETTING = auto()
    FOLDING = auto()
    DRAW = auto()
    SHOWDOWN = auto()

@dataclass
class GameState:
    deck: List[Card]      # Defines a property 'deck' of type List[Card]. This will store the deck of cards in the game.
    players: List[Player] # Defines a property 'players' of type List[List[Card]]. This will store the hands of all players.
    gamePhase: GamePhase
    pot: int              # Integer value representing the total chips in the pot

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

async def CreateDeck() -> List[Card]:                              # 4 suits * 14 cards = a deck of 56 cards
    print("Opening a new deck!")
    newDeck = [Card(suit, rank) for suit in Suit for rank in Rank] # Declare a list of Card objects, one for each combination of Suit and Rank.
    ShuffleDeck(newDeck)
    return newDeck                                                 # Returns a list of Card objects, one for each combination of Suit and Rank.

async def ShuffleDeck(deck: List[Card]) -> List[Card]:
    print("Shuffling up!")
    await asyncio.to_thread(random.shuffle, deck) # Shuffle asynchronously 
    return deck

async def ShuffleAllToDeck(gameState: GameState) -> List[Card]:
    allCards = [card for player in gameState.players for card in player.hand]
    gameState.deck.extend(allCards)
    return await ShuffleDeck(gameState.deck)

async def DealCards(gameState: GameState, numCards: int) -> List[Card]:
    newCards = []
    if numCards > len(gameState.deck):
        await ShuffleAllToDeck(gameState)
    print("Dealing!")
    for _ in range(numCards): # Draws 'numCards' from the 'gameState.deck' and adds them to the 'newCards' list.
        card = gameState.deck.pop()
        newCards.append(card)
    return newCards

async def DrawCards(gameState: GameState, playerIdx: int, discardIndices: List[int]) -> None:
    playerHand = gameState.players[playerIdx].hand                            # Access the 'hand' attribute of the Player
    if not all(0 <= index < len(playerHand) for index in discardIndices):         
        print("Invalid indices. Please enter valid numbers between 0 and 4.") # Check if the provided indices are valid
        return
    for index in sorted(discardIndices, reverse=True):                        # Discard selected cards
        del playerHand[index]
    print(f"Player {playerIdx + 1} discarded {len(discardIndices)} card(s).") # Print a message
    newCards = await DealCards(gameState, len(discardIndices))                # Draw new cards       
    gameState.players[playerIdx].hand = playerHand + newCards
    print(f"Drew {len(discardIndices)} new card(s) for player {playerIdx + 1} .")

async def PlayFortune(numPlayers: int) -> None:
    newDeck = await CreateDeck()
    players = [Player(hand=[], stack=100) for _ in range(numPlayers)]  # Initialize players with an empty hand and 100 chips
    gameState = GameState(deck = newDeck,                              # Create a game state with a new deck
                        players = players,                             # Set number of players
                        gamePhase = GamePhase.ANTE,                    # Set the game phase
                        pot = 0)                                       # Initial value for the betting pot
    while True:
        for i in range(numPlayers):                                        # Deal cards to each player
            gameState.players[i].hand = await DealCards(gameState, 5)
        for i, player in enumerate(gameState.players):                     # Display initial hands for each player
            print(f"Player {i + 1}'s hand: {', '.join(str(card) for card in player.hand)}")
        for i in range(numPlayers):                                        # Player turns and AI dealer's turn
            if i == numPlayers - 1:
                aiPlayer = gameState.players[i]                            # Get the AI player
                discardIndices = AIPlayer.AIDiscardStrategy(aiPlayer.hand) # Call AIDiscardStrategy
                await DrawCards(gameState, i, discardIndices)              # Execute the draw cards function to discard and replace the chosen cards.
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
        for i, player in enumerate(gameState.players):  # Display final hands for each player
            if isinstance(player, AIPlayer):
                player_type = "AI Player"
            else:
                player_type = "Player"
            print(f"{player_type} {i + 1}'s final hand: {', '.join(str(card) for card in player.hand)}")
        handRanks = [GameState.RankHand(player.hand) for player in gameState.players] # Determine the winner and display the result
        maxRank = max(handRanks)
        winnerIdx = handRanks.index(maxRank)
        print(f"Player {winnerIdx + 1} wins with a {', '.join(str(card) for card in gameState.players[winnerIdx].hand)}!")
        playAgain = input("Do you want to play another round? (yes/no): ")
        if playAgain.lower() == 'yes':
            await ShuffleAllToDeck(gameState) # Put all cards back into the deck and shuffle
        elif playAgain.lower() == 'no':
            return                            # Exit to "main menu" (lol)

def main():
    numPlayers = input("Enter the number of players (2-5): ")          # Get the number of players from user input
    while not numPlayers.isdigit() or not (2 <= int(numPlayers) <= 5): # Validate the user input
        print("Invalid input. Please enter a valid number between 2 and 5.")
        numPlayers = input("Enter the number of players (2-4): ")
    asyncio.run(PlayFortune(int(numPlayers)))                          # Start the game with the specified number of players
    replay = input("Do you want to play another game? (yes/no): ")     # Ask if the user wants to play another game
    if replay.lower() == 'yes':
        main()
    elif replay.lower() == 'no':
        sys.exit()

if __name__ == "__main__":
    main()