# Le "cerveau" du jeu : toutes les règles et toutes les données de la partie.
# Ce script est chargé automatiquement (autoload) sous le nom "Game".
# L'interface (main.gd) ne fait qu'afficher ces données et appeler ces fonctions.
extends Node

signal changed                         # quelque chose a changé : l'interface se met à jour
signal logged(line: String)            # nouvelle ligne dans le journal
signal decision_needed(ev: Dictionary) # un événement demande un choix au joueur
signal game_over(reason: String)       # faillite

const D := preload("res://scripts/data.gd")

const SAVE_PATH := "user://sauvegarde.json"
const START_YEAR := 2027
const START_MONEY := 10000000.0
const STUDIO_SHARE := 0.55        # part des recettes qui revient au studio (le reste va aux cinémas)
const MAX_LOAN := 20000000.0
const LOAN_WEEKLY_RATE := 0.003
const BANKRUPTCY_WEEKS := 12

var started := false
var studio_name := "Mon Studio"
var week := 0
var money := 0.0
var reputation := 20.0
var loan := 0.0
var total_gross := 0.0
var scripts_market := []
var owned_scripts := []
var talents := []
var projects := []
var rivals := []
var rival_films := []
var upgrades := {}
var trends := {}
var log_lines := []
var awards := []
var next_id := 1
var negative_weeks := 0
var is_over := false
var pending_event = null


# ---------------------------------------------------------------------------
# Nouvelle partie
# ---------------------------------------------------------------------------

func new_game(name: String) -> void:
	randomize()
	studio_name = name.strip_edges() if name.strip_edges() != "" else "Mon Studio"
	week = 0
	money = START_MONEY
	reputation = 20.0
	loan = 0.0
	total_gross = 0.0
	scripts_market = []
	owned_scripts = []
	talents = []
	projects = []
	rival_films = []
	log_lines = []
	awards = []
	next_id = 1
	negative_weeks = 0
	is_over = false
	pending_event = null
	upgrades = {}
	for key in D.UPGRADES:
		upgrades[key] = D.UPGRADES[key]["min"]
	trends = {}
	for g in D.GENRES:
		trends[g] = randf_range(0.8, 1.2)
	for i in 14:
		talents.append(_gen_talent("director"))
	for i in 40:
		talents.append(_gen_talent("actor"))
	rivals = []
	for i in D.RIVAL_NAMES.size():
		rivals.append({
			"id": i, "name": D.RIVAL_NAMES[i],
			"money": randf_range(30e6, 60e6), "reputation": randf_range(40.0, 60.0),
			"films": 0, "total_gross": 0.0,
			"next_week": randi_range(2, 8), "next_genre": _pick_trending_genre(),
		})
	_refresh_market()
	started = true
	add_log("Bienvenue ! Le studio « %s » ouvre ses portes. Commencez par acheter un scénario." % studio_name)
	changed.emit()


# ---------------------------------------------------------------------------
# Petits outils
# ---------------------------------------------------------------------------

func _new_id() -> int:
	next_id += 1
	return next_id - 1


func add_log(text: String) -> void:
	var line := "[S%d/%d] %s" % [week_of_year(), year(), text]
	log_lines.append(line)
	if log_lines.size() > 200:
		log_lines.pop_front()
	logged.emit(line)


func year() -> int:
	return START_YEAR + floori(week / 52.0)


func week_of_year() -> int:
	return week % 52 + 1


func date_text() -> String:
	var month: String = D.MONTHS[mini(11, int((week % 52) / 52.0 * 12.0))]
	return "Semaine %d · %s %d" % [week_of_year(), month, year()]


func season_factor(w: int = -1) -> float:
	if w < 0:
		w = week
	var woy := w % 52 + 1
	if woy >= 26 and woy <= 35:
		return 1.3   # vacances d'été
	if woy >= 49:
		return 1.35  # fêtes de fin d'année
	if woy >= 7 and woy <= 13:
		return 0.85  # fin d'hiver, salles calmes
	return 1.0


func season_name(w: int = -1) -> String:
	var f := season_factor(w)
	if f >= 1.35:
		return "Fêtes de fin d'année (affluence +35 %)"
	if f >= 1.3:
		return "Vacances d'été (affluence +30 %)"
	if f < 1.0:
		return "Fin d'hiver (affluence -15 %)"
	return "Saison normale"


func trend_label(g: String) -> String:
	var t: float = trends.get(g, 1.0)
	if t >= 1.3:
		return "Très demandé"
	if t >= 1.1:
		return "En vogue"
	if t >= 0.9:
		return "Normal"
	if t >= 0.75:
		return "En baisse"
	return "Boudé"


func weekly_overhead() -> float:
	var levels := 0
	for key in upgrades:
		levels += int(upgrades[key])
	return 30000.0 + 30000.0 * levels


func _pick_trending_genre() -> String:
	# Les rivaux aiment suivre les modes : tirage pondéré par la tendance.
	var total := 0.0
	for g in D.GENRES:
		total += float(trends.get(g, 1.0))
	var r := randf() * total
	for g in D.GENRES:
		r -= float(trends.get(g, 1.0))
		if r <= 0.0:
			return g
	return D.GENRES[0]


# ---------------------------------------------------------------------------
# Talents (acteurs et réalisateurs)
# ---------------------------------------------------------------------------

func _gen_name() -> String:
	for attempt in 30:
		var n: String = "%s %s" % [D.FIRST_NAMES.pick_random(), D.LAST_NAMES.pick_random()]
		var taken := false
		for t in talents:
			if t["name"] == n:
				taken = true
				break
		if not taken:
			return n
	return "%s %s" % [D.FIRST_NAMES.pick_random(), D.LAST_NAMES.pick_random()]


func _gen_talent(kind: String, young := false) -> Dictionary:
	var fame := clampi(int(randfn(35.0, 20.0)), 1, 95)
	var age := randi_range(22, 66)
	if young:
		fame = randi_range(1, 20)
		age = randi_range(19, 28)
	return {
		"id": _new_id(), "name": _gen_name(), "kind": kind,
		"skill": clampi(int(randfn(50.0, 15.0)), 15, 95),
		"fame": fame, "genre": D.GENRES.pick_random(), "age": age,
		"busy_until": 0, "busy_with": "", "films": 0, "retired": false,
	}


func get_talent(id) -> Dictionary:
	for t in talents:
		if int(t["id"]) == int(id):
			return t
	return {}


func salary(t: Dictionary) -> float:
	var s := 100000.0 + float(t["fame"]) * float(t["fame"]) * 550.0 + float(t["skill"]) * 9000.0
	if t["kind"] == "director":
		s *= 1.2
	return round(s / 10000.0) * 10000.0


func is_available(t: Dictionary) -> bool:
	return not t["retired"] and int(t["busy_until"]) <= week


func available_talents(kind: String) -> Array:
	var list := talents.filter(func(t): return t["kind"] == kind and is_available(t))
	list.sort_custom(func(a, b): return a["fame"] > b["fame"])
	return list


func talent_status(t: Dictionary) -> String:
	if t["retired"]:
		return "À la retraite"
	if is_available(t):
		return "Disponible"
	return "Pris par %s (jusqu'à S%d)" % [t["busy_with"], (int(t["busy_until"]) % 52) + 1]


# ---------------------------------------------------------------------------
# Scénarios
# ---------------------------------------------------------------------------

func _gen_title(g: String) -> String:
	var parts: Array = D.TITLE_PARTS[g]
	for attempt in 20:
		var title: String = "%s %s" % [parts[0].pick_random(), parts[1].pick_random()]
		if not _title_used(title):
			return title
	return "%s %s %d" % [parts[0].pick_random(), parts[1].pick_random(), randi_range(2, 4)]


func _title_used(title: String) -> bool:
	for s in scripts_market + owned_scripts + projects + rival_films:
		if s["title"] == title:
			return true
	return false


func _gen_script() -> Dictionary:
	var g: String = D.GENRES.pick_random()
	var q := clampi(int(randfn(42.0 + upgrades["ecriture"] * 5.0, 14.0)), 10, 98)
	var roles := 2 if g == "Animation" else randi_range(1, 3)
	return {
		"id": _new_id(), "title": _gen_title(g), "genre": g, "quality": q, "roles": roles,
		"cost": round((40000.0 + q * q * 55.0) / 5000.0) * 5000.0,
	}


func _refresh_market() -> void:
	scripts_market = []
	for i in 6 + 2 * int(upgrades["ecriture"]):
		scripts_market.append(_gen_script())


func weeks_until_new_scripts() -> int:
	return 4 - (week % 4)


func buy_script(id) -> String:
	for s in scripts_market:
		if int(s["id"]) == int(id):
			if money < s["cost"]:
				return "Pas assez d'argent pour acheter ce scénario."
			money -= s["cost"]
			scripts_market.erase(s)
			owned_scripts.append(s)
			add_log("Vous achetez le scénario « %s » (%s) pour %s." % [s["title"], s["genre"], fmt_money(s["cost"])])
			changed.emit()
			return ""
	return "Ce scénario n'est plus disponible."


func get_owned_script(id) -> Dictionary:
	for s in owned_scripts:
		if int(s["id"]) == int(id):
			return s
	return {}


# ---------------------------------------------------------------------------
# Production d'un film
# ---------------------------------------------------------------------------

func active_productions() -> Array:
	return projects.filter(func(p): return p["phase"] in ["preprod", "shooting", "postprod"])


func free_stages() -> int:
	return int(upgrades["plateaux"]) - active_productions().size()


func postprod_weeks() -> int:
	return maxi(2, D.BASE_POSTPROD_WEEKS - int(upgrades["montage"]))


# Estime ce que va coûter un film (sans le marketing, choisi à la sortie).
func estimate(script: Dictionary, director: Dictionary, actors: Array, prod_level: int) -> Dictionary:
	var salaries := 0.0
	if not director.is_empty():
		salaries += salary(director)
	for a in actors:
		if not a.is_empty():
			salaries += salary(a)
	var shoot: int = D.SHOOT_WEEKS[script["genre"]] if not script.is_empty() else 0
	var shooting_cost: float = D.PROD_LEVELS[prod_level]["weekly"] * shoot
	return {
		"salaries": salaries, "shooting": shooting_cost, "total": salaries + shooting_cost,
		"weeks": D.PREPROD_WEEKS + shoot + postprod_weeks(), "shoot_weeks": shoot,
	}


func start_production(script_id, director_id, actor_ids: Array, prod_level: int) -> String:
	var script := get_owned_script(script_id)
	if script.is_empty():
		return "Choisissez un scénario."
	if free_stages() <= 0:
		return "Tous vos plateaux sont occupés. Attendez la fin d'un tournage ou achetez un plateau."
	var director := get_talent(director_id)
	if director.is_empty() or director["kind"] != "director" or not is_available(director):
		return "Choisissez un réalisateur disponible."
	if actor_ids.size() != int(script["roles"]):
		return "Ce scénario demande %d acteur(s)." % script["roles"]
	var actors := []
	for aid in actor_ids:
		var a := get_talent(aid)
		if a.is_empty() or a["kind"] != "actor" or not is_available(a):
			return "Un des acteurs choisis n'est pas disponible."
		for other in actors:
			if int(other["id"]) == int(a["id"]):
				return "Le même acteur ne peut pas jouer deux rôles."
		actors.append(a)
	var est := estimate(script, director, actors, prod_level)
	if money < est["salaries"]:
		return "Pas assez d'argent pour payer les cachets (%s)." % fmt_money(est["salaries"])

	money -= est["salaries"]
	var end_shoot: int = week + D.PREPROD_WEEKS + int(est["shoot_weeks"])
	var names := []
	for t in [director] + actors:
		t["busy_until"] = end_shoot + 1
		t["busy_with"] = studio_name
		t["films"] = int(t["films"]) + 1
	for a in actors:
		names.append(a["name"])
	owned_scripts.erase(script)
	var p := {
		"id": _new_id(), "title": script["title"], "genre": script["genre"],
		"script_quality": script["quality"], "director": director["id"], "director_name": director["name"],
		"actors": actor_ids.duplicate(), "actor_names": names, "prod_level": prod_level,
		"phase": "preprod", "weeks_left": D.PREPROD_WEEKS, "phase_total": D.PREPROD_WEEKS,
		"shoot_weeks": est["shoot_weeks"], "cost": script["cost"] + est["salaries"], "revenue": 0.0,
		"quality_mod": 0, "hype_mod": 0, "quality": 0, "critic": 0, "screening": "",
		"hype": 0.0, "opening": 0.0, "weeks_in": 0, "last_gross": 0.0, "gross": 0.0,
		"release_week": -1, "mkt_level": 0, "start_week": week, "events": [],
	}
	projects.append(p)
	add_log("Lancement de « %s » réalisé par %s. Préproduction : %d semaines." % [p["title"], director["name"], D.PREPROD_WEEKS])
	changed.emit()
	return ""


func get_project(id) -> Dictionary:
	for p in projects:
		if int(p["id"]) == int(id):
			return p
	return {}


func phase_name(p: Dictionary) -> String:
	match p["phase"]:
		"preprod": return "Préproduction"
		"shooting": return "Tournage"
		"postprod": return "Post-production"
		"ready": return "Prêt à sortir"
		"in_theaters": return "Au cinéma"
		"finished": return "Terminé"
	return "?"


func _compute_quality(p: Dictionary) -> int:
	var d := get_talent(p["director"])
	var fit := 0.0
	var a_sum := 0.0
	for aid in p["actors"]:
		var a := get_talent(aid)
		a_sum += float(a.get("skill", 40))
		if a.get("genre", "") == p["genre"]:
			fit += 2.0
	var a_avg := a_sum / maxf(1.0, float(p["actors"].size()))
	if d.get("genre", "") == p["genre"]:
		fit += 4.0
	var q := float(p["script_quality"]) * 0.35 + float(d.get("skill", 40)) * 0.25 + a_avg * 0.25
	q += D.PROD_LEVELS[int(p["prod_level"])]["bonus"] + int(upgrades["montage"]) * 2 + fit + float(p["quality_mod"])
	if p["genre"] in D.VFX_GENRES:
		q += int(upgrades["vfx"]) * 3
	q += randf_range(-6.0, 6.0)
	return clampi(int(round(q)), 1, 100)


func _screening_text(q: int) -> String:
	# L'avis des projections test donne une idée (pas exacte !) de la qualité.
	var guess := q + randi_range(-8, 8)
	if guess >= 75:
		return "Excellent : le public test a applaudi"
	if guess >= 60:
		return "Bon : réactions positives"
	if guess >= 45:
		return "Moyen : avis partagés"
	return "Faible : beaucoup de gens se sont ennuyés"


func _process_projects() -> void:
	for p in projects.duplicate():
		match p["phase"]:
			"preprod":
				p["weeks_left"] = int(p["weeks_left"]) - 1
				if p["weeks_left"] <= 0:
					p["phase"] = "shooting"
					p["weeks_left"] = p["shoot_weeks"]
					p["phase_total"] = p["shoot_weeks"]
					add_log("Premier jour de tournage pour « %s » !" % p["title"])
			"shooting":
				var c: float = D.PROD_LEVELS[int(p["prod_level"])]["weekly"]
				money -= c
				p["cost"] += c
				_maybe_shooting_event(p)
				p["weeks_left"] = int(p["weeks_left"]) - 1
				if p["weeks_left"] <= 0:
					p["phase"] = "postprod"
					p["weeks_left"] = postprod_weeks()
					p["phase_total"] = postprod_weeks()
					for tid in [p["director"]] + p["actors"]:
						var t := get_talent(tid)
						if not t.is_empty() and t["busy_with"] == studio_name:
							t["busy_until"] = week
					add_log("Fin du tournage de « %s ». Place au montage." % p["title"])
			"postprod":
				p["weeks_left"] = int(p["weeks_left"]) - 1
				if p["weeks_left"] <= 0:
					p["quality"] = _compute_quality(p)
					p["screening"] = _screening_text(int(p["quality"]))
					p["phase"] = "ready"
					add_log("« %s » est terminé ! Projections test : %s. Choisissez sa date de sortie." % [p["title"], p["screening"]])


# ---------------------------------------------------------------------------
# Événements de tournage
# ---------------------------------------------------------------------------

func _maybe_shooting_event(p: Dictionary) -> void:
	if randf() > 0.12:
		return
	var director_name: String = p["director_name"]
	var star: String = p["actor_names"].pick_random() if p["actor_names"].size() > 0 else director_name
	var roll := randi_range(0, 8)
	# Événements à choix (seulement si aucun autre choix n'est en attente).
	if roll <= 3 and pending_event == null:
		var ev := {"project_id": p["id"], "title": p["title"]}
		match roll:
			0:
				var amount := 500000.0 + 100000.0 * randi_range(0, 5)
				ev.merge({"kind": "scene", "amount": amount, "accept": "Payer %s" % fmt_money(amount), "refuse": "Refuser",
					"text": "Sur « %s », %s veut tourner une scène spectaculaire en plus. Coût : %s. Le film serait meilleur." % [p["title"], director_name, fmt_money(amount)]})
			1:
				var amount := 200000.0 + 50000.0 * randi_range(0, 4)
				ev.merge({"kind": "caprice", "amount": amount, "accept": "Céder (%s)" % fmt_money(amount), "refuse": "Refuser",
					"text": "%s exige une caravane de luxe sur le tournage de « %s » (%s). Sinon, la star menace de mal jouer." % [star, p["title"], fmt_money(amount)]})
			2:
				var amount := 600000.0 + 100000.0 * randi_range(0, 6)
				ev.merge({"kind": "placement", "amount": amount, "accept": "Accepter (+%s)" % fmt_money(amount), "refuse": "Refuser",
					"text": "Une marque de sodas propose %s pour voir sa canette dans « %s ». Les critiques risquent de le remarquer." % [fmt_money(amount), p["title"]]})
			3:
				var amount := 300000.0
				ev.merge({"kind": "fuite", "amount": amount, "accept": "Contre-attaquer (%s)" % fmt_money(amount), "refuse": "Ignorer",
					"text": "Des images de « %s » ont fuité sur internet ! Lancer une contre-campagne de communication ?" % p["title"]})
		pending_event = ev
		decision_needed.emit(ev)
		return
	# Événements automatiques.
	match roll:
		4:
			p["weeks_left"] = int(p["weeks_left"]) + 1
			add_log("Tempête sur le tournage de « %s » : une semaine de retard." % p["title"])
		5:
			p["quality_mod"] = int(p["quality_mod"]) + 4
			add_log("%s improvise une scène culte sur « %s » ! (+qualité)" % [star, p["title"]])
		6:
			p["hype_mod"] = int(p["hype_mod"]) + 8
			add_log("Les réseaux sociaux s'enflamment pour les photos de tournage de « %s ». (+buzz)" % p["title"])
		7:
			var extra := float(D.PROD_LEVELS[int(p["prod_level"])]["weekly"]) * 0.5
			money -= extra
			p["cost"] += extra
			add_log("Décor endommagé sur « %s » : %s de réparations." % [p["title"], fmt_money(extra)])
		_:
			p["quality_mod"] = int(p["quality_mod"]) + 3
			add_log("Belle complicité entre les acteurs de « %s ». (+qualité)" % p["title"])


func resolve_event(accept: bool) -> void:
	if pending_event == null:
		return
	var ev: Dictionary = pending_event
	pending_event = null
	var p := get_project(ev["project_id"])
	if p.is_empty():
		changed.emit()
		return
	var amount := float(ev.get("amount", 0.0))
	match ev["kind"]:
		"scene":
			if accept:
				money -= amount
				p["cost"] += amount
				p["quality_mod"] = int(p["quality_mod"]) + 6
				add_log("La scène spectaculaire de « %s » est tournée. (+qualité)" % p["title"])
			else:
				add_log("Pas de scène en plus pour « %s »." % p["title"])
		"caprice":
			if accept:
				money -= amount
				p["cost"] += amount
				add_log("La star de « %s » a sa caravane. Tout le monde est content." % p["title"])
			else:
				p["quality_mod"] = int(p["quality_mod"]) - 5
				add_log("La star de « %s » boude et joue moins bien. (-qualité)" % p["title"])
		"placement":
			if accept:
				money += amount
				p["revenue"] += amount
				p["quality_mod"] = int(p["quality_mod"]) - 3
				add_log("Placement de produit accepté pour « %s » (+%s)." % [p["title"], fmt_money(amount)])
			else:
				add_log("Placement de produit refusé pour « %s »." % p["title"])
		"fuite":
			if accept:
				money -= amount
				p["cost"] += amount
				p["hype_mod"] = int(p["hype_mod"]) + 6
				add_log("La contre-campagne transforme la fuite de « %s » en bon buzz !" % p["title"])
			else:
				p["hype_mod"] = int(p["hype_mod"]) - 5
				add_log("La fuite de « %s » gâche un peu la surprise. (-buzz)" % p["title"])
	changed.emit()


# ---------------------------------------------------------------------------
# Sortie au cinéma et box-office
# ---------------------------------------------------------------------------

func compute_hype(p: Dictionary, mkt_level: int) -> float:
	var fame_sum := 0.0
	for aid in p["actors"]:
		fame_sum += float(get_talent(aid).get("fame", 20))
	var fame_avg := fame_sum / maxf(1.0, float(p["actors"].size()))
	var d_fame := float(get_talent(p["director"]).get("fame", 20))
	var mkt := float(D.MKT_LEVELS[mkt_level]["hype"]) * (1.0 + 0.2 * int(upgrades["marketing"]))
	var h := fame_avg * 0.45 + d_fame * 0.15 + mkt + reputation * 0.25 + float(p["hype_mod"])
	h += float(D.PROD_LEVELS[int(p["prod_level"])]["hype"])
	return clampf(h, 0.0, 130.0)


func _opening(genre: String, quality: float, hype: float) -> float:
	# La pub et les stars aident, mais de moins en moins quand on en ajoute (rendements décroissants).
	var hype_factor := 0.3 + 1.4 * (1.0 - exp(-hype / 60.0))
	return 6000000.0 * float(D.GENRE_BASE[genre]) * float(trends[genre]) \
		* hype_factor * (0.3 + quality / 80.0) * randf_range(0.85, 1.15)


func release_film(id, mkt_level: int) -> String:
	var p := get_project(id)
	if p.is_empty() or p["phase"] != "ready":
		return "Ce film n'est pas prêt."
	var cost: float = D.MKT_LEVELS[mkt_level]["cost"]
	if money < cost:
		return "Pas assez d'argent pour cette campagne de publicité."
	money -= cost
	p["cost"] += cost
	p["mkt_level"] = mkt_level
	p["hype"] = compute_hype(p, mkt_level)
	p["critic"] = clampi(int(p["quality"]) + randi_range(-10, 10), 1, 100)
	p["opening"] = _opening(p["genre"], float(p["quality"]), float(p["hype"]))
	p["phase"] = "in_theaters"
	p["release_week"] = week
	p["weeks_in"] = 0
	trends[p["genre"]] = maxf(0.6, float(trends[p["genre"]]) - 0.03)
	add_log("« %s » sort au cinéma ! Note des critiques : %d/100." % [p["title"], p["critic"]])
	changed.emit()
	return ""


func films_in_theaters() -> Array:
	var list := []
	for p in projects:
		if p["phase"] == "in_theaters":
			list.append(p)
	for f in rival_films:
		if not f["done"]:
			list.append(f)
	return list


func _process_theaters() -> void:
	var all := films_in_theaters()
	for f in all:
		f["weeks_in"] = int(f["weeks_in"]) + 1
	var season := season_factor()
	for i in all.size():
		var f: Dictionary = all[i]
		# Concurrence : les nouveaux films du même genre (et un peu tous les autres) se partagent le public.
		var comp := 0.0
		for j in all.size():
			if i != j and int(all[j]["weeks_in"]) <= 3:
				comp += 0.3 if all[j]["genre"] == f["genre"] else 0.05
		# Un bon film garde son public plus longtemps (bouche-à-oreille).
		var decay := 0.45 + float(f["quality"]) / 300.0
		var g := float(f["opening"]) * pow(decay, int(f["weeks_in"]) - 1) * season / (1.0 + comp)
		f["last_gross"] = g
		f["gross"] = float(f["gross"]) + g
	for f in all:
		var g: float = f["last_gross"]
		var leaving: bool = g < 150000.0 or int(f["weeks_in"]) >= 14
		if f.has("rival_id"):
			var r: Dictionary = rivals[int(f["rival_id"])]
			r["money"] = float(r["money"]) + g * STUDIO_SHARE
			r["total_gross"] = float(r["total_gross"]) + g
			if leaving:
				f["done"] = true
				f["last_gross"] = 0.0
				r["reputation"] = clampf(float(r["reputation"]) + (float(f["critic"]) - 55.0) / 10.0, 20.0, 95.0)
		else:
			money += g * STUDIO_SHARE
			f["revenue"] = float(f["revenue"]) + g * STUDIO_SHARE
			total_gross += g
			if leaving:
				_finish_film(f)


func _finish_film(p: Dictionary) -> void:
	p["phase"] = "finished"
	p["last_gross"] = 0.0
	# Après le cinéma : ventes TV, streaming, DVD...
	var after := float(p["gross"]) * 0.12 + float(p["quality"]) * 25000.0
	money += after
	p["revenue"] = float(p["revenue"]) + after
	var profit := float(p["revenue"]) - float(p["cost"])
	var rep_change := (float(p["critic"]) - 55.0) / 12.0 + (1.0 if profit > 0 else -1.5)
	if rep_change > 0:
		rep_change *= 1.0 - reputation / 125.0  # plus on est célèbre, plus c'est dur de progresser
	reputation = clampf(reputation + rep_change, 0.0, 100.0)
	var success := profit > 0 and float(p["critic"]) >= 55.0
	for tid in [p["director"]] + p["actors"]:
		var t := get_talent(tid)
		if t.is_empty():
			continue
		if success:
			t["fame"] = mini(100, int(t["fame"]) + randi_range(2, 6))
		elif profit < 0:
			t["fame"] = maxi(1, int(t["fame"]) - randi_range(0, 3))
		if int(t["skill"]) < 90 and randf() < 0.5:
			t["skill"] = int(t["skill"]) + 1
	var verdict := "succès" if profit > 0 else "échec"
	add_log("« %s » quitte les salles : %s au box-office, bénéfice %s (%s). Ventes TV/streaming : %s." % [
		p["title"], fmt_money(p["gross"]), fmt_money(profit), verdict, fmt_money(after)])


# ---------------------------------------------------------------------------
# Studios rivaux
# ---------------------------------------------------------------------------

func _process_rivals() -> void:
	for r in rivals:
		if int(r["next_week"]) <= week:
			_rival_release(r)
		# Les rivaux engagent parfois une star disponible.
		if randf() < 0.08:
			var free := available_talents("actor" if randf() < 0.75 else "director")
			if free.size() > 0:
				var t: Dictionary = free[randi_range(0, mini(5, free.size() - 1))]
				t["busy_until"] = week + randi_range(8, 20)
				t["busy_with"] = r["name"]
				t["films"] = int(t["films"]) + 1
				if int(t["fame"]) >= 50:
					add_log("La star %s signe chez %s pour son prochain film." % [t["name"], r["name"]])


func _rival_release(r: Dictionary) -> void:
	var g: String = r["next_genre"]
	var q := clampi(int(randfn(float(r["reputation"]) * 0.8 + 10.0, 12.0)), 10, 98)
	var budget := randf_range(10e6, 30e6)
	if float(r["money"]) < 20e6:
		budget *= 0.5
	r["money"] = float(r["money"]) - budget
	var hype := float(r["reputation"]) * 0.6 + randf_range(10.0, 40.0)
	var f := {
		"id": _new_id(), "title": _gen_title(g), "studio": r["name"], "rival_id": r["id"],
		"genre": g, "quality": q, "critic": clampi(q + randi_range(-10, 10), 1, 100),
		"opening": _opening(g, float(q), hype), "weeks_in": 0, "last_gross": 0.0, "gross": 0.0,
		"release_week": week, "budget": budget, "done": false,
	}
	rival_films.append(f)
	r["films"] = int(r["films"]) + 1
	trends[g] = maxf(0.6, float(trends[g]) - 0.03)
	add_log("%s sort « %s » (%s)." % [r["name"], f["title"], g])
	# Un rival riche produit plus de films.
	r["next_week"] = week + (randi_range(4, 8) if float(r["money"]) > 80e6 else randi_range(6, 12))
	r["next_genre"] = _pick_trending_genre()


# Classement de tous les studios selon les recettes totales.
func ranking() -> Array:
	var list := [{"name": studio_name, "reputation": reputation, "films": released_films().size(),
		"total_gross": total_gross, "player": true, "next": "—"}]
	for r in rivals:
		var wait := int(r["next_week"]) - week
		list.append({"name": r["name"], "reputation": r["reputation"], "films": r["films"],
			"total_gross": r["total_gross"], "player": false,
			"next": "%s, dans %d sem." % [r["next_genre"], maxi(0, wait)] if wait > 0 else "%s, cette semaine" % r["next_genre"]})
	list.sort_custom(func(a, b): return a["total_gross"] > b["total_gross"])
	return list


func player_rank() -> int:
	var list := ranking()
	for i in list.size():
		if list[i]["player"]:
			return i + 1
	return list.size()


func released_films() -> Array:
	return projects.filter(func(p): return p["phase"] in ["in_theaters", "finished"])


func upcoming_rival_releases(within: int) -> Array:
	var list := []
	for r in rivals:
		var wait := int(r["next_week"]) - week
		if wait <= within:
			list.append("%s (%s) dans %d sem." % [r["name"], r["next_genre"], maxi(0, wait)])
	return list


# ---------------------------------------------------------------------------
# Améliorations et banque
# ---------------------------------------------------------------------------

func upgrade_cost(key: String) -> float:
	var u: Dictionary = D.UPGRADES[key]
	var lvl := int(upgrades[key])
	if lvl >= int(u["max"]):
		return -1.0
	return float(u["costs"][lvl])


func buy_upgrade(key: String) -> String:
	var cost := upgrade_cost(key)
	if cost < 0:
		return "Cette amélioration est déjà au maximum."
	if money < cost:
		return "Pas assez d'argent."
	money -= cost
	upgrades[key] = int(upgrades[key]) + 1
	add_log("Amélioration : %s passe au niveau %d." % [D.UPGRADES[key]["name"], upgrades[key]])
	if key == "ecriture":
		scripts_market.append(_gen_script())
		scripts_market.append(_gen_script())
	changed.emit()
	return ""


func take_loan(amount: float) -> String:
	amount = minf(amount, MAX_LOAN - loan)
	if amount <= 0:
		return "La banque refuse : vous avez déjà emprunté le maximum (%s)." % fmt_money(MAX_LOAN)
	loan += amount
	money += amount
	add_log("Vous empruntez %s à la banque." % fmt_money(amount))
	changed.emit()
	return ""


func repay_loan(amount: float) -> String:
	amount = minf(amount, loan)
	if amount <= 0:
		return "Vous n'avez rien à rembourser."
	if money < amount:
		return "Pas assez d'argent pour rembourser."
	loan -= amount
	money -= amount
	add_log("Vous remboursez %s à la banque." % fmt_money(amount))
	changed.emit()
	return ""


# ---------------------------------------------------------------------------
# Le temps passe : une semaine de jeu
# ---------------------------------------------------------------------------

func advance_week() -> void:
	if not started or is_over or pending_event != null:
		return
	week += 1
	money -= weekly_overhead()
	money -= loan * LOAN_WEEKLY_RATE
	# La réputation s'use doucement si on ne sort plus de bons films.
	reputation = maxf(0.0, reputation - (reputation - 25.0) * 0.004)
	_process_projects()
	_process_theaters()
	_process_rivals()
	if week % 4 == 0:
		_refresh_market()
		for g in D.GENRES:
			trends[g] = clampf(float(trends[g]) + randf_range(-0.1, 0.12), 0.6, 1.5)
	if week % 52 == 0:
		_new_year()
	_check_money()
	if week % 4 == 0 and not is_over:
		save_game()
	changed.emit()


func _new_year() -> void:
	var y := year() - 1
	# Les Bobines d'Or : prix du meilleur film de l'année.
	var best = null
	var best_studio := ""
	for p in released_films():
		if int(p["release_week"]) >= week - 52 and (best == null or p["critic"] > best["critic"]):
			best = p
			best_studio = studio_name
	for f in rival_films:
		if int(f["release_week"]) >= week - 52 and (best == null or f["critic"] > best["critic"]):
			best = f
			best_studio = f["studio"]
	if best != null:
		awards.append({"year": y, "title": best["title"], "studio": best_studio, "critic": best["critic"]})
		if best_studio == studio_name:
			money += 1000000.0
			reputation = minf(100.0, reputation + 8.0)
			add_log("BOBINE D'OR %d : « %s » est sacré meilleur film de l'année ! (+1 M$, +8 réputation)" % [y, best["title"]])
		else:
			add_log("Bobine d'Or %d : « %s » de %s remporte le prix." % [y, best["title"], best_studio])
	# Les talents vieillissent, certains prennent leur retraite, des jeunes arrivent.
	for t in talents:
		if t["retired"]:
			continue
		t["age"] = int(t["age"]) + 1
		if int(t["age"]) > 68 and randf() < 0.35 and is_available(t):
			t["retired"] = true
			add_log("%s prend sa retraite." % t["name"])
	for i in 5:
		talents.append(_gen_talent("actor", true))
	for i in 2:
		talents.append(_gen_talent("director", true))
	# On oublie les vieux films des rivaux pour garder une sauvegarde légère.
	rival_films = rival_films.filter(func(f): return not f["done"] or int(f["release_week"]) >= week - 104)
	add_log("Bonne année %d ! De nouveaux talents arrivent à Hollywood... euh, au studio." % year())


func _check_money() -> void:
	if money < 0:
		negative_weeks += 1
		if negative_weeks == 1:
			add_log("ATTENTION : votre trésorerie est dans le rouge ! Faillite après %d semaines dans le négatif." % BANKRUPTCY_WEEKS)
		if negative_weeks >= BANKRUPTCY_WEEKS:
			is_over = true
			add_log("Faillite. Le studio ferme ses portes.")
			game_over.emit("Votre trésorerie est restée dans le rouge pendant %d semaines. La banque ferme le studio « %s »." % [BANKRUPTCY_WEEKS, studio_name])
	else:
		negative_weeks = 0


# ---------------------------------------------------------------------------
# Sauvegarde
# ---------------------------------------------------------------------------

const SAVED_FIELDS := ["studio_name", "week", "money", "reputation", "loan", "total_gross", "scripts_market",
	"owned_scripts", "talents", "projects", "rivals", "rival_films", "upgrades", "trends", "log_lines",
	"awards", "next_id", "negative_weeks", "is_over", "pending_event"]


func save_game() -> bool:
	var data := {"version": 1}
	for f in SAVED_FIELDS:
		data[f] = get(f)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	return true


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func load_game() -> bool:
	if not has_save():
		return false
	var text := FileAccess.get_file_as_string(SAVE_PATH)
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		return false
	data = _fix_numbers(data)
	for f in SAVED_FIELDS:
		if data.has(f):
			set(f, data[f])
	money = float(money)
	reputation = float(reputation)
	loan = float(loan)
	total_gross = float(total_gross)
	started = true
	changed.emit()
	if pending_event != null:
		decision_needed.emit(pending_event)
	return true


# Le format JSON transforme tous les nombres entiers en nombres à virgule :
# on les remet en entiers pour que les identifiants se comparent bien.
func _fix_numbers(v):
	match typeof(v):
		TYPE_FLOAT:
			if v == floor(v) and absf(v) < 1e15:
				return int(v)
			return v
		TYPE_ARRAY:
			var out := []
			for x in v:
				out.append(_fix_numbers(x))
			return out
		TYPE_DICTIONARY:
			var out := {}
			for k in v:
				out[k] = _fix_numbers(v[k])
			return out
	return v


# ---------------------------------------------------------------------------
# Affichage de l'argent : 1 250 000 -> "1,3 M$"
# ---------------------------------------------------------------------------

static func fmt_money(v) -> String:
	var x := float(v)
	var prefix := "-" if x < 0 else ""
	x = absf(x)
	if x >= 1000000.0:
		return (prefix + "%.1f M$" % (x / 1000000.0)).replace(".", ",")
	if x >= 1000.0:
		return prefix + "%d k$" % int(round(x / 1000.0))
	return prefix + "%d $" % int(round(x))
