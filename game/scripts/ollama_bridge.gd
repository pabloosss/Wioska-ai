extends Node

signal status_changed(message: String)
signal decisions_received(decisions: Array)

@export var model_name := "qwen3.5:35b"
const OLLAMA_URL := "http://127.0.0.1:11434"

var http: HTTPRequest
var is_busy := false
var is_ready := false
var request_kind := ""

func _ready() -> void:
	http = HTTPRequest.new()
	http.timeout = 90.0
	http.request_completed.connect(_on_request_completed)
	add_child(http)
	connect_to_ollama()

func connect_to_ollama() -> void:
	if is_busy:
		return
	is_ready = false
	is_busy = true
	request_kind = "tags"
	emit_signal("status_changed", "AI: sprawdzam Ollamę…")
	var error := http.request(OLLAMA_URL + "/api/tags")
	if error != OK:
		is_busy = false
		request_kind = ""
		emit_signal("status_changed", "AI: Ollama niedostępna")

func request_decisions(world_state: Dictionary, people: Array) -> void:
	if not is_ready or is_busy:
		return
	is_busy = true
	request_kind = "chat"
	var schema := {
		"type": "object",
		"properties": {
			"decisions": {
				"type": "array",
				"items": {
					"type": "object",
					"properties": {
						"name": {"type": "string"},
						"action": {"type": "string", "enum": ["work", "eat", "rest", "warm"]},
						"reason": {"type": "string"}
					},
					"required": ["name", "action", "reason"]
				}
			}
		},
		"required": ["decisions"]
	}
	var system_prompt := "Jesteś wspólnym lokalnym AI zarządzającym małą wioską. Podejmujesz decyzję osobno dla każdego mieszkańca na podstawie jego charakteru, potrzeb, pracy, ekwipunku i wspomnień. Wybieraj tylko: work, eat, rest, warm. Nie zmieniaj bezpośrednio zasobów ani świata. Jeżeli mieszkaniec jest głodny i ma dostęp do jedzenia, wybierz eat; jeżeli jest zmęczony, rest; jeżeli marznie, warm. W pozostałych sytuacjach wybierz work. Zwróć wyłącznie JSON zgodny ze schematem."
	var user_data := {
		"world": world_state,
		"residents": people,
		"instruction": "Wybierz jedną rozsądną czynność dla każdego mieszkańca. Krótkie uzasadnienie po polsku."
	}
	var body := {
		"model": model_name,
		"messages": [
			{"role": "system", "content": system_prompt},
			{"role": "user", "content": JSON.stringify(user_data)}
		],
		"stream": false,
		"format": schema,
		"options": {"temperature": 0.2, "num_predict": 512},
		"keep_alive": "10m"
	}
	var headers := PackedStringArray(["Content-Type: application/json"])
	var error := http.request(OLLAMA_URL + "/api/chat", headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if error != OK:
		is_busy = false
		request_kind = ""
		emit_signal("status_changed", "AI: nie udało się wysłać zapytania")

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var completed_kind := request_kind
	request_kind = ""
	is_busy = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		if completed_kind == "tags":
			is_ready = false
		emit_signal("status_changed", "AI: błąd połączenia z Ollamą (%d)" % response_code)
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		emit_signal("status_changed", "AI: Ollama zwróciła nieczytelną odpowiedź")
		return
	if completed_kind == "tags":
		var found_model := false
		var models: Array = parsed.get("models", [])
		for model in models:
			var installed_name: String = str(model.get("name", ""))
			if installed_name == model_name:
				found_model = true
				break
		if found_model:
			is_ready = true
			emit_signal("status_changed", "AI: aktywna — " + model_name)
		else:
			is_ready = false
			emit_signal("status_changed", "AI: brak modelu " + model_name)
		return
	if completed_kind == "chat":
		var message: Dictionary = parsed.get("message", {})
		var content_text: String = str(message.get("content", ""))
		var answer: Variant = JSON.parse_string(content_text)
		if typeof(answer) != TYPE_DICTIONARY or not answer.has("decisions"):
			emit_signal("status_changed", "AI: odpowiedź nie pasuje do schematu")
			return
		is_ready = true
		emit_signal("status_changed", "AI: aktywna — " + model_name)
		emit_signal("decisions_received", answer.get("decisions", []))