class_name FogOfWar

# Precisamos disso para saber o que é "CHAO"

var largura: int
var altura: int
var raio_visao: int
var fog_data := [] # Nosso array 2D de booleanos (True = Oculto, False = Visível)


func _init(p_largura: int, p_altura: int, p_raio_visao: int = 3):
	self.largura = p_largura
	self.altura = p_altura
	self.raio_visao = p_raio_visao
	
	# Preenche o fog_data com 'true' (tudo oculto)
	for y in range(altura):
		var linha := []
		for x in range(largura): # <- CORREÇÃO: Isso deve ser 'largura'
			linha.push_back(true) # True = oculto
		fog_data.push_back(linha)

# ... (o resto do script permanece o mesmo) ...

# Função auxiliar interna (porta do 'revelar_circular')
func _revelar_circular(cx: int, cy: int):
	"""Revela mini-área de raio 1 ao redor de (cx, cy)."""
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var nx = cx + dx
			var ny = cy + dy
			if 0 <= nx and nx < largura and 0 <= ny and ny < altura:
				fog_data[ny][nx] = false # False = visível


# Função principal (porta do 'revelar_area')
func revelar_area(pos_x: int, pos_y: int, grid_logico: Array):
	"""Revela tiles ao redor do jogador com visão circular + cruz linear."""
	
	# --- 1. Visão circular imediata do jogador ---
	_revelar_circular(pos_x, pos_y)

	# --- 2. Visão linear em cruz ---
	var direcoes = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)] # N, S, O, L
	
	for dir in direcoes:
		for passo in range(1, raio_visao + 1):
			var nx = pos_x + dir.x * passo
			var ny = pos_y + dir.y * passo

			if not (0 <= nx and nx < largura and 0 <= ny and ny < altura):
				break # Fora do mapa

			# Vê o tile atual
			fog_data[ny][nx] = false # Revela este tile
			
			# Converte o tile do grid para MapTileData
			var tile_data = grid_logico[ny][nx] as MapTileData
			var eh_passavel = false
			
			# Se a conversão funcionou, use a propriedade 'passavel'
			if tile_data:
				eh_passavel = tile_data.passavel

			if eh_passavel:
				# V passável: revela mini-cruz adjacente
				for adj_dir in direcoes:
					var ax = nx + adj_dir.x
					var ay = ny + adj_dir.y
					if 0 <= ax and ax < largura and 0 <= ay and ay < altura:
						fog_data[ay][ax] = false
			else:
				# V é parede: revela apenas a si mesmo e para o loop
				break


func esta_visivel(x: int, y: int) -> bool:
	"""Checa se um tile (x, y) está visível (false) ou oculto (true)."""
	if 0 <= x and x < largura and 0 <= y and y < altura:
		return not fog_data[y][x] # Invertemos, pois 'true' é oculto
	return false

func revelar_tudo():
	"""Revela o mapa inteiro (útil para o Hub ou Debug)."""
	for y in range(altura):
		for x in range(largura):
			fog_data[y][x] = false
