extends Node2D
const Simulation = preload("res://scripts/simulation.gd")
const Bridge = preload("res://scripts/ollama_bridge.gd")
const Interface = preload("res://scripts/village_ui.gd")
const WorldView = preload("res://scripts/world_view.gd")
const SETTINGS := "user://wioska_ai_settings.json"
var sim: RefCounted
var bridge: Node
var ui: CanvasLayer
var world: Node2D
var selected := 0
var paused := false
var speed := 1.0
var tick_accumulator := 0.0
var ui_elapsed := 0.0
var save_elapsed := 0.0
var config := {"version": 2, "model": "qwen3:4b-instruct", "enabled": true, "cooldown": 20, "fps": 60, "timeout": 45, "guidance": "Dbaj o stały zapas jedzenia i drewna. Dziel pracę między mieszkańców."}
var request_revisions: Dictionary = {}
var status_detail := "Uruchamianie lokalnego AI"
var last_plan_ms := -1
var accepted_plans := 0
var simulation_step_count := 0

func _ready() -> void:
	get_tree().auto_accept_quit = false
	_load_config()
	Engine.max_fps = int(config["fps"])
	sim = Simulation.new()
	sim.load_game()
	world = WorldView.new()
	world.simulation = sim
	world.position = Vector2(12, 142)
	world.person_selected.connect(_select)
	add_child(world)
	ui = Interface.new()
	add_child(ui)
	ui.build(config, sim.people)
	ui.pause_requested.connect(func(): paused = not paused)
	ui.speed_requested.connect(func(value: float): speed = value)
	ui.selection_changed.connect(_select)
	ui.paths_requested.connect(func(value: bool): world.show_paths = value)
	ui.save_requested.connect(_save)
	ui.plan_requested.connect(_request_now)
	ui.retry_requested.connect(_reconnect)
	ui.ai_toggled.connect(_toggle_ai)
	ui.settings_requested.connect(_apply_settings)
	ui.model_requested.connect(_change_model)
	ui.export_requested.connect(_export_logs)
	bridge = Bridge.new()
	bridge.model_name = str(config["model"])
	bridge.cooldown_seconds = float(config["cooldown"])
	bridge.decision_timeout = float(config["timeout"])
	bridge.status_changed.connect(_status)
	bridge.decisions_received.connect(_decisions)
	add_child(bridge)
	sim.log_event("Wersja 0.2: AI wybiera plany, wykonawca kończy zbiór i dostawę.")
	_update_ui()

func _process(delta: float) -> void:
	# Fixed 20 Hz simulation. Bound catch-up to avoid a spiral after a stalled frame.
	if not paused:
		tick_accumulator += minf(delta, 0.2) * speed
		var steps := 0
		while tick_accumulator >= 0.05 and steps < 8:
			sim.step(0.05)
			tick_accumulator -= 0.05
			steps += 1
			simulation_step_count += 1
		if steps > 0:
			world.queue_redraw()
	ui_elapsed += delta
	if ui_elapsed >= 0.25:
		ui_elapsed = 0.0
		_maybe_plan()
		_update_ui()
	save_elapsed += delta
	if save_elapsed >= 30.0:
		save_elapsed = 0.0
		if sim.dirty:
			_save()

func _maybe_plan() -> void:
	if paused or not bool(config["enabled"]) or not bridge.is_ready or bridge.is_busy or bridge.runtime_preparing or bridge.runtime_download_active:
		return
	if Time.get_ticks_msec() < bridge.next_request_ms:
		return
	var idle: Array = sim.idle_snapshot()
	if idle.is_empty():
		return
	request_revisions.clear()
	for person in idle:
		request_revisions[person["name"]] = person["revision"]
	bridge.request_decisions(sim.world_snapshot(), idle, 0.1, str(config["guidance"]))

func _decisions(decisions: Array) -> void:
	if not bool(config["enabled"]):
		return
	var count: int = sim.apply_decisions(decisions, request_revisions)
	request_revisions.clear()
	if count > 0:
		last_plan_ms = Time.get_ticks_msec()
		accepted_plans += count
		status_detail = "Przyjęto plany dla %d mieszkańców." % count
	else:
		status_detail = "Odpowiedź AI nie pasuje do oczekujących mieszkańców. Trwające zadania zachowano."
		sim.log_event(status_detail)
	world.queue_redraw()
	_update_ui()

func _status(message: String) -> void:
	status_detail = message
	sim.log_event("AI: " + message)

func _update_ui() -> void:
	var headline := "AI: " + status_detail
	var color := Color("f1cb82")
	var waiting: int = sim.idle_snapshot().size()
	if not bool(config["enabled"]):
		headline = "AI wyłączone • mieszkańcy kończą otrzymane plany"
	elif bridge.request_kind == "chat":
		var seconds := float(Time.get_ticks_msec() - bridge.request_started_ms) / 1000.0
		headline = "AI planuje dla %d osób • %.0f s / limit %.0f s" % [request_revisions.size(), seconds, bridge.decision_timeout]
	elif not str(bridge.last_error).is_empty():
		headline = "Błąd AI • " + str(bridge.last_error).left(105)
		color = Color("f29a87")
	elif bridge.is_ready and not bridge.is_busy:
		if waiting == 0:
			headline = "Mieszkańcy wykonują plany AI • %d ukończonych zadań" % sim.completed
			color = Color("92d6ad") if last_plan_ms >= 0 else Color("f1cb82")
		else:
			var remaining := maxf(0.0, float(bridge.next_request_ms - Time.get_ticks_msec()) / 1000.0)
			headline = "AI gotowe • %d osób czeka na plan • kolejny cykl za %.0f s" % [waiting, remaining]
	if paused:
		headline = "PAUZA SYMULACJI • " + headline
	var plan_age := "jeszcze nie otrzymano"
	if last_plan_ms >= 0:
		plan_age = "%.0f s temu" % (float(Time.get_ticks_msec() - last_plan_ms) / 1000.0)
	ui.refresh(sim, selected, paused, {"headline": headline, "color": color, "model": bridge.model_name,
		"last_plan": plan_age, "detail": status_detail, "latency": bridge.last_latency,
		"requests": bridge.requests_finished, "errors": bridge.request_errors, "accepted": accepted_plans})

func _select(index: int) -> void:
	selected = clampi(index, 0, sim.people.size() - 1)
	world.selected = selected
	world.queue_redraw()
	_update_ui()

func _request_now() -> void:
	if bridge.is_busy:
		sim.log_event("AI już pracuje. Nie dodano drugiego zapytania.")
		return
	bridge.next_request_ms = 0
	_maybe_plan()

func _reconnect() -> void:
	if bridge.is_busy:
		sim.log_event("Trwa żądanie AI. Poczekaj na odpowiedź lub limit czasu.")
		return
	bridge.last_error = ""
	bridge.next_request_ms = 0
	bridge.connect_to_ollama()

func _toggle_ai(value: bool) -> void:
	config["enabled"] = value
	if not value:
		request_revisions.clear()
		bridge.cancel_decision()
	_write_config()
	_update_ui()

func _change_model(value: String) -> void:
	if value.is_empty() or bridge.is_busy or bridge.runtime_preparing or bridge.runtime_download_active:
		sim.log_event("Zmiana modelu wymaga zakończenia bieżącego zapytania lub pobierania.")
		return
	config["model"] = value
	request_revisions.clear()
	last_plan_ms = -1
	bridge.last_error = ""
	bridge.select_model(value)
	_write_config()

func _apply_settings(values: Dictionary) -> void:
	for key in ["cooldown", "fps", "timeout", "guidance"]:
		if values.has(key):
			config[key] = values[key]
	Engine.max_fps = int(config["fps"])
	bridge.cooldown_seconds = float(config["cooldown"])
	bridge.decision_timeout = float(config["timeout"])
	_write_config()
	sim.log_event("Zapisano ustawienia. Obowiązują od następnego zapytania.")

func _load_config() -> void:
	if not FileAccess.file_exists(SETTINGS):
		return
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(SETTINGS)) != OK or not parser.data is Dictionary:
		return
	var data: Dictionary = parser.data
	config["model"] = str(data.get("model", config["model"]))
	config["enabled"] = bool(data.get("enabled", true))
	config["cooldown"] = clampi(int(data.get("cooldown", data.get("decision_pause", 20))), 10, 120)
	config["fps"] = 30 if int(data.get("fps", 60)) == 30 else 60
	config["timeout"] = 120 if int(data.get("timeout", 45)) == 120 else 45
	config["guidance"] = str(data.get("guidance", config["guidance"])).left(1000)

func _write_config() -> void:
	var file := FileAccess.open(SETTINGS, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(config))
	else:
		sim.log_event("Nie udało się zapisać ustawień.")

func _save() -> void:
	if not sim.save_game():
		sim.log_event(sim.last_save)

func _export_logs() -> void:
	var path := "user://wioska_diagnostyka.txt"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		sim.log_event("Błąd eksportu dziennika.")
		return
	file.store_string("Wioska AI 0.2\nModel: %s\nStatus: %s\nFPS: %d\nOstatnia odpowiedź: %.1f s\n\n%s" % [bridge.model_name, status_detail, Engine.get_frames_per_second(), bridge.last_latency, "\n".join(sim.logs)])
	file.close()
	sim.log_event("Zapisano diagnostykę: " + ProjectSettings.globalize_path(path))
	OS.shell_open(ProjectSettings.globalize_path("user://"))

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			paused = not paused
		elif event.keycode >= KEY_1 and event.keycode <= KEY_5:
			_select(event.keycode - KEY_1)
		elif event.keycode == KEY_F2:
			ui.tabs.current_tab = 2

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save()
		get_tree().quit()
