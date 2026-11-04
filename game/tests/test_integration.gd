extends SceneTree
var checks := 0
func check(condition: bool, label: String) -> void:
	if not condition:
		push_error("FAIL: " + label)
		quit(1)
		assert(condition, label)
	checks += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var app = load("res://scripts/village.gd").new()
	root.add_child(app)
	app.speed = 2.0
	await create_timer(0.4).timeout
	check(app.ui.status_label.visible, "AI status always visible")
	check(app.simulation_step_count > 0, "simulation runs during AI request")
	await create_timer(8.0).timeout
	check(app.accepted_plans == 3, "three valid plans accepted")
	check(app.bridge.requests_finished == 1, "no requests during cooldown or busy jobs")
	check(app.sim.delivered["food"] == 12, "planned residents delivered food in running scene")
	check(app.sim.stock["food"] == 28, "warehouse stock matches deliveries and private meals")
	check(app.ui.timing_label.text.contains("s temu"), "last accepted plan visible")
	check(app.ui.summary_label.text.contains("jedzenie 12"), "delivery counter visible")
	check(app.bridge.last_latency >= 0.5, "latency measured")
	app.ui.tabs.current_tab = 4
	await process_frame
	check(app.ui.status_label.is_visible_in_tree(), "status survives tab switches")
	for index in range(app.ui.tabs.get_tab_count()):
		app.ui.tabs.current_tab = index
		await process_frame
		check(app.ui.status_label.is_visible_in_tree(), "status visible on tab " + str(index))
	app._select(1)
	check(app.ui.memory_text.text.begins_with("Olek"), "memory follows selected resident")
	check(app.ui.skill_bars["foraging"].value == 10, "UI shows earned skill XP")
	check(app.ui.need_bars["hunger"].value > 0, "UI need bar populated")
	app.ui.tabs.current_tab = 4
	check(app.ui.status_label.get_global_rect().end.y < 138, "status fits permanent header")
	check(app.ui.tabs.get_global_rect().end.x <= 1268 and app.ui.tabs.get_global_rect().end.y <= 706, "sidebar fits viewport")
	check(app.ui.need_bars["health"].value > 0, "health visible in inspector")
	check(app.ui.colony_text.text.contains("5 mieszkańców"), "colony overview reports population")
	check(app.ui.world_controls.size() == 10, "world options present")
	var next_batch: Array = app._planning_batch()
	check(next_batch[0]["name"] == "Tomasz" and next_batch[1]["name"] == "Iga", "idle residents rotate fairly")
	app._apply_world_settings({"births": false, "needs_percent": 50})
	check(not app.sim.life.options["births"] and app.sim.life.options["needs_percent"] == 50, "world controls update simulation")
	app._apply_settings({"cooldown": 10, "fps": 30, "timeout": 45, "guidance": "Zadbaj o jedzenie"})
	app._request_now()
	await create_timer(1.0).timeout
	check(app.bridge.request_errors == 1, "invalid JSON reported")
	check(app.accepted_plans == 3, "invalid JSON does not invent tasks")
	app.bridge.decision_timeout = 0.25
	app._request_now()
	await create_timer(0.8).timeout
	check(not app.bridge.is_busy and app.bridge.request_errors == 2, "timeout releases busy flag")
	check(app.ui.status_label.text.contains("Błąd AI"), "timeout visible on main screen")
	var before := int(app.simulation_step_count)
	await create_timer(0.4).timeout
	check(app.simulation_step_count > before, "simulation responsive after timeout")
	app.paused = true
	var elapsed_before := float(app.sim.elapsed)
	await create_timer(0.3).timeout
	check(app.sim.elapsed == elapsed_before, "pause stops world")
	app.bridge.decision_timeout = 45.0
	app._change_model("qwen3.5:35b")
	await create_timer(1.0).timeout
	check(app.bridge.model_name == "qwen3.5:35b" and app.bridge.is_ready, "model switching unloads old model and checks new")
	app.sim.people[0]["pregnancy_partner"] = "Olek"
	app.sim.life._birth(app.sim, app.sim.people[0])
	app._select(5)
	await process_frame
	check(app.ui.picker.item_count == 6 and app.ui.picker.selected == 5, "newborn appears and can be selected")
	check(app.ui.people_text.text.contains("Mira, Olek") and app.ui.colony_text.text.contains("6 mieszkańców"), "family and population visible after birth")
	app._save()
	check(app.sim.last_save.begins_with("Zapisano"), "save scene state")
	print("PASS integration: ", checks, " assertions; real scene, delayed/invalid/timed-out API, physical hauling, status, pause, model switch")
	app.queue_free()
	await process_frame
	quit()
