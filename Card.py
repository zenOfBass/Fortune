from dataclasses import dataclass
from enum import Enum


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

@dataclass # Marks this class as a data class, which provides special methods like __init__ and __repr__ automatically.
class Card:
    suit: Suit                                                   # Defines a property 'suit' of type Suit. This will store the suit of the card.
    rank: Rank                                                   # Defines a property 'rank' of type Rank. This will store the rank of the card.
    def __str__(self):                                           # This method defines how the card will be converted to a string when using str(card).
        return f"{self.rank.name.capitalize()}{self.suit.value}" # It returns a formatted string, e.g., "Ace of Swords".