extends Control

var PORT = 9999
var IP_ADDRESS = "127.0.0.1"

@onready var username_field: LineEdit = $ColorRect/HBoxContainer/ServerClientPanel/UsernameField
@onready var host_button: Button = $ColorRect/HBoxContainer/ServerClientPanel/HostButton
@onready var join_button: Button = $ColorRect/HBoxContainer/ServerClientPanel/JoinButton
@onready var chat_box: TextEdit = $ColorRect/HBoxContainer/ChatPanel/ChatBox
@onready var message_field: LineEdit = $ColorRect/HBoxContainer/ChatPanel/HBOX/MessgaeField
@onready var send_button: Button = $ColorRect/HBoxContainer/ChatPanel/HBOX/SendButton
@onready var username_label: Label = $ColorRect/HBoxContainer/ChatPanel/UsernameLabel
@onready var address_field: LineEdit = $ColorRect/HBoxContainer/ServerClientPanel/AddressField
@onready var port_field: LineEdit = $ColorRect/HBoxContainer/ServerClientPanel/PortField
@onready var upnp_check_box: CheckBox = $ColorRect/HBoxContainer/ServerClientPanel/UPNPCheckBox

var username: String
var message: String

func _ready() -> void:
	if ("--server") in OS.get_cmdline_args():
		_on_host_button_pressed()



func _on_host_button_pressed() -> void:
	var peer = ENetMultiplayerPeer.new()
	if port_field.text != "": PORT = port_field.text.to_int()
	peer.create_server(PORT)
	get_tree().set_multiplayer(SceneMultiplayer.new(), self.get_path())
	multiplayer.multiplayer_peer = peer
	
	print("[Server created on port: " + str(PORT) + "]")
	
	joined()

	if upnp_check_box.button_pressed: upnp_setup(PORT)


func _on_join_button_pressed() -> void:
	
	var peer = ENetMultiplayerPeer.new()
	if address_field.text != "": IP_ADDRESS = address_field.text
	if port_field.text != "": PORT = port_field.text.to_int()
	peer.create_client(IP_ADDRESS, PORT)
	get_tree().set_multiplayer(SceneMultiplayer.new(), self.get_path())
	multiplayer.multiplayer_peer = peer
	
	joined()


func _on_send_button_pressed() -> void:
	if message_field.text == "/list":
		chat_box.text += str(PeerManager.connected_peers, "\n")
		return
		
	msg_rpc.rpc(username, message_field.text)


@rpc("any_peer", "call_local", "unreliable", 1)
func msg_rpc(_username, data):
	chat_box.text += str("<", _username,":",multiplayer.get_remote_sender_id(), ">: ", data, "\n")


@rpc("any_peer", "call_local", "unreliable")
func add_peer(id, _username):
	if PeerManager.connected_peers.has(id): return
	#PeerManager.connected_peers[id] = _username
	send_peer_information.rpc_id(1, id, _username)
	# chat_box.text += PeerManager.connected_peers[id] + " has joined the server.\n"


@rpc("any_peer", "call_local")
func send_peer_information(id, usrname):
	if !PeerManager.connected_peers.has(id):
		PeerManager.connected_peers[id] = usrname
	else: return
		
	if multiplayer.is_server():
		for i in PeerManager.connected_peers:
			send_peer_information.rpc(i, PeerManager.connected_peers[i])
			# chat_box.text += str(i, " ", PeerManager.connected_peers[i])


func joined() -> void:
	$ColorRect/HBoxContainer/ServerClientPanel.hide()
	username = username_field.text
	username_label.text = str("ID: ", multiplayer.get_unique_id(), " USERNAME: ", username)
	await get_tree().create_timer(1).timeout
	add_peer.rpc(multiplayer.get_unique_id(), username)
	

func upnp_setup(_port):
	
	print("Using UPNP")
	
	var upnp = UPNP.new()
	
	var discover_result = upnp.discover()
	assert(discover_result == UPNP.UPNP_RESULT_SUCCESS, \
		"UPNP Discover Failed! Error %s" % discover_result)

	assert(upnp.get_gateway() and upnp.get_gateway().is_valid_gateway(), \
		"UPNP Invalid Gateway!")

	var map_result = upnp.add_port_mapping(_port)
	assert(map_result == UPNP.UPNP_RESULT_SUCCESS, \
		"UPNP Port Mapping Failed! Error %s" % map_result)

	print("Success! Join Address: %s" % upnp.query_external_address())
