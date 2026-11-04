extends Node2D

const OllamaBridge = preload("res://scripts/ollama_bridge.gd")
const SAVE_PATH := "user://wioska_ai_save.json"
const AI_SETTINGS_PATH := "user://wioska_ai_settings.json"

const SIDEBAR_X := 850.0
const HOME := Vector2(500, 390)
const STORAGE_SPOT := Vector2(590, 440)
const FOOD_SPOT := Vector2(230, 270)
const WOOD_SPOT := Vector2(665, 230)
const FIRE_SPOT := Vector2(500, 430)

var residents: Array[Dictionary] = []
var stock := {"food": 16, "wood": 18}
var logs: Array[String] = []
var selected := 0
var paused := false
var day_minute := 8 * 60
var build_progress := 0
var houses := 1
var clock: Timer
var ollama_bridge: Node
var ai_status := "AI: sprawdzam Ollamę…"
var ai_minute_counter := 120
var ai_model_name := "qwen3.5:35b"
var ai_interval_minutes := 30
var ai_temperature := 0.2
var ai_enabled := true
var ai_guidance := ""
var ai_priority := 0
var settings_open := false
var ui_layer: CanvasLayer
var settings_panel: PanelContainer
var settings_status_label: Label
var model_picker: OptionButton
var ai_enabled_toggle: CheckButton
var interval_picker: OptionButton
var temperature_slider: HSlider
var temperature_value_label: Label
var priority_picker: OptionButton
var guidance_edit: TextEdit


func _ready() -> void:
	_create_residents()
	_load_game()
	_load_ai_settings()
	_add_log("Wioska zaczyna dzień. Pięciu mieszkańców rusza do pracy.")
	ollama_bridge = OllamaBridge.new()
	ollama_bridge.set("model_name", ai_model_name)
	ollama_bridge.connect("status_changed", Callable(self, "_on_ai_status_changed"))
	ollama_bridge.connect("decisions_received", Callable(self, "_on_ai_decisions"))
	ollama_bridge.connect("models_received", Callable(self, "_on_models_received"))
	add_child(ollama_bridge)
	_build_settings_ui()
	clock = Timer.new()
	clock.wait_time = 1.0
	clock.timeout.connect(_on_tick)
	add_child(clock)
	clock.start()



func _build_settings_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(root)

	var open_button := Button.new()
	open_button.text = "USTAWIENIA AI"
	open_button.position = Vector2(1095, 14)
	open_button.size = Vector2(160, 38)
	open_button.pressed.connect(_show_ai_settings)
	root.add_child(open_button)

	settings_panel = PanelContainer.new()
	settings_panel.set_anchors_preset(Control.PRESET_CENTER)
	settings_panel.offset_left = -330
	settings_panel.offset_top = -305
	settings_panel.offset_right = 330
	settings_panel.offset_bottom = 305
	settings_panel.visible = false
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#1d2928")
	panel_style.border_color = Color("#d7b878")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(14)
	panel_style.content_margin_left = 22
	panel_style.content_margin_right = 22
	panel_style.content_margin_top = 18
	panel_style.content_margin_bottom = 18
	settings_panel.add_theme_stylebox_override("panel", panel_style)
	root.add_child(settings_panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	settings_panel.add_child(layout)

	var heading := HBoxContainer.new()
	layout.add_child(heading)
	var title := Label.new()
	title.text = "Ustawienia lokalnego AI"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("#f4d99b"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var close_button := Button.new()
	close_button.text = "Zamknij"
	close_button.pressed.connect(_hide_ai_settings)
	heading.add_child(close_button)

	var intro := Label.new()
	intro.text = "Wybierz tempo i priorytet. AI planuje regularnie, a mieszkańcy pracują podczas oczekiwania na odpowiedź."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_color_override("font_color", Color("#d5dfd5"))
	layout.add_child(intro)

	settings_status_label = Label.new()
	settings_status_label.text = ai_status
	settings_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	settings_status_label.custom_minimum_size.y = 28
	settings_status_label.add_theme_color_override("font_color", Color("#91d3a4"))
	layout.add_child(settings_status_label)

	var model_row := HBoxContainer.new()
	layout.add_child(model_row)
	var model_label := Label.new()
	model_label.text = "Model Ollamy"
	model_label.custom_minimum_size.x = 135
	model_row.add_child(model_label)
	model_picker = OptionButton.new()
	model_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	model_row.add_child(model_picker)
	var refresh_models := Button.new()
	refresh_models.text = "Odśwież"
	refresh_models.pressed.connect(_refresh_models)
	model_row.add_child(refresh_models)

	ai_enabled_toggle = CheckButton.new()
	ai_enabled_toggle.text = "AI wybiera działania mieszkańców"
	ai_enabled_toggle.button_pressed = ai_enabled
	layout.add_child(ai_enabled_toggle)

	var interval_row := HBoxContainer.new()
	layout.add_child(interval_row)
	var interval_label := Label.new()
	interval_label.text = "Częstotliwość decyzji"
	interval_label.custom_minimum_size.x = 175
	interval_row.add_child(interval_label)
	interval_picker = OptionButton.new()
	interval_picker.add_item("Aktywnie — co 3 sekundy", 30)
	interval_picker.add_item("Spokojnie — co 6 sekund", 60)
	interval_picker.add_item("Oszczędnie — co 12 sekund", 120)
	interval_picker.add_item("Rzadko — co 24 sekundy", 240)
	interval_row.add_child(interval_picker)

	var temperature_row := HBoxContainer.new()
	layout.add_child(temperature_row)
	var temperature_label := Label.new()
	temperature_label.text = "Swoboda AI"
	temperature_label.custom_minimum_size.x = 135
	temperature_row.add_child(temperature_label)
	temperature_slider = HSlider.new()
	temperature_slider.min_value = 0.0
	temperature_slider.max_value = 1.0
	temperature_slider.step = 0.1
	temperature_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	temperature_slider.value_changed.connect(_on_temperature_changed)
	temperature_row.add_child(temperature_slider)
	temperature_value_label = Label.new()
	temperature_value_label.custom_minimum_size.x = 42
	temperature_row.add_child(temperature_value_label)

	var priority_row := HBoxContainer.new()
	layout.add_child(priority_row)
	var priority_label := Label.new()
	priority_label.text = "Priorytet wioski"
	priority_label.custom_minimum_size.x = 135
	priority_row.add_child(priority_label)
	priority_picker = OptionButton.new()
	priority_picker.add_item("Równowaga", 0)
	priority_picker.add_item("Potrzeby mieszkańców", 1)
	priority_picker.add_item("Zasoby i budowa", 2)
	priority_row.add_child(priority_picker)

	var guidance_label := Label.new()
	guidance_label.text = "Dodatkowe wskazówki dla AI"
	layout.add_child(guidance_label)
	guidance_edit = TextEdit.new()
	guidance_edit.placeholder_text = "Np. dbaj o zapas jedzenia i odpoczynek. Dostępne działania: praca, jedzenie, odpoczynek, ogrzanie."
	guidance_edit.custom_minimum_size = Vector2(0, 92)
	guidance_edit.text = ai_guidance
	layout.add_child(guidance_edit)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	layout.add_child(actions)
	var defaults_button := Button.new()
	defaults_button.text = "Domyślne"
	defaults_button.pressed.connect(_restore_default_ai_settings)
	actions.add_child(defaults_button)
	var save_button := Button.new()
	save_button.text = "Zapisz ustawienia"
	save_button.pressed.connect(_save_ai_settings)
	actions.add_child(save_button)

	temperature_slider.value = ai_temperature
	_on_temperature_changed(ai_temperature)
	_select_option_by_id(interval_picker, ai_interval_minutes)
	_select_option_by_id(priority_picker, ai_priority)


func _show_ai_settings() -> void:
	settings_open = true
	settings_panel.visible = true
	ai_enabled_toggle.button_pressed = ai_enabled
	guidance_edit.text = ai_guidance
	temperature_slider.value = ai_temperature
	_on_temperature_changed(ai_temperature)
	_select_option_by_id(interval_picker, ai_interval_minutes)
	_select_option_by_id(priority_picker, ai_priority)
	_refresh_models()


func _hide_ai_settings() -> void:
	settings_open = false
	settings_panel.visible = false


func _refresh_models() -> void:
	if ollama_bridge != null:
		ollama_bridge.call("request_models")
		settings_status_label.text = "Pobieram listę modeli z lokalnej Ollamy…"


func _on_models_received(models: Array) -> void:
	model_picker.clear()
	var selected_index := -1
	for model_name in models:
		var model := str(model_name)
		if model.is_empty():
			continue
		model_picker.add_item(model)
		if model == ai_model_name:
			selected_index = model_picker.item_count - 1
	if selected_index == -1:
		model_picker.add_item(ai_model_name + " (wybrany)")
		selected_index = model_picker.item_count - 1
	model_picker.select(selected_index)
	if settings_status_label != null:
		settings_status_label.text = "Znalezione modele: %d" % models.size()


func _select_model_name_in_picker(target_model: String) -> void:
	for index in range(model_picker.item_count):
		var item_text := model_picker.get_item_text(index).trim_suffix(" (wybrany)")
		if item_text == target_model:
			model_picker.select(index)
			return
	model_picker.add_item(target_model + " (wybrany)")
	model_picker.select(model_picker.item_count - 1)


func _select_option_by_id(option: OptionButton, option_id: int) -> void:
	for index in range(option.item_count):
		if option.get_item_id(index) == option_id:
			option.select(index)
			return


func _on_temperature_changed(value: float) -> void:
	if temperature_value_label != null:
		temperature_value_label.text = "%.1f" % value


func _save_ai_settings() -> void:
	var old_model := str(ollama_bridge.get("model_name")) if ollama_bridge != null else ai_model_name
	ai_enabled = ai_enabled_toggle.button_pressed
	ai_model_name = model_picker.get_item_text(model_picker.get_selected()).trim_suffix(" (wybrany)") if model_picker.item_count > 0 else ai_model_name
	ai_interval_minutes = interval_picker.get_selected_id()
	ai_temperature = temperature_slider.value
	ai_priority = priority_picker.get_selected_id()
	ai_guidance = guidance_edit.text.strip_edges()
	ai_minute_counter = ai_interval_minutes

	var config := {
		"model": ai_model_name,
		"enabled": ai_enabled,
		"interval_minutes": ai_interval_minutes,
		"temperature": ai_temperature,
		"priority": ai_priority,
		"guidance": ai_guidance
	}
	var file := FileAccess.open(AI_SETTINGS_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(config))

	if old_model != ai_model_name and ollama_bridge != null:
		ollama_bridge.call("select_model", ai_model_name)
	_on_ai_status_changed("Ustawienia zapisane — model: " + ai_model_name)
	_add_log("Zmieniono ustawienia lokalnego AI.")
	_hide_ai_settings()


func _restore_default_ai_settings() -> void:
	ai_model_name = "qwen3.5:35b"
	ai_enabled = true
	ai_interval_minutes = 30
	ai_temperature = 0.2
	ai_priority = 0
	ai_guidance = ""
	_select_model_name_in_picker(ai_model_name)
	ai_enabled_toggle.button_pressed = true
	temperature_slider.value = ai_temperature
	_select_option_by_id(interval_picker, ai_interval_minutes)
	_select_option_by_id(priority_picker, ai_priority)
	guidance_edit.text = ai_guidance


func _load_ai_settings() -> void:
	if not FileAccess.file_exists(AI_SETTINGS_PATH):
		return
	var file := FileAccess.open(AI_SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	ai_model_name = str(parsed.get("model", ai_model_name))
	ai_enabled = bool(parsed.get("enabled", ai_enabled))
	ai_interval_minutes = clampi(int(parsed.get("interval_minutes", 30)), 30, 240)
	ai_temperature = clampf(float(parsed.get("temperature", ai_temperature)), 0.0, 1.0)
	ai_priority = clampi(int(parsed.get("priority", ai_priority)), 0, 2)
	ai_guidance = str(parsed.get("guidance", ai_guidance))




func _process(delta: float) -> void:
	if not paused:
		for person in residents:
			var position: Vector2 = person["position"]
			var target: Vector2 = person["target"]
			person["position"] = position.move_toward(target, 48.0 * delta)
	queue_redraw()


func _create_residents() -> void:
	residents = [
		_make_person("Mira", "Zbieracz", Vector2(400, 350), Color("#e8a45b"), "Ciekawska", "Zielarstwo", "sznurkowa bransoletka", ["kosz"]),
		_make_person("Olek", "Zbieracz", Vector2(440, 380), Color("#d47a6a"), "Spokojny", "Zielarstwo", "gładki kamień", ["kosz"]),
		_make_person("Lena", "Drwal", Vector2(545, 350), Color("#84b878"), "Pracowita", "Drwalstwo", "drewniany gwizdek", ["topór"]),
		_make_person("Tomasz", "Drwal", Vector2(575, 390), Color("#7799c9"), "Ostrożny", "Drwalstwo", "stary guzik", ["topór"]),
		_make_person("Iga", "Budowniczy", Vector2(505, 355), Color("#c38bd1"), "Pomysłowa", "Budowanie", "notes z rysunkami", ["młotek"])
	]


func _make_person(person_name: String, job: String, start: Vector2, tint: Color, personality_trait: String, skill: String, keepsake: String, equipment: Array) -> Dictionary:
	return {
		"name": person_name,
		"job": job,
		"position": start,
		"target": start,
		"color": tint,
		"trait": personality_trait,
		"skill": skill,
		"skill_level": 1,
		"hunger": 82.0,
		"rest": 88.0,
		"warmth": 76.0,
		"work_ticks": 0,
		"skill_xp": 0,
		"ai_action": "work",
		"ai_reason": "",
		"memory": [],
		"cargo_food": 0,
		"cargo_wood": 0,
		"inventory": {"food": 1, "keepsake": keepsake, "equipment": equipment}
	}


func _on_tick() -> void:
	if paused:
		return
	day_minute = (day_minute + 10) % 1440
	for person in residents:
		person["hunger"] = maxf(0.0, person["hunger"] - 1.2)
		person["rest"] = maxf(0.0, person["rest"] - 0.55)
		person["warmth"] = maxf(0.0, person["warmth"] - (0.8 if _is_night() else 0.12))
		_choose_task(person)
		_do_task(person)
	ai_minute_counter += 10
	if ai_enabled and ai_minute_counter >= ai_interval_minutes and ollama_bridge != null and bool(ollama_bridge.get("is_ready")) and not bool(ollama_bridge.get("is_busy")):
		ai_minute_counter = 0
		_request_ai_decisions()
	_save_game()
	queue_redraw()


func _choose_task(person: Dictionary) -> void:
	var position: Vector2 = person["position"]
	var cargo_food: int = person["cargo_food"]
	var cargo_wood: int = person["cargo_wood"]
	var ai_action: String = str(person.get("ai_action", "work")) if ai_enabled else "work"
	var inventory: Dictionary = person["inventory"]
	var has_food: bool = inventory["food"] > 0 or stock["food"] > 0
	if cargo_food >= 4 or cargo_wood >= 4:
		person["task"] = "Niesie ładunek do magazynu"
		person["target"] = STORAGE_SPOT
	elif person["hunger"] < 15.0 and has_food:
		person["task"] = "Je"
		person["target"] = position if inventory["food"] > 0 else STORAGE_SPOT
	elif person["rest"] < 8.0:
		person["task"] = "Odpoczywa"
		person["target"] = HOME
	elif person["warmth"] < 12.0:
		person["task"] = "Grzeje się"
		person["target"] = FIRE_SPOT
	elif ai_action == "eat" and person["hunger"] < 70.0 and has_food:
		person["task"] = "Je"
		person["target"] = position if inventory["food"] > 0 else STORAGE_SPOT
	elif ai_action == "rest" and person["rest"] < 65.0:
		person["task"] = "Odpoczywa"
		person["target"] = HOME
	elif ai_action == "warm" and person["warmth"] < 55.0:
		person["task"] = "Grzeje się"
		person["target"] = FIRE_SPOT
	elif person["hunger"] < 28.0 and has_food:
		person["task"] = "Je"
		person["target"] = position if inventory["food"] > 0 else STORAGE_SPOT
	elif person["rest"] < 18.0:
		person["task"] = "Odpoczywa"
		person["target"] = HOME
	elif person["warmth"] < 24.0:
		person["task"] = "Grzeje się"
		person["target"] = FIRE_SPOT
	elif person["job"] == "Zbieracz" or (not has_food and person["hunger"] < 40.0):
		person["task"] = "Zbiera jedzenie"
		person["target"] = FOOD_SPOT
	elif person["job"] == "Drwal" or (person["job"] == "Budowniczy" and stock["wood"] < 4):
		person["task"] = "Ścina drewno"
		person["target"] = WOOD_SPOT
	else:
		person["task"] = "Buduje dom"
		person["target"] = HOME

func _do_task(person: Dictionary) -> void:
	var task: String = person.get("task", "")
	if task == "Je":
		var eating_position: Vector2 = person["position"]
		var eating_target: Vector2 = person["target"]
		if eating_position.distance_to(eating_target) > 18.0:
			return
		var inventory: Dictionary = person["inventory"]
		if inventory["food"] > 0:
			inventory["food"] -= 1
			person["hunger"] = minf(100.0, person["hunger"] + 42.0)
			_add_log("%s zjada swoje jedzenie." % person["name"])
			_remember(person, "Zjadł własne jedzenie.")
		elif stock["food"] > 0:
			stock["food"] -= 1
			person["hunger"] = minf(100.0, person["hunger"] + 42.0)
			_add_log("%s bierze jedzenie ze wspólnego magazynu." % person["name"])
			_remember(person, "Wziął jedzenie ze wspólnego magazynu.")
		else:
			_add_log("%s jest głodny — w magazynie nie ma jedzenia." % person["name"])
		return

	var position: Vector2 = person["position"]
	var target: Vector2 = person["target"]
	if position.distance_to(target) > 18.0:
		return

	if task == "Niesie ładunek do magazynu":
		var delivered_food: int = person["cargo_food"]
		var delivered_wood: int = person["cargo_wood"]
		stock["food"] += delivered_food
		stock["wood"] += delivered_wood
		person["cargo_food"] = 0
		person["cargo_wood"] = 0
		_add_log("%s zanosi do magazynu: jedzenie %d, drewno %d." % [person["name"], delivered_food, delivered_wood])
		_remember(person, "Zaniósł do magazynu: jedzenie %d, drewno %d." % [delivered_food, delivered_wood])
		return

	if task == "Odpoczywa":
		person["rest"] = minf(100.0, person["rest"] + 7.0)
		return
	if task == "Grzeje się":
		person["warmth"] = minf(100.0, person["warmth"] + 8.0)
		return

	person["work_ticks"] += 1
	if person["work_ticks"] < 3:
		return
	person["work_ticks"] = 0

	if task == "Zbiera jedzenie":
		person["cargo_food"] += 2
		_add_log("%s zbiera jedzenie (%d/4)." % [person["name"], person["cargo_food"]])
		_remember(person, "Zebrał jedzenie; ma teraz %d jednostki ładunku." % person["cargo_food"])
		_gain_skill(person)
	elif task == "Ścina drewno":
		person["cargo_wood"] += 2
		_add_log("%s zbiera drewno (%d/4)." % [person["name"], person["cargo_wood"]])
		_remember(person, "Zebrał drewno; ma teraz %d jednostki ładunku." % person["cargo_wood"])
		_gain_skill(person)
	elif task == "Buduje dom":
		if stock["wood"] < 4:
			return
		stock["wood"] -= 4
		build_progress += 1
		_gain_skill(person)
		if build_progress >= 5:
			build_progress = 0
			houses += 1
			_add_log("%s kończy nowy dom. Wioska ma %d domy." % [person["name"], houses])
			_remember(person, "Pomógł ukończyć nowy dom. W wiosce jest ich %d." % houses)
		else:
			_add_log("%s pracuje przy domu (%d/5)." % [person["name"], build_progress])


func _on_ai_status_changed(message: String) -> void:
	ai_status = message
	if settings_status_label != null:
		settings_status_label.text = message
	queue_redraw()

func _request_ai_decisions() -> void:
	var people_data: Array = []
	for person in residents:
		var memories: Array = person["memory"]
		var recent_memories: Array = memories.slice(maxi(0, memories.size() - 4))
		var inventory: Dictionary = person["inventory"]
		people_data.append({
			"name": person["name"],
			"job": person["job"],
			"personality": person["trait"],
			"skill": person["skill"],
			"skill_level": person["skill_level"],
			"needs": {"hunger": roundi(person["hunger"]), "rest": roundi(person["rest"]), "warmth": roundi(person["warmth"])},
			"inventory": {"private_food": inventory["food"], "cargo_food": person["cargo_food"], "cargo_wood": person["cargo_wood"]},
			"recent_memories": recent_memories
		})
	var world_state := {
		"time": "%02d:%02d" % [int(day_minute / 60), day_minute % 60],
		"shared_food": stock["food"],
		"shared_wood": stock["wood"],
		"houses": houses,
		"build_progress": build_progress
	}
	var priority_guidance := "Podejmuj zrównoważone decyzje, dbając o potrzeby i zapasy."
	if ai_priority == 1:
		priority_guidance = "Priorytetem jest zdrowie mieszkańców: najpierw głód, odpoczynek i ciepło, potem praca."
	elif ai_priority == 2:
		priority_guidance = "Priorytetem jest rozwój wioski: zbieraj zasoby i buduj, ale reaguj na pilny głód, zmęczenie i zimno."
	var combined_guidance := priority_guidance
	if not ai_guidance.strip_edges().is_empty():
		combined_guidance += " " + ai_guidance.strip_edges()
	ollama_bridge.call("request_decisions", world_state, people_data, ai_temperature, combined_guidance)

func _on_ai_decisions(decisions: Array) -> void:
	for decision in decisions:
		if typeof(decision) != TYPE_DICTIONARY:
			continue
		var person_name: String = str(decision.get("name", ""))
		var action: String = str(decision.get("action", "work"))
		if not ["work", "eat", "rest", "warm"].has(action):
			continue
		for person in residents:
			if str(person["name"]).to_lower() != person_name.strip_edges().to_lower():
				continue
			person["ai_action"] = action
			var reason: String = str(decision.get("reason", ""))
			if reason.length() > 100:
				reason = reason.substr(0, 100)
			person["ai_reason"] = reason
			_remember(person, "AI wybrało %s: %s" % [action, reason])
			_add_log("%s: AI wybiera %s — %s" % [person_name, action, reason])
			break
	_save_game()
	queue_redraw()

func _remember(person: Dictionary, note: String) -> void:
	var memories: Array = person["memory"]
	memories.append("%02d:%02d %s" % [int(day_minute / 60), day_minute % 60, note])
	while memories.size() > 8:
		memories.pop_front()
	person["memory"] = memories

func _gain_skill(person: Dictionary) -> void:
	person["skill_xp"] += 1
	if person["skill_xp"] >= 5:
		person["skill_xp"] = 0
		person["skill_level"] += 1
		var note := "Rozwinął umiejętność %s do poziomu %d." % [person["skill"], person["skill_level"]]
		_add_log("%s %s" % [person["name"], note])
		_remember(person, note)

func _save_game() -> void:
	var saved_people: Array = []
	for person in residents:
		saved_people.append({
			"name": person["name"],
			"position": [person["position"].x, person["position"].y],
			"hunger": person["hunger"],
			"rest": person["rest"],
			"warmth": person["warmth"],
			"skill_level": person["skill_level"],
			"skill_xp": person["skill_xp"],
			"inventory": person["inventory"],
			"cargo_food": person["cargo_food"],
			"cargo_wood": person["cargo_wood"],
			"memory": person["memory"]
		})
	var save_data := {
		"day_minute": day_minute,
		"stock": stock,
		"houses": houses,
		"build_progress": build_progress,
		"residents": saved_people
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(save_data))

func _load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var save_data: Variant = JSON.parse_string(file.get_as_text())
	if typeof(save_data) != TYPE_DICTIONARY:
		return
	day_minute = int(save_data.get("day_minute", day_minute))
	var saved_stock: Dictionary = save_data.get("stock", stock)
	stock["food"] = int(saved_stock.get("food", stock["food"]))
	stock["wood"] = int(saved_stock.get("wood", stock["wood"]))
	houses = int(save_data.get("houses", houses))
	build_progress = int(save_data.get("build_progress", build_progress))
	for saved_person in save_data.get("residents", []):
		if typeof(saved_person) != TYPE_DICTIONARY:
			continue
		for person in residents:
			if person["name"] != saved_person.get("name", ""):
				continue
			for key in ["hunger", "rest", "warmth", "skill_level", "skill_xp", "inventory", "cargo_food", "cargo_wood", "memory"]:
				if saved_person.has(key):
					person[key] = saved_person[key]
			var saved_position: Array = saved_person.get("position", [])
			if saved_position.size() == 2:
				person["position"] = Vector2(float(saved_position[0]), float(saved_position[1]))
				person["target"] = person["position"]
			break

func _is_night() -> bool:
	var hour := int(day_minute / 60)
	return hour >= 20 or hour < 6


func _add_log(message: String) -> void:
	logs.push_front("%02d:%02d  %s" % [int(day_minute / 60), day_minute % 60, message])
	while logs.size() > 6:
		logs.pop_back()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and settings_open:
			_hide_ai_settings()
			return
		if event.keycode == KEY_F2:
			if settings_open:
				_hide_ai_settings()
			else:
				_show_ai_settings()
			return
		if settings_open:
			return
		if event.keycode == KEY_SPACE:
			paused = not paused
		elif event.keycode >= KEY_1 and event.keycode <= KEY_5:
			selected = event.keycode - KEY_1
		elif event.keycode == KEY_R and ollama_bridge != null:
			ollama_bridge.call("connect_to_ollama")
	if settings_open and event is InputEventMouseButton:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_position: Vector2 = event.position
		for index in range(residents.size()):
			var person_position: Vector2 = residents[index]["position"]
			if mouse_position.distance_to(person_position) < 24.0:
				selected = index
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, SIDEBAR_X, 720), Color("#78945f"))
	_draw_world()
	draw_rect(Rect2(SIDEBAR_X, 0, 430, 720), Color("#1d2928"))
	_draw_sidebar()


func _draw_world() -> void:
	# Placeholder scenery until the selected licensed pack is connected.
	draw_rect(Rect2(70, 90, 700, 540), Color("#87a96b"))
	for x in range(90, 770, 48):
		draw_line(Vector2(x, 90), Vector2(x, 630), Color("#90b174", 0.35), 1.0)
	for y in range(110, 630, 48):
		draw_line(Vector2(70, y), Vector2(770, y), Color("#90b174", 0.35), 1.0)

	draw_rect(Rect2(430, 330, 140, 95), Color("#a77c55"))
	draw_rect(Rect2(450, 300, 100, 70), Color("#d5bf91"))
	draw_rect(Rect2(488, 350, 24, 42), Color("#6a4836"))
	_draw_text("wspólny magazyn", 430, 445, 13, Color("#fff4d6"))

	draw_circle(FIRE_SPOT, 13.0, Color("#ed8b43"))
	draw_circle(FIRE_SPOT, 6.0, Color("#ffd36e"))
	_draw_text("ognisko", 474, 458, 13, Color("#fff4d6"))

	draw_circle(FOOD_SPOT, 24.0, Color("#496f43"))
	draw_circle(FOOD_SPOT + Vector2(-9, -4), 5.0, Color("#db5f54"))
	draw_circle(FOOD_SPOT + Vector2(8, -8), 5.0, Color("#db5f54"))
	_draw_text("jagody", 202, 310, 13, Color.WHITE)

	for tree in [Vector2(625, 205), Vector2(690, 265), Vector2(710, 185)]:
		draw_rect(Rect2(tree.x - 4, tree.y + 12, 8, 18), Color("#72503a"))
		draw_circle(tree, 20.0, Color("#365c3b"))
	_draw_text("las", 650, 305, 13, Color.WHITE)

	for index in range(residents.size()):
		var person: Dictionary = residents[index]
		var position: Vector2 = person["position"]
		var tint: Color = person["color"]
		if index == selected:
			draw_circle(position, 20.0, Color("#fff1a8"))
		draw_circle(position, 15.0, tint)
		draw_circle(position + Vector2(0, -17), 7.0, Color("#f1d1ae"))
		if person["cargo_food"] > 0 or person["cargo_wood"] > 0:
			draw_rect(Rect2(position + Vector2(10, -4), Vector2(10, 10)), Color("#b88b52"))
		_draw_text(person["name"], position.x - 22, position.y + 34, 12, Color.WHITE)

	_draw_text("WIOSKA AI  •  %02d:%02d" % [int(day_minute / 60), day_minute % 60], 82, 65, 20, Color.WHITE)
	_draw_text("SPACJA — pauza  |  kliknij mieszkańca albo użyj 1–5", 82, 610, 14, Color.WHITE)


func _draw_sidebar() -> void:
	_draw_text("WIOSKA AI", 885, 42, 24, Color("#f4d99b"))
	_draw_text("Dzień 1   •   %s" % ("noc" if _is_night() else "dzień"), 885, 70, 15, Color("#d5dfd5"))
	_draw_text(ai_status.left(53), 885, 91, 11, Color("#91d3a4") if ai_status.begins_with("AI: aktywna") else Color("#e6c17d"))
	_draw_text("MAGAZYN WSPÓLNY", 885, 112, 15, Color("#f4d99b"))
	_draw_text("Jedzenie: %d     Drewno: %d" % [stock["food"], stock["wood"]], 885, 138, 16, Color.WHITE)
	_draw_text("Domy: %d     Budowa: %d/5" % [houses, build_progress], 885, 162, 14, Color("#d5dfd5"))

	_draw_text("MIESZKAŃCY", 885, 207, 15, Color("#f4d99b"))
	for index in range(residents.size()):
		var person: Dictionary = residents[index]
		var color: Color = Color("#fff1a8") if index == selected else Color("#d5dfd5")
		_draw_text("%d. %s — %s" % [index + 1, person["name"], person.get("task", "wybiera pracę")], 885, 235 + index * 25, 13, color)

	var chosen: Dictionary = residents[selected]
	_draw_text("WYBRANY MIESZKANIEC", 885, 383, 15, Color("#f4d99b"))
	_draw_text("%s  •  %s  •  %s" % [chosen["name"], chosen["job"], chosen["trait"]], 885, 409, 13, Color.WHITE)
	_draw_text("Sytość", 885, 438, 12, Color("#d5dfd5"))
	_draw_bar(940, 427, 205, chosen["hunger"], Color("#e5a45b"))
	_draw_text("Odpoczynek", 885, 465, 12, Color("#d5dfd5"))
	_draw_bar(970, 454, 175, chosen["rest"], Color("#79b8d2"))
	_draw_text("Ciepło", 885, 492, 12, Color("#d5dfd5"))
	_draw_bar(940, 481, 205, chosen["warmth"], Color("#e77c58"))
	var inventory: Dictionary = chosen["inventory"]
	_draw_text("Umiejętność: %s  •  poziom %d" % [chosen["skill"], chosen["skill_level"]], 885, 522, 12, Color.WHITE)
	_draw_text("Ekwipunek: %s, jedzenie %d" % [str(inventory["equipment"]), inventory["food"]], 885, 544, 12, Color.WHITE)
	_draw_text("Niesie: jedzenie %d, drewno %d" % [chosen["cargo_food"], chosen["cargo_wood"]], 885, 584, 12, Color("#f4d99b"))
	_draw_text("Prywatna rzecz: %s" % inventory["keepsake"], 885, 566, 12, Color.WHITE)

	_draw_text("Decyzja: " + str(chosen.get("ai_reason", "Planuje działanie…")).left(48), 885, 605, 12, Color("#91d3a4"))
	_draw_text("OSTATNIE ZDARZENIA", 885, 630, 14, Color("#f4d99b"))
	for index in range(mini(logs.size(), 4)):
		_draw_text(logs[index].left(58), 885, 650 + index * 16, 11, Color("#d5dfd5"))


func _draw_bar(x: float, y: float, width: float, value: float, color: Color) -> void:
	draw_rect(Rect2(x, y, width, 10), Color("#3c4a46"))
	draw_rect(Rect2(x, y, width * clampf(value / 100.0, 0.0, 1.0), 10), color)


func _draw_text(text: String, x: float, y: float, size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)
