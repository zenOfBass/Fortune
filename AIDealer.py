import asyncio
import random
from Card import Card, Rank, Suit
from GameState import GameState
from Players import AIPlayer, Player


class AIDealer(AIPlayer):
    def __init__(self):
        super().__init__(hand = [], stack = 100)  # Provide default values for hand and stack

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
        deck = await self.CreateDeck()
        players = [Player(hand = [], stack = 100) for _ in range(numPlayers)]
        gameState = GameState(deck = deck,
                            players = players,
                            pot = 0,
                            numPlayers = numPlayers,
                            activePlayers = [0, 1, 2, 3])

        while True:
            await self.ANTE(gameState)
            await self.DEALING(gameState)
            await self.BETTING(gameState)
            await self.DRAW(gameState)
            await self.BETTING(gameState)
            await self.SHOWDOWN(gameState)
            
            playAgain = input("Do you want to play another round? (yes/no): ")
            if playAgain.lower() == 'yes':
                await self.ShuffleAllToDeck(gameState)
            elif playAgain.lower() == 'no':
                return # Exit to "main menu" (lol)

    async def ANTE(self, gameState: GameState) -> None:
        anteAmount = 1
        gameState.pot = 0  # Initialize the pot
        anteQueue = asyncio.Queue()  # Use an asynchronous queue to handle the ante contributions

        # Function to simulate a player's contribution
        async def antePlayer(player):
            await anteQueue.put(anteAmount)  # Add the ante amount to the pot

        tasks = [antePlayer(player) for player in gameState.players]
        await asyncio.gather(*tasks)  # Wait for all players to contribute to the pot
        print("Gathering ante into pot!")

        for _ in range(len(gameState.players)):
            gameState.pot += await anteQueue.get()

    async def DEALING(self, gameState: GameState) -> None:
        print(f"Dealing!")
        for i in range(gameState.numPlayers):
            gameState.players[i].hand = await self.DealCards(gameState, 5)
        for i, player in enumerate(gameState.players):
                print(f"Player {i + 1}'s hand: {', '.join(str(card) for card in player.hand)}")

    async def BETTING(self, gameState: GameState) -> None:
        currentBet = 1  # Set the initial bet to the ante amount
        gameState.activePlayers = list(range(gameState.numPlayers))  # Track active players

        for i in range(gameState.numPlayers):
            if i == gameState.numPlayers - 1:  # AI Player
                # Implement AI betting logic
                betAmount = self.AIBettingStrategy(currentBet)
            else:
                # Human player input
                betAmount = int(input(f"Player {i + 1}, current bet is {currentBet}. Enter your bet (0 to check, -1 to fold): "))
                if betAmount == -1:
                    print(f"Player {i + 1} folds!")
                    gameState.activePlayers.remove(i)
                    continue
                elif betAmount < currentBet:
                    print(f"Invalid bet. Must be at least {currentBet}. Try again.")
                    i -= 1
                    continue
            if betAmount > currentBet:
                currentBet = betAmount

    async def DRAW(self, gameState: GameState) -> None:
        for i in gameState.activePlayers:
            if i == gameState.numPlayers - 1:
                aiPlayer = gameState.players[i]
                discardIndices = self.AIDiscardStrategy(aiPlayer.hand)
                await self.DrawCards(gameState, i, discardIndices)
            else:
                while True:
                    discardIndices = input(f"Player {i + 1}, enter the indices of the cards to discard (1-5, separated by spaces): ")
                    discardIndices = discardIndices.split()
                    try:
                        discardIndices = [
                            int(index) - 1 for index in discardIndices]
                        if all(0 <= index <= 4 for index in discardIndices):
                            break
                        else:
                            print("Invalid input. Please enter numbers between 1 and 5.")
                    except ValueError:
                        print("Invalid input. Please enter valid numbers separated by spaces.")
                await self.DrawCards(gameState, i, discardIndices)

    async def SHOWDOWN(self, gameState: GameState) -> None:
        for i in gameState.activePlayers:
            player = gameState.players[i]
            if isinstance(player, AIPlayer):
                playerType = "AI Player"
            else:
                playerType = "Player"
            print(f"{playerType} {i + 1}'s final hand: {', '.join(str(card) for card in player.hand)}")

        handRanks = [GameState.RankHand(gameState.players[i].hand) for i in gameState.activePlayers]
        maxRank = max(handRanks)
        winnerIdx = handRanks.index(maxRank)
        winner = gameState.players[gameState.activePlayers[winnerIdx]]
        print(f"Player {gameState.activePlayers[winnerIdx] + 1} wins with a {', '.join(str(card) for card in winner.hand)}!")
        winner.stack += gameState.pot