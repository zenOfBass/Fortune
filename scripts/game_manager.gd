extends Node

# ---- Signals (UI connects to these) ------------------------------------------

signal phase_changed(phase_name: String)

signal player_hand_updated(player_idx: int, hand: Array)
# Emitted when round_state flags that affect display sort (inverted_values, king_beats_ace)
# change mid-round. Table re-renders the human's hand without animation/SFX.
signal display_sort_changed
# Emitted after resume_match() rebuilds GameManager state. Table handles by
# repopulating the entire UI from current state without animations or SFX.
signal state_restored
signal cards_drawn(player_idx: int, count: int)
signal player_chips_changed(player_idx: int, chips: int)
signal player_folded(player_idx: int)

signal pot_changed(new_amount: int)

signal arcana_revealed(arcana_id: int, arcana_name: String)
signal arcana_cancelled(cancelled_id: int)          # Hierophant blocked it
# Emitted from arcana_effects.gd (The World) — analyzer is per-file, suppress.
@warning_ignore("unused_signal")
signal last_round_announced()

# Requests for human input — UI shows appropriate controls then calls submit_*
signal bet_input_needed(player_idx: int, current_bet: int, can_check: bool, min_raise: int, opponents_have_chips: bool)
signal discard_input_needed(player_idx: int)
signal arcana_choice_needed(player_idx: int, arcana_id: int) # interactive arcana phase 4

signal player_hand_revealed(player_idx: int, hand: Array)
signal round_ended(winner_indices: Array, hand_names: Array, split: bool)
signal page_bonus(winner_idx: int, bonus_per_player: int)
signal game_ended(final_chips: Array)

signal game_log(message: String)
signal player_bet_changed(player_idx: int, contributed: int)
signal player_raised(player_idx: int, raise_to: int, prev_bet: int)
signal ai_bluffing(player_idx: int)

# ---- Internal signals (awaited inside coroutines) ----------------------------

signal _bet_ready(action: String, amount: int)
signal _discard_ready(indices: Array)
signal _arcana_effect_done  # UI calls complete_arcana_effect() when interactive done
signal _round_advance_ready # UI calls confirm_next_round() after result panel

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
var _game_gen: int = 0  # incremented by setup_game(); every async phase captures a local g=_game_gen
						# and checks "if g != _game_gen: return" after each await to exit if a new
						# game started while the coroutine was suspended.
var debug_arcana_id: int = -1  # -1 = normal random; 0-21 = force this arcana every round
var arcana_choice: int = -1   # scratch var; set by UI before complete_arcana_effect()
var arcana_choice2: int = -1  # second scratch var for arcana needing two ints (Temperance)

# Per-round journal of the human's behavior. Reset each round, committed into each
# AI's OpponentMemory at round end. See _reset_journal() / _commit_journal().
var _human_journal: Dictionary = {}

# Where the round loop currently is. Updated at each phase entry; snapshotted
# into MatchState so resume_match knows which phase to re-enter.
# Values: "" | "ARCANA" | "BET1" | "DRAW" | "BET2" | "MOON_SWAP" | "JUDGEMENT" | "SHOWDOWN"
var _current_phase: String = ""

# When RunManager.launch_current_match detects a mid-match save, it parks the
# loaded MatchState here and skips fresh setup. table.gd._ready picks it up
# after wiring signal connections and hands it to resume_match — that ordering
# guarantees state_restored has listeners by the time it fires.
var pending_resume_state: MatchState = null

const HUMAN_IDX := 0  # player 0 is always the human

func _ready() -> void:
	# Godot 4 generally auto-seeds the global RNG on startup, but being explicit
	# guards against any platform where it doesn't — and against the "got the
	# same hand twice" feel-bad even if it's just confirmation bias.
	randomize()

# ---- Public API (called by the game setup scene) -----------------------------

func setup_game(num_players: int, starting_chips: int, ante: int, arcana_id: int = -1) -> void:
	_game_gen += 1  # invalidate any coroutine from a previous game
	debug_arcana_id = arcana_id
	last_round = false
	players.clear()
	var ai_profiles := [AIProfile.aggressor(), AIProfile.rock(), AIProfile.ghost()]
	for i in num_players:
		var p := Player.new(starting_chips)
		if i > 0:
			p.profile = ai_profiles[i - 1]
			p.memory  = OpponentMemory.new()  # AI's read of the human; reset per game
		players.append(p)
	ante_amount = ante
	round_num = 0
	deck = Deck.new()
	deck.build()
	deck.shuffle()
	_setup_arcana_deck()
	round_state = RoundState.new()
	_reset_journal()

func start_game() -> void:
	var g := _game_gen
	game_log.emit("=== Game start — ante: %d, players: %d ===" % [ante_amount, players.size()])
	while true:
		await _run_round(g)
		if g != _game_gen: return
		if _should_end_game():
			break
		await _round_advance_ready
		if g != _game_gen: return
	var chips: Array = []
	for p in players:
		chips.append(p.chips)
	game_ended.emit(chips)

# Game-end check used by both start_game and resume_match. Career runs end
# the moment the player busts — there's no spectating the AI fight, and it
# closes the "save mid-bust → resume into a one-player-left round" edge case.
# Quick Play keeps the original behavior: play out until only one solvent
# player remains (or the World was drawn).
func _should_end_game() -> bool:
	if last_round or _only_one_solvent():
		return true
	if RunManager.session_belongs_to_run() and players[HUMAN_IDX].chips == 0:
		game_log.emit("*** You're out — the run ends here. ***")
		return true
	return false

# ---- Round loop --------------------------------------------------------------

func _run_round(g: int) -> void:
	# Carry over Hierophant state between rounds.
	var hierophant_carry := round_state.hierophant_active
	round_state = RoundState.new()
	round_state.hierophant_active = hierophant_carry

	for pidx in active_players:
		if players[pidx].chips == 0:
			game_log.emit("*** %s is eliminated! ***" % _pname(pidx))
			player_hand_updated.emit(pidx, [])

	active_players.assign(range(players.size()).filter(func(i): return players[i].chips > 0))
	for p in players:
		deck.add_cards(p.hand)
		p.clear_for_new_round()
	_reset_journal()
	_human_journal["human_active"] = active_players.has(HUMAN_IDX)

	# Rebuild from scratch when the deck is running low; otherwise the returned
	# hands are still in there. Either way, shuffle every round — without it, the
	# deck acts like a rotating queue and the same hands cycle back around.
	if deck.size() < players.size() * 6:
		deck.build()
	deck.shuffle()

	pot = 0
	round_num += 1
	dealer_idx = (dealer_idx + 1) % players.size()
	while players[dealer_idx].chips == 0:
		dealer_idx = (dealer_idx + 1) % players.size()

	_phase_ante()
	await _phase_deal(g)
	if g != _game_gen: return

	if round_state.death_end:
		await _finish_round(g)
		return

	await _continue_from_phase(g, "BET1")

# Drives the rest of the round from a given starting phase. Extracted from
# _run_round so resume_match can re-enter at any phase boundary; also used
# recursively as each phase finishes and hands off to the next.
func _continue_from_phase(g: int, start_phase: String) -> void:
	match start_phase:
		"ARCANA":
			_current_phase = "ARCANA"
			await _apply_arcana(round_state.arcana_id, g)
			if g != _game_gen: return
			if round_state.death_end:
				await _finish_round(g)
				return
			await _continue_from_phase(g, "BET1")
		"BET1":
			_current_phase = "BET1"
			await _phase_bet(g)
			if g != _game_gen: return
			if round_state.death_end or active_players.size() <= 1:
				await _finish_round(g)
				return
			if not round_state.skip_draw:
				await _continue_from_phase(g, "DRAW")
			else:
				await _continue_from_phase(g, "BET2")
		"DRAW":
			_current_phase = "DRAW"
			await _phase_draw(g)
			if g != _game_gen: return
			await _continue_from_phase(g, "BET2")
		"BET2":
			_current_phase = "BET2"
			await _phase_bet(g)
			if g != _game_gen: return
			await _finish_round(g)
		"MOON_SWAP", "JUDGEMENT", "SHOWDOWN":
			await _finish_round(g)

# Post-betting tail: optional Moon swap, optional Judgement re-entry, then
# showdown. Each sub-phase is resume-aware on its own, so calling _finish_round
# repeatedly is safe — phases that have already happened skip naturally.
func _finish_round(g: int) -> void:
	if not round_state.moon_secret.is_empty():
		_current_phase = "MOON_SWAP"
		await _phase_moon_swap(g)
		if g != _game_gen: return
	if round_state.judgement_active:
		_current_phase = "JUDGEMENT"
		await _phase_judgement_reentry(g)
		if g != _game_gen: return
	_current_phase = "SHOWDOWN"
	await _phase_showdown(g)

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

func _phase_deal(g: int) -> void:
	phase_changed.emit("DEAL")
	for pidx in active_players:
		players[pidx].receive_cards(deck.deal_many(5))
		player_hand_updated.emit(pidx, players[pidx].hand)
	game_log.emit("Cards dealt.")

	if not round_state.arcana_drawn:
		if debug_arcana_id >= 0:
			await _draw_arcana(g)
		elif players[dealer_idx].has_page:
			game_log.emit("%s holds the Page — drawing arcana..." % _pname(dealer_idx))
			await _draw_arcana(g)

# ---- Phase: Bet --------------------------------------------------------------

func _phase_bet(g: int) -> void:
	phase_changed.emit("BET")
	if active_players.size() <= 1:
		return
	if active_players.all(func(p): return players[p].chips == 0):
		return

	# Resume-aware: on a fresh entry, initialize the betting state on RoundState.
	# On resume, bet_in_progress is already true and bet_queue/contributed/etc.
	# hold the saved snapshot. Skip init so we pick up exactly where we left off.
	if not round_state.bet_in_progress:
		game_log.emit("--- Betting ---")
		round_state.bet_current = 0
		round_state.bet_contributed = {}
		for p in active_players:
			round_state.bet_contributed[p] = 0
		round_state.bet_acted = {}
		round_state.bet_player_raises = {}
		round_state.bet_raise_count = 0
		round_state.bet_queue = _act_order_from(dealer_idx)
		round_state.bet_in_progress = true

	# Aliases for readability. Dictionaries and typed arrays are by-reference,
	# so mutations on these are mutations on RoundState. bet_current (int) is
	# read/written directly via round_state.
	var contributed: Dictionary = round_state.bet_contributed
	var acted: Dictionary = round_state.bet_acted
	var player_raises: Dictionary = round_state.bet_player_raises
	var queue: Array[int] = round_state.bet_queue

	while not queue.is_empty() and active_players.size() > 1:
		var pidx: int = queue.pop_front()

		if not active_players.has(pidx):
			continue  # folded while waiting
		# Skip only if the player has already acted AND already matched the bet.
		if acted.has(pidx) and contributed.get(pidx, 0) >= round_state.bet_current:
			continue
		# All-in players have nothing left to commit — skip silently.
		if players[pidx].chips == 0:
			acted[pidx] = true
			continue

		var can_check  := round_state.bet_current == 0
		var min_raise: int = (round_state.bet_current + 1) if round_state.no_forced_min_bet \
						else (max(1, round_state.bet_current * 2) if round_state.raise_must_double \
						else (round_state.bet_current + 1))

		var action: String
		var amount: int = 0

		if pidx == HUMAN_IDX:
			# Any other active player with chips left? If not, raising above the
			# current bet just gets refunded as an unmatched overbet — the panel
			# uses this to grey out Raise / All-In / increment buttons.
			var opponents_have_chips := false
			for other in active_players:
				if other != HUMAN_IDX and players[other].chips > 0:
					opponents_have_chips = true
					break
			bet_input_needed.emit(pidx, round_state.bet_current, can_check, min_raise, opponents_have_chips)
			var r = await _bet_ready
			if g != _game_gen: return
			action = r[0]; amount = r[1]
		else:
			await _ai_think()
			if g != _game_gen: return
			var r := AIPlayer.bet(pidx, round_state.bet_current, can_check, contributed.get(pidx, 0), player_raises.get(pidx, 0), round_state.bet_raise_count)
			action = r[0]; amount = r[1]
			if action == "raise" and r.size() > 2 and r[2]:
				ai_bluffing.emit(pidx)

		acted[pidx] = true

		match action:
			"fold":
				if pidx == HUMAN_IDX:
					_human_journal["human_folded"] = true
					if round_state.bet_current > 0:
						_human_journal["human_folded_to_raise"] = true
				players[pidx].fold()
				active_players.erase(pidx)
				player_folded.emit(pidx)
				game_log.emit("%s folds." % _pname(pidx))
				if active_players.size() == 1:
					if pidx == HUMAN_IDX:
						save_match_checkpoint()
					_clear_bet_state()
					return

			"check":
				game_log.emit("%s checks." % _pname(pidx))

			"call":
				var to_pay: int = round_state.bet_current - contributed.get(pidx, 0)
				var paid   := players[pidx].bet(to_pay)
				contributed[pidx] = contributed.get(pidx, 0) + paid
				_add_to_pot(paid, pidx)
				if pidx == HUMAN_IDX:
					if round_state.bet_current > 0:
						_human_journal["human_called_raise"] = true
					if players[pidx].chips == 0:
						_human_journal["human_all_in"] = true
				var call_suffix := " (all in)" if players[pidx].chips == 0 else ""
				game_log.emit("%s calls %d.%s" % [_pname(pidx), paid, call_suffix])
				player_bet_changed.emit(pidx, contributed[pidx])

			"raise":
				var raise_to: int = max(amount, min_raise)
				var to_pay: int = max(0, raise_to - contributed.get(pidx, 0))
				if to_pay > 0:
					var paid := players[pidx].bet(to_pay)
					contributed[pidx] = contributed.get(pidx, 0) + paid
					_add_to_pot(paid, pidx)
					raise_to = contributed[pidx]  # cap to what was actually paid
					player_bet_changed.emit(pidx, contributed[pidx])
				var prev_bet := round_state.bet_current
				round_state.bet_current = max(round_state.bet_current, raise_to)
				if pidx == HUMAN_IDX:
					_human_journal["human_raises"] = int(_human_journal.get("human_raises", 0)) + 1
					if players[pidx].chips == 0:
						_human_journal["human_all_in"] = true
				var raise_suffix := " (all in)" if players[pidx].chips == 0 else ""
				game_log.emit("%s raises to %d.%s" % [_pname(pidx), round_state.bet_current, raise_suffix])
				player_raised.emit(pidx, raise_to, prev_bet)
				player_raises[pidx] = player_raises.get(pidx, 0) + 1
				round_state.bet_raise_count += 1
				# Re-queue in seat order starting left of the raiser.
				for other in _act_order_from(pidx):
					if other != pidx and contributed.get(other, 0) < round_state.bet_current:
						if not queue.has(other):
							queue.append(other)

		# Checkpoint after the human's action commits — captures their decision
		# plus any queue/pot mutations from it. AI actions don't save (their
		# state changes are deterministic from the saved deck).
		if pidx == HUMAN_IDX:
			save_match_checkpoint()

		if round_state.death_end:
			_clear_bet_state()
			return

	if round_state.no_forced_min_bet:
		var refunded := false
		for pidx in active_players:
			var excess: int = contributed.get(pidx, 0) - round_state.bet_current
			if excess > 0:
				players[pidx].receive_chips(excess)
				pot -= excess
				player_chips_changed.emit(pidx, players[pidx].chips)
				game_log.emit("%s refunded %d (Justice)." % [_pname(pidx), excess])
				refunded = true
		if refunded:
			pot_changed.emit(pot)

	# Refund unmatched overbet: if a player put in more than any other active
	# player (e.g. they raised and the only caller went all-in short), return the
	# uncallable excess — it has no one to win against.
	var overbet_refund := false
	for pidx in active_players:
		var own: int = contributed.get(pidx, 0)
		var others_max: int = 0
		for other in active_players:
			if other != pidx:
				others_max = max(others_max, int(contributed.get(other, 0)))
		var excess: int = own - others_max
		if excess > 0:
			players[pidx].receive_chips(excess)
			pot -= excess
			player_chips_changed.emit(pidx, players[pidx].chips)
			game_log.emit("%s refunded %d (unmatched overbet)." % [_pname(pidx), excess])
			overbet_refund = true
	if overbet_refund:
		pot_changed.emit(pot)

	_clear_bet_state()

# ---- Phase: Draw -------------------------------------------------------------

func _phase_draw(g: int) -> void:
	phase_changed.emit("DRAW")
	# Resume-aware: skip players in draw_completed; they already discarded+drew
	# in a previous session. Log header only on fresh entry.
	if round_state.draw_completed.is_empty():
		game_log.emit("--- Draw phase ---")
	for pidx in active_players:
		if round_state.draw_completed.has(pidx):
			continue
		if pidx == HUMAN_IDX:
			discard_input_needed.emit(pidx)
			var indices: Array = await _discard_ready
			if g != _game_gen: return
			_do_discard(pidx, indices)
			round_state.draw_completed.append(pidx)
			save_match_checkpoint()
		else:
			await _ai_think()
			if g != _game_gen: return
			_do_discard(pidx, AIPlayer.discard(pidx))
			round_state.draw_completed.append(pidx)

# ---- Phase: Moon swap --------------------------------------------------------

func _phase_moon_swap(g: int) -> void:
	# Resume-aware: moon_swap_completed marks players done with their decision.
	# Log header only on fresh entry.
	if round_state.moon_swap_completed.is_empty():
		game_log.emit("--- The Moon — swap your secret card or keep your hand? ---")
	for pidx in round_state.moon_secret.keys():
		if round_state.moon_swap_completed.has(pidx):
			continue
		var secret: Card = round_state.moon_secret[pidx]
		if not active_players.has(pidx):
			deck.add_cards([secret])
			round_state.moon_swap_completed.append(pidx)
			continue
		if pidx == HUMAN_IDX:
			arcana_choice_needed.emit(pidx, 18)
			await _arcana_effect_done
			if g != _game_gen: return
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
			round_state.moon_swap_completed.append(pidx)
			save_match_checkpoint()
		else:
			await _ai_think()
			if g != _game_gen: return
			var best_swap_idx := -1
			var best_score := AIPlayer.score_hand(players[pidx].hand)
			for i in players[pidx].hand.size():
				var test_hand := players[pidx].hand.duplicate()
				test_hand[i] = secret
				var s := AIPlayer.score_hand(test_hand)
				if s > best_score:
					best_score = s
					best_swap_idx = i
			if best_swap_idx >= 0:
				var old_card: Card = players[pidx].hand[best_swap_idx]
				players[pidx].hand[best_swap_idx] = secret
				deck.add_cards([old_card])
				player_hand_updated.emit(pidx, players[pidx].hand)
				game_log.emit("%s swaps their Moon secret into hand." % _pname(pidx))
			else:
				deck.add_cards([secret])
				game_log.emit("%s discards their Moon secret." % _pname(pidx))
			round_state.moon_swap_completed.append(pidx)
	round_state.moon_secret.clear()

# ---- Phase: Judgement re-entry -----------------------------------------------

func _phase_judgement_reentry(g: int) -> void:
	# Resume-aware: judgement_decided marks players done with their choice.
	# Recompute can_reenter each entry — folded players' chip counts could
	# change between rounds, so it's not stable across saves.
	if round_state.judgement_decided.is_empty():
		game_log.emit("--- Judgement — last chance to re-enter ---")
	var can_reenter: Array[int] = []
	for pidx in range(players.size()):
		if not active_players.has(pidx) and players[pidx].chips >= ante_amount:
			can_reenter.append(pidx)
	if can_reenter.is_empty():
		if round_state.judgement_decided.is_empty():
			game_log.emit("No folded players can afford to re-enter.")
		return
	if deck.size() < can_reenter.size() * 5:
		deck.build()
		deck.shuffle()
	for pidx in can_reenter:
		if round_state.judgement_decided.has(pidx):
			continue
		if pidx == HUMAN_IDX:
			arcana_choice_needed.emit(pidx, 20)
			await _arcana_effect_done
			if g != _game_gen: return
			if arcana_choice == 1:
				_do_reenter(pidx)
			else:
				game_log.emit("You choose to stay folded.")
			round_state.judgement_decided.append(pidx)
			save_match_checkpoint()
		else:
			await _ai_think()
			if g != _game_gen: return
			var expected_share := float(pot) / float(active_players.size() + 1)
			var threshold := float(ante_amount) * (1.5 if players[pidx].chips <= ante_amount * 2 else 1.1)
			if expected_share >= threshold:
				_do_reenter(pidx)
			else:
				game_log.emit("%s stays folded (not +EV to re-enter)." % _pname(pidx))
			round_state.judgement_decided.append(pidx)

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

func _phase_showdown(g: int) -> void:
	phase_changed.emit("SHOWDOWN")
	game_log.emit("--- Showdown (pot: %d) ---" % pot)

	# Tower fired earlier this round? Destroy half the pot now, after it has
	# had a chance to grow through betting. Applies before every award path
	# (uncontested, Sun split, Lovers split, normal showdown) so the halving
	# is consistent regardless of how the round resolves.
	if round_state.tower_pending and pot > 0:
		@warning_ignore("integer_division")
		var lost := (pot + 1) / 2
		pot = maxi(0, pot - lost)
		pot_changed.emit(pot)
		game_log.emit("The Tower strikes — %d chips lost to ruin! (pot: %d)" % [lost, pot])
		round_state.tower_pending = false

	if active_players.size() == 1:
		var solo := active_players[0]
		game_log.emit("%s %s %d uncontested." % [_pname(solo), "win" if solo == HUMAN_IDX else "wins", pot])
		_award_pot(active_players)
		_commit_journal(false, false, 0.0)
		round_ended.emit([solo], [], false)
		# Page bonus only triggers in rounds where an arcana actually fired —
		# otherwise Pages turn into a passive attrition tax. Tying the bonus to
		# arcana rounds keeps Pages identified as arcana keys, not chip vacuums.
		if players[solo].has_page and round_state.arcana_drawn:
			var bonus_total := 0
			for pidx in range(players.size()):
				if pidx != solo and players[pidx].chips >= ante_amount:
					var paid := players[pidx].bet(ante_amount)
					bonus_total += paid
					player_chips_changed.emit(pidx, players[pidx].chips)
			players[solo].receive_chips(bonus_total)
			player_chips_changed.emit(solo, players[solo].chips)
			page_bonus.emit(solo, ante_amount)
			game_log.emit("%s collects the Page bonus: +%d from each player!" % [_pname(solo), ante_amount])
		return

	if round_state.sun_end:
		game_log.emit("The Sun splits the pot equally.")
		await get_tree().create_timer(1.5).timeout
		if g != _game_gen: return
		@warning_ignore("integer_division")
		var share := pot / active_players.size()
		for pidx in active_players:
			players[pidx].receive_chips(share)
			player_chips_changed.emit(pidx, players[pidx].chips)
		pot = 0
		pot_changed.emit(pot)
		# Sun splits the pot regardless of hand strength, so it doesn't qualify
		# as a "showdown" for bluff detection — count the round but skip showdown stats.
		_commit_journal(false, false, 0.0)
		round_ended.emit(active_players, [], true)
		return

	var opts  := round_state.eval_options()
	var scores: Dictionary = {}
	for pidx in active_players:
		scores[pidx] = HandEvaluator.score(players[pidx].hand, opts["king_beats_ace"], opts["inverted_values"], opts["fool_active"])

	for pidx in active_players:
		var card_names := ", ".join(players[pidx].hand.map(func(c: Card): return c.display_name()))
		game_log.emit("%s shows: %s (%s)" % [_pname(pidx), HandEvaluator.hand_type_name(scores[pidx]), card_names])
		player_hand_revealed.emit(pidx, players[pidx].hand)
		await get_tree().create_timer(0.8).timeout
		if g != _game_gen: return

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
			game_log.emit("%s %s %d with %s!" % [_pname(winners[0]), "win" if winners[0] == HUMAN_IDX else "wins", won, hand_names[0]])
		else:
			var names := ", ".join(winners.map(func(w): return _pname(w)))
			@warning_ignore("integer_division")
			game_log.emit("Tie! %s each win %d (%s)." % [names, won / winners.size(), hand_names[0]])

	var human_reached := active_players.has(HUMAN_IDX)
	var human_hand_type := (float(scores.get(HUMAN_IDX, 0)) / 1048576.0) if human_reached else 0.0
	_commit_journal(human_reached, winners.has(HUMAN_IDX), human_hand_type)

	round_ended.emit(winners, hand_names, split)

	# Page bonus only fires in arcana rounds (see uncontested branch above).
	for w in winners:
		if players[w].has_page and round_state.arcana_drawn:
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

func _draw_arcana(g: int) -> void:
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
	await _arcana_effect_done
	if g != _game_gen: return
	# Mark the phase so any human-action save inside the arcana captures the
	# right value. resume_match maps "ARCANA" → re-enter _apply_arcana with
	# round_state.arcana_id, then continue the round.
	_current_phase = "ARCANA"
	# Snapshot sort-affecting flags; if Strength or Emperor flipped one on, the
	# table needs to re-render the human's hand so the display order matches.
	# The original set_hand call in _phase_deal fires before this point.
	var sort_was_inverted := round_state.inverted_values
	var sort_was_king_high := round_state.king_beats_ace
	await _apply_arcana(id, g)
	if g != _game_gen: return
	if (round_state.inverted_values != sort_was_inverted \
			or round_state.king_beats_ace != sort_was_king_high) \
			and active_players.has(HUMAN_IDX):
		display_sort_changed.emit()

func _apply_arcana(id: int, g: int) -> void:
	# All 22 per-arcana effects live in arcana_effects.gd, mirroring the
	# AIPlayer pattern: static class accessing GameManager state directly.
	await ArcanaEffects.apply(id, g)

# ---- Helpers -----------------------------------------------------------------

# Snapshot the current match into RunManager. Called after every human-driven
# state transition (bet, discard, arcana choice). No-op when not in a career
# match — Quick Play and detached sessions skip persistence.
func save_match_checkpoint() -> void:
	if not RunManager.session_belongs_to_run() or not RunManager.run_active:
		return
	var snap := make_match_snapshot()
	if snap != null:
		RunManager.save_match_state(snap)

# Captures everything needed to reconstruct the current match state. Cards
# are encoded as [suit, rank] pairs; Dictionaries with Card values get their
# values pair-encoded so the result is ConfigFile-safe end to end.
func make_match_snapshot() -> MatchState:
	var m := MatchState.new()
	m.phase = _current_phase
	m.deck = deck.to_pairs() if deck != null else []
	m.dealer_idx = dealer_idx
	m.pot = pot
	m.ante_amount = ante_amount
	m.round_num = round_num
	m.last_round = last_round
	m.active_players = active_players.duplicate()
	m.arcana_deck = arcana_deck.duplicate()
	m.arcana_pos = arcana_pos
	m.debug_arcana_id = debug_arcana_id
	m.human_journal = _human_journal.duplicate(true)

	for p: Player in players:
		m.players_chips.append(p.chips)
		m.players_folded.append(p.folded)
		m.players_hands.append(p.hand_to_pairs())
		m.players_profile_names.append(p.profile.persona_name if p.profile != null else "")
		if p.profile != null and p.memory != null:
			m.opponent_memories[p.profile.persona_name] = p.memory.to_dict()

	m.rs_king_beats_ace = round_state.king_beats_ace
	m.rs_inverted_values = round_state.inverted_values
	m.rs_skip_draw = round_state.skip_draw
	m.rs_split_pot_two_best = round_state.split_pot_two_best
	m.rs_raise_must_double = round_state.raise_must_double
	m.rs_no_forced_min_bet = round_state.no_forced_min_bet
	m.rs_hanged_man_active = round_state.hanged_man_active
	m.rs_fool_active = round_state.fool_active
	m.rs_six_card_hand = round_state.six_card_hand
	m.rs_tower_pending = round_state.tower_pending
	m.rs_death_end = round_state.death_end
	m.rs_sun_end = round_state.sun_end
	m.rs_arcana_id = round_state.arcana_id
	m.rs_arcana_drawn = round_state.arcana_drawn
	m.rs_hierophant_active = round_state.hierophant_active
	m.rs_moon_reveal_done = round_state.moon_reveal_done
	m.rs_judgement_active = round_state.judgement_active

	# Dictionaries with Card values → pair-encode in place.
	for pidx in round_state.priestess_revealed:
		m.rs_priestess_revealed[pidx] = (round_state.priestess_revealed[pidx] as Card).to_pair()
	for pidx in round_state.moon_secret:
		m.rs_moon_secret[pidx] = (round_state.moon_secret[pidx] as Card).to_pair()
	for c in round_state.temperance_flop:
		m.rs_temperance_flop.append((c as Card).to_pair())

	m.rs_bet_current = round_state.bet_current
	m.rs_bet_contributed = round_state.bet_contributed.duplicate(true)
	m.rs_bet_acted = round_state.bet_acted.duplicate(true)
	m.rs_bet_player_raises = round_state.bet_player_raises.duplicate(true)
	m.rs_bet_raise_count = round_state.bet_raise_count
	m.rs_bet_queue = round_state.bet_queue.duplicate()
	m.rs_bet_in_progress = round_state.bet_in_progress

	m.rs_draw_completed = round_state.draw_completed.duplicate()
	m.rs_moon_swap_completed = round_state.moon_swap_completed.duplicate()
	m.rs_judgement_decided = round_state.judgement_decided.duplicate()
	m.rs_temperance_completed = round_state.temperance_completed.duplicate()
	m.rs_magician_completed = round_state.magician_completed.duplicate()
	m.rs_star_completed = round_state.star_completed.duplicate()
	m.rs_chariot_chosen = round_state.chariot_chosen.duplicate(true)
	m.rs_chariot_passed = round_state.chariot_passed
	return m

# Restores a saved match state and re-enters the saved phase to continue play.
# Called by RunManager.launch_current_match when a mid-match save exists; the
# normal setup_game path is bypassed entirely (player counts/chips come from
# the snapshot, not the ladder config).
func resume_match(state: MatchState) -> void:
	_game_gen += 1
	var g := _game_gen
	last_round = state.last_round
	dealer_idx = state.dealer_idx
	pot = state.pot
	ante_amount = state.ante_amount
	round_num = state.round_num
	arcana_pos = state.arcana_pos
	debug_arcana_id = state.debug_arcana_id
	_human_journal = state.human_journal.duplicate(true)
	active_players.assign(state.active_players)
	arcana_deck.assign(state.arcana_deck)

	# Reset the arcana-choice scratch vars; the panel will repopulate them
	# when the resumed phase reaches an arcana_choice_needed prompt.
	arcana_choice = -1
	arcana_choice2 = -1

	# Rebuild deck.
	deck = Deck.new()
	deck.load_pairs(state.deck)

	# Rebuild players. Profile is reconstructed from persona_name by looking
	# up the AI factory; memory is restored from opponent_memories.
	players.clear()
	for i in state.players_chips.size():
		var p := Player.new(int(state.players_chips[i]))
		p.folded = bool(state.players_folded[i])
		p.set_hand_from_pairs(state.players_hands[i])
		var pname := String(state.players_profile_names[i])
		if pname != "":
			p.profile = _profile_for_persona(pname)
			if state.opponent_memories.has(pname):
				p.memory = OpponentMemory.from_dict(state.opponent_memories[pname])
			else:
				p.memory = OpponentMemory.new()
		players.append(p)

	# Rebuild RoundState.
	round_state = RoundState.new()
	round_state.king_beats_ace = state.rs_king_beats_ace
	round_state.inverted_values = state.rs_inverted_values
	round_state.skip_draw = state.rs_skip_draw
	round_state.split_pot_two_best = state.rs_split_pot_two_best
	round_state.raise_must_double = state.rs_raise_must_double
	round_state.no_forced_min_bet = state.rs_no_forced_min_bet
	round_state.hanged_man_active = state.rs_hanged_man_active
	round_state.fool_active = state.rs_fool_active
	round_state.six_card_hand = state.rs_six_card_hand
	round_state.tower_pending = state.rs_tower_pending
	round_state.death_end = state.rs_death_end
	round_state.sun_end = state.rs_sun_end
	round_state.arcana_id = state.rs_arcana_id
	round_state.arcana_drawn = state.rs_arcana_drawn
	round_state.hierophant_active = state.rs_hierophant_active
	round_state.moon_reveal_done = state.rs_moon_reveal_done
	round_state.judgement_active = state.rs_judgement_active

	# Pair-decode Card dicts/arrays back into Card instances.
	for pidx in state.rs_priestess_revealed:
		round_state.priestess_revealed[int(pidx)] = Card.from_pair(state.rs_priestess_revealed[pidx] as Array)
	for pidx in state.rs_moon_secret:
		round_state.moon_secret[int(pidx)] = Card.from_pair(state.rs_moon_secret[pidx] as Array)
	for pair in state.rs_temperance_flop:
		round_state.temperance_flop.append(Card.from_pair(pair as Array))

	round_state.bet_current = state.rs_bet_current
	round_state.bet_contributed = state.rs_bet_contributed.duplicate(true)
	round_state.bet_acted = state.rs_bet_acted.duplicate(true)
	round_state.bet_player_raises = state.rs_bet_player_raises.duplicate(true)
	round_state.bet_raise_count = state.rs_bet_raise_count
	round_state.bet_queue.assign(state.rs_bet_queue)
	round_state.bet_in_progress = state.rs_bet_in_progress

	round_state.draw_completed.assign(state.rs_draw_completed)
	round_state.moon_swap_completed.assign(state.rs_moon_swap_completed)
	round_state.judgement_decided.assign(state.rs_judgement_decided)
	round_state.temperance_completed.assign(state.rs_temperance_completed)
	round_state.magician_completed.assign(state.rs_magician_completed)
	round_state.star_completed.assign(state.rs_star_completed)
	round_state.chariot_chosen = state.rs_chariot_chosen.duplicate(true)
	round_state.chariot_passed = state.rs_chariot_passed

	_current_phase = state.phase

	# UI rebuilds itself from current state on this signal.
	state_restored.emit()

	# RunManager already cleared the on-disk save before calling us; we'll
	# write a fresh checkpoint at the next human action.

	# Re-enter the saved phase. _continue_from_phase handles the rest of the
	# round normally.
	await _continue_from_phase(g, state.phase)
	if g != _game_gen: return
	# Round finished — advance into the normal multi-round loop, mirroring
	# start_game's structure.
	if _should_end_game():
		var chips: Array = []
		for p in players:
			chips.append(p.chips)
		game_ended.emit(chips)
		return
	await _round_advance_ready
	if g != _game_gen: return
	while true:
		await _run_round(g)
		if g != _game_gen: return
		if _should_end_game():
			break
		await _round_advance_ready
		if g != _game_gen: return
	var final_chips: Array = []
	for p in players:
		final_chips.append(p.chips)
	game_ended.emit(final_chips)

func _profile_for_persona(persona: String) -> AIProfile:
	# Mirror of the factory in setup_game; RunManager.launch_current_match
	# re-applies its ladder overrides on top of these defaults.
	if persona == AIProfile.aggressor().persona_name: return AIProfile.aggressor()
	if persona == AIProfile.rock().persona_name:      return AIProfile.rock()
	if persona == AIProfile.ghost().persona_name:     return AIProfile.ghost()
	return AIProfile.aggressor()  # fallback

# Reset the promoted betting-loop fields after a bet phase completes. Called
# from every exit path of _phase_bet so BET1 and BET2 don't share state.
func _clear_bet_state() -> void:
	round_state.bet_in_progress = false
	round_state.bet_current = 0
	round_state.bet_contributed = {}
	round_state.bet_acted = {}
	round_state.bet_player_raises = {}
	round_state.bet_raise_count = 0
	round_state.bet_queue = []

func _ai_think() -> void:
	await get_tree().create_timer(randf_range(0.4, 0.9)).timeout

func _pname(pidx: int) -> String:
	if pidx == HUMAN_IDX:
		return "You"
	var profile := players[pidx].profile
	return profile.persona_name if profile else "AI %d" % pidx

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
		return
	game_log.emit("%s discards %d card(s)." % [_pname(pidx), indices.size()])
	var discarded := players[pidx].discard_at(indices)
	deck.add_cards(discarded)
	var new_cards := deck.deal_many(discarded.size())
	players[pidx].receive_cards(new_cards)
	cards_drawn.emit(pidx, new_cards.size())
	player_hand_updated.emit(pidx, players[pidx].hand)
	if pidx == HUMAN_IDX:
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

func _reset_journal() -> void:
	_human_journal = {
		"human_active":          false,
		"human_folded":          false,
		"human_folded_to_raise": false,
		"human_called_raise":    false,
		"human_raises":          0,
		"human_all_in":          false,
	}

func _commit_journal(human_reached_showdown: bool, human_won: bool, human_hand_type: float) -> void:
	for i in range(players.size()):
		if i == HUMAN_IDX:
			continue
		var mem: OpponentMemory = players[i].memory
		if mem != null:
			mem.note_round_outcome(_human_journal, human_hand_type, human_won, human_reached_showdown)

# ---- Public API (UI calls these) ---------------------------------------------

func submit_bet(action: String, amount: int = 0) -> void:
	_bet_ready.emit(action, amount)

func submit_discard(indices: Array) -> void:
	_discard_ready.emit(indices)

func complete_arcana_effect() -> void:
	_arcana_effect_done.emit()

func confirm_next_round() -> void:
	_round_advance_ready.emit()

func submit_arcana_choice(choice: int) -> void:
	arcana_choice = choice
	_arcana_effect_done.emit()

func submit_arcana_choice_pair(choice1: int, choice2: int) -> void:
	arcana_choice = choice1
	arcana_choice2 = choice2
	_arcana_effect_done.emit()
