import random
import math
from world import tiles

comprimento = 51
altura = 31

def gera_grid():
    return [[tiles.parede for x in range(comprimento)] for y in range(altura)]

def é_valido(x, y):
    #Verifica se uma coordenada (x, y) está dentro dos limites do grid.
    return 0 <= x < comprimento and 0 <= y < altura

def imprimir_grid(grid):
    """Função utilitária para "desenhar" nosso mapa no console."""
    for y in range(altura):
        linha = ""
        for x in range(comprimento):
            if grid[y][x].passavel:
                linha += "  " # Chão
            else:
                linha += "██" # Parede
        print(linha)

def gera_labirinto_dfs(grid, start_x, start_y):
    # 1. Cria a pilha (stack) para o DFS
    pilha = []
    
    # 2. Marca a célula inicial como CHÃO e adiciona à pilha
    grid[start_y][start_x] = tiles.chao
    pilha.append((start_x, start_y))

    # 3. Loop principal: continua enquanto houver células na pilha
    while len(pilha) > 0:
        # Pega a célula atual (o topo da pilha)
        (x, y) = pilha[-1] # Apenas "olha" (peek), não remove ainda
        
        # 4. Encontra todos os vizinhos válidos (a 2 passos de distância)
        vizinhos = []
        
        # Vizinhos (Norte, Sul, Leste, Oeste) a 2 passos
        # O "salto" de 2 é o segredo para criar paredes entre os caminhos
        for (dx, dy) in [(0, -2), (0, 2), (-2, 0), (2, 0)]:
            nx, ny = x + dx, y + dy
            
            # Verifica se o vizinho está dentro do grid E AINDA É UMA PAREDE
            if é_valido(nx, ny) and grid[ny][nx].tipo == "Parede":
                vizinhos.append((nx, ny))
        
        # 5. Decide o que fazer
        if len(vizinhos) > 0:
            # 5a. Se há vizinhos, escolhe um aleatoriamente
            (prox_x, prox_y) = random.choice(vizinhos)
            
            # 6. "Cava" a parede ENTRE a célula atual e o vizinho
            # (Calcula o ponto médio)
            parede_x = (x + prox_x) // 2
            parede_y = (y + prox_y) // 2
            grid[parede_y][parede_x] = tiles.chao
            
            # 7. "Cava" o próprio vizinho
            grid[prox_y][prox_x] = tiles.chao
            
            # 8. Adiciona o vizinho à pilha (será o próximo 'atual')
            pilha.append((prox_x, prox_y))
            
        else:
            # 5b. Se não há vizinhos válidos (beco sem saída)
            # Remove a célula atual da pilha (o "backtracking")
            pilha.pop()