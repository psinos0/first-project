extends Node
## Original short synthesized sounds; no external audio assets.
var player: AudioStreamPlayer

func _ready() -> void:
	player = AudioStreamPlayer.new()
	player.volume_db = -18.0
	add_child(player)

func play(sale: bool = false) -> void:
	# The headless runner has no audio output; do not feed its dummy mixer.
	if not Game.sound_enabled or DisplayServer.get_name() == "headless":
		return
	var length := 0.30 if sale else 0.055
	var rate := 22050
	var data := PackedByteArray()
	data.resize(int(length * rate) * 2)
	for i in range(int(length * rate)):
		var t := float(i) / rate
		var frequency := (660.0 if t < 0.1 else (880.0 if t < 0.2 else 1100.0)) if sale else 520.0
		var envelope := sin(PI * t / length) * exp(-t * 5.0)
		var value := int(sin(TAU * frequency * t) * envelope * 14000.0)
		data.encode_s16(i * 2, value)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	player.stop()
	player.stream = stream
	player.play()

func _exit_tree() -> void:
	player.stop()
	player.stream = null
