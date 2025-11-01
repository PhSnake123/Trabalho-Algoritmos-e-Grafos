from world import world_map

def main():
    """Executa a geração e visualização do labirinto."""
    # 1. Cria o grid
    grid = world_map.gerar_grid()

    # 2. Gera o labirinto usando DFS
    world_map.gerar_labirinto(grid, inicio=(1, 1))

    # 3. Exibe o labirinto no console
    world_map.imprimir_grid(grid)

if __name__ == "__main__":
    main()
