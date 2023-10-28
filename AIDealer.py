import asyncio
import random
from Card import Card, Rank, Suit
from GameState import GamePhase, GameState
from Players import AIPlayer, Player


class AIDealer(AIPlayer):
    def __init__(self):
        super().__init__(hand=[], stack=100)  # Provide default values for hand and stack

    async def CreateDeck(self):
        print("Opening a new deck!")
        newDeck = [Card(suit, rank) for suit in Suit for rank in Rank]
        await self.ShuffleDeck(newDeck)
        return newDeck

    async def ShuffleDeck(self, deck):
        print("Shuffling up!")
        await asyncio.to_thread(random.shuffle, deck)
        return deck

    async def ShuffleAllToDeck(self, gameState):
        allCards = [card for player in gameState.players for card in player.hand]
        gameState.deck.extend(allCards)
        return await self.ShuffleDeck(gameState.deck)

    async def DealCards(self, gameState, numCards):
        newCards = []
        if numCards > len(gameState.deck):
            await self.ShuffleAllToDeck(gameState)
        print("Dealing!")
        for _ in range(numCards):
            card = gameState.deck.pop()
            newCards.append(card)
        return newCards

    async def DrawCards(self, gameState, playerIdx, discardIndices):
        playerHand = gameState.players[playerIdx].hand
        if not all(0 <= index < len(playerHand) for index in discardIndices):
            print("Invalid indices. Please enter valid numbers between 0 and 4.")
            return
        for index in sorted(discardIndices, reverse=True):
            del playerHand[index]
        print(f"Player {playerIdx + 1} discarded {len(discardIndices)} card(s).")
        newCards = await self.DealCards(gameState, len(discardIndices))
        gameState.players[playerIdx].hand = playerHand + newCards
        print(f"Drew {len(discardIndices)} new card(s) for player {playerIdx + 1}.")

    async def PlayFortune(self, numPlayers):
        newDeck = await self.CreateDeck()
        players = [Player(hand=[], stack=100) for _ in range(numPlayers)]
        gameState = GameState(deck=newDeck,
                            players=players,
                            gamePhase=GamePhase.ANTE,
                            pot=0)
        while True:
            for i in range(numPlayers):
                gameState.players[i].hand = await self.DealCards(gameState, 5)
            for i, player in enumerate(gameState.players):
                print(f"Player {i + 1}'s hand: {', '.join(str(card) for card in player.hand)}")
            for i in range(numPlayers):
                if i == numPlayers - 1:
                    aiPlayer = gameState.players[i]
                    discardIndices = self.AIDiscardStrategy(aiPlayer.hand)
                    await self.DrawCards(gameState, i, discardIndices)
                else:
                    while True:
                        discardIndices = input(f"Player {i + 1}, enter the indices of the cards to discard (1-5, separated by spaces): ")
                        discardIndices = discardIndices.split()
                        try:
                            discardIndices = [int(index) - 1 for index in discardIndices]
                            if all(0 <= index <= 4 for index in discardIndices):
                                break
                            else:
                                print("Invalid input. Please enter numbers between 1 and 5.")
                        except ValueError:
                            print("Invalid input. Please enter valid numbers separated by spaces.")
                    await self.DrawCards(gameState, i, discardIndices)
            for i, player in enumerate(gameState.players):
                if isinstance(player, AIPlayer):
                    player_type = "AI Player"
                else:
                    player_type = "Player"
                print(f"{player_type} {i + 1}'s final hand: {', '.join(str(card) for card in player.hand)}")
            handRanks = [GameState.RankHand(player.hand) for player in gameState.players]
            maxRank = max(handRanks)
            winnerIdx = handRanks.index(maxRank)
            print(f"Player {winnerIdx + 1} wins with a {', '.join(str(card) for card in gameState.players[winnerIdx].hand)}!")
            playAgain = input("Do you want to play another round? (yes/no): ")
            if playAgain.lower() == 'yes':
                await self.ShuffleAllToDeck(gameState)
            elif playAgain.lower() == 'no':
                return # Exit to "main menu" (lol)