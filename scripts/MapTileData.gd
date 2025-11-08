# res://scripts/MapTileData.gd
extends Resource
class_name MapTileData

# Baseado no seu protótipo tiles.py
@export var tipo: String = "Chao"        # "Chao", "Parede", "Lama", "Porta"
@export var custo_tempo: float = 1.0     # O "peso" para o Dijkstra
@export var dano_hp: int = 0             # Dano ao entrar no tile
@export var passavel: bool = true        # O Player pode entrar?

# Específico para mecânicas de jogo
@export var eh_porta: bool = false
@export var eh_parede_quebravel: bool = false
# (Poderíamos adicionar 'dá_dica: bool' aqui no futuro)
