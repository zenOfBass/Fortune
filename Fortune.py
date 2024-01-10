import asyncio
import sys
from AIDealer import AIDealer


def main():
    numPlayers = input("Enter the number of players (2-5): ")          # Get the number of players from user input
    while not numPlayers.isdigit() or not (2 <= int(numPlayers) <= 5): # Validate the user input
        print("Invalid input. Please enter a valid number between 2 and 5.")
        numPlayers = input("Enter the number of players (2-5): ")
    asyncio.run(AIDealer().PlayFortune(int(numPlayers)))               # Start the game with the specified number of players
    replay = input("Do you want to start a new game? (yes/no): ")     # Ask if the user wants to play another game
    if replay.lower() == 'yes':
        main()
    elif replay.lower() == 'no':
        sys.exit()

if __name__ == "__main__":
    main()