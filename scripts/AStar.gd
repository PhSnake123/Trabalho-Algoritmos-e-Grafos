# res://scripts/AStar.gd
class_name AStar

var grafo: Graph

# --- CONFIGURAÇÃO DO COMPORTAMENTO ---
# Quanto vale 1 ponto de Vida em relação ao Tempo?
# Se for 10.0: O drone prefere perder 9 segundos dando a volta do que perder 1 de Vida.
# Se for 0.5: O drone aceita perder 1 de vida para economizar 0.5 segundos (agressivo).
var peso_dano: float = 1.0 

func _init(p_grafo: Graph):
	self.grafo = p_grafo

# 1. A Heurística (Distância de Manhattan)
# É o "chute" da distância restante. Como não andamos na diagonal, somamos as diferenças de X e Y.
func _heuristica(a: Vector2i, b: Vector2i) -> float:
	return abs(a.x - b.x) + abs(a.y - b.y)

# 2. Função para encontrar o nó com menor F_Score no "Open Set"
# (Similar ao que você usou no Dijkstra, mas olhando para o custo total estimado)
func _encontrar_menor_f_score(open_set: Array, f_score: Dictionary) -> Vector2i:
	var melhor_node = Vector2i(-1, -1) # Inválido
	var menor_f = INF
	
	for node in open_set:
		var score = f_score.get(node, INF)
		if score < menor_f:
			menor_f = score
			melhor_node = node
			
	return melhor_node

# 3. O Algoritmo A* Principal
func calcular_caminho(inicio: Vector2i, fim: Vector2i) -> Array[Vector2i]:
	# Inicialização
	var open_set: Array[Vector2i] = [inicio] # Nós para visitar
	var came_from = {} # Para reconstruir o caminho depois
	
	# G_Score: Custo real do início até aqui
	var g_score = {} 
	g_score[inicio] = 0.0
	
	# F_Score: Custo real (G) + Estimativa (H)
	var f_score = {}
	f_score[inicio] = _heuristica(inicio, fim)
	
	while not open_set.is_empty():
		# Pega o nó com menor chance de ser o melhor caminho
		var atual = _encontrar_menor_f_score(open_set, f_score)
		
		# Se chegamos ao fim, reconstruímos o caminho
		if atual == fim:
			return _reconstruir_caminho(came_from, atual)
		
		# Remove do open_set (já estamos visitando)
		open_set.erase(atual)
		
		# Checa vizinhos
		if grafo.adjacencias.has(atual):
			for aresta in grafo.adjacencias[atual]:
				var vizinho: Vector2i = aresta[0]
				var custo_tempo_vizinho: float = aresta[1]
				
				# --- AQUI ESTÁ O SEGREDO DO "CAMINHO ÓTIMO" ---
				# Precisamos descobrir se esse vizinho tem DANO.
				# O grafo atual guarda [pos, custo_tempo]. Precisamos acessar o MapData para ver o dano.
				var custo_dano_vizinho = _obter_dano_do_tile(vizinho)
				
				# Custo Real do Passo = Tempo + (Dano * Peso)
				var custo_passo = custo_tempo_vizinho + (custo_dano_vizinho * peso_dano)
				
				var tentativa_g_score = g_score[atual] + custo_passo
				
				# Se achamos um caminho melhor para o vizinho do que o registrado antes:
				if tentativa_g_score < g_score.get(vizinho, INF):
					came_from[vizinho] = atual
					g_score[vizinho] = tentativa_g_score
					f_score[vizinho] = g_score[vizinho] + _heuristica(vizinho, fim)
					
					if not open_set.has(vizinho):
						open_set.push_back(vizinho)
	
	# Se o loop acabar e não retornarmos nada, não há caminho
	print("AStar: Caminho não encontrado ou destino inalcançável.")
	return []

# Função auxiliar para pegar o dano direto do Grid Lógico
# (O Grafo original simplificou os dados, então acessamos o grid bruto aqui)
func _obter_dano_do_tile(pos: Vector2i) -> int:
	if pos.y >= 0 and pos.y < grafo.altura and pos.x >= 0 and pos.x < grafo.largura:
		var tile = grafo.grid_logico[pos.y][pos.x] as MapTileData
		if tile:
			return tile.dano_hp
	return 0

# Reconstrói o caminho de trás para frente (igual ao Dijkstra)
func _reconstruir_caminho(came_from: Dictionary, atual: Vector2i) -> Array[Vector2i]:
	var caminho: Array[Vector2i] = [atual]
	while came_from.has(atual):
		atual = came_from[atual]
		caminho.push_front(atual)
	return caminho
