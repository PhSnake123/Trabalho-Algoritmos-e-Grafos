class_name BFS

var grafo: Graph

# Assim como no Dijkstra, recebemos o Grafo pronto no init
func _init(p_grafo: Graph):
	self.grafo = p_grafo

"""
Retorna uma lista de TODOS os tiles (Vector2i) dentro de um alcance máximo (em passos).
Ideal para: Explosões, Áreas de efeito, Drones de limpeza etc.
"""
func obter_area_alcance(inicio: Vector2i, max_passos: int) -> Array[Vector2i]:
	var visitados = {} # Funciona como um Set para evitar ciclos
	var fila = []      # Nossa fila FIFO padrão do BFS
	var resultado: Array[Vector2i] = []
	
	# A fila armazena arrays: [posicao_atual, distancia_do_inicio]
	fila.push_back([inicio, 0])
	visitados[inicio] = true
	resultado.push_back(inicio)
	
	while not fila.is_empty():
		# Pega o primeiro da fila (FIFO)
		var dados = fila.pop_front()
		var vertice_atual = dados[0]
		var distancia_atual = dados[1]
		
		# Se já atingimos o limite de alcance, não adicionamos os vizinhos deste nó
		if distancia_atual >= max_passos:
			continue
			
		# Verifica os vizinhos usando a lista de adjacência do Grafo existente
		# Nota: grafo.adjacencias retorna [vizinho_pos, custo]. 
		# No BFS, ignoramos o custo.
		if grafo.adjacencias.has(vertice_atual):
			for aresta in grafo.adjacencias[vertice_atual]:
				var vizinho_pos = aresta[0]
				
				if not visitados.has(vizinho_pos):
					visitados[vizinho_pos] = true
					# Adiciona na fila com +1 de distância (camada seguinte)
					fila.push_back([vizinho_pos, distancia_atual + 1])
					resultado.push_back(vizinho_pos)
	
	return resultado

"""
(Opcional) Caminho mais curto em NÚMERO DE TILES (ignorando pesos).
Pode ser útil se quisermos um drone(ou inimigos) que voa por cima de tudo sem ligar para o terreno.
"""
func calcular_caminho_simples(inicio: Vector2i, fim: Vector2i) -> Array[Vector2i]:
	var visitados = {}
	var predecessores = {} # Para reconstruir o caminho
	var fila = []
	
	fila.push_back(inicio)
	visitados[inicio] = true
	predecessores[inicio] = null
	
	var encontrou = false
	
	while not fila.is_empty():
		var atual = fila.pop_front()
		
		if atual == fim:
			encontrou = true
			break
		
		if grafo.adjacencias.has(atual):
			for aresta in grafo.adjacencias[atual]:
				var vizinho = aresta[0]
				if not visitados.has(vizinho):
					visitados[vizinho] = true
					predecessores[vizinho] = atual
					fila.push_back(vizinho)
	
	# Reconstrói o caminho de trás para frente
	if not encontrou:
		return []
		
	var caminho: Array[Vector2i] = []
	var curr = fim
	while curr != null:
		caminho.push_back(curr)
		curr = predecessores[curr]
	
	caminho.reverse()
	return caminho
