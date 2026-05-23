class_name Player
extends RefCounted

var hand: Array[Card] = []
var chips: int = 0
var folded: bool = false
var has_page: bool = false  # tracks Page card for the win bonus rule
var profile: AIProfile = null  # null for the human player
var memory: OpponentMemory = null  # AI's read of the human; null for the human player

func _init(starting_chips: int) -> void:
	chips = starting_chips

func receive_cards(new_cards: Array[Card]) -> void:
	hand.append_array(new_cards)
	hand.sort_custom(func(a: Card, b: Card) -> bool:
		return a.suit < b.suit if a.suit != b.suit else a.rank < b.rank)
	_refresh_has_page()

func discard_at(indices: Array[int]) -> Array[Card]:
	var discarded: Array[Card] = []
	var sorted_indices := indices.duplicate()
	sorted_indices.sort()
	sorted_indices.reverse()  # remove from the back first so earlier indices stay valid
	for i: int in sorted_indices:
		if i >= 0 and i < hand.size():
			discarded.append(hand[i])
			hand.remove_at(i)
	_refresh_has_page()
	return discarded

func bet(amount: int) -> int:
	var actual := mini(amount, chips)  # all-in cap
	chips -= actual
	return actual

func receive_chips(amount: int) -> void:
	chips += amount

func fold() -> void:
	folded = true

func clear_for_new_round() -> void:
	hand.clear()
	folded = false
	has_page = false

func _refresh_has_page() -> void:
	has_page = hand.any(func(c: Card) -> bool: return c.rank == Card.Rank.PAGE)

# ---- Serialization (for mid-match save state) -------------------------------

func hand_to_pairs() -> Array:
	var out: Array = []
	for c: Card in hand:
		out.append(c.to_pair())
	return out

# Bypasses the sort in receive_cards — the saved order is the displayed order.
func set_hand_from_pairs(pairs: Array) -> void:
	hand.clear()
	for p in pairs:
		hand.append(Card.from_pair(p as Array))
	_refresh_has_page()
