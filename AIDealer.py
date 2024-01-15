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
        super().__init__(hand=[], stack=100)  # Provide default values for hand and stack

    def attach(self, observer: Observer) -> None:
        self.observers.append(observer)

    def detach(self, observer: Observer) -> None:
        self.notify("NULL")
        self.observers.remove(observer)

    def notify(self, new_phase: str) -> None:
        for observer in self.observers:
            observer.update(self, new_phase)

    async def create_deck(self):
        print("Opening a new deck!")
        new_deck = {Card(suit, rank) for suit in Suit for rank in Rank}
        await self.shuffle_deck(new_deck)
        return new_deck

    @staticmethod
    async def shuffle_deck(deck):
        print("Shuffling up!")
        await asyncio.to_thread(random.shuffle, deck)
        return deck

    async def shuffle_all_to_deck(self, game_state):
        all_cards = [card for player in game_state.players for card in player.hand]
        game_state.deck.extend(all_cards)
        return await self.shuffle_deck(game_state.deck)

    async def deal_cards(self, game_state, num_cards):
        new_cards = []
        if num_cards > len(game_state.deck):
            await self.shuffle_all_to_deck(game_state)
        for _ in range(num_cards):
            card = game_state.deck.pop()
            new_cards.append(card)
        return new_cards

    async def draw_cards(self, game_state, player_idx, discard_indices):
        player_hand = game_state.players[player_idx].hand
        if not all(0 <= index < len(player_hand) for index in discard_indices):
            print("Invalid indices. Please enter valid numbers between 0 and 4.")
            return
        for index in sorted(discard_indices, reverse=True):
            del player_hand[index]
        print(f"Player {player_idx + 1} discarded {len(discard_indices)} card(s).")
        new_cards = await self.deal_cards(game_state, len(discard_indices))
        game_state.players[player_idx].hand = player_hand + new_cards
        print(f"Drew {len(discard_indices)} new card(s) for player {player_idx + 1}.")

    async def play_fortune(self, num_players):
        deck = await self.create_deck()

        # Create one human player (player 1)
        human_player = Player(hand=[], stack=100)
        players = [human_player]

        # Create the rest of the players as AI players
        for _ in range(num_players - 1):
            ai_player = AIPlayer(hand=[], stack=100)
            players.append(ai_player)

        game_state = GameState(deck=list(deck),  # Convert set to list
                               players=players,
                               pot=0,
                               gamePhase="NULL",
                               numPlayers=num_players,
                               activePlayers=list(range(num_players)))
        self.attach(game_state)

        while True:
            await self.ante(game_state)
            await self.dealing(game_state)
            await self.betting(game_state)
            await self.draw(game_state)
            await self.betting(game_state)
            await self.showdown(game_state)

            play_again = input("Do you want to play another round? (yes/no): ")
            if play_again.lower() == 'yes':
                await self.shuffle_all_to_deck(game_state)
            elif play_again.lower() == 'no':
                self.detach(game_state)
                return  # Exit to "main menu" (lol)

    async def ante(self, game_state: GameState) -> None:
        self.notify("ANTE")
        ante_amount = 1
        game_state.pot = 0  # Initialize the pot
        ante_queue = asyncio.Queue()  # Use an asynchronous queue to handle the ante contributions

        # Function to simulate a player's contribution
        async def ante_player(player):
            await ante_queue.put(ante_amount)  # Add the ante amount to the pot

        tasks = [ante_player(player) for player in game_state.players]
        await asyncio.gather(*tasks)  # Wait for all players to contribute to the pot
        print("Gathering ante into pot!")

        for _ in range(len(game_state.players)):
            game_state.pot += await ante_queue.get()

    async def dealing(self, game_state: GameState) -> None:
        self.notify("DEALING")

        print(f"Dealing!")

        for i in range(game_state.numPlayers):
            game_state.players[i].hand = await self.deal_cards(game_state, 5)

    async def betting(self, game_state: GameState) -> None:
        self.notify("BETTING")

        print(f"Player 1's hand: {', '.join(str(card) for card in game_state.players[0].hand)}")

        # # This loop will print all players hands for debugging
        for i, player in enumerate(game_state.players):
            print(f"Player {i + 1}'s hand: {', '.join(str(card) for card in player.hand)}")

        current_bet = 1  # Set the initial bet to the ante amount
        game_state.activePlayers = list(range(game_state.numPlayers))  # Track active players

        for i, player in enumerate(game_state.players):
            if i == 0:  # Human Player (player 1)
                while True:
                    action = input(
                        f"Player {i + 1}, current bet is {current_bet}. Choose action (check/fold/call/raise): ").lower()
                    if action == "check":
                        # Do nothing, as checking is allowed only if no previous bets
                        bet_amount = current_bet
                        break
                    elif action == "fold":
                        print(f"Player {i + 1} folds!")
                        game_state.activePlayers.remove(i)
                        break
                    elif action == "call":
                        bet_amount = current_bet
                        print(f"Player {i + 1} calls with {bet_amount}.")
                        break
                    elif action == "raise":
                        min_raise = current_bet * 2
                        raise_amount = int(input(f"Enter your raise amount (minimum {min_raise}): "))
                        if raise_amount < min_raise:
                            print(f"Invalid raise amount. Must be at least {min_raise}. Try again.")
                        else:
                            bet_amount = raise_amount
                            print(f"Player {i + 1} raises by {raise_amount - current_bet}.")
                            current_bet = raise_amount
                            break
                    else:
                        print("Invalid action. Please choose check, fold, call, or raise.")
            else:
                # Implement AI betting logic
                bet_amount = self.ai_betting_strategy(current_bet)

            if bet_amount > current_bet:
                current_bet = bet_amount

    async def draw(self, game_state: GameState) -> None:
        self.notify("DRAW")

        for i in game_state.activePlayers:
            if i == 0:  # Human Player (player 1)
                while True:
                    discard_indices = input(
                        f"Player {i + 1}, enter the indices of the cards to discard (1-5, separated by spaces): ")
                    discard_indices = discard_indices.split()
                    try:
                        discard_indices = [int(index) - 1 for index in discard_indices]
                        if all(0 <= index <= 4 for index in discard_indices):
                            break
                        else:
                            print("Invalid input. Please enter numbers between 1 and 5.")
                    except ValueError:
                        print("Invalid input. Please enter valid numbers separated by spaces.")
                await self.draw_cards(game_state, i, discard_indices)
            else:
                ai_player = game_state.players[i]
                discard_indices = self.ai_discard_strategy(ai_player.hand)
                await self.draw_cards(game_state, i, discard_indices)

    async def showdown(self, game_state: GameState) -> None:
        self.notify("SHOWDOWN")

        for i in game_state.activePlayers:
            player = game_state.players[i]
            if isinstance(player, AIPlayer):
                player_type = "AI Player"
            else:
                player_type = "Player"
            print(f"{player_type} {i + 1}'s final hand: {', '.join(str(card) for card in player.hand)}")

        hand_ranks = [GameState.rank_hand(game_state.players[i].hand) for i in game_state.activePlayers]
        max_rank = max(hand_ranks)
        winner_idx = hand_ranks.index(max_rank)
        winner = game_state.players[game_state.activePlayers[winner_idx]]
        print(
            f"Player {game_state.activePlayers[winner_idx] + 1} wins with a {', '.join(str(card) for card in winner.hand)}!")
        winner.stack += game_state.pot
