# Test automatique : un "joueur robot" joue plusieurs années pour vérifier
# que le jeu ne plante pas et que l'économie reste équilibrée.
# Lancer : godot --headless --path . res://tests/test_runner.tscn
extends Node

const YEARS := 10

func _ready() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	main.name_edit.text = "Studio Test"
	main._on_new_game()
	var errors := 0
	for w in 52 * YEARS:
		_robot_play()
		Game.advance_week()
		# On construit chaque onglet de l'interface pour vérifier qu'il n'y a pas d'erreur.
		main.tabs.current_tab = w % main.TAB_NAMES.size()
		main._refresh()
		if w == 130:
			Game.save_game()
			var before := Game.money
			Game.load_game()
			assert(absf(Game.money - before) < 1.0)
			print("Sauvegarde/chargement OK")
		if Game.week % 52 == 0:
			_report()
		if Game.is_over:
			print("FAILLITE semaine ", Game.week)
			break
	var films := Game.released_films()
	var profit := 0.0
	var wins := 0
	for p in films:
		if p["phase"] == "finished":
			profit += float(p["revenue"]) - float(p["cost"])
			if float(p["revenue"]) > float(p["cost"]):
				wins += 1
	for p in films.slice(films.size() - 12, films.size()):
		print("  %s q=%d hype=%d open=%s gross=%s cost=%s rev=%s" % [p["title"], p["quality"], p["hype"], Game.fmt_money(p["opening"]), Game.fmt_money(p["gross"]), Game.fmt_money(p["cost"]), Game.fmt_money(p["revenue"])])
	print("Films sortis : %d, rentables : %d, bénéfice total : %s" % [films.size(), wins, Game.fmt_money(profit)])
	print("TEST TERMINÉ")
	get_tree().quit()


func _report() -> void:
	var r := Game.ranking()
	var s := ""
	for x in r:
		s += "%s=%s  " % [x["name"].left(10), Game.fmt_money(x["total_gross"])]
	print("Année %d | argent %s | prêt %s | réput %d | films %d | rang %d | %s" % [
		Game.year() - 1, Game.fmt_money(Game.money), Game.fmt_money(Game.loan), int(Game.reputation),
		Game.released_films().size(), Game.player_rank(), s])


func _robot_play() -> void:
	if Game.pending_event != null:
		Game.resolve_event(randf() < 0.5)
	# Sortir les films prêts
	for p in Game.projects:
		if p["phase"] == "ready":
			Game.release_film(p["id"], 1 if Game.money > 4e6 else 0)
	# Acheter un scénario
	if Game.owned_scripts.size() < Game.free_stages() and Game.scripts_market.size() > 0:
		var best = null
		for s in Game.scripts_market:
			if s["cost"] < Game.money * 0.1 and (best == null or s["quality"] * Game.trends[s["genre"]] > best["quality"] * Game.trends[best["genre"]]):
				best = s
		if best != null:
			Game.buy_script(best["id"])
	# Lancer un film
	if Game.free_stages() > 0 and Game.owned_scripts.size() > 0:
		var script: Dictionary = Game.owned_scripts[0]
		var budget := Game.money * 0.4
		var dirs := Game.available_talents("director").filter(func(t): return Game.salary(t) < budget * 0.3)
		var acts := Game.available_talents("actor").filter(func(t): return Game.salary(t) < budget * 0.2)
		if dirs.size() > 0 and acts.size() >= int(script["roles"]):
			dirs.sort_custom(func(a, b): return a["skill"] > b["skill"])
			acts.sort_custom(func(a, b): return a["skill"] + a["fame"] > b["skill"] + b["fame"])
			var ids := []
			for i in int(script["roles"]):
				ids.append(acts[i]["id"])
			var err := Game.start_production(script["id"], dirs[0]["id"], ids, 1 if Game.money > 12e6 else 0)
			if err != "":
				pass
	# Améliorations
	if Game.money > 25e6:
		for key in ["plateaux", "montage", "ecriture", "marketing", "vfx"]:
			var c := Game.upgrade_cost(key)
			if c > 0 and Game.money - c > 15e6:
				Game.buy_upgrade(key)
				break
	if Game.money < 0 and Game.loan < Game.MAX_LOAN:
		Game.take_loan(2e6)
	if Game.money > 20e6 and Game.loan > 0:
		Game.repay_loan(Game.loan)
