class_name Player
extends RefCounted

var hand: Array[Card] = []
var chips: int = 0
var folded: bool = false
var has_page: bool = false  # tracks Page card for the win bonus rule

func _init(starting_chips: int) -> void:
	chips = starting_chips

func receive_cards(new_cards: Array[Card]) -> void:
	hand.append_array(new_cards)
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
