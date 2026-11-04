extends Node

signal status_changed(message: String)
signal decisions_received(decisions: Array)
signal models_received(models: Array)

@export var model_name := "qwen3.5:35b"
const OLLAMA_URL := "http://127.0.0.1:11434"
const LATEST_RELEASE_URL := "https://api.github.com/repos/ollama/ollama/releases/latest"
const RUNTIME_DIR := "user://wioska_ai_runtime"
const MODELS_DIR := "user://wioska_ai_runtime/models"

var http: HTTPRequest
var download_http: HTTPRequest
var probe_timer: Timer
var request_kind := ""
var is_busy := false
var is_ready := false
var runtime_download_queue: Array[Dictionary] = []
var runtime_download_index := 0
var runtime_download_path := ""
var runtime_download_active := false
var startup_attempts := 0
var process_attempted := false
var ollama_pid := -1
var last_download_progress := -1
var pending_model_check := false
var request_started_ms := 0
var last_latency := 0.0
var requests_finished := 0
var request_errors := 0
var next_request_ms := 0
var cooldown_seconds := 30.0
var response_tokens := 1024
var cpu_threads := 4
var context_tokens := 4096
var expected_names: Array = []


func _ready() -> void:
	http = HTTPRequest.new()
	http.timeout = 15.0
	http.use_threads = true
	http.request_completed.connect(_on_api_request_completed)
	add_child(http)
	download_http = HTTPRequest.new()
	download_http.timeout = 0.0
	download_http.use_threads = true
	download_http.request_completed.connect(_on_runtime_download_completed)
	add_child(download_http)
	probe_timer = Timer.new()
	probe_timer.wait_time = 2.0
	probe_timer.timeout.connect(_probe_server)
	add_child(probe_timer)
	connect_to_ollama()


func _process(_delta: float) -> void:
	if not runtime_download_active:
		return
	var total := download_http.get_body_size()
	var downloaded := download_http.get_downloaded_bytes()
	if total > 0:
		var percent := int(float(downloaded) * 100.0 / float(total))
		if percent != last_download_progress:
			last_download_progress = percent
			emit_signal("status_changed", "Pobieram lokalny silnik AI: %d%%" % percent)
	else:
		var downloaded_mb := int(downloaded / 1048576)
		if downloaded_mb != last_download_progress:
			last_download_progress = downloaded_mb
			emit_signal("status_changed", "Pobieram lokalny silnik AI… %d MB" % downloaded_mb)


func connect_to_ollama() -> void:
	if is_busy:
		return
	_request_tags()


func request_models() -> void:
	if is_busy:
		return
	is_busy = true
	request_kind = "models"
	var error := http.request(OLLAMA_URL + "/api/tags")
	if error != OK:
		is_busy = false
		request_kind = ""
		emit_signal("status_changed", "Nie udało się pobrać listy modeli")


func select_model(new_model: String) -> void:
	if new_model.is_empty() or new_model == model_name:
		return
	model_name = new_model
	is_ready = false
	emit_signal("status_changed", "Sprawdzam wybrany model: " + model_name)
	if is_busy:
		pending_model_check = true
		return
	_request_tags()


func _request_tags() -> void:
	if is_busy:
		return
	is_busy = true
	request_kind = "tags"
	http.timeout = 10.0
	var error := http.request(OLLAMA_URL + "/api/tags")
	if error != OK:
		is_busy = false
		request_kind = ""
		_handle_server_unavailable()


func _handle_server_unavailable() -> void:
	if process_attempted:
		if ollama_pid > 0 and not OS.is_process_running(ollama_pid):
			process_attempted = false
			ollama_pid = -1
		elif probe_timer.is_stopped():
			startup_attempts = 0
			probe_timer.start()
		return
	var installed_path := _find_installed_ollama()
	if not installed_path.is_empty():
		_start_ollama(installed_path, false)
		return
	var portable_path := _find_ollama_executable(ProjectSettings.globalize_path(RUNTIME_DIR))
	if not portable_path.is_empty():
		_start_ollama(portable_path, true)
		return
	_fetch_release_metadata()


func _find_installed_ollama() -> String:
	var local_app_data := OS.get_environment("LOCALAPPDATA")
	if local_app_data.is_empty():
		return ""
	var candidate := local_app_data.path_join("Programs/Ollama/ollama.exe")
	return candidate if FileAccess.file_exists(candidate) else ""


func _fetch_release_metadata() -> void:
	if is_busy:
		return
	is_busy = true
	request_kind = "release"
	http.timeout = 30.0
	emit_signal("status_changed", "Przygotowuję lokalny silnik AI…")
	var headers := PackedStringArray(["Accept: application/vnd.github+json"])
	var error := http.request(LATEST_RELEASE_URL, headers)
	if error != OK:
		is_busy = false
		request_kind = ""
		emit_signal("status_changed", "Nie udało się sprawdzić wydania Ollamy")


func _build_runtime_download_queue(release: Dictionary) -> bool:
	var assets: Array = release.get("assets", [])
	var needed := ["ollama-windows-amd64.zip"]
	var vendor := RenderingServer.get_video_adapter_vendor().to_lower()
	if vendor.contains("amd") or vendor.contains("advanced micro devices") or vendor.contains("ati"):
		needed.append("ollama-windows-amd64-rocm.zip")
	runtime_download_queue.clear()
	for asset_name in needed:
		var found := false
		for asset in assets:
			if str(asset.get("name", "")) == asset_name:
				runtime_download_queue.append({
					"name": asset_name,
					"url": str(asset.get("browser_download_url", "")),
					"digest": str(asset.get("digest", ""))
				})
				found = true
				break
		if not found:
			return false
	return true


func _download_next_runtime_archive() -> void:
	if runtime_download_index >= runtime_download_queue.size():
		runtime_download_active = false
		var executable := _find_ollama_executable(ProjectSettings.globalize_path(RUNTIME_DIR))
		if executable.is_empty():
			emit_signal("status_changed", "Nie znaleziono pliku Ollamy po rozpakowaniu")
			return
		_start_ollama(executable, true)
		return
	var item: Dictionary = runtime_download_queue[runtime_download_index]
	var cache_dir := ProjectSettings.globalize_path(RUNTIME_DIR)
	DirAccess.make_dir_recursive_absolute(cache_dir)
	runtime_download_path = RUNTIME_DIR.path_join(str(item["name"]))
	var absolute_path := ProjectSettings.globalize_path(runtime_download_path)
	var existing_digest: String = _sha256_file(absolute_path)
	var expected_digest: String = str(item["digest"]).trim_prefix("sha256:")
	if not expected_digest.is_empty() and existing_digest == expected_digest:
		if not _extract_archive(absolute_path):
			emit_signal("status_changed", "Nie udało się rozpakować silnika AI")
			return
		DirAccess.remove_absolute(absolute_path)
		runtime_download_index += 1
		_download_next_runtime_archive()
		return
	if not expected_digest.is_empty() and not existing_digest.is_empty():
		DirAccess.remove_absolute(absolute_path)
	download_http.download_file = absolute_path
	runtime_download_active = true
	emit_signal("status_changed", "Pobieram lokalny silnik AI…")
	var error := download_http.request(str(item["url"]))
	if error != OK:
		runtime_download_active = false
		emit_signal("status_changed", "Nie udało się pobrać silnika Ollama")


func _on_runtime_download_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	runtime_download_active = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		emit_signal("status_changed", "Pobieranie silnika AI przerwane (%d)" % response_code)
		return
	var item: Dictionary = runtime_download_queue[runtime_download_index]
	var expected_digest: String = str(item["digest"]).trim_prefix("sha256:")
	var actual_digest: String = _sha256_file(ProjectSettings.globalize_path(runtime_download_path))
	if not expected_digest.is_empty() and actual_digest != expected_digest:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(runtime_download_path))
		emit_signal("status_changed", "Weryfikacja pobranego silnika AI nie powiodła się")
		return
	if not _extract_archive(ProjectSettings.globalize_path(runtime_download_path)):
		emit_signal("status_changed", "Nie udało się rozpakować silnika AI")
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(runtime_download_path))
	runtime_download_index += 1
	_download_next_runtime_archive()


func _extract_archive(archive_path: String) -> bool:
	var reader := ZIPReader.new()
	if reader.open(archive_path) != OK:
		return false
	var destination := ProjectSettings.globalize_path(RUNTIME_DIR)
	DirAccess.make_dir_recursive_absolute(destination)
	for entry_path in reader.get_files():
		var relative_path := str(entry_path).trim_prefix("/")
		if relative_path.begins_with("..") or relative_path.contains("/../"):
			continue
		var output_path := destination.path_join(relative_path)
		if relative_path.ends_with("/"):
			DirAccess.make_dir_recursive_absolute(output_path)
			continue
		DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
		var output_file := FileAccess.open(output_path, FileAccess.WRITE)
		if output_file == null:
			reader.close()
			return false
		output_file.store_buffer(reader.read_file(entry_path))
	reader.close()
	return true


func _sha256_file(file_path: String) -> String:
	if not FileAccess.file_exists(file_path):
		return ""
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return ""
	var hashing := HashingContext.new()
	if hashing.start(HashingContext.HASH_SHA256) != OK:
		return ""
	while not file.eof_reached():
		var chunk := file.get_buffer(1048576)
		if chunk.is_empty():
			break
		hashing.update(chunk)
	return hashing.finish().hex_encode()


func _find_ollama_executable(directory_path: String) -> String:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return ""
	for file_name in directory.get_files():
		if file_name.to_lower() == "ollama.exe":
			return directory_path.path_join(file_name)
	for child_name in directory.get_directories():
		if child_name.begins_with("."):
			continue
		var found := _find_ollama_executable(directory_path.path_join(child_name))
		if not found.is_empty():
			return found
	return ""


func _start_ollama(executable_path: String, portable: bool) -> void:
	if process_attempted:
		return
	process_attempted = true
	var models_path := ProjectSettings.globalize_path(MODELS_DIR)
	DirAccess.make_dir_recursive_absolute(models_path)
	OS.set_environment("OLLAMA_HOST", "127.0.0.1:11434")
	if portable:
		OS.set_environment("OLLAMA_MODELS", models_path)
	emit_signal("status_changed", "Uruchamiam lokalny silnik AI…")
	ollama_pid = OS.create_process(executable_path, PackedStringArray(["serve"]), false)
	if ollama_pid < 0:
		process_attempted = false
		emit_signal("status_changed", "Nie udało się uruchomić Ollamy")
		return
	startup_attempts = 0
	probe_timer.start()


func _probe_server() -> void:
	if is_busy:
		return
	startup_attempts += 1
	if startup_attempts > 60:
		probe_timer.stop()
		emit_signal("status_changed", "Silnik AI nie odpowiada; naciśnij R, aby spróbować ponownie")
		return
	_request_tags()


func _pull_model() -> void:
	if is_busy:
		return
	is_busy = true
	request_kind = "pull"
	http.timeout = 0.0
	emit_signal("status_changed", "Pobieram model %s — pierwsze uruchomienie może potrwać długo" % model_name)
	var headers := PackedStringArray(["Content-Type: application/json"])
	var body := JSON.stringify({"model": model_name, "stream": false})
	var error := http.request(OLLAMA_URL + "/api/pull", headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		is_busy = false
		request_kind = ""
		emit_signal("status_changed", "Nie udało się rozpocząć pobierania modelu")


func _extract_decision_answer(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return _normalise_decision_answer(value)
	if typeof(value) == TYPE_ARRAY:
		return _normalise_decision_answer({"decisions": value})
	if typeof(value) != TYPE_STRING:
		return {}

	var response := str(value).strip_edges()
	if response.is_empty():
		return {}
	if response.begins_with("```"):
		var first_newline := response.find("\n")
		if first_newline >= 0:
			response = response.substr(first_newline + 1)
		if response.ends_with("```"):
			response = response.trim_suffix("```").strip_edges()

	var parsed: Variant = JSON.parse_string(response)
	if typeof(parsed) == TYPE_DICTIONARY or typeof(parsed) == TYPE_ARRAY:
		return _normalise_decision_answer(parsed)

	var object_start := response.find("{")
	var object_end := response.rfind("}")
	if object_start >= 0 and object_end > object_start:
		parsed = JSON.parse_string(response.substr(object_start, object_end - object_start + 1))
		if typeof(parsed) == TYPE_DICTIONARY or typeof(parsed) == TYPE_ARRAY:
			return _normalise_decision_answer(parsed)

	var array_start := response.find("[")
	var array_end := response.rfind("]")
	if array_start >= 0 and array_end > array_start:
		parsed = JSON.parse_string(response.substr(array_start, array_end - array_start + 1))
		if typeof(parsed) == TYPE_ARRAY:
			return _normalise_decision_answer(parsed)
	return {}


func _normalise_decision_answer(raw_answer: Variant) -> Dictionary:
	var raw_decisions: Array = []
	if typeof(raw_answer) == TYPE_ARRAY:
		raw_decisions = raw_answer
	elif typeof(raw_answer) == TYPE_DICTIONARY:
		if raw_answer.get("decisions") is Array:
			raw_decisions = raw_answer.get("decisions", [])
		elif raw_answer.get("actions") is Array:
			raw_decisions = raw_answer.get("actions", [])
		elif raw_answer.get("residents") is Array:
			raw_decisions = raw_answer.get("residents", [])
		elif raw_answer.has("name") or raw_answer.has("resident") or raw_answer.has("villager"):
			raw_decisions = [raw_answer]
		else:
			for person_name in raw_answer.keys():
				var person_action: Variant = raw_answer[person_name]
				if typeof(person_action) == TYPE_DICTIONARY:
					var named_action: Dictionary = person_action.duplicate()
					named_action["name"] = str(person_action.get("name", person_name))
					raw_decisions.append(named_action)
	if raw_decisions.is_empty():
		return {}

	var normalised: Array = []
	for raw_decision in raw_decisions:
		if typeof(raw_decision) != TYPE_DICTIONARY:
			continue
		var person_name := str(raw_decision.get("name", raw_decision.get("resident", raw_decision.get("resident_name", raw_decision.get("villager", raw_decision.get("npc", raw_decision.get("person", ""))))))).strip_edges()
		var raw_action := str(raw_decision.get("action", raw_decision.get("decision", raw_decision.get("choice", raw_decision.get("task", "work"))))).to_lower().strip_edges()
		var action := raw_action
		if person_name.is_empty() or not ["work", "gather_food", "gather_wood", "build", "deliver", "eat", "rest", "warm", "wait"].has(raw_action):
			continue
		if ["eat", "food", "je", "jedz", "jedzenie", "eat_food"].has(raw_action):
			action = "eat"
		elif ["rest", "sleep", "odpoczywa", "odpoczynek", "śpi", "spij"].has(raw_action):
			action = "rest"
		elif ["warm", "heat", "warm_up", "grzeje", "grzeje się", "ogrzewanie"].has(raw_action):
			action = "warm"
		var reason := str(raw_decision.get("reason", raw_decision.get("why", raw_decision.get("thought", "Działanie wybrane na podstawie potrzeb i pracy."))))
		normalised.append({"name": person_name, "action": action, "reason": reason})
	return {"decisions": normalised}


func _on_api_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var completed_kind := request_kind
	if completed_kind == "chat":
		last_latency = float(Time.get_ticks_msec() - request_started_ms) / 1000.0
		requests_finished += 1
		next_request_ms = Time.get_ticks_msec() + int(maxf(cooldown_seconds, last_latency * 0.5) * 1000.0)
		if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
			request_errors += 1
	request_kind = ""
	is_busy = false
	if pending_model_check:
		pending_model_check = false
		call_deferred("_request_tags")
	var request_ok := result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300
	if completed_kind == "release":
		if not request_ok:
			emit_signal("status_changed", "Nie udało się pobrać informacji o silniku AI")
			return
		var release_data: Variant = JSON.parse_string(body.get_string_from_utf8())
		if typeof(release_data) != TYPE_DICTIONARY or not _build_runtime_download_queue(release_data):
			emit_signal("status_changed", "Nie znaleziono odpowiedniego pakietu Ollamy dla tego komputera")
			return
		runtime_download_index = 0
		_download_next_runtime_archive()
		return
	if completed_kind == "models":
		if not request_ok:
			emit_signal("status_changed", "Nie udało się pobrać listy modeli z Ollamy")
			return
		var model_data: Variant = JSON.parse_string(body.get_string_from_utf8())
		if typeof(model_data) != TYPE_DICTIONARY:
			emit_signal("status_changed", "Nie udało się odczytać listy modeli")
			return
		var installed_models: Array = []
		for installed_model in model_data.get("models", []):
			installed_models.append(str(installed_model.get("name", "")))
		emit_signal("models_received", installed_models)
		return
	if completed_kind == "tags":
		if not request_ok:
			if not process_attempted:
				_handle_server_unavailable()
			elif not probe_timer.is_stopped():
				emit_signal("status_changed", "Uruchamiam lokalny silnik AI…")
			return
		var tag_data: Variant = JSON.parse_string(body.get_string_from_utf8())
		if typeof(tag_data) != TYPE_DICTIONARY:
			emit_signal("status_changed", "Nie udało się odczytać listy lokalnych modeli")
			return
		var found_model := false
		for model in tag_data.get("models", []):
			if str(model.get("name", "")) == model_name:
				found_model = true
				break
		if found_model:
			probe_timer.stop()
			is_ready = true
			emit_signal("status_changed", "AI: aktywna — " + model_name)
		else:
			probe_timer.stop()
			_pull_model()
		return
	if completed_kind == "pull":
		if not request_ok:
			is_ready = false
			emit_signal("status_changed", "Nie udało się pobrać modelu %s (%d)" % [model_name, response_code])
			return
		is_ready = true
		emit_signal("status_changed", "AI: gotowa — " + model_name)
		return
	if completed_kind == "chat":
		if not request_ok:
			emit_signal("status_changed", "AI: błąd zapytania do modelu (%d)" % response_code)
			return
		var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
		if typeof(parsed) != TYPE_DICTIONARY:
			emit_signal("status_changed", "AI: Ollama zwróciła nieczytelną odpowiedź")
			return
		var message: Dictionary = parsed.get("message", {})
		var content_value: Variant = message.get("content", "")
		var content_text := str(content_value)
		if content_text.strip_edges().is_empty():
			content_text = ""
		var answer := _extract_decision_answer(content_value)
		if answer.is_empty():
			answer = _extract_decision_answer(content_text)
		var decisions: Array = answer.get("decisions", [])
		var validated: Array = []
		var seen: Array = []
		for decision in decisions:
			var decision_name := str(decision.get("name", ""))
			if expected_names.has(decision_name) and not seen.has(decision_name):
				validated.append(decision)
				seen.append(decision_name)
		decisions = validated
		if decisions.is_empty():
			request_errors += 1
			var preview := content_text.strip_edges().replace("\n", " ")
			if preview.is_empty():
				preview = "pusta odpowiedź"
			if preview.length() > 90:
				preview = preview.substr(0, 90) + "…"
			emit_signal("status_changed", "AI: nie odczytałem decyzji — " + preview)
			return
		is_ready = true
		emit_signal("status_changed", "AI: aktywna — " + model_name)
		emit_signal("decisions_received", decisions)


func request_decisions(world_state: Dictionary, people: Array, ai_temperature: float = 0.2, behavior_guidance: String = "") -> void:
	if not is_ready or is_busy:
		return
	is_busy = true
	request_kind = "chat"
	http.timeout = 120.0
	request_started_ms = Time.get_ticks_msec()
	expected_names.clear()
	for person in people:
		expected_names.append(str(person.get("name", "")))
	emit_signal("status_changed", "AI planuje zadania mieszkańców…")
	var schema := {
		"type": "object",
		"properties": {
			"decisions": {
				"type": "array",
				"items": {
					"type": "object",
					"properties": {
						"name": {"type": "string"},
						"action": {"type": "string", "enum": ["gather_food", "gather_wood", "build", "deliver", "eat", "rest", "warm", "wait"]},
						"reason": {"type": "string"}
					},
					"required": ["name", "action", "reason"]
				}
			}
		},
		"required": ["decisions"]
	}
	var system_prompt := "Jesteś wspólnym lokalnym AI zarządzającym małą wioską. Podejmujesz decyzję osobno dla każdego mieszkańca na podstawie jego charakteru, potrzeb, pracy, ekwipunku i wspomnień. Sam wybierasz zadania: gather_food (zbierz i zanieś jedzenie), gather_wood (zbierz i zanieś drewno), build (buduj za 4 drewna), deliver (odnieś ładunek), eat (zjedz jedną porcję), rest, warm, wait. Każdy może zbierać dowolny zasób. Zawód to specjalizacja. Jeśli nie ma jedzenia, skieruj część mieszkańców do gather_food. Nie wybieraj eat przy sytości ponad 70. Nie wybieraj build bez drewna. Uwzględniaj trwające zadania: nie przerywaj ciągle dojścia na miejsce. Gra nie podejmie za ciebie decyzji. Nie zmieniaj bezpośrednio zasobów ani świata. Jeżeli mieszkaniec jest głodny i ma dostęp do jedzenia, wybierz eat; jeżeli jest zmęczony, rest; jeżeli marznie, warm. W pozostałych sytuacjach wybierz konkretne potrzebne zadanie. Zwróć wyłącznie JSON zgodny ze schematem."
	if not behavior_guidance.strip_edges().is_empty():
		system_prompt += " Dodatkowe wskazówki użytkownika: " + behavior_guidance.strip_edges()
	var user_data := {
		"world": world_state,
		"residents": people,
		"instruction": "Zwróć dokładnie obiekt JSON z kluczem decisions, zawierający po jednym elemencie dla każdego mieszkańca. Każdy element ma pola name, action (gather_food, gather_wood, build, deliver, eat, rest, warm lub wait) i reason. Uzasadnienie krótko po polsku. Wybierz jedną rozsądną czynność dla każdego mieszkańca."
	}
	var body := {
		"model": model_name,
		"messages": [
			{"role": "system", "content": system_prompt},
			{"role": "user", "content": JSON.stringify(user_data)}
		],
		"stream": false,
		"think": false,
		"format": schema,
		"options": {"temperature": ai_temperature, "num_predict": response_tokens, "num_ctx": context_tokens, "num_thread": cpu_threads},
		"keep_alive": "10m"
	}
	var headers := PackedStringArray(["Content-Type: application/json"])
	var error := http.request(OLLAMA_URL + "/api/chat", headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if error != OK:
		is_busy = false
		request_kind = ""
		request_errors += 1
		next_request_ms = Time.get_ticks_msec() + 30000
		emit_signal("status_changed", "AI: nie udało się wysłać zapytania")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and ollama_pid > 0 and OS.is_process_running(ollama_pid):
		OS.kill(ollama_pid)



func cancel_decision() -> void:
	if request_kind != "chat":
		return
	http.cancel_request()
	request_kind = ""
	is_busy = false
	next_request_ms = Time.get_ticks_msec() + int(cooldown_seconds * 1000.0)
	emit_signal("status_changed", "Przerwano oczekiwanie. Ollama może jeszcze kończyć obliczenia.")
