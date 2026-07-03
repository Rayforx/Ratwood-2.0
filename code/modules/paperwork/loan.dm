#define LOAN_NOTE_BLANK 0
#define LOAN_NOTE_FUNDED 1
#define LOAN_NOTE_SIGNED 2
#define LOAN_NOTE_PAID 3

GLOBAL_LIST_EMPTY(loan_ledger)

GLOBAL_LIST_INIT(debt_chastity_styles, list(
	"belt" = list("label" = "Iron Belt", "cname" = "debt-bound chastity belt", "chastity_type" = 0, "organtype" = 0, "sprite" = /datum/sprite_accessory/chastity/full),
	"cage" = list("label" = "Chastity Cage", "cname" = "debt-bound chastity cage", "chastity_type" = 1, "organtype" = 1, "sprite" = /datum/sprite_accessory/chastity/cage),
	"cursed" = list("label" = "Cursed Belt", "cname" = "cursed debt-bound chastity belt", "chastity_type" = 0, "organtype" = 0, "sprite" = /datum/sprite_accessory/chastity/cursed_belt),
))

/datum/loan
	var/debtor_name
	var/creditor_name
	var/principal = 0
	var/surcharge = 0
	var/interest_rate = 10
	var/base_debt = 0
	var/owed = 0
	var/paid = FALSE
	var/time_signed
	var/due_days = 2
	var/days_elapsed = 0
	var/punish_forever = FALSE
	var/list/clause_types = list()
	var/list/applied_clauses = list() // clause typepaths that actually took hold on the debtor
	var/clauses_fired = FALSE
	var/release_pending = FALSE
	var/brand_text
	var/chastity_style = "belt"
	var/off_the_books = FALSE
	var/repaid_pool = 0
	var/datum/bounty/posted_bounty
	var/obj/item/loan_note/note
	var/obj/item/loan_note/debtor_note

/datum/loan/New(debtor, creditor, amount, note_surcharge = 0, note_rate = 10, note_due = 2, note_forever = FALSE, list/note_clauses)
	debtor_name = debtor
	creditor_name = creditor
	principal = amount
	surcharge = note_surcharge
	interest_rate = note_rate
	base_debt = principal + surcharge
	owed = base_debt
	due_days = note_due
	punish_forever = note_forever
	if(islist(note_clauses))
		clause_types = note_clauses.Copy()
	time_signed = world.time

/datum/loan/proc/repay(amount)
	if(paid)
		return 0
	var/applied = min(floor(amount), owed)
	if(applied < 1)
		return 0
	owed -= applied
	if(owed <= 0)
		owed = 0
		paid = TRUE
		for(var/obj/item/loan_note/paper in list(note, debtor_note))
			if(QDELETED(paper))
				continue
			paper.note_state = LOAN_NOTE_PAID
			paper.rebuild_info()
			paper.update_icon_state()
		if(clauses_fired && !punish_forever)
			release_pending = TRUE
			try_release()
	return applied

// The due date is exact: the debt defaults at the due_days-th dawn after signing.
/datum/loan/proc/is_overdue()
	return !paid && days_elapsed >= due_days

/datum/loan/proc/accrue_daily()
	if(paid)
		return
	days_elapsed++
	if(interest_rate > 0 && base_debt > 0)
		owed += max(1, round(base_debt * interest_rate / 100, 1))

// Clauses that could not take hold this dawn (debtor busy, slot occupied) are retried next dawn.
/datum/loan/proc/process_clauses()
	if(release_pending)
		try_release()
		return
	if(paid || !length(clause_types) || !is_overdue())
		return
	var/mob/living/carbon/human/debtor = find_living_by_name(debtor_name)
	if(!debtor)
		return
	var/already_announced = clauses_fired
	for(var/clause_type in clause_types)
		if(paid)
			break // a clause (wage seizure) may settle the debt mid-loop
		if(clause_type in applied_clauses)
			continue
		var/datum/loan_clause/clause = get_loan_clause(clause_type)
		if(clause && clause.apply(debtor, src))
			applied_clauses |= clause_type
			clauses_fired = TRUE
	// Skip the default announcement if a clause (wage seizure) already settled the debt this
	// same dawn, so the debtor is not told they defaulted a heartbeat before it is lifted.
	if(clauses_fired && !already_announced && !paid)
		to_chat(debtor, span_userdanger("The debt you signed for has come due unpaid. Its terms take hold of you!"))
		debtor.visible_message(span_danger("A dreadful weight settles over [debtor] as an unpaid debt comes due."))
		send_ooc_note("<b>DEBT:</b> [debtor_name] has defaulted on your loan. The contract's terms have taken hold.", name = creditor_name)
	if(paid && clauses_fired && !punish_forever && length(applied_clauses) && !release_pending)
		release_pending = TRUE
		try_release(debtor)
	for(var/clause_type in applied_clauses)
		if(paid)
			break // a dawn effect (wage seizure) may settle the debt mid-loop
		var/datum/loan_clause/clause = get_loan_clause(clause_type)
		if(clause)
			clause.dawn_tick(debtor, src)

/datum/loan/proc/try_release(mob/living/carbon/human/debtor)
	if(!release_pending)
		return
	if(!debtor)
		debtor = find_living_by_name(debtor_name)
	if(!debtor)
		return
	for(var/clause_type in applied_clauses)
		var/datum/loan_clause/clause = get_loan_clause(clause_type)
		if(clause)
			clause.release(debtor, src)
	applied_clauses.Cut()
	release_pending = FALSE
	to_chat(debtor, span_greentext("Your debt is settled. The terms that bound you fall away."))
	debtor.visible_message(span_notice("A weight lifts from [debtor] as a settled debt releases its hold."))

/proc/accrue_loan_interest()
	for(var/datum/loan/loan in GLOB.loan_ledger)
		loan.accrue_daily()
		loan.process_clauses()

// Only a present, living, connected debtor counts: clauses must not fire on corpses or
// logged-off bodies, and a null client would silently bypass content-preference gates.
/proc/find_living_by_name(name)
	if(!name)
		return
	for(var/mob/living/carbon/human/human in GLOB.human_list)
		if(human.real_name == name && human.client && human.stat != DEAD)
			return human

/obj/item/loan_note
	name = "loan note"
	desc = "A binding loan note, waiting for coin and a signature."
	icon = 'icons/roguetown/items/misc.dmi'
	icon_state = "scrollwrite"
	w_class = WEIGHT_CLASS_TINY
	dropshrink = 0.6
	throw_range = 3
	resistance_flags = FLAMMABLE
	firefuel = 30 SECONDS
	sellprice = 2
	var/info
	var/folded = FALSE
	var/base_name
	var/note_state = LOAN_NOTE_BLANK
	var/loaded = 0
	var/coin_only = FALSE
	var/is_debtor_copy = FALSE
	var/creditor_name
	var/pending_surcharge = 0
	var/pending_rate = 10
	var/pending_due_days = 2
	var/pending_punish_forever = FALSE
	var/list/pending_clauses = list()
	var/pending_brand_text
	var/pending_chastity_style = "belt"
	var/datum/loan/loan

/obj/item/loan_note/Initialize(mapload)
	. = ..()
	base_name = name

/obj/item/loan_note/attackby(obj/item/attacking_item, mob/living/carbon/human/user, params)
	if(!ishuman(user))
		return ..()
	if(istype(attacking_item, /obj/item/roguecoin/gilbranze))
		return
	if(istype(attacking_item, /obj/item/roguecoin/inqcoin))
		return
	if(istype(attacking_item, /obj/item/roguecoin))
		var/obj/item/roguecoin/coin = attacking_item
		var/value = coin.get_real_price()
		if(value < 1)
			return
		switch(note_state)
			if(LOAN_NOTE_BLANK, LOAN_NOTE_FUNDED)
				if(!coin_only && !(user in SStreasury.bank_accounts))
					to_chat(user, span_warning("I have no bank account for the note to answer to. I must register at a nervelock first."))
					return
				if(creditor_name && user.real_name != creditor_name)
					to_chat(user, span_warning("This note already answers to [creditor_name]. My coin would become theirs."))
					return
				loaded += value
				if(!creditor_name)
					creditor_name = user.real_name
				note_state = LOAN_NOTE_FUNDED
				qdel(attacking_item)
				playsound(loc, 'sound/misc/coininsert.ogg', 100, FALSE, -1)
				user.visible_message(span_notice("[user] binds [value] mammon to [src]."), \
					span_notice("I bind [value] mammon to [src]. It now offers a loan of [loaded] mammon."))
				rebuild_info()
				update_icon_state()
			if(LOAN_NOTE_SIGNED)
				if(!loan)
					return
				var/applied = loan.repay(value)
				if(applied < 1)
					return
				loan.repaid_pool += applied
				qdel(attacking_item)
				playsound(loc, 'sound/misc/coininsert.ogg', 100, FALSE, -1)
				var/change = value - applied
				if(change > 0)
					spawn_coins(change, user)
				if(loan.paid)
					note_state = LOAN_NOTE_PAID
					user.visible_message(span_notice("[user] settles the debt bound to [src]."), \
						span_notice("I pay the last [applied] mammon of the debt. Paid in full."))
				else
					to_chat(user, span_notice("I pay [applied] mammon toward the debt. [loan.owed] mammon remains."))
				rebuild_info()
			if(LOAN_NOTE_PAID)
				to_chat(user, span_warning("The debt is settled."))
		return
	if(istype(attacking_item, /obj/item/natural/feather) || istype(attacking_item, /obj/item/natural/thorn))
		try_sign(user)
		return
	..()

/obj/item/loan_note/coin
	name = "unmarked loan note"
	desc = "A loan note bearing no seal and answering to no ledger but its own. Coin for coin, no bank and no questions asked. Favored by those whose debts are best left unwritten."
	coin_only = TRUE

// Interest accrues on the datum overnight; the body is rebuilt each time it is read.
/obj/item/loan_note/proc/show_contract(mob/user)
	if(folded || !user.client || !user.can_read(src))
		return
	if(note_state == LOAN_NOTE_SIGNED && loan)
		rebuild_info()
	user << browse_rsc('html/book.png')
	var/dat = {"<html><head><meta charset="utf-8"><style>body{background-image:url('book.png');background-repeat:repeat;}</style></head><body>[info]</body></html>"}
	user << browse(dat, "window=loannote;size=390x510")

/obj/item/loan_note/update_icon_state()
	if(folded)
		icon_state = "scroll_folded"
	else
		icon_state = info ? "scrollwrite" : "scroll"

/obj/item/loan_note/attack_self(mob/user)
	folded = !folded
	update_icon_state()
	name = folded ? "folded [base_name]" : base_name
	var/fold_message = folded ? "I fold [base_name]." : "I unfold [base_name]."
	to_chat(user, span_notice(fold_message))

/obj/item/loan_note/proc/try_sign(mob/living/carbon/human/user)
	if(folded)
		to_chat(user, span_warning("I should unfold [src] first."))
		return
	if(!user.is_literate())
		to_chat(user, span_warning("I can't read the terms, much less sign them."))
		return
	if(!coin_only && !(user in SStreasury.bank_accounts))
		to_chat(user, span_warning("I have no bank account for the coin to flow into. I must register at a nervelock first."))
		return
	if(note_state == LOAN_NOTE_SIGNED || note_state == LOAN_NOTE_PAID)
		to_chat(user, span_warning("It already bears a signature."))
		return
	if(note_state != LOAN_NOTE_FUNDED || loaded < 1)
		to_chat(user, span_warning("No coin backs this note."))
		return
	if(user.real_name == creditor_name)
		to_chat(user, span_warning("I cannot borrow my own coin."))
		return
	var/amount = loaded
	var/lender = creditor_name
	var/surcharge = pending_surcharge
	var/rate = pending_rate
	var/due_days = pending_due_days
	var/forever = pending_punish_forever
	var/list/chosen_clauses = pending_clauses.Copy()
	var/brand_text = pending_brand_text
	var/chastity_style = pending_chastity_style
	var/clause_text = ""
	if(length(chosen_clauses))
		var/list/clause_names = list()
		for(var/clause_type in chosen_clauses)
			var/datum/loan_clause/clause = get_loan_clause(clause_type)
			if(clause)
				clause_names += clause.name
		clause_text = " On default: [jointext(clause_names, ", ")]. [forever ? "These punishments will NEVER lift, even if I repay." : "They lift once the debt is repaid."]"
	if(alert("Sign this note? I take [amount] mammon and owe [amount + surcharge] mammon, growing [rate]% each day. Due within [due_days] day\s.[clause_text]",, "Yes", "No") != "Yes")
		return
	if(!do_after(user, 20, target = src))
		return
	if(QDELETED(src) || note_state != LOAN_NOTE_FUNDED || loaded != amount || amount < 1 || loan || folded)
		return
	if(creditor_name != lender || user.real_name == lender)
		return
	if(!coin_only && !(user in SStreasury.bank_accounts))
		return
	if(pending_surcharge != surcharge || pending_rate != rate || pending_due_days != due_days || pending_punish_forever != forever)
		return
	if(json_encode(pending_clauses) != json_encode(chosen_clauses) || pending_brand_text != brand_text || pending_chastity_style != chastity_style)
		return
	loaded = 0
	loan = new(user.real_name, lender, amount, surcharge, rate, due_days, forever, chosen_clauses)
	loan.brand_text = brand_text
	loan.chastity_style = chastity_style
	loan.off_the_books = coin_only
	loan.note = src
	GLOB.loan_ledger += loan
	note_state = LOAN_NOTE_SIGNED
	var/sign_message = coin_only ? "I set my name to the scroll and take the coin in hand, the debt with it." : "I set my name to the scroll. The coin is pledged to my account, and the debt with it."
	user.visible_message(span_notice("[user] signs [src]."), span_notice(sign_message))
	playsound(src, 'sound/items/write.ogg', 100, FALSE)
	if(coin_only)
		spawn_coins(amount, user)
	else
		deposit_to_account(user, amount, "Loan from [lender]")
	rebuild_info()
	update_icon_state()
	var/obj/item/loan_note/copy = new type(get_turf(user))
	copy.is_debtor_copy = TRUE
	copy.creditor_name = lender
	copy.note_state = LOAN_NOTE_SIGNED
	copy.loan = loan
	loan.debtor_note = copy
	copy.name = "[copy.name] (debtor's copy)"
	copy.base_name = copy.name
	copy.rebuild_info()
	user.put_in_hands(copy)
	to_chat(user, span_notice("The contract is drawn in duplicate. I keep my own copy, and coin paid upon it counts no less."))

/obj/item/loan_note/proc/deposit_to_account(mob/living/carbon/human/user, amount, reason)
	if(!(user in SStreasury.bank_accounts))
		SStreasury.create_bank_account(user)
	SStreasury.bank_accounts[user] += amount
	SStreasury.give_money_treasury(amount, "coin bound to a loan note, deposited for [user.real_name]")
	send_ooc_note("<b>NERVELOCK:</b> You received [amount]m into your account. ([reason])", name = user.real_name)

/obj/item/loan_note/proc/spawn_coins(amount, mob/living/user)
	amount = floor(amount)
	if(amount < 1)
		return
	var/turf/coin_turf = user ? get_turf(user) : get_turf(src)
	if(!coin_turf)
		return
	var/gold = floor(amount / 10)
	amount -= gold * 10
	var/silver = floor(amount / 5)
	amount -= silver * 5
	var/list/payout = list(/obj/item/roguecoin/gold = gold, /obj/item/roguecoin/silver = silver, /obj/item/roguecoin/copper = amount)
	var/first_stack = TRUE
	for(var/coin_type in payout)
		var/remaining = payout[coin_type]
		while(remaining > 0)
			var/stack_size = min(remaining, 20)
			var/obj/item/roguecoin/coin = new coin_type(coin_turf, stack_size)
			if(first_stack && user)
				user.put_in_hands(coin)
				first_stack = FALSE
			remaining -= stack_size
	playsound(coin_turf, 'sound/misc/coindispense.ogg', 100, FALSE, -1)

/obj/item/loan_note/proc/is_creditor(mob/user)
	var/holder = loan ? loan.creditor_name : creditor_name
	return holder && user.real_name == holder

/obj/item/loan_note/examine(mob/user)
	. = ..()
	if(info && !folded)
		. += "<a href='?src=[REF(src)];read=1'>Read</a>"
	if(is_debtor_copy)
		. += span_info("The debtor's counterpart of the contract. Coin paid onto it settles the debt all the same.")
	switch(note_state)
		if(LOAN_NOTE_BLANK)
			. += span_info("Bind coin to it to offer a loan, then have the borrower sign it with a feather.")
			if(coin_only)
				. += span_info("Coin changes hands directly, with no bank and no questions. Even the outlawed may use it.")
			else
				. += span_info("Lender and borrower must both hold a bank account at a nervelock.")
		if(LOAN_NOTE_FUNDED)
			. += span_info("This note is backed by [loaded] mammon, lent by [creditor_name].")
			. += span_info("The signer will owe [loaded + pending_surcharge] mammon, growing [pending_rate]% each day, due within [pending_due_days] day\s.")
			if(length(pending_clauses))
				. += span_warning("It carries [length(pending_clauses)] clause\s of punishment.")
			. += "<a href='?src=[REF(src)];contract=1'>Contract terms</a>"
			if(is_creditor(user))
				. += "<a href='?src=[REF(src)];reclaim=1'>Reclaim coin</a>"
		if(LOAN_NOTE_SIGNED)
			if(loan)
				. += span_info("[loan.debtor_name] currently owes [loan.owed] mammon[loan.interest_rate > 0 ? ", growing [loan.interest_rate]% a day" : ""].")
				if(loan.clauses_fired)
					. += span_warning("The debt is in default. Its clauses are in force.")
				else if(loan.is_overdue())
					. += span_warning("The debt is overdue.")
			. += "<a href='?src=[REF(src)];contract=1'>Contract terms</a>"
			if(loan && loan.repaid_pool > 0 && is_creditor(user))
				. += "<a href='?src=[REF(src)];collect=1'>Collect [loan.repaid_pool] mammon</a>"
		if(LOAN_NOTE_PAID)
			. += span_info("PAID IN FULL.")
			. += "<a href='?src=[REF(src)];contract=1'>Contract terms</a>"
			if(loan && loan.repaid_pool > 0 && is_creditor(user))
				. += "<a href='?src=[REF(src)];collect=1'>Collect [loan.repaid_pool] mammon</a>"

/obj/item/loan_note/Topic(href, href_list)
	..()
	if(!ishuman(usr))
		return
	if(!usr.canUseTopic(src, BE_CLOSE))
		return
	var/mob/living/carbon/human/user = usr
	if(href_list["read"])
		show_contract(user)
	if(href_list["contract"])
		ui_interact(user)
	if(href_list["reclaim"])
		if(note_state != LOAN_NOTE_FUNDED || loaded < 1)
			return
		if(!is_creditor(user))
			to_chat(user, span_warning("The coin is bound to [creditor_name]. Only they may reclaim it."))
			return
		if(loc != user)
			to_chat(user, span_warning("I must hold the note to reclaim its coin."))
			return
		var/amount = loaded
		loaded = 0
		creditor_name = null
		note_state = LOAN_NOTE_BLANK
		user.visible_message(span_warning("[user] voids the loan offer bound to [src]."))
		// Reclaim returns the physical coin the creditor set aside - not a bank deposit,
		// which would let a note launder coin into an account tax-free.
		spawn_coins(amount, user)
		rebuild_info()
		update_icon_state()
	if(href_list["collect"])
		if(!loan || loan.repaid_pool < 1)
			return
		if(!is_creditor(user))
			to_chat(user, span_warning("The repaid coin is bound to [loan ? loan.creditor_name : creditor_name]. Only they may collect it."))
			return
		if(loc != user)
			to_chat(user, span_warning("I must hold the note to collect from it."))
			return
		var/amount = loan.repaid_pool
		loan.repaid_pool = 0
		user.visible_message(span_notice("[user] collects the repayments bound to [src]."))
		if(coin_only)
			spawn_coins(amount, user)
		else
			deposit_to_account(user, amount, "Loan repayments from [loan ? loan.debtor_name : "the note"]")
		rebuild_info()

/obj/item/loan_note/Destroy()
	var/pool = loaded
	loaded = 0
	if(loan)
		if(loan.note == src)
			loan.note = null
		if(loan.debtor_note == src)
			loan.debtor_note = null
		if(!loan.note && !loan.debtor_note && loan.repaid_pool > 0 && get_turf(src))
			pool += loan.repaid_pool
			loan.repaid_pool = 0
	if(pool > 0)
		spawn_coins(pool, null)
	loan = null
	return ..()

/obj/item/loan_note/proc/clause_summary(list/clause_type_list, forever)
	if(!length(clause_type_list))
		return ""
	var/list/clause_names = list()
	for(var/clause_type in clause_type_list)
		var/datum/loan_clause/clause = get_loan_clause(clause_type)
		if(clause)
			clause_names += clause.name
	return "Upon default the following terms take hold: [jointext(clause_names, ", ")]. [forever ? "They shall never be lifted." : "They lift once the debt is repaid."]<br/>"

/obj/item/loan_note/proc/rebuild_info()
	info = null
	info += "<h2>Loan Note[is_debtor_copy ? " (Debtor's Copy)" : ""]</h2>"
	info += "<hr/>"
	switch(note_state)
		if(LOAN_NOTE_BLANK)
			info += "This note is not yet backed by any coin.<br/>"
		if(LOAN_NOTE_FUNDED)
			info += "[creditor_name] offers a loan of [loaded] mammon to whoever signs below.<br/>"
			info += "The signer will owe [loaded + pending_surcharge] mammon, growing [pending_rate]% each day, due within [pending_due_days] day\s.<br/>"
			info += clause_summary(pending_clauses, pending_punish_forever)
			info += "<br/>SIGNED,<br/>____________"
		if(LOAN_NOTE_SIGNED)
			if(loan)
				info += "[loan.creditor_name] has lent [loan.principal] mammon.<br/>"
				if(loan.surcharge > 0 || loan.interest_rate > 0)
					info += "The debt began at [loan.base_debt] mammon and grows [loan.interest_rate]% a day.<br/>"
				info += "It falls due [loan.due_days] day\s after signing.<br/>"
				info += clause_summary(loan.clause_types, loan.punish_forever)
				info += "[loan.owed] mammon remains owed.<br/>"
				info += "<br/>SIGNED,<br/>"
				info += "<font face=\"[FOUNTAIN_PEN_FONT]\" color=#27293f>[loan.debtor_name]</font>"
		if(LOAN_NOTE_PAID)
			if(loan)
				info += "[loan.creditor_name] lent [loan.principal] mammon.<br/>"
				info += "<b>PAID IN FULL.</b><br/>"
				info += "<br/>SIGNED,<br/>"
				info += "<font face=\"[FOUNTAIN_PEN_FONT]\" color=#27293f>[loan.debtor_name]</font>"

/obj/item/loan_note/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "LoanContract", "Loan Contract")
		// No polling: every ui_act pushes its own update, and dawn-side changes
		// refresh on reopen. Matches the PaperWriterPanel precedent.
		ui.set_autoupdate(FALSE)
		ui.open()

/obj/item/loan_note/ui_data(mob/user)
	var/list/data = list()
	data["state"] = note_state
	data["loaded"] = loaded
	data["creditor"] = loan ? loan.creditor_name : (creditor_name || "nobody")
	data["surcharge"] = loan ? loan.surcharge : pending_surcharge
	data["rate"] = loan ? loan.interest_rate : pending_rate
	data["due_days"] = loan ? loan.due_days : pending_due_days
	data["punish_forever"] = loan ? loan.punish_forever : pending_punish_forever
	// Stored html-encoded (for safe examine output); decode for the editable field so it round-trips.
	data["brand_text"] = pending_brand_text ? html_decode(pending_brand_text) : ""
	data["chastity_style"] = loan ? loan.chastity_style : pending_chastity_style
	var/list/style_list = list()
	for(var/style_key in GLOB.debt_chastity_styles)
		style_list += list(list("key" = style_key, "label" = GLOB.debt_chastity_styles[style_key]["label"]))
	data["chastity_styles"] = style_list
	data["repaid_pool"] = loan ? loan.repaid_pool : 0
	var/list/clause_data = list()
	if(loan)
		for(var/clause_type in loan.clause_types)
			var/datum/loan_clause/clause = get_loan_clause(clause_type)
			if(clause)
				clause_data += list(list("path" = "[clause_type]", "name" = clause.name, "desc" = clause.desc, "enabled" = TRUE))
	else
		var/list/all_clauses = get_all_loan_clauses()
		for(var/clause_type in all_clauses)
			var/datum/loan_clause/clause = all_clauses[clause_type]
			clause_data += list(list("path" = "[clause_type]", "name" = clause.name, "desc" = clause.desc, "enabled" = (clause_type in pending_clauses)))
	data["clauses"] = clause_data
	data["debtor"] = loan ? loan.debtor_name : ""
	data["owed"] = loan ? loan.owed : 0
	data["base_debt"] = loan ? loan.base_debt : 0
	data["days_left"] = loan ? max(0, loan.due_days - loan.days_elapsed) : 0
	data["overdue"] = loan ? loan.is_overdue() : FALSE
	data["fired"] = loan ? loan.clauses_fired : FALSE
	return data

/obj/item/loan_note/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	if(..())
		return TRUE
	if(!ishuman(ui.user))
		return TRUE
	if(note_state != LOAN_NOTE_FUNDED)
		return TRUE
	// And only by the creditor: anyone may read the contract, but a would-be debtor
	// must not be able to soften the terms before signing.
	if(!is_creditor(ui.user))
		return TRUE
	switch(action)
		if("set_surcharge")
			pending_surcharge = clamp(round(text2num("[params["value"]]") || 0), 0, 100000)
		if("set_rate")
			pending_rate = clamp(round(text2num("[params["value"]]") || 0), 0, 1000)
		if("set_due")
			pending_due_days = clamp(round(text2num("[params["value"]]") || 2), 1, 7)
		if("toggle_forever")
			pending_punish_forever = !pending_punish_forever
		if("toggle_clause")
			var/clause_type = text2path(params["path"])
			if(ispath(clause_type, /datum/loan_clause) && clause_type != /datum/loan_clause)
				if(clause_type in pending_clauses)
					pending_clauses -= clause_type
				else
					pending_clauses += clause_type
		if("set_brand_text")
			var/new_text = sanitize(copytext("[params["value"]]", 1, 200))
			pending_brand_text = length(new_text) ? new_text : null
		if("set_chastity_style")
			var/style_key = "[params["key"]]"
			if(GLOB.debt_chastity_styles[style_key])
				pending_chastity_style = style_key
		else
			return FALSE
	rebuild_info()
	return TRUE

GLOBAL_LIST_EMPTY(loan_clauses)

/proc/get_loan_clause(clause_type)
	if(!ispath(clause_type, /datum/loan_clause) || clause_type == /datum/loan_clause)
		return
	if(!GLOB.loan_clauses[clause_type])
		GLOB.loan_clauses[clause_type] = new clause_type
	return GLOB.loan_clauses[clause_type]

/proc/get_all_loan_clauses()
	for(var/clause_type in subtypesof(/datum/loan_clause))
		get_loan_clause(clause_type)
	return GLOB.loan_clauses

// apply() returns TRUE when the clause took hold (so process_clauses records it and can
// stop retrying); release() must undo only what THIS loan imposed.
/datum/loan_clause
	var/name = "clause"
	var/desc = ""

/datum/loan_clause/proc/apply(mob/living/carbon/human/debtor, datum/loan/loan)
	return TRUE

/datum/loan_clause/proc/release(mob/living/carbon/human/debtor, datum/loan/loan)
	return

/datum/loan_clause/proc/dawn_tick(mob/living/carbon/human/debtor, datum/loan/loan)
	return

/datum/loan_clause/bounty
	name = "Bounty of Default"
	desc = "Default, and coin equal to the debt is put on the debtor's head, paid to whoever hauls them to the castifico."

/datum/loan_clause/bounty/apply(mob/living/carbon/human/debtor, datum/loan/loan)
	var/list/before = GLOB.head_bounties.Copy()
	var/list/descriptors = debtor.get_mob_descriptors()
	var/descriptor_height = build_coalesce_description_nofluff(descriptors, debtor, list(MOB_DESCRIPTOR_SLOT_HEIGHT), "%DESC1%")
	var/descriptor_body = build_coalesce_description_nofluff(descriptors, debtor, list(MOB_DESCRIPTOR_SLOT_BODY), "%DESC1%")
	var/descriptor_voice = build_coalesce_description_nofluff(descriptors, debtor, list(MOB_DESCRIPTOR_SLOT_VOICE), "%DESC1%")
	// Cap on the borrowed amount, not the interest-inflated owed, so runaway interest cannot mint a giant arrest-chair reward.
	add_bounty(debtor.real_name, debtor.dna.species, debtor.gender, descriptor_height, descriptor_body, descriptor_voice, clamp(loan.base_debt, 10, 2000), FALSE, "Defaulted on a debt to [loan.creditor_name].", loan.creditor_name)
	for(var/datum/bounty/bounty in GLOB.head_bounties)
		if(!(bounty in before))
			loan.posted_bounty = bounty // remember the exact bounty this loan created
			break
	return TRUE

/datum/loan_clause/bounty/release(mob/living/carbon/human/debtor, datum/loan/loan)
	if(loan.posted_bounty && (loan.posted_bounty in GLOB.head_bounties))
		GLOB.head_bounties -= loan.posted_bounty
	loan.posted_bounty = null

/datum/loan_clause/collar
	name = "Debtor's Collar"
	desc = "Default, and an iron collar seals itself around the debtor's neck."

/datum/loan_clause/collar/apply(mob/living/carbon/human/debtor, datum/loan/loan)
	var/obj/item/old_neck = debtor.get_item_by_slot(SLOT_NECK)
	if(old_neck)
		if(HAS_TRAIT(old_neck, TRAIT_NODROP))
			return FALSE // don't destroy a locked/cursed collar; retry next dawn
		debtor.dropItemToGround(old_neck, TRUE)
	var/obj/item/clothing/neck/roguetown/collar/debtor/collar = new
	collar.desc = "A heavy iron collar sealed shut by a debt contract. The seal of [loan.creditor_name] is stamped into it."
	collar.owner_loan_ref = REF(loan)
	debtor.equip_to_slot_or_del(collar, SLOT_NECK, TRUE)
	if(QDELETED(collar) || debtor.get_item_by_slot(SLOT_NECK) != collar)
		return FALSE
	return TRUE

/datum/loan_clause/collar/release(mob/living/carbon/human/debtor, datum/loan/loan)
	var/obj/item/clothing/neck/roguetown/collar/debtor/collar = debtor.get_item_by_slot(SLOT_NECK)
	if(istype(collar) && collar.owner_loan_ref == REF(loan))
		debtor.visible_message(span_notice("The debtor's collar around [debtor]'s neck clicks open and crumbles away."))
		qdel(collar)

/datum/loan_clause/chastity
	name = "Iron Chastity"
	desc = "Default, and a keyless chastity device locks itself onto the debtor."

/datum/loan_clause/chastity/apply(mob/living/carbon/human/debtor, datum/loan/loan)
	if(debtor.client?.prefs && !debtor.client.prefs.chastenable)
		// Wearer opted out of this content: consent wins. The clause counts as satisfied
		// (so the default still registers) but no device is ever placed.
		to_chat(debtor, span_notice("The debt's chastity clause finds no purchase. You are spared this indignity."))
		return TRUE
	if(debtor.chastity_device)
		return FALSE // slot occupied; retry next dawn
	var/obj/item/chastity/debtor/belt = new
	var/list/style = GLOB.debt_chastity_styles[loan.chastity_style] || GLOB.debt_chastity_styles["belt"]
	belt.name = style["cname"]
	belt.chastity_type = style["chastity_type"]
	belt.chastity_organtype = style["organtype"]
	belt.sprite_acc = style["sprite"]
	if(!belt.chastity_genital_check(debtor))
		qdel(belt)
		to_chat(debtor, span_notice("The debt's chastity clause finds no purchase. You are spared this indignity."))
		return TRUE
	if(!belt.equip_standard_chastity(debtor, null))
		qdel(belt)
		return FALSE
	belt.owner_loan_ref = REF(loan)
	belt.set_chastity_locked_state(debtor, TRUE)
	to_chat(debtor, span_userdanger("Cold iron clamps shut around my groin!"))
	return TRUE

/datum/loan_clause/chastity/release(mob/living/carbon/human/debtor, datum/loan/loan)
	var/obj/item/chastity/debtor/belt = debtor.chastity_device
	if(istype(belt) && belt.owner_loan_ref == REF(loan))
		belt.remove_chastity(debtor)
		to_chat(debtor, span_notice("The debt-bound chastity device unlocks and falls away."))
		qdel(belt)

/datum/loan_clause/brand
	name = "Debtor's Brand"
	desc = "Default, and the creditor's brand sears itself into the debtor's flesh."

/datum/loan_clause/brand/apply(mob/living/carbon/human/debtor, datum/loan/loan)
	ADD_TRAIT(debtor, TRAIT_DEBT_BRANDED, "debt_[REF(loan)]")
	to_chat(debtor, span_userdanger("Searing pain! A brand burns itself into my flesh!"))
	debtor.emote("agony")
	return TRUE

/datum/loan_clause/brand/release(mob/living/carbon/human/debtor, datum/loan/loan)
	REMOVE_TRAIT(debtor, TRAIT_DEBT_BRANDED, "debt_[REF(loan)]")

/datum/loan_clause/pacifism
	name = "Oath of Peace"
	desc = "Default, and the debtor is bound from all violence."

/datum/loan_clause/pacifism/apply(mob/living/carbon/human/debtor, datum/loan/loan)
	ADD_TRAIT(debtor, TRAIT_PACIFISM, "debt_[REF(loan)]")
	to_chat(debtor, span_userdanger("My oath binds my hands. I cannot bring myself to violence while the debt stands!"))
	return TRUE

/datum/loan_clause/pacifism/release(mob/living/carbon/human/debtor, datum/loan/loan)
	REMOVE_TRAIT(debtor, TRAIT_PACIFISM, "debt_[REF(loan)]")

/datum/loan_clause/garnish
	name = "Seized Wages"
	desc = "Default, and the Stewardry seizes the debtor's wages and bank account toward the debt, each day it stands."

// Wages are deliberately NOT suspended: dawn pays them into the account first
// (time.dm calls distribute_daily_payments before accrue_loan_interest), then the
// seizure sweeps the account, so each day's wage genuinely pays the debt down.
/datum/loan_clause/garnish/apply(mob/living/carbon/human/debtor, datum/loan/loan)
	to_chat(debtor, span_warning("Word reaches the Stewardry. My wages are seized toward the debt until it is settled."))
	seize_account(debtor, loan)
	return TRUE

/datum/loan_clause/garnish/dawn_tick(mob/living/carbon/human/debtor, datum/loan/loan)
	seize_account(debtor, loan)

// Moves coin the debtor already holds in the bank straight to the creditor's account.
// A pure account-to-account transfer (both are claims on the same vault), so the crown's
// purse is untouched. If the creditor has no account to receive it, the seizure waits.
/datum/loan_clause/garnish/proc/seize_account(mob/living/carbon/human/debtor, datum/loan/loan)
	if(loan.paid || !(debtor in SStreasury.bank_accounts))
		return
	// The account is keyed by mob, so match the creditor by name (they need not be online).
	var/mob/living/carbon/human/creditor_account
	for(var/account in SStreasury.bank_accounts)
		if(!ishuman(account))
			continue
		var/mob/living/carbon/human/holder = account
		if(holder.real_name == loan.creditor_name)
			creditor_account = holder
			break
	if(!creditor_account)
		return // no lawful destination but the crown's purse; leave the coin and retry
	var/take = min(floor(SStreasury.bank_accounts[debtor]), loan.owed)
	if(take < 1)
		return
	SStreasury.bank_accounts[debtor] -= take
	SStreasury.bank_accounts[creditor_account] += take
	loan.repay(take)
	send_ooc_note("<b>NERVELOCK:</b> The Stewardry seized [take]m from your account toward your debt to [loan.creditor_name].", name = loan.debtor_name)
	send_ooc_note("<b>NERVELOCK:</b> You received [take]m, seized from [loan.debtor_name] toward their debt.", name = loan.creditor_name)

/datum/loan_clause/stress
	name = "Oathbreaker's Weight"
	desc = "Default, and the broken oath weighs upon the debtor's soul."

/datum/loan_clause/stress/apply(mob/living/carbon/human/debtor, datum/loan/loan)
	debtor.add_stress(/datum/stressevent/debt_oath)
	return TRUE

/datum/loan_clause/stress/release(mob/living/carbon/human/debtor, datum/loan/loan)
	// The stress event is shared by type; keep it while any other unsettled debt still imposes it.
	for(var/datum/loan/other in GLOB.loan_ledger)
		if(other == loan || other.debtor_name != loan.debtor_name)
			continue
		if(!(/datum/loan_clause/stress in other.applied_clauses))
			continue
		if(other.paid && !other.punish_forever)
			continue
		return
	debtor.remove_stress(/datum/stressevent/debt_oath)

/proc/get_debt_brand_lines(name)
	var/list/lines = list()
	for(var/datum/loan/loan in GLOB.loan_ledger)
		if(loan.debtor_name != name)
			continue
		if(!(/datum/loan_clause/brand in loan.applied_clauses))
			continue
		if(loan.paid && !loan.punish_forever)
			continue
		lines += (loan.brand_text ? loan.brand_text : "[loan.creditor_name]'s brand is seared into their flesh. They have defaulted on a debt.")
	return lines

/obj/item/clothing/neck/roguetown/collar/debtor
	name = "debtor's collar"
	desc = "A heavy iron collar sealed shut by a debt contract."
	icon_state = "castifico_collar"
	item_state = "castifico_collar"
	resistance_flags = FIRE_PROOF
	slot_flags = ITEM_SLOT_NECK
	body_parts_covered = NONE
	leashable = TRUE
	var/owner_loan_ref

/obj/item/clothing/neck/roguetown/collar/debtor/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NODROP, CURSED_ITEM_TRAIT)

/obj/item/clothing/neck/roguetown/collar/debtor/dropped(mob/living/carbon/human/user)
	. = ..()
	if(QDELETED(src))
		return
	qdel(src)

/obj/item/chastity/debtor
	name = "debt-bound chastity belt"
	desc = "A keyless chastity device sealed by contract and vile magic. It will only release when the debt is settled."
	lockable = FALSE // no key exists; only the debt's settlement (or the release proc) frees it
	var/owner_loan_ref

#undef LOAN_NOTE_BLANK
#undef LOAN_NOTE_FUNDED
#undef LOAN_NOTE_SIGNED
#undef LOAN_NOTE_PAID
