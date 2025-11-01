from world import map

def main():
    #Faz o Grid
    grid = map.gera_grid()
    
    #Gera o labirinto
    
    map.gera_labirinto_dfs(grid, 1, 1)
    
    #Visualização
    map.imprimir_grid(grid)

if __name__ == "__main__":
    main()