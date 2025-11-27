extends Node

#Referência aos nós filhos que vamos criar na cena 
@onready var music_player: AudioStreamPlayer = $MusicPlayer
@onready var sfx_player: AudioStreamPlayer = $SFXPlayer

"""
Função para tocar música.
Para a música atual e toca a nova.
"""
func play_music(music_stream: AudioStream):
	if not music_stream:
		print("AudioManager: Tentativa de tocar música nula.")
		return
		
	# Para a música atual antes de tocar a nova
	if music_player.playing:
		music_player.stop()
		
	music_player.stream = music_stream
	# O ideal é que a música seja importada com "Loop" ativado
	music_player.play()

"""
Função para tocar efeitos sonoros.
"""
func play_sfx(sfx_stream: AudioStream):
	if not sfx_stream:
		print("AudioManager: Tentativa de tocar SFX nulo.")
		return

	# Toca o som no player de SFX
	# NOTA: Como o plano especifica um único nó "SFXPlayer", 
	# este método vai cortar qualquer SFX que já estiver tocando.
	# (Para o futuro, a gente pode melhorar isso com um "pool" de players,
	# mas por enquanto, vamos deixar assim
	sfx_player.stream = sfx_stream
	sfx_player.play()

# Função para parar a música atual
func stop_music():
	if music_player.playing:
		music_player.stop()
