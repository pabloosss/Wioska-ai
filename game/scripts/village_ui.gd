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
	style.bg_color = Color("182822")
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
	add_child(root)
	var top := _panel(root, Rect2(12, 10, 1256, 116))
	var row := HBoxContainer.new()
	top.add_child(row)
	var title := _label(row, "WIOSKA AI  •  v0.2", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	summary_label = _label(sidebar, "", 16)
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.add_child(tabs)
	var residents_tab := VBoxContainer.new()
	residents_tab.name = "Mieszkańcy"
	tabs.add_child(residents_tab)
	picker = OptionButton.new()
	for person in people:
		picker.add_item(person["name"])
	picker.item_selected.connect(func(index: int): selection_changed.emit(index))
	residents_tab.add_child(picker)
	people_text = _text(residents_tab)
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
	journal.name = "Dziennik"
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
	summary_label.text = "Jedzenie %d  •  Drewno %d  •  Domy %d\nDostarczono: jedzenie %d / drewno %d" % [sim.stock["food"], sim.stock["wood"], sim.houses, sim.delivered["food"], sim.delivered["wood"]]
	picker.select(index)
	var p: Dictionary = sim.people[index]
	var lines: Array[String] = []
	for resident in sim.people:
		lines.append("%s: %s" % [resident["name"], resident["task"]])
	lines.append("\n%s • %s • %s" % [p["name"], p["job"], p["trait"]])
	lines.append("Sytość %d/100 • Wypoczęcie %d/100\nCiepło %d/100" % [p["hunger"], p["rest"], p["warmth"]])
	lines.append("Ładunek: %d jedzenia / %d drewna\nPrywatne jedzenie: %d\nPamiątka: %s\nSprzęt: %s" % [p["cargo_food"], p["cargo_wood"], p["inventory"]["food"], p["inventory"]["keepsake"], str(p["inventory"]["equipment"])])
	lines.append("Poziom umiejętności: %d • Ukończone zadania: %d" % [p["skill_level"], p["jobs_done"]])
	lines.append("\nDLACZEGO AI WYBRAŁO TO ZADANIE\n" + str(p["reason"]))
	var pending: Array[String] = []
	for step in p["queue"]:
		pending.append(str(step["action"]))
	lines.append("\nKOLEJNE KROKI AI\n" + (", ".join(pending) if not pending.is_empty() else "Brak — po zadaniu nowy plan"))
	lines.append("\nWSPOMNIENIA\n" + "\n".join(p["memory"]))
	var text := "\n".join(lines)
	if text != last_people:
		people_text.text = text
		last_people = text
	ai_text.text = "STATUS POŁĄCZENIA\n%s\n\nOstatnia odpowiedź: %.1f s\nZapytania: %d • błędy: %d\nPrzyjęte plany mieszkańców: %d\nOczekujących mieszkańców: %d\n\n%s\n\nAI wybiera do 3 kolejnych zadań. Trwający zbiór i dostawa nie są przerywane nową odpowiedzią.\n\nZielony status oznacza przyjęty plan; samo znalezienie modelu nie potwierdza poprawnych decyzji." % [data["detail"], data["latency"], data["requests"], data["errors"], data["accepted"], sim.idle_snapshot().size(), sim.last_save]
	var journal := "\n\n".join(sim.logs)
	if journal != last_logs:
		log_text.text = journal
		last_logs = journal
