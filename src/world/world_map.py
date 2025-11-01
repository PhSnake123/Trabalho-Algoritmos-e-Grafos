import random
from world import tiles

LARGURA = 51
ALTURA = 31

# ----------------- Grid -----------------
def gerar_grid():
    """Cria um grid preenchido apenas com paredes."""
    return [[tiles.Parede for _ in range(LARGURA)] for _ in range(ALTURA)]

def imprimir_grid(grid):
    """Exibe o grid no console."""
    for y in range(ALTURA):
        linha = "".join("  " if celula_passavel(grid, x, y) else "██" for x in range(LARGURA))
        print(linha)

# ----------------- Verificações -----------------
def dentro_da_largura(x):
    return 0 <= x < LARGURA

def dentro_da_altura(y):
    return 0 <= y < ALTURA

def coordenada_valida(x, y):
    return dentro_da_largura(x) and dentro_da_altura(y)

def celula_eh_parede(grid, x, y):
    return grid[y][x].Tipo == "Parede"

def celula_passavel(grid, x, y):
    return grid[y][x].Passavel

# ----------------- Labirinto -----------------
def gerar_labirinto(grid, inicio=(1, 1)):
    """Gera labirinto usando DFS iterativo a partir de uma célula inicial."""
    gerar_labirinto_dfs(grid, inicio[0], inicio[1])

def gerar_labirinto_dfs(grid, x, y):
    pilha = [(x, y)]
    marcar_como_chao(grid, x, y)

    while pilha:
        x, y = pilha[-1]
        vizinhos = obter_vizinhos_validos(grid, x, y)

        if vizinhos:
            prox_x, prox_y = random.choice(vizinhos)
            cavar_caminho(grid, x, y, prox_x, prox_y)
            pilha.append((prox_x, prox_y))
        else:
            pilha.pop()

def direcoes_dfs():
    """Direções possíveis a 2 passos para a DFS."""
    return [(0, -2), (0, 2), (-2, 0), (2, 0)]

def obter_vizinhos_validos(grid, x, y):
    return [(nx, ny) for dx, dy in direcoes_dfs()
            if coordenada_valida(nx := x + dx, ny := y + dy) and celula_eh_parede(grid, nx, ny)]

def marcar_como_chao(grid, x, y):
    grid[y][x] = tiles.Chao

def cavar_entre(grid, x1, y1, x2, y2):
    meio_x = (x1 + x2) // 2
    meio_y = (y1 + y2) // 2
    grid[meio_y][meio_x] = tiles.Chao

def cavar_caminho(grid, x1, y1, x2, y2):
    cavar_entre(grid, x1, y1, x2, y2)
    marcar_como_chao(grid, x2, y2)

# ----------------- Execução -----------------
if __name__ == "__main__":
    grid = gerar_grid()
    gerar_labirinto(grid, (1, 1))
    imprimir_grid(grid)
