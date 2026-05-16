class_name Deck
extends RefCounted

var cards: Array[Card] = []

func build() -> void:
	cards.clear()
	for suit_val: int in Card.Suit.values():
		for rank_val: int in Card.Rank.values():
			cards.append(Card.new(suit_val as Card.Suit, rank_val as Card.Rank))

func shuffle() -> void:
	cards.shuffle()

func deal_one() -> Card:
	assert(not cards.is_empty(), "Deck is empty")
	return cards.pop_back()

func deal_many(count: int) -> Array[Card]:
	var result: Array[Card] = []
	for i in count:
		result.append(deal_one())
	return result

func add_cards(extras: Array[Card]) -> void:
	for card in extras:
		cards.push_front(card)

func size() -> int:
	return cards.size()

func is_empty() -> bool:
	return cards.is_empty()
