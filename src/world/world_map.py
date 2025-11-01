import random
from world import tiles

LARGURA = 51
ALTURA = 31

# ----------------- Criação do Grid -----------------
def gerar_grid():
    """Cria um grid preenchido apenas com paredes."""
    return [[tiles.Parede for _ in range(LARGURA)] for _ in range(ALTURA)]


# ----------------- Verificações -----------------
def dentro_da_largura(x):
    """Retorna True se a coordenada x está dentro da largura do grid."""
    return 0 <= x < LARGURA


def dentro_da_altura(y):
    """Retorna True se a coordenada y está dentro da altura do grid."""
    return 0 <= y < ALTURA


def coordenada_valida(x, y):
    """Retorna True se a coordenada (x, y) está dentro do grid."""
    return dentro_da_largura(x) and dentro_da_altura(y)


def celula_eh_parede(grid, x, y):
    """Retorna True se a célula é parede."""
    return grid[y][x].Tipo == "Parede"


def celula_passavel(grid, x, y):
    """Retorna True se a célula é passável (não parede)."""
    return grid[y][x].Passavel


# ----------------- Impressão -----------------
def imprimir_grid(grid):
    """Imprime o grid no console."""
    for y in range(ALTURA):
        linha = ""
        for x in range(LARGURA):
            linha += "  " if celula_passavel(grid, x, y) else "██"
        print(linha)


# ----------------- Geração do Labirinto -----------------
def gerar_labirinto(grid, inicio=(1, 1)):
    """Interface principal para gerar labirinto no grid."""
    gerar_labirinto_dfs(grid, inicio[0], inicio[1])


def gerar_labirinto_dfs(grid, start_x, start_y):
    """Gera um labirinto usando DFS iterativo."""
    pilha = []
    marcar_como_chao(grid, start_x, start_y)
    pilha.append((start_x, start_y))

    while pilha:
        x, y = pilha[-1]  # peek
        vizinhos = obter_vizinhos_validos(grid, x, y)

        if vizinhos:
            prox_x, prox_y = random.choice(vizinhos)
            cavar_caminho(grid, x, y, prox_x, prox_y)
            pilha.append((prox_x, prox_y))
        else:
            pilha.pop()


def direcoes_dfs():
    """Retorna as direções possíveis a 2 passos para a DFS."""
    return [(0, -2), (0, 2), (-2, 0), (2, 0)]


def obter_vizinhos_validos(grid, x, y):
    """Retorna os vizinhos a 2 passos que ainda são paredes."""
    vizinhos = []
    for dx, dy in direcoes_dfs():
        nx, ny = x + dx, y + dy
        if coordenada_valida(nx, ny) and celula_eh_parede(grid, nx, ny):
            vizinhos.append((nx, ny))
    return vizinhos


def marcar_como_chao(grid, x, y):
    """Marca a célula como chão."""
    grid[y][x] = tiles.Chao


def cavar_entre(grid, x1, y1, x2, y2):
    """Cava a parede entre duas células adjacentes."""
    meio_x = (x1 + x2) // 2
    meio_y = (y1 + y2) // 2
    grid[meio_y][meio_x] = tiles.Chao


def cavar_caminho(grid, x1, y1, x2, y2):
    """Cria o caminho entre duas células: cava a parede e marca o destino como chão."""
    cavar_entre(grid, x1, y1, x2, y2)
    marcar_como_chao(grid, x2, y2)


# ----------------- Execução -----------------
if __name__ == "__main__":
    grid = gerar_grid()
    gerar_labirinto(grid, (1, 1))
    imprimir_grid(grid)
