extends CanvasLayer
signal pause_requested
signal speed_requested(value: float)
signal plan_requested
signal retry_requested
signal ai_toggled(value: bool)
signal settings_requested(values: Dictionary)
signal model_requested(value: String)
signal save_requested
signal selection_changed(index: int)
signal paths_requested(value: bool)
signal export_requested
var status_label: Label
var timing_label: Label
var summary_label: Label
var people_text: RichTextLabel
var ai_text: RichTextLabel
var log_text: RichTextLabel
var picker: OptionButton
var model_input: LineEdit
var pause_button: Button
var ai_button: CheckButton
var cadence: OptionButton
var fps: OptionButton
var timeout_picker: OptionButton
var tabs: TabContainer
var guidance: TextEdit
var last_people := ""
var last_logs := ""
var memory_text: RichTextLabel
var growth_text: RichTextLabel
var task_label: Label
var resource_values: Dictionary = {}
var need_bars: Dictionary = {}
var need_values: Dictionary = {}
var skill_bars: Dictionary = {}
var skill_titles: Dictionary = {}
var skill_details: Dictionary = {}
var last_memory := ""
var last_growth := ""

func _label(parent: Node, text: String, font_size: int = 16) -> Label:
	var result := Label.new()
	result.text = text
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.add_theme_font_size_override("font_size", font_size)
	parent.add_child(result)
	return result

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var result := Button.new()
	result.text = text
	result.custom_minimum_size.y = 34
	result.pressed.connect(callback)
	parent.add_child(result)
	return result

func _text(parent: Node) -> RichTextLabel:
	var result := RichTextLabel.new()
	result.size_flags_vertical = Control.SIZE_EXPAND_FILL
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.selection_enabled = true
	result.add_theme_font_size_override("normal_font_size", 15)
	parent.add_child(result)
	return result

func _panel(parent: Node, rect: Rect2) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.position = rect.position
	panel.size = rect.size
	var style := StyleBoxFlat.new()
	style.bg_color = Color("172a23")
	style.border_color = Color("355244")
	style.set_border_width_all(1)
	style.shadow_color = Color(0, 0, 0, 0.25)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 3)
	style.set_corner_radius_all(10)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	return box

func build(config: Dictionary, people: Array) -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _make_theme()
	add_child(root)
	var top := _panel(root, Rect2(12, 10, 1256, 116))
	var row := HBoxContainer.new()
	top.add_child(row)
	var title := _label(row, "WIOSKA AI  /  OSADA", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", Color("e9d5a4"))
	pause_button = _button(row, "Pauza", func(): pause_requested.emit())
	var speed := OptionButton.new()
	for caption in ["0.5×", "1×", "2×"]:
		speed.add_item(caption)
	speed.select(1)
	speed.item_selected.connect(func(index: int): speed_requested.emit([0.5, 1.0, 2.0][index]))
	row.add_child(speed)
	_button(row, "Zaplanuj teraz", func(): plan_requested.emit())
	_button(row, "Połącz ponownie", func(): retry_requested.emit())
	_button(row, "Zapisz", func(): save_requested.emit())
	status_label = _label(top, "AI: uruchamianie…", 19)
	timing_label = _label(top, "Brak potwierdzonej decyzji AI", 14)
	var sidebar := _panel(root, Rect2(814, 138, 454, 568))
	var resources := HBoxContainer.new()
	resources.add_theme_constant_override("separation", 8)
	sidebar.add_child(resources)
	for item in [["food", "JEDZENIE", "e7bd77"], ["wood", "DREWNO", "9dcca7"], ["houses", "DOMY", "9ec4dd"]]:
		var card := _card(resources)
		_label(card, item[1], 11).add_theme_color_override("font_color", Color("acbeb1"))
		var value := _label(card, "0", 24)
		value.add_theme_color_override("font_color", Color(item[2]))
		resource_values[item[0]] = value
	summary_label = _label(sidebar, "", 12)
	summary_label.add_theme_color_override("font_color", Color("acbeb1"))
	picker = OptionButton.new()
	picker.custom_minimum_size.y = 36
	for person in people:
		picker.add_item("%s  •  %s" % [person["name"], person["job"]])
	picker.item_selected.connect(func(index: int): selection_changed.emit(index))
	sidebar.add_child(picker)
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.add_child(tabs)
	var residents_tab := VBoxContainer.new()
	residents_tab.name = "Postać"
	tabs.add_child(residents_tab)
	task_label = _label(residents_tab, "Czeka na plan", 17)
	task_label.add_theme_color_override("font_color", Color("e9d5a4"))
	var needs := HBoxContainer.new()
	needs.add_theme_constant_override("separation", 10)
	residents_tab.add_child(needs)
	for entry in [["hunger", "Sytość", "e7bd77"], ["rest", "Wypoczęcie", "9ec4dd"], ["warmth", "Ciepło", "e69c7b"]]:
		var box := VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		needs.add_child(box)
		need_values[entry[0]] = _label(box, entry[1], 12)
		need_bars[entry[0]] = _bar(box, Color(entry[2]), 9)
	people_text = _text(residents_tab)
	var memory_tab := VBoxContainer.new()
	memory_tab.name = "Pamięć"
	tabs.add_child(memory_tab)
	_label(memory_tab, "DOŚWIADCZENIA I WNIOSKI", 13).add_theme_color_override("font_color", Color("e9d5a4"))
	memory_text = _text(memory_tab)
	var growth_tab := VBoxContainer.new()
	growth_tab.name = "Rozwój"
	tabs.add_child(growth_tab)
	_label(growth_tab, "Praktyka rozwija umiejętności. Poziom skraca czas pracy przy zasobie lub budowie.", 13)
	for key in ["foraging", "woodcutting", "building"]:
		var card := _card(growth_tab)
		skill_titles[key] = _label(card, "", 15)
		skill_bars[key] = _bar(card, Color("d5b878"), 8)
		skill_details[key] = _label(card, "", 12)
	growth_text = _text(growth_tab)
	var ai_tab := VBoxContainer.new()
	ai_tab.name = "AI"
	tabs.add_child(ai_tab)
	ai_button = CheckButton.new()
	ai_button.text = "AI planuje nowe zadania"
	ai_button.button_pressed = bool(config["enabled"])
	ai_button.toggled.connect(func(value: bool): ai_toggled.emit(value))
	ai_tab.add_child(ai_button)
	ai_text = _text(ai_tab)
	var options_scroll := ScrollContainer.new()
	options_scroll.name = "Opcje"
	tabs.add_child(options_scroll)
	var options := VBoxContainer.new()
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options.add_theme_constant_override("separation", 8)
	options_scroll.add_child(options)
	_label(options, "Model lokalny", 18)
	model_input = LineEdit.new()
	model_input.text = str(config["model"])
	options.add_child(model_input)
	_button(options, "Użyj / pobierz wpisany model", func(): model_requested.emit(model_input.text.strip_edges()))
	_button(options, "Szybki model: qwen3:4b-instruct", func():
		model_input.text = "qwen3:4b-instruct"
		model_requested.emit(model_input.text))
	_label(options, "Model 4B wymaga pobrania przy pierwszym użyciu. Model 35B może obciążać komputer nawet przy rzadkich zapytaniach.", 14)
	_label(options, "Minimalna przerwa po odpowiedzi")
	cadence = OptionButton.new()
	for seconds in [10, 20, 30, 60, 120]:
		cadence.add_item("%d sekund" % seconds, seconds)
	select_id(cadence, int(config["cooldown"]))
	options.add_child(cadence)
	_label(options, "Limit klatek gry")
	fps = OptionButton.new()
	fps.add_item("30 FPS", 30)
	fps.add_item("60 FPS", 60)
	select_id(fps, int(config["fps"]))
	options.add_child(fps)
	_label(options, "Limit oczekiwania na decyzję")
	timeout_picker = OptionButton.new()
	timeout_picker.add_item("45 sekund", 45)
	timeout_picker.add_item("120 sekund", 120)
	select_id(timeout_picker, int(config["timeout"]))
	options.add_child(timeout_picker)
	var paths := CheckButton.new()
	paths.text = "Pokazuj trasę wybranej postaci"
	paths.button_pressed = true
	paths.toggled.connect(func(value: bool): paths_requested.emit(value))
	options.add_child(paths)
	_label(options, "Wskazówki dla AI")
	guidance = TextEdit.new()
	guidance.custom_minimum_size = Vector2(0, 90)
	guidance.text = str(config["guidance"])
	options.add_child(guidance)
	_button(options, "Zapisz ustawienia", func(): settings_requested.emit({"cooldown": cadence.get_selected_id(), "fps": fps.get_selected_id(), "timeout": timeout_picker.get_selected_id(), "guidance": guidance.text.left(1000)}))
	_button(options, "Eksportuj dziennik diagnostyczny", func(): export_requested.emit())
	var journal := VBoxContainer.new()
	journal.name = "Log"
	tabs.add_child(journal)
	log_text = _text(journal)

func select_id(option: OptionButton, id_value: int) -> void:
	for i in range(option.item_count):
		if option.get_item_id(i) == id_value:
			option.select(i)
			return

func refresh(sim: RefCounted, index: int, paused: bool, data: Dictionary) -> void:
	pause_button.text = "Wznów" if paused else "Pauza"
	status_label.text = str(data["headline"])
	status_label.add_theme_color_override("font_color", data["color"])
	timing_label.text = "%s  |  model %s  |  ostatni przyjęty plan: %s  |  %d FPS" % [sim.clock_text(), data["model"], data["last_plan"], Engine.get_frames_per_second()]
	resource_values["food"].text = str(sim.stock["food"])
	resource_values["wood"].text = str(sim.stock["wood"])
	resource_values["houses"].text = str(sim.houses)
	summary_label.text = "Dostarczono: jedzenie %d / drewno %d • Budowa %d/5" % [sim.delivered["food"], sim.delivered["wood"], sim.build_progress]
	picker.select(index)
	var p: Dictionary = sim.people[index]
	picker.add_theme_color_override("font_color", p["color"])
	task_label.text = str(p["task"])
	var need_names := {"hunger": "Sytość", "rest": "Wypoczęcie", "warmth": "Ciepło"}
	for key in need_bars:
		need_bars[key].value = float(p[key])
		need_values[key].text = "%s  %d" % [need_names[key], p[key]]
		need_values[key].add_theme_color_override("font_color", Color("ef9c87") if p[key] < 20 else Color("c8d5c9"))
	var lines: Array[String] = []
	lines.append("%s • %s\nUkończone zadania: %d" % [p["job"], p["trait"], p["jobs_done"]])
	lines.append("\nŁADUNEK I RZECZY\n%d jedzenia • %d drewna\nPrywatne jedzenie: %d\nPamiątka: %s\nSprzęt: %s" % [p["cargo_food"], p["cargo_wood"], p["inventory"]["food"], p["inventory"]["keepsake"], str(p["inventory"]["equipment"])])
	lines.append("\nDECYZJA AI\n" + str(p["reason"]))
	var pending: Array[String] = []
	for step in p["queue"]:
		pending.append(str(sim.ACTION_NAMES.get(step["action"], step["action"])))
	lines.append("\nDALEJ W PLANIE\n" + (" → ".join(pending) if not pending.is_empty() else "Nowy plan po zakończeniu zadania"))
	lines.append("\nPOZOSTALI MIESZKAŃCY")
	for resident in sim.people:
		if resident["name"] != p["name"]:
			lines.append("%s • %s" % [resident["name"], resident["task"]])
	var text := "\n".join(lines)
	if text != last_people:
		people_text.text = text
		last_people = text
	_refresh_memory_and_skills(sim, p)
	ai_text.text = "STATUS POŁĄCZENIA\n%s\n\nOstatnia odpowiedź: %.1f s\nZapytania: %d • błędy: %d\nPrzyjęte plany mieszkańców: %d\nOczekujących mieszkańców: %d\n\n%s\n\nAI wybiera do 3 kolejnych zadań. Trwający zbiór i dostawa nie są przerywane nową odpowiedzią.\n\nZielony status oznacza przyjęty plan; samo znalezienie modelu nie potwierdza poprawnych decyzji." % [data["detail"], data["latency"], data["requests"], data["errors"], data["accepted"], sim.idle_snapshot().size(), sim.last_save]
	var journal := "\n\n".join(sim.logs)
	if journal != last_logs:
		log_text.text = journal
		last_logs = journal


func _style(background: Color, border: Color, radius: int = 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

func _make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 15
	var normal := _style(Color("263e32"), Color("49634d"))
	var hover := _style(Color("365540"), Color("b7ba7d"))
	var pressed := _style(Color("162c23"), Color("d5b878"))
	var focus := _style(Color(0, 0, 0, 0), Color("e3c88c"))
	for type_name in ["Button", "OptionButton"]:
		theme.set_stylebox("normal", type_name, normal)
		theme.set_stylebox("hover", type_name, hover)
		theme.set_stylebox("pressed", type_name, pressed)
		theme.set_stylebox("focus", type_name, focus)
		theme.set_color("font_color", type_name, Color("eee7cf"))
		theme.set_color("font_hover_color", type_name, Color("fff4d3"))
	for type_name in ["Label", "RichTextLabel", "CheckButton", "LineEdit", "TextEdit"]:
		theme.set_color("font_color" if type_name != "RichTextLabel" else "default_color", type_name, Color("d9e1d2"))
	for type_name in ["LineEdit", "TextEdit"]:
		theme.set_stylebox("normal", type_name, _style(Color("10231c"), Color("3b5642")))
		theme.set_stylebox("focus", type_name, focus)
		theme.set_color("caret_color", type_name, Color("e3c88c"))
	var panel := _style(Color("172a23"), Color("172a23"), 6)
	panel.content_margin_left = 2
	panel.content_margin_right = 2
	theme.set_stylebox("panel", "TabContainer", panel)
	for type_name in ["TabContainer", "TabBar"]:
		theme.set_stylebox("tab_selected", type_name, _style(Color("344c38"), Color("6b7952"), 6))
		theme.set_stylebox("tab_unselected", type_name, _style(Color("1b3027"), Color("263e31"), 6))
		theme.set_stylebox("tab_hovered", type_name, hover)
		theme.set_color("font_selected_color", type_name, Color("f1d8a1"))
		theme.set_color("font_unselected_color", type_name, Color("aebfae"))
		theme.set_font_size("font_size", type_name, 13)
	theme.set_stylebox("panel", "PopupMenu", _style(Color("1b3027"), Color("67815b")))
	theme.set_stylebox("hover", "PopupMenu", hover)
	return theme

func _card(parent: Node) -> VBoxContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _style(Color("21392d"), Color("3b5440")))
	parent.add_child(card)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 3)
	card.add_child(content)
	return content

func _bar(parent: Node, color: Color, height: int) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = height
	bar.show_percentage = false
	var background := StyleBoxFlat.new()
	background.bg_color = Color("0e2119")
	background.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	return bar

func _refresh_memory_and_skills(sim: RefCounted, p: Dictionary) -> void:
	var memory_lines: Array[String] = []
	memory_lines.append("%s • pamięć osobista\nDostarczono: %d jedzenia i %d drewna" % [p["name"], p["experience"]["delivered_food"], p["experience"]["delivered_wood"]])
	memory_lines.append("\nTRWAŁE WNIOSKI")
	if p["knowledge"].is_empty():
		memory_lines.append("Pierwsze wnioski pojawią się po wykonaniu zadań.")
	for key in p["knowledge"]:
		memory_lines.append("• " + str(p["knowledge"][key]))
	memory_lines.append("\nDOŚWIADCZENIE W DZIAŁANIU")
	for action in p["experience"]["actions"]:
		var stats: Dictionary = p["experience"]["actions"][action]
		memory_lines.append("%s: %d udanych / %d nieudanych" % [sim.ACTION_NAMES.get(action, action), stats["successes"], stats["failures"]])
	memory_lines.append("\nOSTATNIE WSPOMNIENIA • %d/40" % p["episodes"].size())
	var events: Array = p["episodes"].duplicate()
	events.reverse()
	for event in events:
		var outcome := "NIEPOWODZENIE" if event["outcome"] == "failure" else "DOŚWIADCZENIE"
		memory_lines.append("\n%s • %s\n%s" % [event["at"], outcome, event["text"]])
	memory_lines.append("\nAI otrzymuje skrót doświadczeń i wniosków. Pamięć i poziomy są zachowywane w zapisie gry.")
	var memory_value := "\n".join(memory_lines)
	if memory_value != last_memory:
		memory_text.text = memory_value
		last_memory = memory_value
	for key in skill_bars:
		var skill: Dictionary = p["skills"][key]
		var level := int(skill["level"])
		skill_titles[key].text = "%s    POZIOM %d" % [sim.SKILL_NAMES[key], level]
		skill_bars[key].max_value = sim.xp_needed(level)
		skill_bars[key].value = sim.xp_needed(level) if level == sim.MAX_SKILL_LEVEL else skill["xp"]
		var progress := "Mistrzostwo" if level == sim.MAX_SKILL_LEVEL else "%d / %d XP" % [skill["xp"], sim.xp_needed(level)]
		skill_details[key].text = "%s  •  Szybkość pracy +%d%%" % [progress, (level - 1) * 8]
	var growth_lines: Array[String] = ["OSIĄGNIĘCIA"]
	if p["milestones"].is_empty():
		growth_lines.append("Pierwszy poziom zdobędziesz po 3 pełnych zbiorach. Budowa daje 12 XP za etap.")
	var milestones: Array = p["milestones"].duplicate()
	milestones.reverse()
	for milestone in milestones:
		growth_lines.append("%s\n%s" % [milestone["at"], milestone["text"]])
	var growth_value := "\n\n".join(growth_lines)
	if growth_value != last_growth:
		growth_text.text = growth_value
		last_growth = growth_value
