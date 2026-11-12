extends Button
## Opens the Moonetix offerwall with a link your server signed for the signed-in player.
## The game never builds the hash itself: that would ship the link salt inside the export.

signal message(text: String)

const WALL_PREFIX := "https://wall.moonetix.com/"

var http := HTTPRequest.new()
var _link := ""
var _open_when_ready := false


func _ready() -> void:
	# Valve does not allow offerwalls in Steam games. Export Steam builds with the
	# custom feature tag "steam" and leave the earn screen out of that preset too.
	if OS.has_feature("steam"):
		queue_free()
		return
	add_child(http)
	http.request_completed.connect(_on_link_received)
	pressed.connect(_on_pressed)
	PlayerSession.sign_in_finished.connect(_on_sign_in_finished)
	PlayerSession.signed_out.connect(_on_signed_out)
	_prefetch()


# Web exports open the link with window.open, which browsers allow only in direct response
# to a click. So the link is fetched ahead of time and opened right in the pressed handler.
func _prefetch() -> void:
	if PlayerSession.is_signed_in() and _link == "":
		http.request(PlayerSession.SERVER_URL + "/api/offerwall-link", PlayerSession.auth_headers())


func _on_pressed() -> void:
	if _link != "":
		OS.shell_open(_link)
		return
	if not PlayerSession.is_signed_in():
		message.emit("Confirm your age first.")
		return
	_open_when_ready = true
	disabled = true
	var err := http.request(PlayerSession.SERVER_URL + "/api/offerwall-link", PlayerSession.auth_headers())
	if err != OK and err != ERR_BUSY:
		_fail()


func _on_link_received(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	disabled = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		if response_code == 401:
			PlayerSession.sign_out()
		_fail()
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY or not data.has("url"):
		_fail()
		return
	var url := str(data["url"])
	# Only ever open Moonetix links, even if a bad response comes back.
	if not url.begins_with(WALL_PREFIX):
		_fail()
		return
	_link = url
	if _open_when_ready:
		_open_when_ready = false
		OS.shell_open(_link)


func _fail() -> void:
	disabled = false
	if _open_when_ready:
		_open_when_ready = false
		message.emit("Offers are not available right now.")


func _on_sign_in_finished(ok: bool) -> void:
	if ok:
		_prefetch()


func _on_signed_out() -> void:
	_link = ""
