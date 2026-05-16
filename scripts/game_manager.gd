extends Node

# ---- Signals (UI connects to these) ------------------------------------------

signal phase_changed(phase_name: String)

signal player_hand_updated(player_idx: int, hand: Array)
signal player_chips_changed(player_idx: int, chips: int)
signal player_folded(player_idx: int)

signal pot_changed(new_amount: int)

signal arcana_revealed(arcana_id: int, arcana_name: String)
signal arcana_cancelled(cancelled_id: int)          # Hierophant blocked it
signal last_round_announced()

# Requests for human input — UI shows appropriate controls then calls submit_*
signal bet_input_needed(player_idx: int, current_bet: int, can_check: bool, min_raise: int)
signal discard_input_needed(player_idx: int)
signal arcana_choice_needed(player_idx: int, arcana_id: int) # interactive arcana phase 4

signal round_ended(winner_indices: Array, hand_names: Array, split: bool)
signal page_bonus(winner_idx: int, bonus_per_player: int)
signal game_ended(final_chips: Array)

signal game_log(message: String)

# ---- Internal signals (awaited inside coroutines) ----------------------------

signal _bet_ready(action: String, amount: int)
signal _discard_ready(indices: Array)
signal _arcana_effect_done  # UI calls complete_arcana_effect() when interactive done

# ---- State -------------------------------------------------------------------

var players:        Array[Player] = []
var deck:           Deck
var arcana_deck:    Array[int] = []
var arcana_pos:     int = 0
var round_state:    RoundState

var active_players: Array[int] = []  # indices of non-folded players this round
var dealer_idx:     int = 0
var pot:            int = 0
var ante_amount:    int = 1
var last_round:     bool = false
var round_num:      int = 0
var debug_arcana_id: int = -1  # -1 = normal random; 0-21 = force this arcana every round
var arcana_choice: int = -1   # scratch var; set by UI before complete_arcana_effect()
var arcana_choice2: int = -1  # second scratch var for arcana needing two ints (Temperance)

const HUMAN_IDX := 0  # player 0 is always the human

# ---- Public API (called by the game setup scene) -----------------------------

func setup_game(num_players: int, starting_chips: int, ante: int, arcana_id: int = -1) -> void:
	debug_arcana_id = arcana_id
	last_round = false
	players.clear()
	for i in num_players:
		players.append(Player.new(starting_chips))
	ante_amount = ante
	round_num = 0
	deck = Deck.new()
	deck.build()
	deck.shuffle()
	_setup_arcana_deck()
	round_state = RoundState.new()

func start_game() -> void:
	game_log.emit("=== Game start — ante: %d, players: %d ===" % [ante_amount, players.size()])
	while true:
		await _run_round()
		if last_round or _only_one_solvent():
			break
	var chips: Array = []
	for p in players:
		chips.append(p.chips)
	game_ended.emit(chips)

# ---- Round loop --------------------------------------------------------------

func _run_round() -> void:
	# Carry over Hierophant state between rounds.
	var hierophant_carry := round_state.hierophant_active
	round_state = RoundState.new()
	round_state.hierophant_active = hierophant_carry

	for pidx in active_players:
		if players[pidx].chips == 0:
			game_log.emit("*** %s is eliminated! ***" % _pname(pidx))

	active_players.assign(range(players.size()).filter(func(i): return players[i].chips > 0))
	for p in players:
		p.clear_for_new_round()

	if deck.size() < players.size() * 6:
		deck.build()
		deck.shuffle()

	pot = 0
	round_num += 1
	dealer_idx = (dealer_idx + 1) % players.size()

	_phase_ante()
	await _phase_deal()

	if round_state.death_end or round_state.sun_end:
		if not round_state.moon_secret.is_empty():
			await _phase_moon_swap()
		if round_state.judgement_active:
			await _phase_judgement_reentry()
		await _phase_showdown()
		return

	await _phase_bet()

	if round_state.death_end or round_state.sun_end or active_players.size() <= 1:
		if not round_state.moon_secret.is_empty():
			await _phase_moon_swap()
		if round_state.judgement_active:
			await _phase_judgement_reentry()
		await _phase_showdown()
		return

	if not round_state.skip_draw:
		await _phase_draw()

	await _phase_bet()

	if not round_state.moon_secret.is_empty():
		await _phase_moon_swap()
	if round_state.judgement_active:
		await _phase_judgement_reentry()
	await _phase_showdown()

# ---- Phase: Ante -------------------------------------------------------------

func _phase_ante() -> void:
	phase_changed.emit("ANTE")
	game_log.emit("--- Round %d. Dealer: %s ---" % [round_num, _pname(dealer_idx)])
	var standings := " | ".join(range(players.size()).map(func(i): return "%s: %d" % [_pname(i), players[i].chips]))
	game_log.emit("Chips — " + standings)
	for pidx in active_players:
		var paid := players[pidx].bet(ante_amount)
		pot += paid
		player_chips_changed.emit(pidx, players[pidx].chips)
		game_log.emit("%s pays ante: %d" % [_pname(pidx), paid])
	pot_changed.emit(pot)

# ---- Phase: Deal -------------------------------------------------------------

func _phase_deal() -> void:
	phase_changed.emit("DEAL")
	for pidx in active_players:
		players[pidx].receive_cards(deck.deal_many(5))
		player_hand_updated.emit(pidx, players[pidx].hand)
	game_log.emit("Cards dealt.")

	if not round_state.arcana_drawn:
		if debug_arcana_id >= 0:
			await _draw_arcana()
		elif players[dealer_idx].has_page:
			game_log.emit("%s holds the Page — drawing arcana..." % _pname(dealer_idx))
			await _draw_arcana()

# ---- Phase: Bet --------------------------------------------------------------

func _phase_bet() -> void:
	phase_changed.emit("BET")
	if active_players.size() <= 1:
		return

	game_log.emit("--- Betting ---")

	var _current_bet := 0
	# Track how much each player has committed in THIS betting round.
	var contributed: Dictionary = {}
	for p in active_players:
		contributed[p] = 0

	# acted[pidx] = true once the player has taken any action this round.
	var acted: Dictionary = {}

	# Betting order starts left of dealer.
	var queue: Array[int] = _act_order_from(dealer_idx)

	while not queue.is_empty() and active_players.size() > 1:
		var pidx: int = queue.pop_front()

		if not active_players.has(pidx):
			continue  # folded while waiting
		# Skip only if the player has already acted AND already matched the bet.
		if acted.has(pidx) and contributed.get(pidx, 0) >= _current_bet:
			continue
		# All-in players have nothing left to commit — skip silently.
		if players[pidx].chips == 0:
			acted[pidx] = true
			continue

		var can_check  := _current_bet == 0
		var min_raise  := 1 if round_state.no_forced_min_bet \
						else ((_current_bet * 2) if round_state.raise_must_double \
						else (_current_bet + 1))

		var action: String
		var amount: int = 0

		if pidx == HUMAN_IDX:
			bet_input_needed.emit(pidx, _current_bet, can_check, min_raise)
			var r = await _bet_ready
			action = r[0]; amount = r[1]
		else:
			await _ai_think()
			var r := _ai_bet(pidx, _current_bet, can_check)
			action = r[0]; amount = r[1]

		acted[pidx] = true

		match action:
			"fold":
				players[pidx].fold()
				active_players.erase(pidx)
				player_folded.emit(pidx)
				game_log.emit("%s folds." % _pname(pidx))
				if active_players.size() == 1:
					return

			"check":
				game_log.emit("%s checks." % _pname(pidx))

			"call":
				var to_pay: int = _current_bet - contributed.get(pidx, 0)
				var paid   := players[pidx].bet(to_pay)
				contributed[pidx] = contributed.get(pidx, 0) + paid
				_add_to_pot(paid, pidx)
				game_log.emit("%s calls %d." % [_pname(pidx), paid])

			"raise":
				var raise_to: int = max(amount, min_raise)
				var to_pay: int = max(0, raise_to - contributed.get(pidx, 0))
				if to_pay > 0:
					var paid := players[pidx].bet(to_pay)
					contributed[pidx] = contributed.get(pidx, 0) + paid
					_add_to_pot(paid, pidx)
					raise_to = contributed[pidx]  # cap to what was actually paid
				_current_bet = max(_current_bet, raise_to)
				game_log.emit("%s raises to %d." % [_pname(pidx), _current_bet])
				# Re-queue everyone who hasn't matched the new bet.
				for other: int in active_players:
					if other != pidx and contributed.get(other, 0) < _current_bet:
						if not queue.has(other):
							queue.append(other)

		if round_state.death_end or round_state.sun_end:
			return

	if round_state.no_forced_min_bet:
		var refunded := false
		for pidx in active_players:
			var excess: int = contributed.get(pidx, 0) - _current_bet
			if excess > 0:
				players[pidx].receive_chips(excess)
				pot -= excess
				player_chips_changed.emit(pidx, players[pidx].chips)
				game_log.emit("%s refunded %d (Justice)." % [_pname(pidx), excess])
				refunded = true
		if refunded:
			pot_changed.emit(pot)

# ---- Phase: Draw -------------------------------------------------------------

func _phase_draw() -> void:
	phase_changed.emit("DRAW")
	game_log.emit("--- Draw phase ---")
	for pidx in active_players:
		if pidx == HUMAN_IDX:
			discard_input_needed.emit(pidx)
			var indices: Array = await _discard_ready
			_do_discard(pidx, indices)
		else:
			await _ai_think()
			_do_discard(pidx, _ai_discard(pidx))

# ---- Phase: Moon swap --------------------------------------------------------

func _phase_moon_swap() -> void:
	game_log.emit("--- The Moon — swap your secret card or keep your hand? ---")
	for pidx in round_state.moon_secret.keys():
		var secret: Card = round_state.moon_secret[pidx]
		if not active_players.has(pidx):
			deck.add_cards([secret])
			continue
		if pidx == HUMAN_IDX:
			arcana_choice_needed.emit(pidx, 18)
			await _arcana_effect_done
			var choice := arcana_choice
			if choice >= 0 and choice < players[pidx].hand.size():
				var old_card: Card = players[pidx].hand[choice]
				players[pidx].hand[choice] = secret
				deck.add_cards([old_card])
				player_hand_updated.emit(pidx, players[pidx].hand)
				game_log.emit("You swap a hand card for your Moon secret.")
			else:
				deck.add_cards([secret])
				game_log.emit("You keep your hand, discarding your Moon secret.")
		else:
			await _ai_think()
			if not players[pidx].hand.is_empty() and randi() % 2 == 0:
				var idx := randi() % players[pidx].hand.size()
				var old_card: Card = players[pidx].hand[idx]
				players[pidx].hand[idx] = secret
				deck.add_cards([old_card])
				player_hand_updated.emit(pidx, players[pidx].hand)
				game_log.emit("%s swaps their Moon secret into hand." % _pname(pidx))
			else:
				deck.add_cards([secret])
				game_log.emit("%s discards their Moon secret." % _pname(pidx))
	round_state.moon_secret.clear()

# ---- Phase: Judgement re-entry -----------------------------------------------

func _phase_judgement_reentry() -> void:
	game_log.emit("--- Judgement — last chance to re-enter ---")
	var can_reenter: Array[int] = []
	for pidx in range(players.size()):
		if not active_players.has(pidx) and players[pidx].chips >= ante_amount:
			can_reenter.append(pidx)
	if can_reenter.is_empty():
		game_log.emit("No folded players can afford to re-enter.")
		return
	if deck.size() < can_reenter.size() * 5:
		deck.build()
		deck.shuffle()
	for pidx in can_reenter:
		if pidx == HUMAN_IDX:
			arcana_choice_needed.emit(pidx, 20)
			await _arcana_effect_done
			if arcana_choice == 1:
				_do_reenter(pidx)
			else:
				game_log.emit("You choose to stay folded.")
		else:
			await _ai_think()
			_do_reenter(pidx)

func _do_reenter(pidx: int) -> void:
	var paid := players[pidx].bet(ante_amount)
	pot += paid
	pot_changed.emit(pot)
	player_chips_changed.emit(pidx, players[pidx].chips)
	players[pidx].folded = false
	active_players.append(pidx)
	active_players.sort()
	players[pidx].hand.clear()
	players[pidx].receive_cards(deck.deal_many(5))
	player_hand_updated.emit(pidx, players[pidx].hand)
	game_log.emit("%s pays %d and re-enters with a fresh hand!" % [_pname(pidx), ante_amount])

# ---- Phase: Showdown ---------------------------------------------------------

func _phase_showdown() -> void:
	phase_changed.emit("SHOWDOWN")
	game_log.emit("--- Showdown (pot: %d) ---" % pot)

	if active_players.size() == 1:
		game_log.emit("%s wins %d uncontested." % [_pname(active_players[0]), pot])
		_award_pot(active_players)
		return

	if round_state.sun_end:
		game_log.emit("The Sun splits the pot equally.")
		@warning_ignore("integer_division")
		var share := pot / active_players.size()
		for pidx in active_players:
			players[pidx].receive_chips(share)
			player_chips_changed.emit(pidx, players[pidx].chips)
		pot = 0
		pot_changed.emit(pot)
		round_ended.emit(active_players, [], true)
		return

	var opts  := round_state.eval_options()
	var scores: Dictionary = {}
	for pidx in active_players:
		scores[pidx] = HandEvaluator.score(players[pidx].hand, opts["king_beats_ace"], opts["inverted_values"], opts["fool_active"])

	for pidx in active_players:
		var card_names := ", ".join(players[pidx].hand.map(func(c: Card): return c.display_name()))
		game_log.emit("%s shows: %s (%s)" % [_pname(pidx), HandEvaluator.hand_type_name(scores[pidx]), card_names])
		await get_tree().create_timer(0.8).timeout

	var sorted_players: Array = active_players.duplicate()
	sorted_players.sort_custom(func(a, b): return scores[a] > scores[b])

	var winners: Array[int]
	var hand_names: Array[String] = []
	var split := false

	if round_state.split_pot_two_best and sorted_players.size() >= 2:
		# Lovers: top two hands split.
		winners = [sorted_players[0], sorted_players[1]]
		split = true
		@warning_ignore("integer_division")
		var half_up   := (pot + 1) / 2
		@warning_ignore("integer_division")
		var half_down := pot / 2
		players[winners[0]].receive_chips(half_up)
		players[winners[1]].receive_chips(half_down)
		pot = 0
		pot_changed.emit(pot)
		for w in winners:
			player_chips_changed.emit(w, players[w].chips)
			hand_names.append(HandEvaluator.hand_type_name(scores[w]))
		game_log.emit("The Lovers split: %s (%s) & %s (%s)" % [
			_pname(winners[0]), hand_names[0], _pname(winners[1]), hand_names[1]])
	else:
		# Standard: highest score wins; ties split equally.
		var top_score: int = scores[sorted_players[0]]
		winners = sorted_players.filter(func(p): return scores[p] == top_score)
		var won := _award_pot(winners)
		for w in winners:
			hand_names.append(HandEvaluator.hand_type_name(scores[w]))
		if winners.size() == 1:
			game_log.emit("%s wins %d with %s!" % [_pname(winners[0]), won, hand_names[0]])
		else:
			var names := ", ".join(winners.map(func(w): return _pname(w)))
			@warning_ignore("integer_division")
			game_log.emit("Tie! %s each win %d (%s)." % [names, won / winners.size(), hand_names[0]])

	round_ended.emit(winners, hand_names, split)

	# Page bonus: winner with a Page card collects ante from every other player.
	for w in winners:
		if players[w].has_page:
			var bonus_total := 0
			for pidx in range(players.size()):
				if pidx != w and players[pidx].chips >= ante_amount:
					var paid := players[pidx].bet(ante_amount)
					bonus_total += paid
					player_chips_changed.emit(pidx, players[pidx].chips)
			players[w].receive_chips(bonus_total)
			player_chips_changed.emit(w, players[w].chips)
			page_bonus.emit(w, ante_amount)
			game_log.emit("%s collects the Page bonus: +%d from each player!" % [_pname(w), ante_amount])

# ---- Arcana deck setup (per rules) ------------------------------------------

func _setup_arcana_deck() -> void:
	if debug_arcana_id >= 0:
		arcana_deck = []
		for i in 22:
			arcana_deck.append(debug_arcana_id)
		arcana_pos = 0
		return
	var non_world: Array[int] = []
	for i in range(0, 21):  # 0–20, World (#21) excluded initially
		non_world.append(i)
	non_world.shuffle()

	# Split as equally as possible: 10 + 11. Insert World into the smaller pile.
	var pile_a: Array[int] = non_world.slice(0, 10)  # gets World → 11 cards
	var pile_b: Array[int] = non_world.slice(10)     # stays 11, no World
	pile_a.append(21)
	pile_a.shuffle()
	pile_b.shuffle()
	# Pile without World on top; pile with World on bottom.
	arcana_deck = pile_b + pile_a
	arcana_pos = 0

func _draw_arcana() -> void:
	if arcana_pos >= arcana_deck.size():
		return
	var id: int = arcana_deck[arcana_pos]
	arcana_pos += 1
	round_state.arcana_drawn = true

	# Hierophant cancels the next drawn arcana (The World is immune).
	if round_state.hierophant_active and id != 21:
		round_state.hierophant_active = false
		arcana_cancelled.emit(id)
		game_log.emit("The Hierophant cancels %s!" % MajorArcana.arcana_name(id))
		return

	arcana_revealed.emit(id, MajorArcana.arcana_name(id))
	game_log.emit("Arcana: %s" % MajorArcana.arcana_name(id))
	round_state.arcana_id = id
	await get_tree().create_timer(1.5).timeout
	await _apply_arcana(id)

func _apply_arcana(id: int) -> void:
	match id:
		0:  # The Fool — wild-card evaluation
			round_state.fool_active = true
			game_log.emit("The Fool is wild — best possible hand counts!")

		20:  # Judgement — folded players may pay ante and re-enter before showdown
			round_state.judgement_active = true
			game_log.emit("Judgement — the dead may rise! Folded players may pay %d to re-enter." % ante_amount)

		14:  # Temperance — discard one card, pick from a 3-card face-up flop
			game_log.emit("Temperance — each player discards one card and picks from the flop.")
			var flop: Array[Card] = []
			for _i in 3:
				if not deck.is_empty():
					flop.append(deck.deal_one())
			if flop.is_empty():
				game_log.emit("Deck too empty for Temperance flop.")
			else:
				for pidx in active_players:
					if flop.is_empty():
						game_log.emit("%s — no flop cards left, skipped." % _pname(pidx))
						continue
					if pidx == HUMAN_IDX:
						round_state.temperance_flop = flop
						arcana_choice_needed.emit(pidx, 14)
						await _arcana_effect_done
						var discard_idx := arcana_choice
						var flop_idx := arcana_choice2
						if discard_idx >= 0 and discard_idx < players[pidx].hand.size() \
								and flop_idx >= 0 and flop_idx < flop.size():
							var taken: Card = flop[flop_idx]
							var discarded: Card = players[pidx].hand[discard_idx]
							players[pidx].hand.remove_at(discard_idx)
							players[pidx].receive_cards([taken])
							deck.add_cards([discarded])
							flop.remove_at(flop_idx)
							player_hand_updated.emit(pidx, players[pidx].hand)
							game_log.emit("You discard and take from the flop.")
						else:
							game_log.emit("You skip Temperance.")
					else:
						await _ai_think()
						var flop_pick := randi() % flop.size()
						var hand_pick := randi() % players[pidx].hand.size()
						var taken: Card = flop[flop_pick]
						var discarded: Card = players[pidx].hand[hand_pick]
						players[pidx].hand.remove_at(hand_pick)
						players[pidx].receive_cards([taken])
						deck.add_cards([discarded])
						flop.remove_at(flop_pick)
						player_hand_updated.emit(pidx, players[pidx].hand)
						game_log.emit("%s discards and takes from the flop." % _pname(pidx))
				if not flop.is_empty():
					deck.add_cards(flop)

		18:  # The Moon — each player draws a secret card; may swap before showdown
			game_log.emit("The Moon — each player draws a secret card.")
			for pidx in active_players:
				if deck.is_empty():
					game_log.emit("%s — deck empty, skipped." % _pname(pidx))
					continue
				var drawn: Card = deck.deal_one()
				round_state.moon_secret[pidx] = drawn
				if pidx == HUMAN_IDX:
					arcana_choice_needed.emit(pidx, 18)
					await _arcana_effect_done
					round_state.moon_reveal_done = true
					game_log.emit("You tuck a card away secretly.")
				else:
					game_log.emit("%s draws a secret card." % _pname(pidx))

		2:  # The High Priestess — each player reveals one card face-up for the round
			game_log.emit("The High Priestess — each player reveals one card.")
			for pidx in active_players:
				if players[pidx].hand.is_empty():
					continue
				if pidx == HUMAN_IDX:
					arcana_choice_needed.emit(pidx, 2)
					await _arcana_effect_done
					var idx := arcana_choice
					if idx >= 0 and idx < players[pidx].hand.size():
						round_state.priestess_revealed[pidx] = players[pidx].hand[idx]
						player_hand_updated.emit(pidx, players[pidx].hand)
						game_log.emit("You reveal the %s." % players[pidx].hand[idx].display_name())
				else:
					await _ai_think()
					var idx := randi() % players[pidx].hand.size()
					round_state.priestess_revealed[pidx] = players[pidx].hand[idx]
					player_hand_updated.emit(pidx, players[pidx].hand)
					game_log.emit("%s reveals a card." % _pname(pidx))

		1:  # The Magician — each player draws one card; keep it if suit guess is correct
			game_log.emit("The Magician — guess your drawn card's suit to keep it!")
			for pidx in active_players:
				if deck.is_empty():
					game_log.emit("%s — deck empty, skipped." % _pname(pidx))
					continue
				var drawn: Card = deck.deal_one()
				if pidx == HUMAN_IDX:
					arcana_choice_needed.emit(pidx, 1)
					await _arcana_effect_done
					if arcana_choice == (drawn.suit as int):
						players[pidx].receive_cards([drawn])
						player_hand_updated.emit(pidx, players[pidx].hand)
						game_log.emit("Correct! You drew the %s." % drawn.display_name())
					else:
						deck.add_cards([drawn])
						game_log.emit("Wrong — the card was the %s." % drawn.display_name())
				else:
					await _ai_think()
					if randi() % 4 == (drawn.suit as int):
						players[pidx].receive_cards([drawn])
						player_hand_updated.emit(pidx, players[pidx].hand)
						game_log.emit("%s guesses correctly!" % _pname(pidx))
					else:
						deck.add_cards([drawn])
						game_log.emit("%s guesses wrong." % _pname(pidx))

		17:  # The Star — in turn order, may swap one card with top of deck
			game_log.emit("The Star — each player may swap one card with the top of the deck.")
			for pidx in active_players:
				if pidx == HUMAN_IDX:
					arcana_choice_needed.emit(pidx, 17)
					await _arcana_effect_done
					var choice := arcana_choice
					if choice >= 0 and not deck.is_empty():
						var new_card: Card = deck.deal_one()
						var old_card: Card = players[pidx].hand[choice]
						players[pidx].hand.remove_at(choice)
						deck.add_cards([old_card])
						players[pidx].receive_cards([new_card])
						player_hand_updated.emit(pidx, players[pidx].hand)
						game_log.emit("You swap a card with the deck.")
					else:
						game_log.emit("You pass.")
				else:
					await _ai_think()
					if not deck.is_empty() and randi() % 2 == 0:
						var idx := randi() % players[pidx].hand.size()
						var new_card: Card = deck.deal_one()
						var old_card: Card = players[pidx].hand[idx]
						players[pidx].hand.remove_at(idx)
						deck.add_cards([old_card])
						players[pidx].receive_cards([new_card])
						player_hand_updated.emit(pidx, players[pidx].hand)
						game_log.emit("%s swaps a card." % _pname(pidx))
					else:
						game_log.emit("%s passes." % _pname(pidx))

		7:  # The Chariot — each player passes one card to the left
			var chosen: Dictionary = {}
			for pidx in active_players:
				if pidx == HUMAN_IDX:
					arcana_choice_needed.emit(pidx, 7)
					await _arcana_effect_done
					chosen[pidx] = arcana_choice
					game_log.emit("You pass a card left.")
				else:
					await _ai_think()
					chosen[pidx] = randi() % players[pidx].hand.size()
					game_log.emit("%s passes a card left." % _pname(pidx))
			var passing: Dictionary = {}
			for pidx in active_players:
				passing[pidx] = players[pidx].hand[chosen[pidx]]
			for pidx in active_players:
				players[pidx].hand.erase(passing[pidx])
			for i in active_players.size():
				var from_pidx: int = active_players[i]
				var to_pidx: int = active_players[(i + 1) % active_players.size()]
				players[to_pidx].receive_cards([passing[from_pidx]])
			for pidx in active_players:
				player_hand_updated.emit(pidx, players[pidx].hand)
			game_log.emit("The Chariot — cards passed left!")

		3:  # The Empress — each player draws a 6th card
			for pidx: int in active_players:
				if not deck.is_empty():
					players[pidx].receive_cards([deck.deal_one()])
					player_hand_updated.emit(pidx, players[pidx].hand)
			round_state.six_card_hand = true
			game_log.emit("The Empress grants a 6th card to each player.")

		4:
			round_state.king_beats_ace = true
			game_log.emit("The Emperor rules — Kings beat Aces this round.")

		5:
			round_state.hierophant_active = true
			game_log.emit("The Hierophant will cancel the next arcana drawn.")

		6:
			round_state.split_pot_two_best = true
			game_log.emit("The Lovers — the pot splits between the two best hands.")

		8:
			round_state.inverted_values = true
			game_log.emit("Strength inverts the ranking — low cards win.")

		9:
			round_state.skip_draw = true
			game_log.emit("The Hermit — no draw phase this round.")

		10: # Wheel of Fortune — collect all cards, shuffle, redeal
			var cards_each := 6 if round_state.six_card_hand else 5
			var all_cards: Array[Card] = []
			for p: Player in players:
				all_cards.append_array(p.hand)
				p.hand.clear()
			deck.add_cards(all_cards)
			deck.shuffle()
			for pidx: int in active_players:
				players[pidx].receive_cards(deck.deal_many(cards_each))
				player_hand_updated.emit(pidx, players[pidx].hand)
			game_log.emit("The Wheel of Fortune spins — all hands redealt!")

		11:
			round_state.no_forced_min_bet = true
			game_log.emit("Justice — no minimum raise required.")

		12:
			round_state.hanged_man_active = true
			game_log.emit("The Hanged Man — go all-in to draw an extra card.")

		13:
			round_state.death_end = true
			game_log.emit("Death arrives — immediate showdown!")

		15:
			round_state.raise_must_double = true
			game_log.emit("The Devil — raises must at least double the current bet.")

		16: # The Tower — half the pot (rounded up) evaporates
			@warning_ignore("integer_division")
			var lost := (pot + 1) / 2
			pot = int(max(0, pot - lost))
			pot_changed.emit(pot)
			game_log.emit("The Tower strikes — %d chips lost to ruin!" % lost)

		19:
			round_state.sun_end = true
			game_log.emit("The Sun shines — equal split at showdown.")

		21: # The World — this is the last round
			last_round = true
			last_round_announced.emit()
			game_log.emit("The World — this is the final round!")

# ---- Helpers -----------------------------------------------------------------

func _ai_think() -> void:
	await get_tree().create_timer(randf_range(0.4, 0.9)).timeout

func _pname(pidx: int) -> String:
	return "You" if pidx == HUMAN_IDX else "AI %d" % pidx

func _add_to_pot(amount: int, pidx: int) -> void:
	pot += amount
	pot_changed.emit(pot)
	player_chips_changed.emit(pidx, players[pidx].chips)
	# Hanged Man: going all-in grants an extra card.
	if round_state.hanged_man_active and players[pidx].chips == 0:
		if not deck.is_empty():
			players[pidx].receive_cards([deck.deal_one()])
			player_hand_updated.emit(pidx, players[pidx].hand)
			game_log.emit("%s goes all-in and draws an extra card!" % _pname(pidx))

func _do_discard(pidx: int, indices: Array) -> void:
	if indices.is_empty():
		game_log.emit("%s keeps their hand." % _pname(pidx))
	else:
		game_log.emit("%s discards %d card(s)." % [_pname(pidx), indices.size()])
	var discarded := players[pidx].discard_at(indices)
	deck.add_cards(discarded)
	var new_cards := deck.deal_many(discarded.size())
	players[pidx].receive_cards(new_cards)
	player_hand_updated.emit(pidx, players[pidx].hand)
	if pidx == HUMAN_IDX and not indices.is_empty():
		var disc_names := ", ".join(discarded.map(func(c: Card): return c.display_name()))
		var drawn_names := ", ".join(new_cards.map(func(c: Card): return c.display_name()))
		game_log.emit("Discarded: %s" % disc_names)
		game_log.emit("Drew: %s" % drawn_names)

func _award_pot(winners: Array) -> int:
	if winners.is_empty():
		return 0
	var total := pot
	@warning_ignore("integer_division")
	var share := pot / winners.size()
	for w: int in winners:
		players[w].receive_chips(share)
		player_chips_changed.emit(w, players[w].chips)
	pot = 0
	pot_changed.emit(pot)
	return total

func _act_order_from(dealer: int) -> Array[int]:
	var order: Array[int] = []
	for i in range(1, players.size() + 1):
		var pidx := (dealer + i) % players.size()
		if active_players.has(pidx):
			order.append(pidx)
	return order

func _only_one_solvent() -> bool:
	return players.filter(func(p): return p.chips > 0).size() <= 1

# ---- AI ----------------------------------------------------------------------

func _ai_bet(pidx: int, current_bet: int, can_check: bool) -> Array:
	var strength := randf()  # simulated hand assessment
	if strength > 0.8:
		var raise_to := current_bet * 2 if round_state.raise_must_double else current_bet + 1
		raise_to = int(min(raise_to, players[pidx].chips + current_bet))
		return ["raise", raise_to]
	elif strength > 0.4:
		return ["check", 0] if can_check else ["call", 0]
	elif can_check:
		return ["check", 0]
	else:
		return ["fold", 0]

func _ai_discard(pidx: int) -> Array[int]:
	var hand := players[pidx].hand
	var rank_counts: Dictionary = {}
	for c: Card in hand:
		var v := c.rank as int
		rank_counts[v] = rank_counts.get(v, 0) + 1

	# Keep four-of-a-kind, three-of-a-kind, two-pair, full house.
	var max_count: int = rank_counts.values().max() if not rank_counts.is_empty() else 0
	if max_count >= 3:
		return []
	if rank_counts.values().count(2) == 2:
		return []

	# Otherwise discard everything except the highest-ranked card.
	var max_rank: int = rank_counts.keys().max() if not rank_counts.is_empty() else 0
	var indices: Array[int] = []
	for i in range(hand.size()):
		if (hand[i].rank as int) != max_rank:
			indices.append(i)
	return indices

# ---- Public API (UI calls these) ---------------------------------------------

func submit_bet(action: String, amount: int = 0) -> void:
	_bet_ready.emit(action, amount)

func submit_discard(indices: Array) -> void:
	_discard_ready.emit(indices)

func complete_arcana_effect() -> void:
	_arcana_effect_done.emit()

func submit_arcana_choice(choice: int) -> void:
	arcana_choice = choice
	_arcana_effect_done.emit()

func submit_arcana_choice_pair(choice1: int, choice2: int) -> void:
	arcana_choice = choice1
	arcana_choice2 = choice2
	_arcana_effect_done.emit()
