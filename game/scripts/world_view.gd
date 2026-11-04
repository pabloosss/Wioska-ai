extends Node2D
signal person_selected(index: int)
var simulation: RefCounted
var selected := 0
var show_paths := true

func caption(value: String, at: Vector2, size: int = 15, color: Color = Color.WHITE) -> void:
	draw_string(ThemeDB.fallback_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var point := get_local_mouse_position()
		for index in range(simulation.people.size()):
			if point.distance_to(simulation.people[index]["position"]) < 22:
				person_selected.emit(index)
				get_viewport().set_input_as_handled()

func _draw() -> void:
	if simulation == null:
		return
	draw_rect(Rect2(0, 0, 790, 550), Color("243c31"))
	for x in range(20, 790, 40):
		for y in range(20, 550, 40):
			draw_circle(Vector2(x, y), 1, Color("35523d"))
	draw_line(Vector2(185, 235), Vector2(445, 370), Color("665e43"), 28)
	draw_line(Vector2(650, 210), Vector2(445, 370), Color("665e43"), 28)
	draw_line(Vector2(315, 440), Vector2(575, 435), Color("665e43"), 28)
	# Visible resource sites, distinct from the warehouse and home.
	draw_rect(Rect2(100, 175, 160, 90), Color("4a6437"))
	for x in range(120, 255, 30):
		for y in range(190, 255, 28):
			draw_circle(Vector2(x, y), 11, Color("426d46"))
			draw_circle(Vector2(x - 3, y - 3), 3, Color("e4906e"))
	caption("JAGODY • %d / 60" % simulation.life.berries, Vector2(90, 155))
	draw_rect(Rect2(90, 315, 150, 90), Color("795c3c"))
	for row_y in range(330, 400, 17):
		draw_line(Vector2(100, row_y), Vector2(230, row_y), Color("95a665"), 4)
	caption("POLE • uprawa", Vector2(95, 300))
	caption("WARTA", Vector2(665, 320), 14)
	draw_circle(Vector2(690, 350), 22, Color("527075"))
	for point in [Vector2(625, 180), Vector2(690, 200), Vector2(675, 130)]:
		draw_rect(Rect2(point + Vector2(-5, 0), Vector2(10, 35)), Color("a07c4b"))
		draw_circle(point, 26, Color("4e8158"))
	caption("LAS • drewno", Vector2(590, 100))
	draw_rect(Rect2(405, 300, 85, 60), Color("be995e"))
	draw_rect(Rect2(430, 320, 25, 40), Color("564336"))
	caption("MAGAZYN", Vector2(399, 282), 18, Color("f4d99b"))
	caption("Jedzenie %d | drewno %d" % [simulation.stock["food"], simulation.stock["wood"]], Vector2(350, 395), 14)
	draw_rect(Rect2(265, 380, 90, 55), Color("8b7160"))
	draw_colored_polygon(PackedVector2Array([Vector2(250, 385), Vector2(310, 350), Vector2(370, 385)]), Color("c78061"))
	caption("DOMY %d • MIEJSCA %d" % [simulation.houses, simulation.houses * 4], Vector2(220, 475), 14)
	draw_circle(Vector2(575, 435), 24, Color("735b43"))
	draw_circle(Vector2(575, 435), 15, Color("f09a56"))
	draw_circle(Vector2(575, 430), 8, Color("ffe09b"))
	caption("OGNISKO", Vector2(540, 480), 14)
	for index in range(simulation.people.size()):
		var p: Dictionary = simulation.people[index]
		var point: Vector2 = p["position"]
		if index == selected and show_paths and str(p["phase"]).begins_with("to_"):
			draw_line(point, p["target"], Color("d8be78", 0.5), 2)
			draw_arc(p["target"], 8, 0, TAU, 20, Color("d8be78"), 2)
		if index == selected:
			draw_arc(point, 20, 0, TAU, 24, Color("ffe3a0"), 3)
		draw_circle(point + Vector2(2, 7), 14, Color(0, 0, 0, 0.25))
		if not p["alive"]:
			draw_rect(Rect2(point + Vector2(-7, -10), Vector2(14, 20)), Color("89928a"))
			caption(p["name"], point + Vector2(-20, -20), 12, Color("aab6ac"))
			continue
		draw_circle(point, 8 if p["age"] < 18 else 12, p["color"])
		if p["health"] < 50:
			draw_line(point + Vector2(-12, 20), point + Vector2(12, 20), Color("442c29"), 4)
			draw_line(point + Vector2(-12, 20), point + Vector2(-12 + p["health"] * 0.24, 20), Color("e7816c"), 4)
		draw_circle(point + Vector2(0, -12), 7, Color("f2d0a5"))
		caption(p["name"], point + Vector2(-20, -26), 14)
		var amount: int = p["cargo_food"] + p["cargo_wood"]
		if amount > 0:
			draw_rect(Rect2(point + Vector2(10, -3), Vector2(16, 16)), Color("d9ad63"))
			caption(str(amount), point + Vector2(14, 10), 13, Color("30271e"))
		if index == selected:
			caption(str(p["task"]), Vector2(clampf(point.x - 85, 10, 490), point.y + 37), 14, Color("fff0bb"))
	var danger: bool = not str(simulation.life.threat["kind"]).is_empty()
	draw_rect(Rect2(10, 10, 770, 64), Color("533b35") if danger else Color("192e25"))
	caption("%s  •  mieszkańcy %d  •  wolne miejsca %d" % [simulation.life.threat_label(), simulation.life.living(simulation).size(), simulation.life.free_beds(simulation)], Vector2(24, 36), 19, Color("f2b49a") if danger else Color("e6d4a5"))
	var alerts: Array = simulation.life.alerts(simulation)
	caption(str(alerts[0]) if not alerts.is_empty() else "Osada ma zapasy. AI może rozwijać domy, relacje i umiejętności.", Vector2(24, 60), 13, Color("d3d9c5"))
	if simulation.life.threat["kind"] == "wolves":
		for wolf_y in [375, 400, 425]:
			draw_circle(Vector2(740, wolf_y), 10, Color("a9b3b0"))
			draw_circle(Vector2(728, wolf_y - 4), 6, Color("c5cfca"))
	caption("Kliknij mieszkańca • złota linia pokazuje jego cel", Vector2(20, 530), 14, Color("b8c9ba"))
