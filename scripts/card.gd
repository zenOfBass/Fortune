class_name Card
extends RefCounted

enum Suit { SWORDS, CUPS, PENTACLES, WANDS }

enum Rank {
	PAGE   = 0,
	TWO    = 2,
	THREE  = 3,
	FOUR   = 4,
	FIVE   = 5,
	SIX    = 6,
	SEVEN  = 7,
	EIGHT  = 8,
	NINE   = 9,
	TEN    = 10,
	KNIGHT = 11,
	QUEEN  = 12,
	KING   = 13,
	ACE    = 14,
}

# Keyed by raw int value of the enum.
const RANK_DISPLAY := {
	0: "Page", 2: "2", 3: "3", 4: "4", 5: "5", 6: "6",
	7: "7", 8: "8", 9: "9", 10: "10",
	11: "Knight", 12: "Queen", 13: "King", 14: "Ace",
}

const SUIT_DISPLAY := {
	0: "Swords", 1: "Cups", 2: "Pentacles", 3: "Wands"
}

# Asset filenames match the purchased sprite sheet naming convention:
# e.g.  res://assets/cards/minor/ace_of_cups.png
const RANK_ASSET := {
	0: "page", 2: "2", 3: "3", 4: "4", 5: "5", 6: "6",
	7: "7", 8: "8", 9: "9", 10: "10",
	11: "knight", 12: "queen", 13: "king", 14: "ace",
}

const SUIT_ASSET := {
	0: "swords", 1: "cups", 2: "pentacles", 3: "wands"
}

var suit: Suit
var rank: Rank

func _init(s: Suit, r: Rank) -> void:
	suit = s
	rank = r

func display_name() -> String:
	return "%s of %s" % [RANK_DISPLAY[rank], SUIT_DISPLAY[suit]]

func texture_path() -> String:
	return "res://assets/cards/minor/%s_of_%s.png" % [RANK_ASSET[rank], SUIT_ASSET[suit]]

# ---- Serialization (for mid-match save state) -------------------------------

func to_pair() -> Array:
	return [int(suit), int(rank)]

static func from_pair(p: Array) -> Card:
	return Card.new(int(p[0]) as Suit, int(p[1]) as Rank)
