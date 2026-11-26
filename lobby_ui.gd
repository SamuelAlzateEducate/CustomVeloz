extends Control

@export_file("*.tscn") var escena_carrera: String = "res://zona_c.tscn"

@onready var btn_jugar: Button = get_node_or_null("MargenUI/VBoxIzquierda/VBoxBotones/BtnJugar")
@onready var btn_dos_j: Button = get_node_or_null("MargenUI/VBoxIzquierda/VBoxBotones/BtnDosJugadores")
@onready var btn_salir: Button = get_node_or_null("MargenUI/VBoxIzquierda/VBoxBotones/BtnSalir")
@onready var audio_ui: AudioStreamPlayer = get_node_or_null("AudioUI")

var musica_lobby: AudioStreamPlayer = null
var _cambiando_escena: bool = false

func _ready() -> void:
	ConfigJuego.dos_jugadores = false
	ConfigJuego.ganador = 0
	_iniciar_musica_lobby()

	if btn_jugar:
		btn_jugar.pivot_offset = btn_jugar.size / 2.0
		btn_jugar.pressed.connect(_on_btn_jugar_pressed)
		btn_jugar.mouse_entered.connect(_on_btn_mouse_entered.bind(btn_jugar))
		btn_jugar.mouse_exited.connect(_on_btn_mouse_exited.bind(btn_jugar))
	
	if btn_dos_j:
		btn_dos_j.pivot_offset = btn_dos_j.size / 2.0
		btn_dos_j.pressed.connect(_on_btn_dos_j_pressed)
		btn_dos_j.mouse_entered.connect(_on_btn_mouse_entered.bind(btn_dos_j))
		btn_dos_j.mouse_exited.connect(_on_btn_mouse_exited.bind(btn_dos_j))

	if btn_salir:
		btn_salir.pivot_offset = btn_salir.size / 2.0
		btn_salir.pressed.connect(_on_btn_salir_pressed)
		btn_salir.mouse_entered.connect(_on_btn_mouse_entered.bind(btn_salir))
		btn_salir.mouse_exited.connect(_on_btn_mouse_exited.bind(btn_salir))

func _on_btn_mouse_entered(btn: Button) -> void:
	btn.pivot_offset = btn.size / 2.0
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.15)

func _on_btn_mouse_exited(btn: Button) -> void:
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.15)

func _iniciar_musica_lobby() -> void:
	musica_lobby = AudioStreamPlayer.new()
	musica_lobby.name = "MusicaLobby"
	var ruta_musica := "res://SonidoLobby.mp3"
	if ResourceLoader.exists(ruta_musica):
		var stream := load(ruta_musica)
		if stream is AudioStreamMP3:
			stream.loop = true
		musica_lobby.stream = stream
	musica_lobby.volume_db = -8.0
	musica_lobby.bus = "Master"
	add_child(musica_lobby)
	musica_lobby.play()

func _on_btn_jugar_pressed() -> void:
	if _cambiando_escena:
		return
	_cambiando_escena = true
	ConfigJuego.dos_jugadores = false
	ConfigJuego.ganador = 0
	if musica_lobby and is_instance_valid(musica_lobby) and musica_lobby.playing:
		var tw := create_tween()
		tw.tween_property(musica_lobby, "volume_db", -40.0, 0.22)
	if audio_ui and audio_ui.stream:
		audio_ui.play()
		await get_tree().create_timer(0.22).timeout
	if escena_carrera != "":
		get_tree().change_scene_to_file(escena_carrera)

func _on_btn_dos_j_pressed() -> void:
	if _cambiando_escena:
		return
	_cambiando_escena = true
	ConfigJuego.dos_jugadores = true
	ConfigJuego.ganador = 0
	if musica_lobby and is_instance_valid(musica_lobby) and musica_lobby.playing:
		var tw := create_tween()
		tw.tween_property(musica_lobby, "volume_db", -40.0, 0.22)
	if audio_ui and audio_ui.stream:
		audio_ui.play()
		await get_tree().create_timer(0.22).timeout
	if escena_carrera != "":
		get_tree().change_scene_to_file(escena_carrera)

func _on_btn_salir_pressed() -> void:
	get_tree().quit()
