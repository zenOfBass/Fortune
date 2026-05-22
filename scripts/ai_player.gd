class_name AIPlayer
extends RefCounted

static func bet(pidx: int, current_bet: int, can_check: bool,
		already_contributed: int = 0, times_raised: int = 0, raises_so_far: int = 0) -> Array:
	var gm := GameManager
	var profile: AIProfile = gm.players[pidx].profile
	var hand_score: int = HandEvaluator.score(
		gm.players[pidx].hand,
		gm.round_state.king_beats_ace,
		gm.round_state.inverted_values,
		gm.round_state.fool_active
	)
	# Normalize packed score to 0.0–11.0 where floor ≈ hand rank constant (HIGH_CARD=1 … FIVE_OF_A_KIND=11).
	# 1048576 == 16^5 (_b5()) — the multiplier used to pack hand type into the high bits.
	var hand_type: float = hand_score / 1048576.0

	var noise_base: float = clamp(1.4 - (hand_type - 1.0) * 0.13, 0.2, 1.4)
	var noise_mag: float = noise_base * profile.noise_multiplier
	var effective: float = clamp(hand_type + randf_range(-noise_mag, noise_mag), 0.0, 11.0)

	var raise_threshold := profile.raise_threshold
	var fold_threshold  := profile.fold_threshold

	if gm.active_players.size() == 2:
		# Heads-up: each player is more often in the pot, so loosen the AI's
		# ranges — but not so much that they never fold. The old -1.0 push on
		# fold_threshold drove it to -0.2 (effectively never fold), making
		# bluffs impossible. -0.4 keeps folds rare but possible.
		raise_threshold -= 0.6
		fold_threshold  -= 0.4
		var total_chips: int = gm.players.reduce(func(s, p): return s + p.chips, 0)
		if total_chips > 0 and float(gm.players[pidx].chips) / total_chips > 0.6:
			raise_threshold -= 0.3

	# ---- Opponent reads --------------------------------------------------------
	# Memory-driven adjustments. Each delta capped at ~0.5 so personality dominates
	# early and reads only nudge play once a sample has built up.
	var memory: OpponentMemory = gm.players[pidx].memory
	var bluff_chance_eff := profile.bluff_chance
	if memory != null and profile.memory_weight > 0.0:
		var w := profile.memory_weight
		# Human folds to raises a lot → raise lighter against them.
		var fold_to_raise_signal := memory.fold_to_raise_rate() - 0.5
		raise_threshold -= clampf(fold_to_raise_signal * w * 1.4, -0.5, 0.5)
		# Human bluffs a lot → call lighter (don't fold to their aggression).
		fold_threshold -= clampf(memory.bluff_propensity() * w * 1.6, 0.0, 0.5)
		# Human is generally aggressive → tighten our own bluffs (they'll call us).
		# Capped so Tarvosk doesn't drop to ~0 and stop bluffing entirely.
		bluff_chance_eff = clampf(bluff_chance_eff - memory.aggression() * w * 0.10, 0.02, 1.0)

	if hand_type >= 6.0:
		effective = max(effective, raise_threshold + 0.1)

	var is_bluffing := false
	if not can_check and hand_type < 3.0 and randf() < bluff_chance_eff:
		effective = raise_threshold + 0.1
		is_bluffing = true

	if gm.round_state.hanged_man_active and hand_type < 4.0 and effective >= fold_threshold:
		var remaining := gm.players[pidx].chips
		var short_stacked := remaining <= maxi(current_bet * 2, gm.ante_amount * 6)
		if short_stacked or randf() < 0.20:
			effective = raise_threshold + 0.1
			var all_in_level := remaining + already_contributed
			return ["raise", all_in_level]

	var at_raise_cap := times_raised >= profile.raise_cap or raises_so_far >= 6

	if effective >= raise_threshold and not at_raise_cap:
		var all_in_level := gm.players[pidx].chips + already_contributed
		var max_bump: int = max(2, gm.ante_amount * 4)
		var bump: int = min(max(1, int(current_bet * randf_range(0.4, 0.9))), max_bump) \
						if not gm.round_state.raise_must_double \
						else max(1, current_bet)
		var raise_to: int = min(current_bet + bump, all_in_level)
		return ["raise", raise_to, is_bluffing]
	elif effective >= fold_threshold:
		return ["check", 0] if can_check else ["call", 0]
	elif can_check:
		return ["check", 0]
	else:
		return ["fold", 0]


static func discard(pidx: int) -> Array[int]:
	var gm := GameManager
	var hand := gm.players[pidx].hand
	var fool_active: bool = gm.round_state.fool_active
	var rank_counts: Dictionary = {}
	var suit_counts: Dictionary = {}
	for c: Card in hand:
		rank_counts[c.rank as int] = rank_counts.get(c.rank as int, 0) + 1
		suit_counts[c.suit as int] = suit_counts.get(c.suit as int, 0) + 1

	var max_count: int = rank_counts.values().max() if not rank_counts.is_empty() else 0

	if max_count >= 3 or rank_counts.values().count(2) == 2:
		return []

	var max_suit: int = suit_counts.values().max() if not suit_counts.is_empty() else 0
	# With wild, 3 suited cards is a strong flush draw (wild can match any suit).
	var flush_threshold := 3 if fool_active else 4
	if max_suit >= flush_threshold:
		var flush_suit := -1
		for s in suit_counts:
			if suit_counts[s] == max_suit:
				flush_suit = s
				break
		var flush_result: Array[int] = []
		for i in range(hand.size()):
			if (hand[i].suit as int) != flush_suit:
				flush_result.append(i)
		return flush_result

	# Wild takes highest not present, not a gap-filler, so straight draws are unreliable.
	if hand.size() == 5 and not fool_active:
		var skip_idx := four_straight_discard(hand)
		if skip_idx >= 0:
			return [skip_idx]

	if max_count == 2:
		var pair_rank := -1
		for r in rank_counts:
			if rank_counts[r] == 2:
				pair_rank = r
				break
		var pair_result: Array[int] = []
		for i in range(hand.size()):
			if (hand[i].rank as int) != pair_rank:
				pair_result.append(i)
		return pair_result

	var best_cval := -1
	var best_rank := -1
	for c: Card in hand:
		var cv := HandEvaluator._cmp(c.rank as int, gm.round_state.king_beats_ace, gm.round_state.inverted_values)
		if cv > best_cval:
			best_cval = cv
			best_rank = c.rank as int
	var result: Array[int] = []
	for i in range(hand.size()):
		if (hand[i].rank as int) != best_rank:
			result.append(i)
	return result


static func score_hand(hand: Array) -> int:
	var gm := GameManager
	return HandEvaluator.score(hand, gm.round_state.king_beats_ace, gm.round_state.inverted_values, gm.round_state.fool_active)


static func weakest_card_idx(pidx: int) -> int:
	var gm := GameManager
	var hand := gm.players[pidx].hand
	var cvals: Array[int] = []
	for c: Card in hand:
		cvals.append(HandEvaluator._cmp(c.rank as int, gm.round_state.king_beats_ace, gm.round_state.inverted_values))
	var counts: Dictionary = {}
	for v in cvals:
		counts[v] = counts.get(v, 0) + 1
	var best_idx := 0
	var best_cval := 999
	for i in hand.size():
		if counts[cvals[i]] == 1 and cvals[i] < best_cval:
			best_cval = cvals[i]
			best_idx = i
	if best_cval < 999:
		return best_idx
	best_cval = 999
	for i in hand.size():
		if cvals[i] < best_cval:
			best_cval = cvals[i]
			best_idx = i
	return best_idx


static func four_straight_discard(hand: Array) -> int:
	var ranks: Array[int] = []
	for c: Card in hand:
		ranks.append(c.rank as int)
	for skip in range(hand.size()):
		var unique: Dictionary = {}
		for i in range(hand.size()):
			if i != skip:
				unique[ranks[i]] = true
		if unique.size() == 4:
			var keys: Array = unique.keys()
			keys.sort()
			if keys[-1] - keys[0] == 3:
				return skip
	return -1
