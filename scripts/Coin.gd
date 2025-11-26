# res://scripts/Coin.gd
extends Area2D

var valor: int = 1
var main_ref = null # Referência para chamar o texto flutuante

func _ready():
	# Conecta o sinal de entrada de corpo (Player)
	body_entered.connect(_on_body_entered)
	
	# Animaçãozinha de "flutuar"
	var tween = create_tween().set_loops()
	tween.tween_property($AnimatedSprite2D, "position:y", -5.0, 1.0).as_relative().set_trans(Tween.TRANS_SINE)
	tween.tween_property($AnimatedSprite2D, "position:y", 5.0, 1.0).as_relative().set_trans(Tween.TRANS_SINE)

func configurar(qtd: int):
	valor = qtd

func _on_body_entered(body):
	if body.is_in_group("player"):
		Game_State.adicionar_moedas(valor)
		
		# Feedback Visual (Texto Flutuante)
		if main_ref and main_ref.has_method("spawn_floating_text"):
			# Cor Dourada/Amarela
			main_ref.spawn_floating_text(global_position + Vector2(0, -10), "+%d" % valor, Color(1, 0.8, 0.2))
		
		AudioManager.play_sfx(preload("res://Audio/sounds/coin.wav"))
		
		queue_free()
