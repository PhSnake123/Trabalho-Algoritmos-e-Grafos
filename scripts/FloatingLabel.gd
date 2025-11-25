# res://scripts/ui/FloatingLabel.gd
extends Node2D

@onready var label = $Label

func set_text(text: String, color: Color):
	label.text = text
	label.modulate = color

func _ready():
	z_index = 100 # Garante que desenha na frente de tudo
	var tween = create_tween()
	
	# CORREÇÃO AQUI:
	# 1. Usamos o valor "-12.0" (apenas o deslocamento, não a posição final)
	# 2. Adicionamos .as_relative() no final.
	# Isso diz: "Não importa onde eu nasça, suba 12 pixels a partir de lá."
	tween.tween_property(self, "position:y", -12.0, 1.0).as_relative().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# O Fade Out continua igual
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.5).set_delay(0.5)
	
	tween.tween_callback(queue_free)
