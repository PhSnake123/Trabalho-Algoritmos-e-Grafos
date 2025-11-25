# res://scripts/Dijkstra.gd
class_name Dijkstra

var grafo: Graph
var distancias = {}
var predecessores = {}

func _init(p_grafo: Graph):
	self.grafo = p_grafo

# Função auxiliar para o Dijkstra (sem heap)
func _encontrar_vertice_min_dist(vertices_nao_visitados: Dictionary) -> Vector2i:
	var min_dist = INF
	var vertice_mais_proximo = null
	
	for vertice in vertices_nao_visitados:
		if distancias[vertice] < min_dist:
			min_dist = distancias[vertice]
			vertice_mais_proximo = vertice
	return vertice_mais_proximo

# Calcula o caminho mínimo (baseado em dijkstra.py)
func calcular_caminho_minimo(inicio: Vector2i):
	var vertices_nao_visitados = {} # Usamos como um "Set"
	
	# 1. Inicializa distâncias
	for vertice in grafo.adjacencias:
		distancias[vertice] = INF
		predecessores[vertice] = null
		vertices_nao_visitados[vertice] = true # Adiciona ao "set"
	
	distancias[inicio] = 0

	# 2. Loop principal (versão sem heap)
	while not vertices_nao_visitados.is_empty():
		# Encontra o vértice mais próximo não visitado
		var vertice_atual = _encontrar_vertice_min_dist(vertices_nao_visitados)
		
		# Se for nulo ou inalcançável, paramos
		if vertice_atual == null or distancias[vertice_atual] == INF:
			break 
		
		vertices_nao_visitados.erase(vertice_atual) # Remove do "set"
		
		# 3. Atualiza vizinhos
		for aresta in grafo.adjacencias[vertice_atual]:
			var vizinho: Vector2i = aresta[0]
			var custo: int = aresta[1]
			var nova_distancia = distancias[vertice_atual] + custo
			
			if nova_distancia < distancias[vizinho]:
				distancias[vizinho] = nova_distancia
				predecessores[vizinho] = vertice_atual

	return {"distancias": distancias, "predecessores": predecessores}

# --- Lógica do Vértice Final (baseada na nossa discussão anterior) ---
func encontrar_vertice_final(inicio: Vector2i) -> Vector2i:
	# 1. Calcula todas as distâncias
	calcular_caminho_minimo(inicio)
	
	# 2. Filtra vértices inalcançáveis
	var distancias_validas = {}
	for v in distancias:
		if distancias[v] != INF and v != inicio:
			distancias_validas[v] = distancias[v]
	
	if distancias_validas.is_empty():
		return Vector2i.ZERO # Falha

	# 3. Define o limite (ex: 75% da distância máxima)
	var dist_maxima = 0.0
	for d in distancias_validas.values():
		if d > dist_maxima:
			dist_maxima = d
	
	var limite_distancia = dist_maxima * 0.5
	
	# 4. Filtra por distância
	var candidatos_distantes = []
	for v in distancias_validas:
		if distancias_validas[v] >= limite_distancia:
			candidatos_distantes.push_back(v)
	
	# 5. Filtra por "beco sem saída" (1 vizinho)
	var candidatos_finais = []
	for v in candidatos_distantes:
		if grafo.adjacencias[v].size() == 1:
			candidatos_finais.push_back(v)
	
	# 6. Escolhe aleatoriamente
	if not candidatos_finais.is_empty():
		return candidatos_finais.pick_random() # Caso ideal
	elif not candidatos_distantes.is_empty():
		return candidatos_distantes.pick_random() # Caso B (qualquer um longe)
	else:
		# Caso C (pega o mais distante de todos)
		var vertice_final = distancias_validas.keys()[0]
		for v in distancias_validas:
			if distancias_validas[v] > distancias[vertice_final]:
				vertice_final = v
		return vertice_final

func reconstruir_caminho(inicio: Vector2i, fim: Vector2i) -> Array[Vector2i]:
	# CORREÇÃO 1: Inicializa o array com o tipo correto.
	var caminho: Array[Vector2i] = []
	var atual = fim
	
	# Checa se o 'fim' existe nos predecessores (foi alcançado)
	if not predecessores.has(atual):
		print("Erro: Vértice final não encontrado nos predecessores.")
		# CORREÇÃO 2: Retorna um array vazio DO TIPO CORRETO.
		return []
		
	# Volta do fim até o início
	while atual != null:
		caminho.push_back(atual)
		atual = predecessores.get(atual) 
	
	caminho.reverse()
	
	# Verificação final de validade
	if caminho.is_empty() or caminho[0] != inicio:
		print("Erro: Caminho reconstruído não começa no início.")
		# CORREÇÃO 3: Retorna um array vazio DO TIPO CORRETO.
		return []
	
	# Este retorno agora funciona, pois 'caminho' foi inicializado corretamente.
	return caminho

# Função Wrapper para compatibilidade com o Main.gd
# Assim, tanto A* quanto Dijkstra podem ser chamados do mesmo jeito.
func calcular_caminho(inicio: Vector2i, fim: Vector2i) -> Array[Vector2i]:
	# 1. Preenche os mapas de distância e predecessores
	calcular_caminho_minimo(inicio)
	
	# 2. Reconstrói e retorna o array do caminho
	return reconstruir_caminho(inicio, fim)

# --- VERSÃO LIGHT (EARLY EXIT) ---
# Usada para Stalkers e Drones. Para assim que encontra o destino.
func calcular_caminho_rapido(inicio: Vector2i, fim: Vector2i) -> Array[Vector2i]:
	var distancias_local = {}
	var pais_local = {}
	var visitados_local = []
	
	# Otimização: Inicializamos apenas o início no dicionário
	# O dicionário cresce dinamicamente, evitando iterar o mapa todo no começo
	distancias_local[inicio] = 0.0
	
	# Conjunto de nós abertos (simples)
	var nos_para_processar = [inicio]
	
	while not nos_para_processar.is_empty():
		# 1. Encontra o nó com menor distância na lista de processamento
		var u = Vector2i(-1, -1)
		var min_dist = INF
		var index_para_remover = -1
		
		for i in range(nos_para_processar.size()):
			var node = nos_para_processar[i]
			var d = distancias_local.get(node, INF)
			if d < min_dist:
				min_dist = d
				u = node
				index_para_remover = i
		
		# Se não achou nada ou distância é infinita, parou
		if u == Vector2i(-1, -1) or min_dist == INF:
			break
			
		# Remove da lista de processamento e marca visitado
		nos_para_processar.remove_at(index_para_remover)
		visitados_local.append(u)
		
		# --- O PULO DO GATO (EARLY EXIT) ---
		# Se chegamos no destino, paramos IMEDIATAMENTE.
		if u == fim:
			print("DEBUG: Dijkstra Rápido encontrou custo total: ", distancias_local[u])
			return _reconstruir_caminho_local(pais_local, inicio, fim)
		# -----------------------------------
		
		# Relaxamento dos vizinhos
		if grafo.adjacencias.has(u):
			for aresta in grafo.adjacencias[u]:
				var v = aresta[0]
				var peso = aresta[1]
				
				# Se já visitamos, ignora
				if v in visitados_local: continue
				
				var nova_dist = distancias_local[u] + peso
				
				if nova_dist < distancias_local.get(v, INF):
					distancias_local[v] = nova_dist
					pais_local[v] = u
					
					# Adiciona à lista de processamento se não estiver lá
					if not v in nos_para_processar:
						nos_para_processar.push_back(v)

	# Se saiu do loop sem retornar, não achou caminho
	return []

# Função auxiliar privada para reconstruir sem depender das variáveis globais da classe
func _reconstruir_caminho_local(pais: Dictionary, inicio: Vector2i, fim: Vector2i) -> Array[Vector2i]:
	var caminho: Array[Vector2i] = []
	var atual = fim
	
	while atual != inicio:
		caminho.push_front(atual)
		if not pais.has(atual): return [] # Caminho quebrado
		atual = pais[atual]
	
	caminho.push_front(inicio)
	return caminho
