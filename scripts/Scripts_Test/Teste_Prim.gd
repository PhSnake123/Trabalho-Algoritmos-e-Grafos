extends Node

func _ready():
	print("--- Iniciando Teste de Prim (MST) ---")
	
	# 1. SIMULAÇÃO: Grafo Abstrato de Distâncias
	# Imagine que o Dijkstra já rodou e descobriu as distâncias reais
	# entre o Jogador (Inicio) e 3 Terminais (T1, T2, T3).
	
	var inicio = Vector2i(0, 0)
	var t1 = Vector2i(10, 10)
	var t2 = Vector2i(20, 5)
	var t3 = Vector2i(5, 20)
	
	# O dicionário é: { Origem: { Destino: Custo, Destino2: Custo... } }
	var grafo_abstrato = {
		inicio: { t1: 10.0, t2: 50.0, t3: 100.0 },     # Do inicio, T1 é o mais perto
		t1:     { inicio: 10.0, t2: 5.0, t3: 100.0 },  # De T1, T2 é muito perto (Custo 5)
		t2:     { inicio: 50.0, t1: 5.0, t3: 20.0 },   # De T2, T3 é perto (Custo 20)
		t3:     { inicio: 100.0, t1: 100.0, t2: 20.0 } # T3 é longe de tudo, menos de T2
	}
	
	# EXPECTATIVA HUMANA:
	# O caminho mais barato para conectar tudo deve ser:
	# Inicio -> T1 (10.0)
	# T1 -> T2 (5.0)
	# T2 -> T3 (20.0)
	# Custo Total Esperado da Árvore (MST) = 10 + 5 + 20 = 35.0
	
	# 2. Roda o Prim
	var custo_calculado = Prim.calcular_mst(grafo_abstrato)
	
	print("Custo MST Calculado: ", custo_calculado)
	
	if custo_calculado == 35.0:
		print("SUCESSO: O Prim encontrou a árvore ótima!")
	else:
		print("FALHA: Valor esperado era 35.0, mas deu ", custo_calculado)
