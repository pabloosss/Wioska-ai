extends SceneTree
const Sim = preload("res://scripts/simulation.gd")
var checks := 0

func check(condition: bool, label: String) -> void:
	if not condition:
		push_error("FAIL: " + label)
		quit(1)
		assert(condition, label)
	checks += 1

func advance(sim: RefCounted, seconds: float) -> void:
	for i in range(int(seconds / 0.05)):
		sim.step(0.05)

func revisions(sim: RefCounted) -> Dictionary:
	var result: Dictionary = {}
	for p in sim.idle_snapshot():
		result[p["name"]] = p["revision"]
	return result

func _initialize() -> void:
	var sim := Sim.new()
	var plans: Array = []
	for p in sim.people:
		plans.append({"name": p["name"], "action": "gather_food", "reason": "Zapas", "next_actions": ["eat", "rest"]})
	var original_revisions := revisions(sim)
	check(sim.apply_decisions(plans, original_revisions) == 5, "five AI plans accepted")
	advance(sim, 4.0)
	check(sim.stock["food"] == 16, "no teleporting resource delivery")
	check(sim.apply_decisions([{"name": "Mira", "action": "rest"}], original_revisions) == 0, "busy task protected from stale AI response")
	advance(sim, 24.0)
	check(sim.delivered["food"] == 20, "all five villagers physically delivered four food")
	check(sim.stock["food"] == 36, "shared stock conserved; private meals used")
	check(sim.completed == 15, "all three-step AI plans completed")
	for p in sim.people:
		check(p["inventory"]["food"] == 0 and p["cargo_food"] == 0 and p["phase"] == "idle", "finite jobs with empty cargo: " + p["name"])
	advance(sim, 10.0)
	check(sim.stock["food"] == 36, "no invented work after plan ends")
	check(sim.apply_decisions(plans, original_revisions) == 0, "late response rejected even after job completion")
	var eater: Dictionary = sim.people[0]
	eater["position"] = Vector2(100, 100)
	sim.apply_decisions([{"name": "Mira", "action": "eat"}], revisions(sim))
	advance(sim, 1.0)
	check(sim.stock["food"] == 36, "meal requires walking to warehouse")
	advance(sim, 15.0)
	check(sim.stock["food"] == 35, "exactly one shared meal consumed")
	advance(sim, 10.0)
	check(sim.stock["food"] == 35, "meal not repeatedly consumed")
	sim.stock["food"] = 0
	sim.apply_decisions([{"name": "Mira", "action": "eat"}], revisions(sim))
	check(eater["phase"] == "idle" and eater["queue"].is_empty(), "no hidden fallback job when food missing")
	sim.apply_decisions([{"name": "Mira", "action": "gather_wood"}], revisions(sim))
	advance(sim, 9.0)
	var cargo_before := int(eater["cargo_wood"])
	check(cargo_before > 0, "save during cargo transport")
	check(sim.save_game("user://test_resume.json"), "save with backup")
	var restored := Sim.new()
	restored.load_game("user://test_resume.json")
	check(restored.people[0]["cargo_wood"] == cargo_before, "cargo restored")
	advance(restored, 20.0)
	check(restored.delivered["wood"] == 4, "restored AI job delivers exactly four")
	var wood_before := int(restored.stock["wood"])
	restored.apply_decisions([{"name": "Iga", "action": "build"}], revisions(restored))
	advance(restored, 20.0)
	check(restored.stock["wood"] == wood_before - 4 and restored.build_progress == 1, "finite construction consumes four wood")
	print("PASS simulation: ", checks, " assertions; complete haul/meal/build/plan/resume cycles")
	quit()
