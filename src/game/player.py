class Player:
    """
    Representa o jogador no labirinto.
    Controla posição, HP, tempo restante e inventário de itens.
    """
    def __init__(self, x=1, y=1, tempo=100, hp=100):
        self.x = x
        self.y = y
        self.tempo = tempo
        self.hp = hp
        self.hp_max = hp
        self.inventario = set()  # Ex: {"Keycard", "Botas"}

    def mover_para(self, nova_x, nova_y, custo_tempo, dano_hp=0):
        """
        Move o jogador para nova posição, reduzindo tempo e HP.
        Retorna True se o movimento foi possível, False se não há tempo suficiente ou morreu.
        """
        if custo_tempo > self.tempo:
            return False  # não tem tempo suficiente
        self.x = nova_x
        self.y = nova_y
        self.tempo -= custo_tempo
        self.hp -= dano_hp
        if self.hp < 0:
            self.hp = 0
        return True

    def usar_item(self, item):
        """
        Usa um item do inventário.
        Retorna True se o jogador tinha o item, False caso contrário.
        """
        if item in self.inventario:
            self.inventario.remove(item)
            return True
        return False

    def pegar_item(self, item):
        """Adiciona um item ao inventário."""
        self.inventario.add(item)

    def esta_vivo(self):
        return self.hp > 0

    def tempo_restante(self):
        return self.tempo

    def posicao(self):
        return self.x, self.y
