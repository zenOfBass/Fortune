import asyncio
import sys
from AIDealer import AIDealer


def main():
    num_players = input("Enter the number of players (2-5): ")  # Get the number of players from user input
    while not num_players.isdigit() or not (2 <= int(num_players) <= 5):  # Validate the user input
        print("Invalid input. Please enter a valid number between 2 and 5.")
        num_players = input("Enter the number of players (2-5): ")
    asyncio.run(AIDealer().play_fortune(int(num_players)))  # Start the game with the specified number of players
    replay = input("Do you want to start a new game? (yes/no): ")  # Ask if the user wants to play another game
    if replay.lower() == 'yes':
        main()
    elif replay.lower() == 'no':
        sys.exit()


if __name__ == "__main__":
    main()
