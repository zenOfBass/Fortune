import asyncio
import random
from typing import List
from Card import Card, Rank, Suit
from GameState import GameState
from Players import AIPlayer, Player
from Observer import Observer, Subject


class AIDealer(AIPlayer, Subject):
    observers: List[Observer] = []

    def __init__(self):
        super().__init__(hand = [], stack = 100)  # Provide default values for hand and stack

    def Attach(self, observer: Observer) -> None:
        self.observers.append(observer)

    def Detach(self, observer: Observer) -> None:
        self.Notify("NULL")
        self.observers.remove(observer)

    def Notify(self, newPhase: str) -> None:
        for observer in self.observers:
            observer.Update(self, newPhase)

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

        # Create one human player (player 1)
        humanPlayer = Player(hand=[], stack=100)
        players = [humanPlayer]

        # Create the rest of the players as AI players
        for _ in range(numPlayers - 1):
            aiPlayer = AIPlayer(hand=[], stack=100)
            players.append(aiPlayer)

        gameState = GameState(deck=deck,
                            players=players,
                            pot=0,
                            gamePhase="NULL",
                            numPlayers=numPlayers,
                            activePlayers=list(range(numPlayers)))
        self.Attach(gameState)

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
                self.Detach(gameState)
                return  # Exit to "main menu" (lol)

    async def ANTE(self, gameState: GameState) -> None:
        self.Notify("ANTE")
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
        self.Notify("DEALING")

        print(f"Dealing!")

        for i in range(gameState.numPlayers):
            gameState.players[i].hand = await self.DealCards(gameState, 5)

    async def BETTING(self, gameState: GameState) -> None:
        self.Notify("BETTING")

        for i, player in enumerate(gameState.players):
            print(
                f"Player {i + 1}'s hand: {', '.join(str(card) for card in player.hand)}")

        currentBet = 1  # Set the initial bet to the ante amount
        gameState.activePlayers = list(
            range(gameState.numPlayers))  # Track active players

        for i, player in enumerate(gameState.players):
            if i == 0:  # Human Player (player 1)
                while True:
                    action = input(
                        f"Player {i + 1}, current bet is {currentBet}. Choose action (check/fold/call/raise): ").lower()
                    if action == "check":
                        # Do nothing, as checking is allowed only if no previous bets
                        betAmount = currentBet
                        break
                    elif action == "fold":
                        print(f"Player {i + 1} folds!")
                        gameState.activePlayers.remove(i)
                        break
                    elif action == "call":
                        betAmount = currentBet
                        print(f"Player {i + 1} calls with {betAmount}.")
                        break
                    elif action == "raise":
                        minRaise = currentBet * 2
                        raiseAmount = int(
                            input(f"Enter your raise amount (minimum {minRaise}): "))
                        if raiseAmount < minRaise:
                            print(
                                f"Invalid raise amount. Must be at least {minRaise}. Try again.")
                        else:
                            betAmount = raiseAmount
                            print(
                                f"Player {i + 1} raises by {raiseAmount - currentBet}.")
                            currentBet = raiseAmount
                            break
                    else:
                        print(
                            "Invalid action. Please choose check, fold, call, or raise.")
            else:
                # Implement AI betting logic
                betAmount = self.AIBettingStrategy(currentBet)

            if betAmount > currentBet:
                currentBet = betAmount

    async def DRAW(self, gameState: GameState) -> None:
        self.Notify("DRAW")

        for i in gameState.activePlayers:
            if i == 0:  # Human Player (player 1)
                while True:
                    discardIndices = input(
                        f"Player {i + 1}, enter the indices of the cards to discard (1-5, separated by spaces): ")
                    discardIndices = discardIndices.split()
                    try:
                        discardIndices = [
                            int(index) - 1 for index in discardIndices]
                        if all(0 <= index <= 4 for index in discardIndices):
                            break
                        else:
                            print(
                                "Invalid input. Please enter numbers between 1 and 5.")
                    except ValueError:
                        print(
                            "Invalid input. Please enter valid numbers separated by spaces.")
                await self.DrawCards(gameState, i, discardIndices)
            else:
                aiPlayer = gameState.players[i]
                discardIndices = self.AIDiscardStrategy(aiPlayer.hand)
                await self.DrawCards(gameState, i, discardIndices)

    async def SHOWDOWN(self, gameState: GameState) -> None:
        self.Notify("SHOWDOWN")

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