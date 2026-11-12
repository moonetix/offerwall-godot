extends Node
## Loads the balance from your server. Rewards reach your server by postback, never through the game,
## so the game only reads the balance: when it starts, when it gets focus back, and every few seconds.

signal changed(balance: String, currency: String, player_id: int)

const POLL_SECONDS := 15.0

var http := HTTPRequest.new()
var timer := Timer.new()


func _ready() -> void:
	add_child(http)
	http.request_completed.connect(_on_balance_received)
	timer.wait_time = POLL_SECONDS
	timer.timeout.connect(refresh)
	add_child(timer)
	timer.start()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		refresh()


func refresh() -> void:
	if not PlayerSession.is_signed_in():
		return
	# ERR_BUSY means a request is still running. Its answer is fresh enough.
	http.request(PlayerSession.SERVER_URL + "/api/balance", PlayerSession.auth_headers())


func _on_balance_received(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		return
	if response_code == 401:
		PlayerSession.sign_out()
		return
	if response_code != 200:
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY or not data.has("balance"):
		return
	changed.emit(str(data["balance"]), str(data.get("currency", "Coins")), int(data.get("player_id", 0)))
