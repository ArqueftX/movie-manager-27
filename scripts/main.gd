# L'interface du jeu. Elle est construite entièrement en code pour rester simple
# à lire : chaque onglet a sa fonction "_build_xxx" qui crée ses textes et boutons.
extends Control

const D := preload("res://scripts/data.gd")

const GOLD := Color("f5c542")
const MUTED := Color("9aa0b4")
const GOOD := Color("5fd38d")
const BAD := Color("ff6b6b")
const PANEL_BG := Color("1e222d")

const TAB_NAMES := ["Tableau de bord", "Scénarios", "Talents", "Productions", "Box-office", "Studio", "Concurrents", "Aide"]
enum Tab { DASHBOARD, SCRIPTS, TALENTS, PRODUCTIONS, BOX_OFFICE, STUDIO, RIVALS, HELP }

var tabs: TabContainer
var pages := []
var lbl_date: Label
var lbl_money: Label
var lbl_rep: Label
var btn_next: Button
var btn_auto: Button
var speed_opt: OptionButton
var log_box: RichTextLabel
var auto_timer: Timer
var start_screen: Control
var name_edit: LineEdit
var btn_load_start: Button
var btn_resume: Button
var dialog_decision: ConfirmationDialog
var dialog_info: AcceptDialog
var dialog_over: AcceptDialog
var refresh_queued := false
var decision_shown := false

# Ce que le joueur est en train de choisir dans le formulaire "Nouveau film".
var form_script := -1
var form_director := -1
var form_actors := []
var form_prod := 1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = _make_theme()
	_build_layout()
	_build_dialogs()
	_build_start_screen()
	auto_timer = Timer.new()
	auto_timer.wait_time = 1.0
	auto_timer.timeout.connect(_on_auto_tick)
	add_child(auto_timer)
	Game.changed.connect(_queue_refresh)
	Game.logged.connect(_on_logged)
	Game.decision_needed.connect(_on_decision)
	Game.game_over.connect(_on_game_over)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		if not start_screen.visible and Game.started:
			_on_next_week()
			get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# Construction de l'écran
# ---------------------------------------------------------------------------

func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 15
	var panel := StyleBoxFlat.new()
	panel.bg_color = PANEL_BG
	panel.set_corner_radius_all(8)
	panel.set_content_margin_all(10)
	t.set_stylebox("panel", "PanelContainer", panel)
	var btn := StyleBoxFlat.new()
	btn.bg_color = Color("2d3343")
	btn.set_corner_radius_all(6)
	btn.content_margin_left = 12
	btn.content_margin_right = 12
	btn.content_margin_top = 6
	btn.content_margin_bottom = 6
	var hover := btn.duplicate()
	hover.bg_color = Color("3c4459")
	var pressed := btn.duplicate()
	pressed.bg_color = Color("8a6d1c")
	var disabled := btn.duplicate()
	disabled.bg_color = Color("22262f")
	t.set_stylebox("normal", "Button", btn)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_stylebox("normal", "OptionButton", btn)
	t.set_stylebox("hover", "OptionButton", hover)
	t.set_stylebox("pressed", "OptionButton", pressed)
	t.set_color("font_disabled_color", "Button", Color("5c6170"))
	t.set_constant("h_separation", "GridContainer", 18)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color("2a2f3c")
	bar_bg.set_corner_radius_all(4)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = GOLD
	bar_fill.set_corner_radius_all(4)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fill)
	t.set_constant("v_separation", "GridContainer", 6)
	return t


func _build_layout() -> void:
	var bg := ColorRect.new()
	bg.color = Color("14161c")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	# Barre du haut
	var top_panel := PanelContainer.new()
	root.add_child(top_panel)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	top_panel.add_child(top)
	var title := Label.new()
	title.text = "MOVIE MANAGER 2027"
	title.add_theme_color_override("font_color", GOLD)
	title.add_theme_font_size_override("font_size", 20)
	top.add_child(title)
	lbl_date = _l(top, "")
	lbl_money = _l(top, "")
	lbl_rep = _l(top, "")
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	speed_opt = OptionButton.new()
	speed_opt.focus_mode = Control.FOCUS_NONE
	speed_opt.add_item("Lent", 0)
	speed_opt.add_item("Normal", 1)
	speed_opt.add_item("Rapide", 2)
	speed_opt.select(1)
	speed_opt.item_selected.connect(func(_i): _update_speed())
	top.add_child(speed_opt)
	btn_auto = _b(top, "Auto", _on_auto_toggled)
	btn_auto.toggle_mode = true
	btn_next = _b(top, "Semaine suivante ▶", _on_next_week)
	btn_next.tooltip_text = "Raccourci : touche Espace"
	_b(top, "Sauver", _on_save)
	_b(top, "Menu", _show_start_screen)

	# Partie centrale : les onglets à gauche, le journal à droite
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(split)
	tabs = TabContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(tabs)
	for i in TAB_NAMES.size():
		var sc := ScrollContainer.new()
		sc.name = "Onglet%d" % i
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var m := MarginContainer.new()
		m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for side in ["left", "right", "top", "bottom"]:
			m.add_theme_constant_override("margin_" + side, 14)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 8)
		m.add_child(v)
		sc.add_child(m)
		tabs.add_child(sc)
		tabs.set_tab_title(i, TAB_NAMES[i])
		pages.append(v)
	tabs.tab_changed.connect(func(_i): _queue_refresh())

	var log_panel := PanelContainer.new()
	log_panel.custom_minimum_size.x = 300
	split.add_child(log_panel)
	var log_v := VBoxContainer.new()
	log_panel.add_child(log_v)
	_h(log_v, "Journal du studio", 17)
	log_box = RichTextLabel.new()
	log_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_box.scroll_following = true
	log_box.selection_enabled = true
	log_box.add_theme_font_size_override("normal_font_size", 13)
	log_v.add_child(log_box)


func _build_dialogs() -> void:
	dialog_decision = ConfirmationDialog.new()
	dialog_decision.title = "Décision à prendre"
	dialog_decision.dialog_autowrap = true
	dialog_decision.min_size = Vector2i(520, 180)
	dialog_decision.confirmed.connect(func(): _resolve_decision(true))
	dialog_decision.canceled.connect(func(): _resolve_decision(false))
	add_child(dialog_decision)

	dialog_info = AcceptDialog.new()
	dialog_info.title = "Information"
	dialog_info.dialog_autowrap = true
	dialog_info.min_size = Vector2i(420, 140)
	add_child(dialog_info)

	dialog_over = AcceptDialog.new()
	dialog_over.title = "Faillite !"
	dialog_over.dialog_autowrap = true
	dialog_over.min_size = Vector2i(480, 180)
	dialog_over.ok_button_text = "Retour au menu"
	dialog_over.confirmed.connect(_show_start_screen)
	dialog_over.canceled.connect(_show_start_screen)
	add_child(dialog_over)


func _build_start_screen() -> void:
	start_screen = ColorRect.new()
	(start_screen as ColorRect).color = Color("0d0f14")
	start_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(start_screen)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	start_screen.add_child(center)
	var v := VBoxContainer.new()
	v.custom_minimum_size.x = 440
	v.add_theme_constant_override("separation", 14)
	center.add_child(v)
	var t := _h(v, "MOVIE MANAGER 2027", 46)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := _l(v, "Dirigez votre propre studio de cinéma : scénarios, stars, tournages et box-office.", MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_l(v, "Nom de votre studio :")
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Ex : Studio Lumière d'Or"
	name_edit.max_length = 32
	name_edit.text_submitted.connect(func(_t): _on_new_game())
	v.add_child(name_edit)
	_b(v, "Nouvelle partie", _on_new_game)
	btn_resume = _b(v, "Reprendre la partie en cours", _hide_start_screen)
	btn_load_start = _b(v, "Charger la sauvegarde", _on_load)
	_b(v, "Quitter le jeu", func(): get_tree().quit())
	_update_start_buttons()


# ---------------------------------------------------------------------------
# Petites fonctions pour créer des éléments d'interface
# ---------------------------------------------------------------------------

func _h(parent: Node, text: String, size := 20) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", GOLD)
	parent.add_child(l)
	return l


func _l(parent: Node, text: String, color = null) -> Label:
	var l := Label.new()
	l.text = text
	if color != null:
		l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


func _wrap(parent: Node, text: String, color = null) -> Label:
	var l := _l(parent, text, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _b(parent: Node, text: String, cb: Callable, disabled := false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = disabled
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _grid(parent: Node, headers: Array) -> GridContainer:
	var g := GridContainer.new()
	g.columns = headers.size()
	parent.add_child(g)
	if headers.any(func(h): return h != ""):
		for h in headers:
			_l(g, h, MUTED)
	return g


func _bar(parent: Node, value: float, max_value := 100.0, width := 110) -> ProgressBar:
	var b := ProgressBar.new()
	b.max_value = max_value
	b.value = value
	b.show_percentage = false
	b.custom_minimum_size = Vector2(width, 14)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(b)
	return b


func _row(parent: Node) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 10)
	parent.add_child(r)
	return r


func _panel(parent: Node) -> VBoxContainer:
	var p := PanelContainer.new()
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	return v


func _space(parent: Node, h := 10) -> void:
	var c := Control.new()
	c.custom_minimum_size.y = h
	parent.add_child(c)


func _value_bar(parent: Node, value: int) -> void:
	var r := HBoxContainer.new()
	parent.add_child(r)
	_bar(r, value, 100.0, 70)
	_l(r, str(value))


func _money_label(parent: Node, v: float) -> Label:
	return _l(parent, Game.fmt_money(v), GOOD if v >= 0 else BAD)


func _info(text: String) -> void:
	if text == "":
		return
	dialog_info.dialog_text = text
	dialog_info.popup_centered()


# ---------------------------------------------------------------------------
# Mise à jour de l'écran
# ---------------------------------------------------------------------------

func _queue_refresh() -> void:
	if not refresh_queued:
		refresh_queued = true
		call_deferred("_refresh")


func _refresh() -> void:
	refresh_queued = false
	if not Game.started:
		return
	lbl_date.text = Game.date_text()
	lbl_money.text = "Trésorerie : " + Game.fmt_money(Game.money)
	lbl_money.add_theme_color_override("font_color", GOOD if Game.money >= 0 else BAD)
	lbl_rep.text = "Réputation : %d/100" % int(Game.reputation)
	btn_next.disabled = Game.is_over or Game.pending_event != null
	var i := tabs.current_tab
	var page: VBoxContainer = pages[i]
	for c in page.get_children():
		page.remove_child(c)
		c.queue_free()
	match i:
		Tab.DASHBOARD: _build_dashboard(page)
		Tab.SCRIPTS: _build_scripts(page)
		Tab.TALENTS: _build_talents(page)
		Tab.PRODUCTIONS: _build_productions(page)
		Tab.BOX_OFFICE: _build_box_office(page)
		Tab.STUDIO: _build_studio(page)
		Tab.RIVALS: _build_rivals(page)
		Tab.HELP: _build_help(page)


func _go_to(tab: int) -> void:
	tabs.current_tab = tab
	_queue_refresh()


# --- Tableau de bord --------------------------------------------------------

func _build_dashboard(page: VBoxContainer) -> void:
	_h(page, "Studio « %s »" % Game.studio_name, 26)
	_l(page, Game.date_text() + "   ·   " + Game.season_name(), MUTED)

	if Game.negative_weeks > 0:
		_wrap(page, "Attention : trésorerie dans le rouge depuis %d semaine(s). Faillite au bout de %d ! Sortez un film ou empruntez (onglet Studio)." % [Game.negative_weeks, Game.BANKRUPTCY_WEEKS], BAD)

	# 1. Une seule chose à faire, bien visible, avec un bouton qui y mène.
	var step := _next_step()
	var card := _panel(page)
	_l(card, "PROCHAINE ÉTAPE", MUTED)
	var t := _wrap(card, step["text"])
	t.add_theme_font_size_override("font_size", 19)
	var action: Button = null
	if step.has("tab"):
		var target: int = step["tab"]
		action = _b(card, step["button"], func(): _go_to(target))
	elif step.has("next"):
		action = _b(card, step["button"], _on_next_week, Game.is_over)
	if action != null:
		action.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		action.custom_minimum_size.x = 220

	# 2. Les trois chiffres importants.
	_space(page, 4)
	var tiles := HBoxContainer.new()
	tiles.add_theme_constant_override("separation", 12)
	page.add_child(tiles)
	_tile(tiles, "Trésorerie", Game.fmt_money(Game.money), GOOD if Game.money >= 0 else BAD)
	_tile(tiles, "Réputation", "%d / 100" % int(Game.reputation), GOLD)
	_tile(tiles, "Classement", "%de sur %d" % [Game.player_rank(), Game.rivals.size() + 1], GOLD)

	# 3. Vos films, une ligne chacun.
	_space(page, 4)
	_h(page, "Vos films", 18)
	var current := Game.projects.filter(func(p): return p["phase"] != "finished")
	if current.is_empty():
		_l(page, "Aucun film pour l'instant.", MUTED)
	for p in current:
		var r := _row(page)
		_l(r, p["title"])
		var status := Game.phase_name(p)
		var color := MUTED
		if p["phase"] in ["preprod", "shooting", "postprod"]:
			status += ", encore %d sem." % p["weeks_left"]
		elif p["phase"] == "in_theaters":
			status += ", %s cette semaine" % Game.fmt_money(p["last_gross"])
		else:
			color = GOLD
		_l(r, "·  " + status, color)


func _tile(parent: Node, title: String, value: String, color: Color) -> void:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(p)
	var v := VBoxContainer.new()
	p.add_child(v)
	_l(v, title, MUTED)
	var l := _l(v, value, color)
	l.add_theme_font_size_override("font_size", 26)


# Choisit la chose la plus utile à faire maintenant.
func _next_step() -> Dictionary:
	if Game.pending_event != null:
		return {"text": "Une décision vous attend sur un tournage.", "button": "Voir la décision", "next": true}
	var ready_films := Game.projects.filter(func(p): return p["phase"] == "ready")
	if ready_films.size() > 0:
		return {"text": "« %s » est terminé ! Choisissez sa sortie au cinéma." % ready_films[0]["title"],
			"button": "Sortir le film  →", "tab": Tab.PRODUCTIONS}
	if Game.free_stages() > 0:
		if Game.owned_scripts.size() > 0:
			return {"text": "Vous avez un scénario et un plateau libre : lancez un film !",
				"button": "Créer un film  →", "tab": Tab.PRODUCTIONS}
		return {"text": "Achetez un scénario pour préparer votre prochain film.",
			"button": "Voir les scénarios  →", "tab": Tab.SCRIPTS}
	if Game.money > 15000000.0 and Game.upgrades["plateaux"] < 2:
		return {"text": "Vous avez de l'argent : un 2e plateau permet de tourner deux films en même temps.",
			"button": "Améliorer le studio  →", "tab": Tab.STUDIO}
	return {"text": "Vos films avancent. Faites passer le temps.", "button": "Semaine suivante ▶", "next": true}


# --- Scénarios --------------------------------------------------------------

func _build_scripts(page: VBoxContainer) -> void:
	_h(page, "Scénarios à vendre", 22)
	var hot := D.GENRES.filter(func(g): return Game.trends[g] >= 1.1)
	var cold := D.GENRES.filter(func(g): return Game.trends[g] < 0.9)
	_wrap(page, "À la mode en ce moment : %s" % (", ".join(hot) if hot.size() > 0 else "rien de spécial"), GOOD)
	if cold.size() > 0:
		_wrap(page, "Le public s'en lasse : %s" % ", ".join(cold), BAD)
	_wrap(page, "Nouveaux scénarios dans %d semaine(s). La qualité du scénario compte beaucoup dans la qualité du film. Le nombre de rôles = le nombre d'acteurs à engager." % Game.weeks_until_new_scripts(), MUTED)
	if Game.scripts_market.is_empty():
		_l(page, "Plus aucun scénario à vendre pour l'instant.")
	else:
		var g := _grid(page, ["Titre", "Genre", "Envie du public", "Qualité", "Rôles", "Prix", ""])
		for s in Game.scripts_market:
			_l(g, s["title"])
			_l(g, s["genre"])
			_l(g, Game.trend_label(s["genre"]), MUTED)
			_value_bar(g, int(s["quality"]))
			_l(g, str(s["roles"]))
			_l(g, Game.fmt_money(s["cost"]))
			var id = s["id"]
			_b(g, "Acheter", func(): _info(Game.buy_script(id)), Game.money < s["cost"])

	_space(page)
	_h(page, "Vos scénarios", 22)
	if Game.owned_scripts.is_empty():
		_l(page, "Vous n'avez aucun scénario. Achetez-en un ci-dessus.", MUTED)
	else:
		var g2 := _grid(page, ["Titre", "Genre", "Qualité", "Rôles", ""])
		for s in Game.owned_scripts:
			_l(g2, s["title"])
			_l(g2, s["genre"])
			_value_bar(g2, int(s["quality"]))
			_l(g2, str(s["roles"]))
			var id = s["id"]
			_b(g2, "Produire ce film", func():
				form_script = id
				_go_to(Tab.PRODUCTIONS))


# --- Talents ----------------------------------------------------------------

func _build_talents(page: VBoxContainer) -> void:
	_wrap(page, "Le talent rend le film meilleur. La célébrité attire le public. Un talent dont le genre favori correspond au film le rend encore meilleur. Plus un talent est célèbre, plus son cachet est élevé.", MUTED)
	for kind in ["director", "actor"]:
		_h(page, "Réalisateurs" if kind == "director" else "Acteurs et actrices", 22)
		var list := Game.talents.filter(func(t): return t["kind"] == kind and not t["retired"])
		list.sort_custom(func(a, b): return a["fame"] > b["fame"])
		var g := _grid(page, ["Nom", "Âge", "Genre favori", "Talent", "Célébrité", "Cachet", "Films", "Statut"])
		for t in list:
			_l(g, t["name"])
			_l(g, str(t["age"]))
			_l(g, t["genre"])
			_value_bar(g, int(t["skill"]))
			_value_bar(g, int(t["fame"]))
			_l(g, Game.fmt_money(Game.salary(t)))
			_l(g, str(t["films"]))
			_l(g, Game.talent_status(t), GOOD if Game.is_available(t) else MUTED)
		_space(page)


# --- Productions : le cœur du jeu ------------------------------------------

func _build_productions(page: VBoxContainer) -> void:
	_build_new_film_form(page)

	var ready_films := Game.projects.filter(func(p): return p["phase"] == "ready")
	if ready_films.size() > 0:
		_space(page)
		_h(page, "Films prêts à sortir", 22)
		for p in ready_films:
			_build_ready_card(page, p)

	var active := Game.active_productions()
	_space(page)
	_h(page, "Films en production", 22)
	if active.is_empty():
		_l(page, "Aucun film en production.", MUTED)
	for p in active:
		var v := _panel(page)
		var r := _row(v)
		var t := _l(r, "%s  (%s)" % [p["title"], p["genre"]])
		t.add_theme_font_size_override("font_size", 17)
		_l(r, "  " + Game.phase_name(p), GOLD)
		var r2 := _row(v)
		var total := maxi(1, int(p["phase_total"]))
		_bar(r2, total - int(p["weeks_left"]), total, 260)
		_l(r2, "encore %d semaine(s)" % p["weeks_left"], MUTED)
		_wrap(v, "Réalisation : %s   ·   Avec : %s" % [p["director_name"], ", ".join(p["actor_names"])], MUTED)
		_l(v, "%s   ·   Dépensé jusqu'ici : %s" % [D.PROD_LEVELS[int(p["prod_level"])]["name"], Game.fmt_money(p["cost"])], MUTED)


func _build_new_film_form(page: VBoxContainer) -> void:
	_h(page, "Lancer un nouveau film", 22)
	_l(page, "Plateaux libres : %d / %d" % [maxi(0, Game.free_stages()), Game.upgrades["plateaux"]], MUTED)
	if Game.owned_scripts.is_empty():
		_wrap(page, "Il vous faut d'abord un scénario. Allez dans l'onglet Scénarios pour en acheter un.")
		_b(page, "Aller aux scénarios", func(): _go_to(Tab.SCRIPTS))
		return
	if Game.free_stages() <= 0:
		_wrap(page, "Tous vos plateaux sont occupés. Attendez la fin d'un tournage, ou achetez un plateau dans l'onglet Studio.")
		return

	var box := _panel(page)
	var g := GridContainer.new()
	g.columns = 2
	box.add_child(g)

	# 1. Scénario
	if Game.get_owned_script(form_script).is_empty():
		form_script = Game.owned_scripts[0]["id"]
	var script := Game.get_owned_script(form_script)
	_l(g, "1. Scénario")
	var opt_script := OptionButton.new()
	for s in Game.owned_scripts:
		opt_script.add_item("%s — %s, qualité %d, %d rôle(s)" % [s["title"], s["genre"], s["quality"], s["roles"]], int(s["id"]))
	opt_script.select(opt_script.get_item_index(form_script))
	opt_script.item_selected.connect(func(idx):
		form_script = opt_script.get_item_id(idx)
		form_actors = []
		_queue_refresh())
	g.add_child(opt_script)

	# 2. Réalisateur
	var directors := Game.available_talents("director")
	_l(g, "2. Réalisateur")
	if directors.is_empty():
		_l(g, "Aucun réalisateur disponible : attendez quelques semaines.", BAD)
		return
	if not directors.any(func(t): return int(t["id"]) == form_director):
		form_director = _default_talent(directors, Game.money * 0.3, [])
	var opt_dir := OptionButton.new()
	for t in directors:
		opt_dir.add_item(_talent_choice_text(t, script["genre"]), int(t["id"]))
	opt_dir.select(opt_dir.get_item_index(form_director))
	opt_dir.item_selected.connect(func(idx):
		form_director = opt_dir.get_item_id(idx)
		_queue_refresh())
	g.add_child(opt_dir)

	# 3. Acteurs (un menu par rôle)
	var actors := Game.available_talents("actor")
	var roles := int(script["roles"])
	if actors.size() < roles:
		_l(g, "3. Acteurs")
		_l(g, "Pas assez d'acteurs disponibles : attendez quelques semaines.", BAD)
		return
	form_actors.resize(roles)
	var used := []
	for i in roles:
		var ok := false
		for t in actors:
			if form_actors[i] != null and int(t["id"]) == int(form_actors[i]) and not used.has(int(t["id"])):
				ok = true
		if not ok:
			form_actors[i] = _default_talent(actors, Game.money * 0.2, used + form_actors)
		used.append(int(form_actors[i]))
	for i in roles:
		_l(g, "3. Rôle principal" if i == 0 else "    Rôle %d" % (i + 1))
		var opt_actor := OptionButton.new()
		for t in actors:
			opt_actor.add_item(_talent_choice_text(t, script["genre"]), int(t["id"]))
		opt_actor.select(opt_actor.get_item_index(int(form_actors[i])))
		var role := i
		opt_actor.item_selected.connect(func(idx):
			var new_id := opt_actor.get_item_id(idx)
			# Si cet acteur avait déjà un autre rôle, on échange les deux.
			var other := form_actors.find(new_id)
			if other >= 0:
				form_actors[other] = form_actors[role]
			form_actors[role] = new_id
			_queue_refresh())
		g.add_child(opt_actor)

	# 4. Budget
	_l(g, "4. Moyens de production")
	var opt_prod := OptionButton.new()
	for i in D.PROD_LEVELS.size():
		var lv: Dictionary = D.PROD_LEVELS[i]
		opt_prod.add_item("%s — %s / semaine de tournage, +%d qualité" % [lv["name"], Game.fmt_money(lv["weekly"]), lv["bonus"]], i)
	opt_prod.select(form_prod)
	opt_prod.item_selected.connect(func(idx):
		form_prod = idx
		_queue_refresh())
	g.add_child(opt_prod)

	# Résumé et bouton
	var director := Game.get_talent(form_director)
	var actor_list := []
	for aid in form_actors:
		actor_list.append(Game.get_talent(aid))
	var est := Game.estimate(script, director, actor_list, form_prod)
	_space(box, 4)
	_l(box, "Cachets à payer tout de suite : %s   ·   Tournage : %s (%d semaines)   ·   Total estimé : %s" % [
		Game.fmt_money(est["salaries"]), Game.fmt_money(est["shooting"]), est["shoot_weeks"], Game.fmt_money(est["total"])])
	_l(box, "Durée totale avant la sortie : environ %d semaines. La publicité se choisit à la sortie." % est["weeks"], MUTED)
	var r := _row(box)
	_b(r, "Lancer la production !", _on_start_production, Game.money < est["salaries"])
	if Game.money < est["salaries"]:
		_l(r, "Pas assez d'argent pour les cachets.", BAD)


# Choix par défaut : le meilleur talent qu'on peut se payer (sinon le moins cher).
func _default_talent(list: Array, budget: float, exclude: Array) -> int:
	var best = null
	var cheapest = null
	for t in list:
		if exclude.has(int(t["id"])):
			continue
		if cheapest == null or Game.salary(t) < Game.salary(cheapest):
			cheapest = t
		if Game.salary(t) <= budget and (best == null or t["skill"] > best["skill"]):
			best = t
	if best == null:
		best = cheapest
	return int(best["id"]) if best != null else -1


func _talent_choice_text(t: Dictionary, genre: String) -> String:
	var fav := "  ★ genre favori" if t["genre"] == genre else ""
	return "%s — talent %d, célébrité %d, cachet %s%s" % [t["name"], t["skill"], t["fame"], Game.fmt_money(Game.salary(t)), fav]


func _on_start_production() -> void:
	var err := Game.start_production(form_script, form_director, form_actors.duplicate(), form_prod)
	if err != "":
		_info(err)
	else:
		form_actors = []
		form_script = -1


func _build_ready_card(page: VBoxContainer, p: Dictionary) -> void:
	var v := _panel(page)
	var t := _l(v, "%s  (%s)" % [p["title"], p["genre"]])
	t.add_theme_font_size_override("font_size", 18)
	_l(v, "Projections test : " + p["screening"])
	_l(v, "Coût jusqu'ici : %s" % Game.fmt_money(p["cost"]), MUTED)
	var same := 0
	for f in Game.films_in_theaters():
		if f["genre"] == p["genre"]:
			same += 1
	_l(v, "Envie du public pour ce genre : %s   ·   %s" % [Game.trend_label(p["genre"]), Game.season_name()], MUTED)
	_l(v, "Films du même genre déjà au cinéma : %d" % same, BAD if same > 0 else MUTED)
	var upcoming := Game.upcoming_rival_releases(4)
	if upcoming.size() > 0:
		_wrap(v, "Sorties rivales bientôt : " + " ; ".join(upcoming), MUTED)
	_wrap(v, "Choisissez la publicité. Plus de pub = plus de monde la 1re semaine. Vous pouvez aussi attendre une meilleure période (été, fêtes).", MUTED)
	var r := _row(v)
	for i in D.MKT_LEVELS.size():
		var lv: Dictionary = D.MKT_LEVELS[i]
		var label := "Sortir : %s" % lv["name"]
		if lv["cost"] > 0:
			label += " (%s)" % Game.fmt_money(lv["cost"])
		var id = p["id"]
		var level := i
		_b(r, label, func(): _info(Game.release_film(id, level)), Game.money < lv["cost"])


# --- Box-office -------------------------------------------------------------

func _build_box_office(page: VBoxContainer) -> void:
	_h(page, "Box-office de la semaine", 22)
	var films := Game.films_in_theaters()
	films.sort_custom(func(a, b): return a["last_gross"] > b["last_gross"])
	if films.is_empty():
		_l(page, "Aucun film à l'affiche.", MUTED)
	else:
		var g := _grid(page, ["#", "Titre", "Studio", "Genre", "Semaine", "Recette semaine", "Total", "Critiques"])
		var rank := 1
		for f in films:
			var is_mine: bool = not f.has("rival_id")
			var c = GOLD if is_mine else null
			_l(g, str(rank), c)
			_l(g, f["title"], c)
			_l(g, Game.studio_name if is_mine else f["studio"], c)
			_l(g, f["genre"], c)
			_l(g, str(f["weeks_in"]), c)
			_l(g, Game.fmt_money(f["last_gross"]) if f["weeks_in"] > 0 else "sort cette semaine", c)
			_l(g, Game.fmt_money(f["gross"]), c)
			_l(g, "%d/100" % f["critic"], c)
			rank += 1

	_space(page)
	_h(page, "Historique de vos films", 22)
	var mine := Game.released_films()
	if mine.is_empty():
		_l(page, "Vous n'avez encore sorti aucun film.", MUTED)
		return
	var g2 := _grid(page, ["Titre", "Genre", "Sortie", "Critiques", "Box-office", "Coût", "Gains du studio", "Bénéfice", "Statut"])
	for i in range(mine.size() - 1, -1, -1):
		var p: Dictionary = mine[i]
		_l(g2, p["title"])
		_l(g2, p["genre"])
		_l(g2, "S%d %d" % [int(p["release_week"]) % 52 + 1, Game.START_YEAR + floori(int(p["release_week"]) / 52.0)])
		_l(g2, "%d/100" % p["critic"])
		_l(g2, Game.fmt_money(p["gross"]))
		_l(g2, Game.fmt_money(p["cost"]))
		_l(g2, Game.fmt_money(p["revenue"]))
		_money_label(g2, float(p["revenue"]) - float(p["cost"]))
		_l(g2, Game.phase_name(p), MUTED)


# --- Studio -----------------------------------------------------------------

func _build_studio(page: VBoxContainer) -> void:
	_h(page, "Améliorer le studio", 22)
	_wrap(page, "Chaque amélioration coûte une fois, puis augmente un peu les frais fixes (actuellement %s par semaine)." % Game.fmt_money(Game.weekly_overhead()), MUTED)
	for key in D.UPGRADES:
		var u: Dictionary = D.UPGRADES[key]
		var v := _panel(page)
		var r := _row(v)
		var t := _l(r, u["name"])
		t.add_theme_font_size_override("font_size", 17)
		_l(r, "Niveau %d / %d" % [Game.upgrades[key], u["max"]], GOLD)
		_wrap(v, u["desc"], MUTED)
		var cost := Game.upgrade_cost(key)
		if cost < 0:
			_l(v, "Niveau maximum atteint.", GOOD)
		else:
			var k: String = key
			_b(v, "Améliorer (%s)" % Game.fmt_money(cost), func(): _info(Game.buy_upgrade(k)), Game.money < cost)

	_space(page)
	_h(page, "Banque", 22)
	_wrap(page, "Emprunter aide à passer un moment difficile, mais coûte %.1f %% d'intérêts par semaine. Maximum : %s." % [Game.LOAN_WEEKLY_RATE * 100.0, Game.fmt_money(Game.MAX_LOAN)], MUTED)
	_l(page, "Prêt actuel : %s   ·   Intérêts : %s / semaine" % [Game.fmt_money(Game.loan), Game.fmt_money(Game.loan * Game.LOAN_WEEKLY_RATE)])
	var r2 := _row(page)
	_b(r2, "Emprunter 2 M$", func(): _info(Game.take_loan(2000000.0)), Game.loan >= Game.MAX_LOAN)
	_b(r2, "Emprunter 5 M$", func(): _info(Game.take_loan(5000000.0)), Game.loan >= Game.MAX_LOAN)
	_b(r2, "Rembourser 2 M$", func(): _info(Game.repay_loan(2000000.0)), Game.loan <= 0)
	_b(r2, "Tout rembourser", func(): _info(Game.repay_loan(Game.loan)), Game.loan <= 0 or Game.money < Game.loan)

	_space(page)
	_h(page, "Palmarès des Bobines d'Or", 22)
	if Game.awards.is_empty():
		_l(page, "Le premier prix sera remis à la fin de l'année %d." % Game.year(), MUTED)
	for a in Game.awards:
		_l(page, "%d : « %s » (%s), critiques %d/100" % [a["year"], a["title"], a["studio"], a["critic"]],
			GOLD if a["studio"] == Game.studio_name else null)


# --- Concurrents ------------------------------------------------------------

func _build_rivals(page: VBoxContainer) -> void:
	_h(page, "Classement des studios", 22)
	_wrap(page, "Objectif : devenir le studio n°1 en recettes totales. Surveillez les prochaines sorties de vos rivaux pour éviter de sortir un film du même genre la même semaine.", MUTED)
	var g := _grid(page, ["Rang", "Studio", "Réputation", "Films sortis", "Recettes totales", "Prochaine sortie"])
	var rank := 1
	for s in Game.ranking():
		var c = GOLD if s["player"] else null
		_l(g, str(rank), c)
		_l(g, s["name"], c)
		_l(g, "%d/100" % int(s["reputation"]), c)
		_l(g, str(s["films"]), c)
		_l(g, Game.fmt_money(s["total_gross"]), c)
		_l(g, s["next"], c)
		rank += 1


# --- Aide -------------------------------------------------------------------

func _build_help(page: VBoxContainer) -> void:
	_h(page, "Comment jouer", 22)
	var lines := [
		"Vous dirigez un studio de cinéma. Le but : faire de bons films qui rapportent de l'argent, et devenir le studio n°1.",
		"1. Achetez un scénario (onglet Scénarios). Regardez sa qualité et si son genre est à la mode.",
		"2. Lancez la production (onglet Productions) : choisissez un réalisateur, des acteurs et les moyens de production. Les cachets sont payés tout de suite, le tournage chaque semaine.",
		"3. Le film passe par 3 étapes : préproduction, tournage, post-production. Pendant le tournage, des imprévus arrivent : parfois vous devrez décider.",
		"4. Quand le film est prêt, choisissez la publicité et sortez-le au cinéma. La pub, la célébrité des acteurs et votre réputation attirent le public la 1re semaine. Ensuite, c'est la qualité du film qui le fait durer.",
		"5. Le studio touche 55 % des recettes. Après le cinéma, le film rapporte encore un peu (TV, streaming).",
		"Astuces : l'été et les fêtes de fin d'année attirent plus de monde. Évitez de sortir un film quand un rival sort le même genre. Un talent dont le genre favori correspond au film le rend meilleur.",
		"Attention : le studio a des frais fixes chaque semaine. Si votre trésorerie reste négative 12 semaines, c'est la faillite.",
		"Chaque fin d'année, la Bobine d'Or récompense le meilleur film. La partie est sauvegardée automatiquement toutes les 4 semaines.",
		"Raccourci : la touche Espace fait passer une semaine.",
	]
	for line in lines:
		_wrap(page, line)


# ---------------------------------------------------------------------------
# Actions des boutons
# ---------------------------------------------------------------------------

func _on_next_week() -> void:
	if Game.pending_event != null:
		_on_decision(Game.pending_event)
		return
	Game.advance_week()


func _on_auto_toggled() -> void:
	if btn_auto.button_pressed:
		_update_speed()
		auto_timer.start()
		btn_auto.text = "Pause"
	else:
		auto_timer.stop()
		btn_auto.text = "Auto"


func _stop_auto() -> void:
	btn_auto.button_pressed = false
	_on_auto_toggled()


func _update_speed() -> void:
	auto_timer.wait_time = [1.6, 0.8, 0.3][speed_opt.selected]


func _on_auto_tick() -> void:
	if Game.is_over or Game.pending_event != null:
		_stop_auto()
		return
	var had_ready := Game.projects.any(func(p): return p["phase"] == "ready")
	Game.advance_week()
	# On met en pause quand un film vient d'être terminé, pour que le joueur choisisse sa sortie.
	if not had_ready and Game.projects.any(func(p): return p["phase"] == "ready"):
		_stop_auto()


func _on_save() -> void:
	_info("Partie sauvegardée !" if Game.save_game() else "Impossible de sauvegarder.")


func _on_load() -> void:
	if Game.load_game():
		_reload_log()
		_hide_start_screen()
	else:
		_info("Impossible de charger la sauvegarde.")


func _on_new_game() -> void:
	Game.new_game(name_edit.text)
	form_script = -1
	form_director = -1
	form_actors = []
	_reload_log()
	tabs.current_tab = Tab.DASHBOARD
	_hide_start_screen()


func _show_start_screen() -> void:
	_stop_auto()
	_update_start_buttons()
	start_screen.visible = true


func _hide_start_screen() -> void:
	start_screen.visible = false
	_queue_refresh()


func _update_start_buttons() -> void:
	btn_load_start.disabled = not Game.has_save()
	btn_resume.visible = Game.started and not Game.is_over


func _reload_log() -> void:
	log_box.clear()
	for line in Game.log_lines:
		log_box.append_text(_color_log(line) + "\n")


func _on_logged(line: String) -> void:
	log_box.append_text(_color_log(line) + "\n")


func _color_log(line: String) -> String:
	var safe := line.replace("[", "[lb]")
	if line.contains("ATTENTION") or line.contains("Faillite") or line.contains("échec"):
		return "[color=#ff6b6b]%s[/color]" % safe
	if line.contains("BOBINE") or line.contains("succès") or line.contains("terminé"):
		return "[color=#f5c542]%s[/color]" % safe
	return safe


func _on_decision(ev: Dictionary) -> void:
	_stop_auto()
	dialog_decision.dialog_text = ev["text"]
	dialog_decision.ok_button_text = ev["accept"]
	dialog_decision.cancel_button_text = ev["refuse"]
	decision_shown = true
	dialog_decision.popup_centered()
	_queue_refresh()


func _resolve_decision(accept: bool) -> void:
	if not decision_shown:
		return
	decision_shown = false
	Game.resolve_event(accept)


func _on_game_over(reason: String) -> void:
	_stop_auto()
	dialog_over.dialog_text = reason + "\n\nFilms sortis : %d · Recettes totales : %s" % [Game.released_films().size(), Game.fmt_money(Game.total_gross)]
	dialog_over.popup_centered()
