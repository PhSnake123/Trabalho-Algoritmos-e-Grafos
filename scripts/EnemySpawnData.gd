# res://scripts/resources/EnemySpawnData.gd
class_name EnemySpawnData
extends Resource

@export var inimigo_cena: PackedScene # Onde você arrasta o robô
@export var quantidade: int = 1       # Quantos vão nascer
@export var flag_secreta: String = "" # Condição (se vazio, nasce sempre)
