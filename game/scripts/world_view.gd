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
	caption("JAGODY • źródło jedzenia", Vector2(90, 155))
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
	caption("DOM / BUDOWA", Vector2(245, 475), 14)
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
		draw_circle(point, 12, p["color"])
		draw_circle(point + Vector2(0, -12), 7, Color("f2d0a5"))
		caption(p["name"], point + Vector2(-20, -26), 14)
		var amount: int = p["cargo_food"] + p["cargo_wood"]
		if amount > 0:
			draw_rect(Rect2(point + Vector2(10, -3), Vector2(16, 16)), Color("d9ad63"))
			caption(str(amount), point + Vector2(14, 10), 13, Color("30271e"))
		if index == selected:
			caption(str(p["task"]), Vector2(clampf(point.x - 85, 10, 490), point.y + 37), 14, Color("fff0bb"))
	caption("Kliknij mieszkańca • złota linia pokazuje jego cel", Vector2(20, 530), 14, Color("b8c9ba"))
