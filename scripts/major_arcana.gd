class_name MajorArcana
extends RefCounted

enum Effect {
	MODIFIER,     # Passive rule change for the whole round
	IMMEDIATE,    # Resolved instantly when drawn, no player choice required
	INTERACTIVE,  # Requires per-player decisions (handled by UI in phase 4)
	GAME_ENDER,   # Skips remaining phases and resolves the round now
	META,         # Special timing rules (Hierophant, The World)
}

const DATA: Array = [
	# id  name                  effect               description (short)
	{ "name": "The Fool",          "effect": Effect.IMMEDIATE,    "desc": "Wild-card flop — any player may use it as part of their hand." },
	{ "name": "The Magician",      "effect": Effect.INTERACTIVE,  "desc": "Each player guesses a suit; if correct they may keep the revealed card." },
	{ "name": "The High Priestess","effect": Effect.INTERACTIVE,  "desc": "All players turn one chosen card face up for the rest of the round." },
	{ "name": "The Empress",       "effect": Effect.IMMEDIATE,    "desc": "Each player draws a sixth card for this round." },
	{ "name": "The Emperor",       "effect": Effect.MODIFIER,     "desc": "Kings supersede Aces for card and hand ranking this round." },
	{ "name": "The Hierophant",    "effect": Effect.META,         "desc": "Stays on the table; cancels the next arcana drawn (not The World)." },
	{ "name": "The Lovers",        "effect": Effect.MODIFIER,     "desc": "The two best hands split the pot this round." },
	{ "name": "The Chariot",       "effect": Effect.INTERACTIVE,  "desc": "Each player passes one chosen card to the player on their left." },
	{ "name": "Strength",          "effect": Effect.MODIFIER,     "desc": "Card values inverted: 2 highest, Ace second-lowest. Page unaffected." },
	{ "name": "The Hermit",        "effect": Effect.MODIFIER,     "desc": "No draw phase — each player uses only the cards in their hand." },
	{ "name": "Wheel of Fortune",  "effect": Effect.IMMEDIATE,    "desc": "All cards in play are shuffled and redealt. New Pages don't trigger arcana." },
	{ "name": "Justice",           "effect": Effect.MODIFIER,     "desc": "Any bet amount is valid; excess above the call is returned to those who over-bet." },
	{ "name": "The Hanged Man",    "effect": Effect.MODIFIER,     "desc": "Players who go all-in draw one extra card." },
	{ "name": "Death",             "effect": Effect.GAME_ENDER,   "desc": "Hands are compared immediately." },
	{ "name": "Temperance",        "effect": Effect.INTERACTIVE,  "desc": "Discard one card each; pick from three face-up flop cards to complete your hand." },
	{ "name": "The Devil",         "effect": Effect.MODIFIER,     "desc": "Raises must be at least double the current bet." },
	{ "name": "The Tower",         "effect": Effect.IMMEDIATE,    "desc": "Half the pot (rounded up) is lost — it goes to no one." },
	{ "name": "The Star",          "effect": Effect.INTERACTIVE,  "desc": "In turn order, each player may swap one card with the top of the deck." },
	{ "name": "The Moon",          "effect": Effect.INTERACTIVE,  "desc": "Each player draws a hidden card; before showdown they may swap it for one in hand." },
	{ "name": "The Sun",           "effect": Effect.GAME_ENDER,   "desc": "The pot is split equally among all active players; remainder is lost." },
	{ "name": "Judgement",         "effect": Effect.INTERACTIVE,  "desc": "Folded players may pay the ante to draw five new cards and re-enter." },
	{ "name": "The World",         "effect": Effect.META,         "desc": "This is the last round of the game." },
]

# Filenames exactly match the purchased pixel-art asset names.
const TEXTURE_FILE: Array = [
	"the_fool", "magician", "priestess", "empress", "emperor", "hierophant",
	"the_lovers", "chariot", "strength", "the_hermit", "wheel_of_fortune", "justice",
	"the_hanged_man", "death", "temperance", "the_devil", "the_tower", "the_star",
	"the_moon", "the_sun", "judgement", "the_world",
]

static func arcana_name(id: int) -> String:
	return DATA[id]["name"]

static func get_effect(id: int) -> Effect:
	return DATA[id]["effect"]

static func get_desc(id: int) -> String:
	return DATA[id]["desc"]

static func texture_path(id: int) -> String:
	return "res://assets/cards/major/%s.png" % TEXTURE_FILE[id]

static func is_interactive(id: int) -> bool:
	return get_effect(id) == Effect.INTERACTIVE
