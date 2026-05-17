class_name HandEvaluator
extends RefCounted

# Hand type constants — higher integer = better hand.
const FIVE_OF_A_KIND  := 11
const ROYAL_FLUSH     := 10
const STRAIGHT_FLUSH  := 9
const FOUR_OF_A_KIND  := 8
const FULL_HOUSE      := 7
const FLUSH           := 6
const STRAIGHT        := 5
const THREE_OF_A_KIND := 4
const TWO_PAIR        := 3
const ONE_PAIR        := 2
const HIGH_CARD       := 1

# Packing base. Max comparison value is 15 (King under Emperor), so base 16 is safe.
const _B := 16

# Returns a comparable integer score. Higher = better hand.
#
# Arcana modifiers:
#   king_beats_ace  — Emperor arcana: King's comparison value becomes 15, beating Ace's 14.
#   inverted_values — Strength arcana: all non-Page cards use (16 − raw_value),
#                     making 2 the highest and Ace the second-lowest. Page stays at 0.
#
# Hand structure (flush, straight, etc.) is always detected from raw ranks so
# that arcana effects only change who wins, not what constitutes a valid hand.
static func score(hand: Array, king_beats_ace: bool = false, inverted_values: bool = false, fool_active: bool = false) -> int:
	var raw:   Array[int] = []
	var suits: Array[int] = []
	for c: Card in hand:
		raw.append(c.rank as int)
		suits.append(c.suit as int)
	if fool_active:
		return _best_wild_score(raw, suits, king_beats_ace, inverted_values)
	return _score_raw(raw, suits, king_beats_ace, inverted_values)


static func _score_raw(raw: Array[int], suits: Array[int], king_beats_ace: bool, inverted_values: bool) -> int:
	var cvals: Array[int] = _comparison_values(raw, king_beats_ace, inverted_values)

	var is_flush    := _all_same(suits)
	var is_str      := _is_straight(raw)
	var is_page_str := _is_page_straight(raw)

	# Count groups using COMPARISON values, not raw ranks, so Emperor/Strength
	# modifiers correctly affect pair/triple detection.
	var counts := {}
	for v: int in cvals:
		counts[v] = counts.get(v, 0) + 1

	var cnt_vals: Array = counts.values()
	cnt_vals.sort()
	cnt_vals.reverse()  # descending, e.g. [3, 2] = Full House

	var sorted_cvals: Array[int] = cvals.duplicate()
	sorted_cvals.sort()
	sorted_cvals.reverse()  # highest comparison value first

	# ---- Straight flush / Royal Flush ----------------------------------------
	if is_flush and (is_str or is_page_str):
		var high := _straight_high_cval(sorted_cvals, is_page_str)
		# Royal Flush = best possible straight flush in current modifier context.
		# Normal & Strength: max_cmp = 14 (Ace or Two-inverted).
		# Emperor:           max_cmp = 15 (King).
		var max_cmp := 15 if king_beats_ace else 14
		if high == max_cmp:
			return ROYAL_FLUSH * _b5()  # all Royal Flushes tie
		return _pack(STRAIGHT_FLUSH, [high, 0, 0, 0, 0])

	# ---- Five of a Kind -------------------------------------------------------
	if cnt_vals[0] == 5:
		return _pack(FIVE_OF_A_KIND, [_first_with_count(counts, 5), 0, 0, 0, 0])

	# ---- Four of a Kind -------------------------------------------------------
	if cnt_vals[0] == 4:
		return _pack(FOUR_OF_A_KIND, [
			_first_with_count(counts, 4),
			_first_with_count(counts, 1), 0, 0, 0])

	# ---- Full House -----------------------------------------------------------
	if cnt_vals[0] == 3 and cnt_vals.size() > 1 and cnt_vals[1] == 2:
		return _pack(FULL_HOUSE, [
			_first_with_count(counts, 3),
			_first_with_count(counts, 2), 0, 0, 0])

	# ---- Flush ----------------------------------------------------------------
	if is_flush:
		return _pack(FLUSH, sorted_cvals)

	# ---- Straight -------------------------------------------------------------
	if is_str or is_page_str:
		return _pack(STRAIGHT, [_straight_high_cval(sorted_cvals, is_page_str), 0, 0, 0, 0])

	# ---- Three of a Kind ------------------------------------------------------
	if cnt_vals[0] == 3:
		var kickers := _all_with_count(counts, 1)
		return _pack(THREE_OF_A_KIND, [_first_with_count(counts, 3), kickers[0], kickers[1], 0, 0])

	# ---- Two Pair -------------------------------------------------------------
	if cnt_vals.count(2) == 2:
		var pairs := _all_with_count(counts, 2)  # sorted desc
		return _pack(TWO_PAIR, [pairs[0], pairs[1], _first_with_count(counts, 1), 0, 0])

	# ---- One Pair -------------------------------------------------------------
	if cnt_vals[0] == 2:
		var kickers := _all_with_count(counts, 1)
		return _pack(ONE_PAIR, [_first_with_count(counts, 2), kickers[0], kickers[1], kickers[2], 0])

	# ---- High Card ------------------------------------------------------------
	return _pack(HIGH_CARD, sorted_cvals)


# For each card position treated as wild, the wild takes the highest rank
# (by comparison value under active modifiers) not already held in the other
# four cards, plus whichever suit scores best. Returns the highest score found.
static func _best_wild_score(raw: Array[int], suits: Array[int], king_beats_ace: bool, inverted_values: bool) -> int:
	var best: int = _score_raw(raw, suits, king_beats_ace, inverted_values)
	var rank_order: Array[int] = [0, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14]
	rank_order.sort_custom(func(a, b):
		return _cmp(a, king_beats_ace, inverted_values) > _cmp(b, king_beats_ace, inverted_values))
	for i in range(raw.size()):
		var others: Dictionary = {}
		for j in range(raw.size()):
			if j != i:
				others[raw[j]] = true
		var wild_rank := -1
		for r in rank_order:
			if not others.has(r):
				wild_rank = r
				break
		for s in range(4):
			var test_raw := raw.duplicate()
			var test_suits := suits.duplicate()
			test_raw[i] = wild_rank
			test_suits[i] = s
			var candidate := _score_raw(test_raw, test_suits, king_beats_ace, inverted_values)
			if candidate > best:
				best = candidate
	return best


# Returns the hand type name for display ("Royal Flush", "Two Pair", etc.)
static func hand_type_name(hand_score: int) -> String:
	@warning_ignore("integer_division")
	match hand_score / _b5():
		11: return "Five of a Kind"
		10: return "Royal Flush"
		9:  return "Straight Flush"
		8:  return "Four of a Kind"
		7:  return "Full House"
		6:  return "Flush"
		5:  return "Straight"
		4:  return "Three of a Kind"
		3:  return "Two Pair"
		2:  return "One Pair"
		_:  return "High Card"


# ---- Private helpers ---------------------------------------------------------

static func _comparison_values(raw: Array[int], king_beats_ace: bool, inverted_values: bool) -> Array[int]:
	var result: Array[int] = []
	for v: int in raw:
		result.append(_cmp(v, king_beats_ace, inverted_values))
	return result


static func _cmp(raw_val: int, king_beats_ace: bool, inverted_values: bool) -> int:
	if raw_val == 0:
		return 0  # Page is always 0; no arcana changes this
	if inverted_values:
		return 16 - raw_val  # Two(2) → 14 (new high); Ace(14) → 2 (near-lowest)
	if king_beats_ace and raw_val == Card.Rank.KING:
		return 15  # King supersedes Ace under Emperor
	return raw_val


static func _all_same(arr: Array[int]) -> bool:
	if arr.is_empty():
		return false
	for v: int in arr:
		if v != arr[0]:
			return false
	return true


static func _is_straight(raw: Array[int]) -> bool:
	var unique := {}
	for r: int in raw:
		unique[r] = true
	if unique.size() != 5:
		return false
	var keys: Array = unique.keys()
	keys.sort()
	# Five unique values where each step is exactly 1 ↔ max − min == 4.
	# Because Page = 0 and Two = 2 (no rank value 1 exists), the only way to
	# have max−min = 4 with Page present is {0,1,2,3,4}, but 1 never appears,
	# so Page cannot sneak into a normal straight — only the explicit Page
	# straight below handles that case.
	return (keys[-1] - keys[0]) == 4


# The special Fortune straight: Page(0), Ace(14), Two(2), Three(3), Four(4).
# Page precedes Ace in this context, making it the weakest possible straight.
static func _is_page_straight(raw: Array[int]) -> bool:
	var s := {}
	for r: int in raw:
		s[r] = true
	return s.size() == 5 and s.has(0) and s.has(14) and s.has(2) and s.has(3) and s.has(4)


# Comparison-value "high card" used for straight tiebreakers.
# Page straight always scores 1 — below any regular straight's minimum high card of 6
# (from the weakest normal straight: Two, Three, Four, Five, Six → high comp = 6).
static func _straight_high_cval(sorted_desc: Array[int], is_page_str: bool) -> int:
	if is_page_str:
		return 1
	return sorted_desc[0]


# Returns the (single) comparison value that appears exactly n times.
# For uniqueness: assumes only one group has this count (e.g. the triple, the quad).
static func _first_with_count(counts: Dictionary, n: int) -> int:
	for val: int in counts:
		if counts[val] == n:
			return val
	return 0


# Returns ALL comparison values that appear exactly n times, sorted descending.
# Used for kickers and paired groups (Two Pair).
static func _all_with_count(counts: Dictionary, n: int) -> Array[int]:
	var result: Array[int] = []
	for val: int in counts:
		if counts[val] == n:
			result.append(val)
	result.sort()
	result.reverse()
	return result


static func _pack(hand_type: int, tiebreakers: Array) -> int:
	# Tiebreakers must have exactly 5 elements (pad with 0 where unused).
	var b := _B
	return hand_type * _b5() \
		+ tiebreakers[0] * (b*b*b*b) \
		+ tiebreakers[1] * (b*b*b) \
		+ tiebreakers[2] * (b*b) \
		+ tiebreakers[3] * b \
		+ tiebreakers[4]


static func _b5() -> int:
	return _B * _B * _B * _B * _B  # 16^5 = 1 048 576


# Returns card indices in the order they should be displayed: groups sorted by
# count descending, then by comparison value descending within each group.
# Result is a permutation of [0, hand.size()-1] suitable for HandDisplay.set_hand.
static func sort_order_for_display(hand: Array, king_beats_ace: bool = false, inverted_values: bool = false) -> Array[int]:
	var raw: Array[int] = []
	for c: Card in hand:
		raw.append(c.rank as int)
	var cvals := _comparison_values(raw, king_beats_ace, inverted_values)
	var counts := {}
	for v: int in cvals:
		counts[v] = counts.get(v, 0) + 1
	var indexed: Array = []
	for i in hand.size():
		indexed.append([i, counts[cvals[i]], cvals[i]])
	indexed.sort_custom(func(a, b):
		if a[1] != b[1]:
			return a[1] > b[1]
		return a[2] > b[2]
	)
	var result: Array[int] = []
	for entry in indexed:
		result.append(entry[0] as int)
	return result
