#define TRADE_DIVIDEND_PERIOD (20 MINUTES)

GLOBAL_DATUM_INIT(trade_market, /datum/trade_market, new)

/datum/trade_venture
	var/name = "venture"
	var/desc = ""
	var/base_price = 10
	var/current_price = 10
	var/yield = 1
	var/volatility = 0
	var/fixed_price = FALSE
	var/shock_chance = 0
	var/shock_min = 0
	var/shock_max = 0
	var/shock_news
	var/windfall_chance = 0
	var/windfall_min = 0
	var/windfall_max = 0
	var/windfall_news
	var/last_news
	var/issued = 0
	var/list/name_pool
	var/name_suffix = ""
	// Cumulative interest per share since round start; certificates snapshot it at
	// print/collection so each dividend period pays at the price it accrued under.
	var/dividend_accum = 0
	var/next_dividend = 0

/datum/trade_venture/New()
	..()
	current_price = base_price
	next_dividend = world.time + TRADE_DIVIDEND_PERIOD
	if(length(name_pool))
		name = "the [pick(name_pool)] [name_suffix]"
	if(shock_news)
		shock_news = replacetext(shock_news, "%NAME%", name)
	if(windfall_news)
		windfall_news = replacetext(windfall_news, "%NAME%", name)

/datum/trade_venture/proc/tick_price()
	if(fixed_price)
		return
	var/floor_price = max(1, round(base_price * 0.25))
	var/ceiling_price = round(base_price * 4)
	// Mean reversion plus a large random step: prices swing widely but orbit their base.
	// Two-arg round: single-arg round() floors, which would bias the walk ~-0.5/tick.
	var/reversion_pull = round((base_price - current_price) * 0.15, 1)
	var/random_step = round(base_price * volatility * rand(-100, 100) / 100, 1)
	current_price = clamp(current_price + reversion_pull + random_step, floor_price, ceiling_price)
	if(shock_chance && prob(shock_chance))
		current_price = max(floor_price, current_price - round(base_price * rand(shock_min, shock_max) / 100, 1))
		last_news = shock_news
	else if(windfall_chance && prob(windfall_chance))
		current_price = min(ceiling_price, current_price + round(base_price * rand(windfall_min, windfall_max) / 100, 1))
		last_news = windfall_news

/datum/trade_venture/bond
	name = "Grenzel Crown Bond"
	desc = "Coin lent to the realm itself. It never falters, and never makes you rich."
	base_price = 150
	yield = 1
	fixed_price = TRUE

/datum/trade_venture/guild
	desc = "Carded fleece and fine cloth. Slow, dependable, dull."
	base_price = 90
	yield = 2
	volatility = 0.06
	name_pool = list("Fullers'", "Weavers'", "Dyers'", "Tanners'", "Coopers'", "Chandlers'")
	name_suffix = "Guild"

/datum/trade_venture/quarry
	desc = "Cut stone for keeps and cathedrals. Heavy, steady coin."
	base_price = 82
	yield = 3
	volatility = 0.1
	shock_chance = 6
	shock_min = 15
	shock_max = 30
	shock_news = "%NAME% has suffered a cave-in!"
	name_pool = list("Greystone", "Deepcut", "Ironhill", "Whitecliff", "Hammerdown")
	name_suffix = "Quarry"

/datum/trade_venture/fleet
	desc = "Cod and herring by the barrel. Calm seas, modest coin."
	base_price = 56
	yield = 3
	volatility = 0.12
	shock_chance = 7
	shock_min = 20
	shock_max = 35
	shock_news = "A storm has scattered %NAME%!"
	name_pool = list("Gull's Wake", "Herring Run", "Grey Sail", "Salt Spray", "Tide's Bounty")
	name_suffix = "Fleet"

/datum/trade_venture/menagerie
	desc = "Far-land beasts in gilded cages. Wondrous coin, until something slips loose."
	base_price = 71
	yield = 4
	volatility = 0.16
	shock_chance = 8
	shock_min = 20
	shock_max = 40
	shock_news = "A beast has slipped its cage at %NAME%!"
	windfall_chance = 4
	windfall_min = 20
	windfall_max = 35
	windfall_news = "%NAME% boasts a prize breeding season!"
	name_pool = list("Gilded Cage", "Speckled Egg", "Far Shores", "Basilisk's Eye", "Wyrmling")
	name_suffix = "Menagerie"

/datum/trade_venture/caravan
	desc = "Saffron and pepper hauled overland. Good coin, but bandits lurk."
	base_price = 68
	yield = 5
	volatility = 0.24
	shock_chance = 10
	shock_min = 30
	shock_max = 60
	shock_news = "%NAME% was waylaid by bandits!"
	windfall_chance = 5
	windfall_min = 30
	windfall_max = 50
	windfall_news = "%NAME% struck a rich bargain in far markets!"
	name_pool = list("Pepperwind", "Saffron Road", "Amber Trail", "Silkwind", "Cinnabar Route")
	name_suffix = "Caravan"

/datum/trade_venture/mercenary
	desc = "Sellswords under contract. War pays well, when they win."
	base_price = 82
	yield = 5
	volatility = 0.22
	shock_chance = 9
	shock_min = 25
	shock_max = 50
	shock_news = "A contract has gone bloodily wrong for %NAME%!"
	windfall_chance = 6
	windfall_min = 25
	windfall_max = 45
	windfall_news = "%NAME% takes a rich field of spoils!"
	name_pool = list("Broken Lance", "Crimson Banner", "Iron Rooster", "Grey Halberd", "Wolfpike")
	name_suffix = "Free Company"

/datum/trade_venture/relic
	desc = "Spades and psalms over old tombs. Most are empty. Some are not."
	base_price = 64
	yield = 6
	volatility = 0.26
	shock_chance = 11
	shock_min = 30
	shock_max = 60
	shock_news = "%NAME% broke into an empty crypt!"
	windfall_chance = 6
	windfall_min = 35
	windfall_max = 60
	windfall_news = "%NAME% has unearthed a true relic!"
	name_pool = list("Saint's Vigil", "Hollow Crypt", "White Sepulcher", "Pilgrim's Spade", "Broken Psycross")
	name_suffix = "Expedition"

/datum/trade_venture/wizard
	desc = "Arcane research and stranger dividends. The tower endures. Usually."
	base_price = 112
	yield = 6
	volatility = 0.28
	shock_chance = 10
	shock_min = 30
	shock_max = 65
	shock_news = "An experiment has gone wrong in %NAME%!"
	windfall_chance = 8
	windfall_min = 30
	windfall_max = 60
	windfall_news = "%NAME% has wrested a new secret from the arcane!"
	name_pool = list("Azure", "Umbral", "Whispering", "Starfall", "Gilded")
	name_suffix = "Tower"

/datum/trade_venture/prospectors
	desc = "Gold pans and blind shafts. Most find mud. Some find fortunes."
	base_price = 41
	yield = 6
	volatility = 0.3
	shock_chance = 12
	shock_min = 40
	shock_max = 75
	shock_news = "%NAME% struck nothing but mud and debt!"
	windfall_chance = 8
	windfall_min = 40
	windfall_max = 80
	windfall_news = "%NAME% struck a glittering vein!"
	name_pool = list("Mudpan", "Lastlode", "Glimmerdig", "Blindshaft", "Fool's Hollow")
	name_suffix = "Prospectors"

/datum/trade_market
	var/list/ventures = list()
	var/next_tick = 0

/datum/trade_market/New()
	..()
	ventures += new /datum/trade_venture/bond
	ventures += new /datum/trade_venture/guild
	ventures += new /datum/trade_venture/quarry
	ventures += new /datum/trade_venture/fleet
	ventures += new /datum/trade_venture/menagerie
	ventures += new /datum/trade_venture/caravan
	ventures += new /datum/trade_venture/mercenary
	ventures += new /datum/trade_venture/relic
	ventures += new /datum/trade_venture/wizard
	ventures += new /datum/trade_venture/prospectors

/datum/trade_market/proc/get_venture(index)
	var/venture_number = round(text2num("[index]"))
	if(!venture_number || venture_number < 1 || venture_number > length(ventures))
		return
	return ventures[venture_number]

/datum/trade_market/proc/maybe_tick()
	if(world.time < next_tick)
		return
	next_tick = world.time + rand(6 MINUTES, 8 MINUTES)
	for(var/datum/trade_venture/venture in ventures)
		venture.tick_price()
		while(world.time >= venture.next_dividend)
			venture.dividend_accum += venture.current_price * venture.yield / 100
			venture.next_dividend += TRADE_DIVIDEND_PERIOD

/obj/item/venture_certificate
	name = "venture certificate"
	desc = "Official paper of the trade exchange, entitling the bearer to a stake in one of its ventures. Present it at a nervelock to collect interest or sell the stake."
	icon = 'icons/roguetown/items/misc.dmi'
	icon_state = "contractsigned"
	w_class = WEIGHT_CLASS_TINY
	resistance_flags = FLAMMABLE
	firefuel = 30 SECONDS
	sellprice = 0
	var/info
	var/folded = FALSE
	var/base_name = "venture certificate"
	var/venture_index = 0
	var/issue_price = 0
	var/accum_at_collect = 0

/obj/item/venture_certificate/proc/setup(index, datum/trade_venture/venture)
	venture_index = index
	issue_price = venture.current_price
	accum_at_collect = venture.dividend_accum
	name = "venture certificate ([venture.name])"
	base_name = name
	info = "<h2>Certificate of Venture</h2><hr/>The trade exchange recognizes the bearer of this paper as holding one stake in [venture.name], issued at [issue_price] mammon."

/obj/item/venture_certificate/proc/get_venture()
	if(!GLOB.trade_market)
		return
	return GLOB.trade_market.get_venture(venture_index)

/obj/item/venture_certificate/proc/get_accrued()
	var/datum/trade_venture/venture = get_venture()
	if(!venture)
		return 0
	return floor(venture.dividend_accum - accum_at_collect)

// The sub-mammon remainder stays banked on the certificate.
/obj/item/venture_certificate/proc/redeem_interest()
	var/amount = get_accrued()
	if(amount < 1)
		return 0
	accum_at_collect += amount
	return amount

/obj/item/venture_certificate/proc/redeem_sale()
	var/datum/trade_venture/venture = get_venture()
	if(!venture)
		return 0
	venture.issued = max(0, venture.issued - 1)
	return venture.current_price

/obj/item/venture_certificate/examine(mob/user)
	. = ..()
	if(info && !folded)
		. += "<a href='?src=[REF(src)];read=1'>Read</a>"
	var/datum/trade_venture/venture = get_venture()
	if(!venture)
		return
	. += span_info("A stake in [venture.name], bought at [issue_price] mammon. Trading at [venture.current_price] mammon.")
	var/accrued = get_accrued()
	if(accrued > 0)
		. += span_info("[accrued] mammon of interest has accrued. Present it at a nervelock.")

/obj/item/venture_certificate/proc/show_certificate(mob/user)
	if(folded || !user.client || !user.can_read(src))
		return
	user << browse_rsc('html/book.png')
	var/dat = {"<html><head><meta charset="utf-8"><style>body{background-image:url('book.png');background-repeat:repeat;}</style></head><body>[info]</body></html>"}
	user << browse(dat, "window=venturecert;size=390x300")

/obj/item/venture_certificate/attack_self(mob/user)
	folded = !folded
	icon_state = folded ? "parchment_folded" : "contractsigned"
	name = folded ? "folded [base_name]" : base_name
	var/fold_message = folded ? "I fold [base_name]." : "I unfold [base_name]."
	to_chat(user, span_notice(fold_message))

/obj/item/venture_certificate/Topic(href, href_list)
	..()
	if(!ishuman(usr) || !usr.canUseTopic(src, BE_CLOSE))
		return
	if(href_list["read"])
		show_certificate(usr)

GLOBAL_DATUM(trade_coinface, /obj/structure/roguemachine/tradeventures)

/obj/structure/roguemachine/tradeventures
	name = "COINFACE"
	desc = "The trade exchange behind a brass grin, selling stakes in ventures far beyond the walls."
	icon = 'icons/roguetown/misc/machines.dmi'
	icon_state = "coinface"
	density = TRUE
	blade_dulling = DULLING_BASH
	max_integrity = 0
	anchored = TRUE
	layer = BELOW_OBJ_LAYER
	locked = FALSE
	lockid = "merchant"
	var/budget = 0
	var/list/profit_id = list("Merchant", "Shophand")

/obj/item/tradeventures_kit
	name = "packed trade exchange"
	desc = "The COINFACE trade exchange, folded into its carrying frame. Use it in hand to set it up on the ground before you."
	icon = 'icons/roguetown/misc/machines.dmi'
	icon_state = "coinface_off"
	w_class = WEIGHT_CLASS_SMALL
	dropshrink = 0.8

/obj/item/tradeventures_kit/attack_self(mob/living/user)
	if(GLOB.trade_coinface)
		to_chat(user, span_warning("A trade exchange already stands. There can be but one, so I keep this frame folded."))
		return
	var/turf/target_turf = get_step(user, user.dir)
	if(!target_turf || target_turf.density || !isopenturf(target_turf))
		to_chat(user, span_warning("I need clear, open ground before me to set the exchange up."))
		return
	for(var/obj/blocker in target_turf)
		if(blocker.density)
			to_chat(user, span_warning("Something is in the way."))
			return
	to_chat(user, span_notice("I begin unfolding the exchange..."))
	if(!do_after(user, 3 SECONDS, target = user))
		return
	if(QDELETED(src))
		return
	if(GLOB.trade_coinface) // another exchange went up during the wait
		to_chat(user, span_warning("A trade exchange already stands."))
		return
	target_turf = get_step(user, user.dir)
	if(!target_turf || target_turf.density || !isopenturf(target_turf))
		return
	for(var/obj/blocker in target_turf)
		if(blocker.density)
			return
	new /obj/structure/roguemachine/tradeventures(target_turf)
	user.visible_message(span_notice("[user] sets up the trade exchange."))
	playsound(target_turf, 'sound/misc/beep.ogg', 100, FALSE, -1)
	qdel(src)

/obj/structure/roguemachine/tradeventures/Initialize(mapload)
	. = ..()
	if(!GLOB.trade_coinface)
		GLOB.trade_coinface = src
	START_PROCESSING(SSroguemachine, src)

/obj/structure/roguemachine/tradeventures/Destroy()
	STOP_PROCESSING(SSroguemachine, src)
	if(GLOB.trade_coinface == src)
		GLOB.trade_coinface = null
	return ..()

/obj/structure/roguemachine/tradeventures/process()
	GLOB.trade_market.maybe_tick()

/obj/structure/roguemachine/tradeventures/update_icon()
	if(obj_broken)
		icon_state = "coinface_broken"
	else if(locked)
		icon_state = "coinface_off"
	else
		icon_state = initial(icon_state)
	..()

/obj/structure/roguemachine/tradeventures/obj_break(damage_flag)
	..()
	budget2change(budget)
	budget = 0
	update_icon()

/obj/structure/roguemachine/tradeventures/attackby(obj/item/attacking_item, mob/living/user, params)
	if(istype(attacking_item, /obj/item/roguekey))
		var/obj/item/roguekey/key = attacking_item
		if(key.lockid == lockid)
			locked = !locked
			playsound(loc, 'sound/misc/beep.ogg', 100, FALSE, -1)
			update_icon()
			return attack_hand(user)
		else
			to_chat(user, span_warning("Wrong key."))
			return
	if(istype(attacking_item, /obj/item/storage/keyring))
		var/right_key = FALSE
		for(var/obj/item/roguekey/keyring_key in attacking_item.contents)
			if(keyring_key.lockid == lockid)
				right_key = TRUE
				locked = !locked
				playsound(loc, 'sound/misc/beep.ogg', 100, FALSE, -1)
				update_icon()
				return attack_hand(user)
		if(!right_key)
			to_chat(user, span_warning("Wrong key."))
			return
	if(istype(attacking_item, /obj/item/roguecoin/gilbranze))
		return
	if(istype(attacking_item, /obj/item/roguecoin/inqcoin))
		return
	if(istype(attacking_item, /obj/item/roguecoin))
		budget += attacking_item.get_real_price()
		qdel(attacking_item)
		playsound(loc, 'sound/misc/coininsert.ogg', 100, FALSE, -1)
		return attack_hand(user)
	..()

/obj/structure/roguemachine/tradeventures/attack_hand(mob/living/user)
	. = ..()
	if(.)
		return
	if(!ishuman(user))
		return
	if(locked)
		return
	user.changeNext_move(CLICK_CD_INTENTCAP)
	playsound(loc, 'sound/misc/beep.ogg', 100, FALSE, -1)
	GLOB.trade_market.maybe_tick()
	var/mob/living/carbon/human/human_user = user
	var/canread = user.can_read(src, TRUE)
	var/is_trader = (human_user.job in profit_id)
	var/contents = "<center>[canread ? "TRADE VENTURES" : stars("TRADE VENTURES")]<BR>"
	contents += "<a href='?src=[REF(src)];change=1'>[canread ? "MAMMON LOADED:" : stars("MAMMON LOADED:")]</a> [budget]<BR></center><HR>"
	var/index = 0
	for(var/datum/trade_venture/venture in GLOB.trade_market.ventures)
		index++
		if(canread)
			contents += "<b>[venture.name]</b> - [venture.desc]<BR>"
			contents += "Worth: [venture.base_price]m | Yield: [venture.yield]% | Issued: [venture.issued]<BR>"
			if(!venture.fixed_price)
				contents += "<i>Trading at [venture.current_price]m.</i><BR>"
			if(venture.last_news)
				contents += "<i>[venture.last_news]</i><BR>"
			if(is_trader)
				contents += "<a href='?src=[REF(src)];print=[index]'>PRINT CERTIFICATE ([venture.current_price]m)</a><BR>"
		else
			contents += "<b>[stars(venture.name)]</b> - [stars(venture.desc)]<BR>"
			contents += "[stars("Worth:")] [venture.base_price]m | [stars("Yield:")] [venture.yield]% | [stars("Issued:")] [venture.issued]<BR>"
			if(!venture.fixed_price)
				contents += "<i>[stars("Trading at")] [venture.current_price]m.</i><BR>"
			if(is_trader)
				contents += "<a href='?src=[REF(src)];print=[index]'>[stars("PRINT CERTIFICATE")] ([venture.current_price]m)</a><BR>"
		contents += "<BR>"

	var/datum/browser/popup = new(user, "VENDORTHING", "", 500, 700)
	popup.set_content(contents)
	popup.open()

/obj/structure/roguemachine/tradeventures/Topic(href, href_list)
	. = ..()
	if(!ishuman(usr))
		return
	var/mob/living/carbon/human/user = usr
	if(!usr.canUseTopic(src, BE_CLOSE) || locked)
		return
	if(href_list["print"])
		if(!(user.job in profit_id))
			return
		var/datum/trade_venture/venture = GLOB.trade_market.get_venture(href_list["print"])
		if(!venture)
			return
		var/price = venture.current_price
		if(budget < price)
			say("Not enough!")
			playsound(src, 'sound/misc/machineno.ogg', 100, FALSE, -1)
			return
		budget -= price
		venture.issued++
		var/obj/item/venture_certificate/cert = new(get_turf(src))
		cert.setup(GLOB.trade_market.ventures.Find(venture), venture)
		user.put_in_hands(cert)
		say("Printed a stake in [venture.name] for [price] mammon.")
		playsound(src, 'sound/misc/machinetalk.ogg', 100, FALSE, -1)
	if(href_list["change"])
		if(budget > 0)
			budget2change(budget, usr)
			budget = 0
	return attack_hand(usr)

#undef TRADE_DIVIDEND_PERIOD
