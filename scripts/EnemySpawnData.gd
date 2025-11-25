# res://scripts/resources/EnemySpawnData.gd
class_name EnemySpawnData
extends Resource

@export_group("Básico")
@export var inimigo_cena: PackedScene 
@export var quantidade: int = 1       
@export var flag_secreta: String = "" 
@export var ai_type: Enemy.EnemyAI = Enemy.EnemyAI.SMART

@export_group("Customização Visual")
# Se for Branco (1,1,1,1), o inimigo mantém a cor original.
@export var cor_modulate: Color = Color.WHITE

@export_group("Override de Atributos (-1 = Padrão)")
# Definimos -1 como "Não mexa nisso, use o valor da cena original"
@export var hp_maximo: int = -1
@export var ataque: int = -1
@export var defesa: int = -1
@export var poise: int = -1
@export var knockback: int = -1
@export var passos_por_turno: int = -1
