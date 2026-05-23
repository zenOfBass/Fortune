class_name ArcanaEffects
extends RefCounted

# Per-arcana effect dispatcher. Each branch reads/writes GameManager state
# directly via the global autoload (same pattern as AIPlayer). Interactive
# arcana await on gm._arcana_effect_done after emitting arcana_choice_needed,
# letting the UI panel surface the choice and call back via submit_*.
#
# Modifier-only arcana (Emperor, Strength, Hermit, etc.) just set a flag on
# RoundState and emit a game_log line; the actual rule change is enforced by
# whoever reads that flag (HandEvaluator, _phase_bet, _phase_showdown).
#
# The `g` parameter is the caller's _game_gen snapshot — every await is paired
# with `if g != gm._game_gen: return` so a new game cancels in-flight arcana.

static func apply(id: int, g: int) -> void:
	var gm := GameManager
	match id:
		0:  # The Fool — wild-card evaluation
			gm.round_state.fool_active = true
			gm.game_log.emit("The Fool is wild — best possible hand counts!")

		20:  # Judgement — folded players may pay ante and re-enter before showdown
			gm.round_state.judgement_active = true
			gm.game_log.emit("Judgement — the dead may rise! Folded players may pay %d to re-enter." % gm.ante_amount)

		14:  # Temperance — discard one card, pick from a 3-card face-up flop
			# Resume-aware: temperance_flop on RoundState is the source of truth
			# (built fresh if empty, otherwise restored from the save). Players
			# in temperance_completed are skipped — they already discarded+picked.
			var fresh_temperance := gm.round_state.temperance_completed.is_empty() \
					and gm.round_state.temperance_flop.is_empty()
			if fresh_temperance:
				gm.game_log.emit("Temperance — each player discards one card and picks from the flop.")
				var fresh_flop: Array[Card] = []
				for _i in 3:
					if not gm.deck.is_empty():
						fresh_flop.append(gm.deck.deal_one())
				gm.round_state.temperance_flop = fresh_flop
			var flop: Array = gm.round_state.temperance_flop
			if flop.is_empty() and fresh_temperance:
				gm.game_log.emit("Deck too empty for Temperance flop.")
			else:
				for pidx in gm.active_players:
					if gm.round_state.temperance_completed.has(pidx):
						continue
					if flop.is_empty():
						gm.game_log.emit("%s — no flop cards left, skipped." % gm._pname(pidx))
						gm.round_state.temperance_completed.append(pidx)
						continue
					if pidx == gm.HUMAN_IDX:
						gm.arcana_choice_needed.emit(pidx, 14)
						await gm._arcana_effect_done
						if g != gm._game_gen: return
						var discard_idx := gm.arcana_choice
						var flop_idx := gm.arcana_choice2
						if discard_idx >= 0 and discard_idx < gm.players[pidx].hand.size() \
								and flop_idx >= 0 and flop_idx < flop.size():
							var taken: Card = flop[flop_idx]
							var discarded: Card = gm.players[pidx].hand[discard_idx]
							gm.players[pidx].hand.remove_at(discard_idx)
							gm.players[pidx].receive_cards([taken])
							gm.deck.add_cards([discarded])
							flop.remove_at(flop_idx)
							gm.player_hand_updated.emit(pidx, gm.players[pidx].hand)
							gm.game_log.emit("You discard and take from the flop.")
						else:
							gm.game_log.emit("You skip Temperance.")
						gm.round_state.temperance_completed.append(pidx)
						gm.save_match_checkpoint()
					else:
						await gm._ai_think()
						if g != gm._game_gen: return
						var best_score := AIPlayer.score_hand(gm.players[pidx].hand)
						var best_hand_pick := -1
						var best_flop_pick := -1
						for fi in flop.size():
							for hi in gm.players[pidx].hand.size():
								var test_hand := gm.players[pidx].hand.duplicate()
								test_hand[hi] = flop[fi]
								var s := AIPlayer.score_hand(test_hand)
								if s > best_score:
									best_score = s
									best_hand_pick = hi
									best_flop_pick = fi
						if best_hand_pick >= 0:
							var taken: Card = flop[best_flop_pick]
							var discarded: Card = gm.players[pidx].hand[best_hand_pick]
							gm.players[pidx].hand.remove_at(best_hand_pick)
							gm.players[pidx].receive_cards([taken])
							gm.deck.add_cards([discarded])
							flop.remove_at(best_flop_pick)
							gm.player_hand_updated.emit(pidx, gm.players[pidx].hand)
							gm.game_log.emit("%s discards and takes from the flop." % gm._pname(pidx))
						else:
							gm.game_log.emit("%s passes on the Temperance flop." % gm._pname(pidx))
						gm.round_state.temperance_completed.append(pidx)
				if not flop.is_empty():
					gm.deck.add_cards(flop)
					gm.round_state.temperance_flop = []

		18:  # The Moon — each player draws a secret card; may swap before showdown
			# Resume-aware: moon_secret.has(pidx) means this player already drew
			# their secret in a previous session — skip the deal AND the prompt.
			if gm.round_state.moon_secret.is_empty():
				gm.game_log.emit("The Moon — each player draws a secret card.")
			for pidx in gm.active_players:
				if gm.round_state.moon_secret.has(pidx):
					continue
				if gm.deck.is_empty():
					gm.game_log.emit("%s — deck empty, skipped." % gm._pname(pidx))
					continue
				var drawn: Card = gm.deck.deal_one()
				gm.round_state.moon_secret[pidx] = drawn
				if pidx == gm.HUMAN_IDX:
					gm.arcana_choice_needed.emit(pidx, 18)
					await gm._arcana_effect_done
					if g != gm._game_gen: return
					gm.round_state.moon_reveal_done = true
					gm.game_log.emit("You tuck a card away secretly.")
					gm.save_match_checkpoint()
				else:
					gm.game_log.emit("%s draws a secret card." % gm._pname(pidx))

		2:  # The High Priestess — each player reveals one card face-up for the round
			# Resume-aware: priestess_revealed.has(pidx) means this player already
			# revealed in a previous session — skip.
			if gm.round_state.priestess_revealed.is_empty():
				gm.game_log.emit("The High Priestess — each player reveals one card.")
			for pidx in gm.active_players:
				if gm.round_state.priestess_revealed.has(pidx):
					continue
				if gm.players[pidx].hand.is_empty():
					continue
				if pidx == gm.HUMAN_IDX:
					gm.arcana_choice_needed.emit(pidx, 2)
					await gm._arcana_effect_done
					if g != gm._game_gen: return
					var idx := gm.arcana_choice
					if idx >= 0 and idx < gm.players[pidx].hand.size():
						gm.round_state.priestess_revealed[pidx] = gm.players[pidx].hand[idx]
						gm.player_hand_updated.emit(pidx, gm.players[pidx].hand)
						gm.game_log.emit("You reveal the %s." % gm.players[pidx].hand[idx].display_name())
					gm.save_match_checkpoint()
				else:
					await gm._ai_think()
					if g != gm._game_gen: return
					var idx := AIPlayer.weakest_card_idx(pidx)
					gm.round_state.priestess_revealed[pidx] = gm.players[pidx].hand[idx]
					gm.player_hand_updated.emit(pidx, gm.players[pidx].hand)
					gm.game_log.emit("%s reveals a card." % gm._pname(pidx))

		1:  # The Magician — each player draws one card; keep it if suit guess is correct
			# Resume-aware: skip players in magician_completed; they already drew.
			if gm.round_state.magician_completed.is_empty():
				gm.game_log.emit("The Magician — guess your drawn card's suit to keep it!")
			for pidx in gm.active_players:
				if gm.round_state.magician_completed.has(pidx):
					continue
				if gm.deck.is_empty():
					gm.game_log.emit("%s — deck empty, skipped." % gm._pname(pidx))
					gm.round_state.magician_completed.append(pidx)
					continue
				var drawn: Card = gm.deck.deal_one()
				if pidx == gm.HUMAN_IDX:
					gm.arcana_choice_needed.emit(pidx, 1)
					await gm._arcana_effect_done
					if g != gm._game_gen: return
					if gm.arcana_choice == (drawn.suit as int):
						gm.players[pidx].receive_cards([drawn])
						gm.player_hand_updated.emit(pidx, gm.players[pidx].hand)
						gm.game_log.emit("Correct! You drew the %s." % drawn.display_name())
					else:
						gm.deck.add_cards([drawn])
						gm.game_log.emit("Wrong — the card was the %s." % drawn.display_name())
					gm.round_state.magician_completed.append(pidx)
					gm.save_match_checkpoint()
				else:
					await gm._ai_think()
					if g != gm._game_gen: return
					if randi() % 4 == (drawn.suit as int):
						gm.players[pidx].receive_cards([drawn])
						gm.player_hand_updated.emit(pidx, gm.players[pidx].hand)
						gm.game_log.emit("%s guesses correctly!" % gm._pname(pidx))
					else:
						gm.deck.add_cards([drawn])
						gm.game_log.emit("%s guesses wrong." % gm._pname(pidx))
					gm.round_state.magician_completed.append(pidx)

		17:  # The Star — in turn order, may swap one card with top of deck
			# Resume-aware: skip players in star_completed; they already chose.
			if gm.round_state.star_completed.is_empty():
				gm.game_log.emit("The Star — each player may swap one card with the top of the deck.")
			for pidx in gm.active_players:
				if gm.round_state.star_completed.has(pidx):
					continue
				if pidx == gm.HUMAN_IDX:
					gm.arcana_choice_needed.emit(pidx, 17)
					await gm._arcana_effect_done
					if g != gm._game_gen: return
					var choice := gm.arcana_choice
					if choice >= 0 and not gm.deck.is_empty():
						var new_card: Card = gm.deck.deal_one()
						var old_card: Card = gm.players[pidx].hand[choice]
						gm.players[pidx].hand.remove_at(choice)
						gm.deck.add_cards([old_card])
						gm.players[pidx].receive_cards([new_card])
						gm.player_hand_updated.emit(pidx, gm.players[pidx].hand)
						gm.game_log.emit("You swap a card with the deck.")
					else:
						gm.game_log.emit("You pass.")
					gm.round_state.star_completed.append(pidx)
					gm.save_match_checkpoint()
				else:
					await gm._ai_think()
					if g != gm._game_gen: return
					var hand_type: float = AIPlayer.score_hand(gm.players[pidx].hand) / 1048576.0
					if not gm.deck.is_empty() and hand_type < 3.0:
						var idx := AIPlayer.weakest_card_idx(pidx)
						var new_card: Card = gm.deck.deal_one()
						var old_card: Card = gm.players[pidx].hand[idx]
						gm.players[pidx].hand.remove_at(idx)
						gm.deck.add_cards([old_card])
						gm.players[pidx].receive_cards([new_card])
						gm.player_hand_updated.emit(pidx, gm.players[pidx].hand)
						gm.game_log.emit("%s swaps a card." % gm._pname(pidx))
					else:
						gm.game_log.emit("%s passes." % gm._pname(pidx))
					gm.round_state.star_completed.append(pidx)

		7:  # The Chariot — each player passes one card to the left
			# Resume-aware: chariot_chosen accumulates pass-1 choices across saves;
			# chariot_passed gates pass-2 so we don't re-move cards on resume.
			if not gm.round_state.chariot_passed:
				for pidx in gm.active_players:
					if gm.round_state.chariot_chosen.has(pidx):
						continue
					if pidx == gm.HUMAN_IDX:
						gm.arcana_choice_needed.emit(pidx, 7)
						await gm._arcana_effect_done
						if g != gm._game_gen: return
						gm.round_state.chariot_chosen[pidx] = gm.arcana_choice
						gm.game_log.emit("You pass a card left.")
						gm.save_match_checkpoint()
					else:
						await gm._ai_think()
						if g != gm._game_gen: return
						gm.round_state.chariot_chosen[pidx] = AIPlayer.weakest_card_idx(pidx)
						gm.game_log.emit("%s passes a card left." % gm._pname(pidx))
				# Pass 2 — cards actually move. Synchronous, no awaits, single shot.
				var passing: Dictionary = {}
				for pidx in gm.active_players:
					passing[pidx] = gm.players[pidx].hand[gm.round_state.chariot_chosen[pidx]]
				for pidx in gm.active_players:
					gm.players[pidx].hand.erase(passing[pidx])
				for i in gm.active_players.size():
					var from_pidx: int = gm.active_players[i]
					var to_pidx: int = gm.active_players[(i + 1) % gm.active_players.size()]
					gm.players[to_pidx].receive_cards([passing[from_pidx]])
				for pidx in gm.active_players:
					gm.player_hand_updated.emit(pidx, gm.players[pidx].hand)
				gm.game_log.emit("The Chariot — cards passed left!")
				gm.round_state.chariot_passed = true

		3:  # The Empress — each player draws a 6th card
			for pidx: int in gm.active_players:
				if not gm.deck.is_empty():
					gm.players[pidx].receive_cards([gm.deck.deal_one()])
					gm.player_hand_updated.emit(pidx, gm.players[pidx].hand)
			gm.round_state.six_card_hand = true
			gm.game_log.emit("The Empress grants a 6th card to each player.")

		4:
			gm.round_state.king_beats_ace = true
			gm.game_log.emit("The Emperor rules — Kings beat Aces this round.")

		5:
			gm.round_state.hierophant_active = true
			gm.game_log.emit("The Hierophant will cancel the next arcana drawn.")

		6:
			gm.round_state.split_pot_two_best = true
			gm.game_log.emit("The Lovers — the pot splits between the two best hands.")

		8:
			gm.round_state.inverted_values = true
			gm.game_log.emit("Strength inverts the ranking — low cards win.")

		9:
			gm.round_state.skip_draw = true
			gm.game_log.emit("The Hermit — no draw phase this round.")

		10: # Wheel of Fortune — collect all cards, shuffle, redeal
			var cards_each := 6 if gm.round_state.six_card_hand else 5
			var all_cards: Array[Card] = []
			for p: Player in gm.players:
				all_cards.append_array(p.hand)
				p.hand.clear()
			gm.deck.add_cards(all_cards)
			gm.deck.shuffle()
			for pidx: int in gm.active_players:
				gm.players[pidx].receive_cards(gm.deck.deal_many(cards_each))
				gm.player_hand_updated.emit(pidx, gm.players[pidx].hand)
			gm.game_log.emit("The Wheel of Fortune spins — all hands redealt!")

		11:
			gm.round_state.no_forced_min_bet = true
			gm.game_log.emit("Justice — no minimum raise required.")

		12:
			gm.round_state.hanged_man_active = true
			gm.game_log.emit("The Hanged Man — go all-in to draw an extra card.")

		13:
			gm.round_state.death_end = true
			gm.game_log.emit("Death arrives — immediate showdown!")

		15:
			gm.round_state.raise_must_double = true
			gm.game_log.emit("The Devil — raises must at least double the current bet.")

		16: # The Tower — half the pot (rounded up) is destroyed at showdown.
			# Deferred from draw-time so the pot has had time to grow through
			# betting; otherwise it'd usually destroy 1 chip and feel like nothing.
			gm.round_state.tower_pending = true
			gm.game_log.emit("The Tower looms — half the pot will crumble at showdown.")

		19:
			gm.round_state.sun_end = true
			gm.game_log.emit("The Sun shines — equal split at showdown.")

		21: # The World — this is the last round
			gm.last_round = true
			gm.last_round_announced.emit()
			gm.game_log.emit("The World — this is the final round!")
