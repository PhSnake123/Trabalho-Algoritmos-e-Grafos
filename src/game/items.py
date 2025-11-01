class Item:
    """Classe base para todos os itens."""
    def __init__(self, nome):
        self.nome = nome

    def aplicar(self, player, tile=None):
        """
        Aplica o efeito do item no jogador ou no tile atual.
        Deve ser sobrescrito nas subclasses.
        """
        pass


class Keycard(Item):
    """Permite abrir portas."""
    def __init__(self):
        super().__init__("Keycard")

    def aplicar(self, player, tile=None):
        """
        Usado automaticamente ao atravessar uma porta.
        Retorna True se o item foi consumido.
        """
        if "Keycard" in player.inventario:
            player.usar_item("Keycard")
            return True
        return False


class Boots(Item):
    """Reduz custo de travessia de tiles difíceis (ex: lama)."""
    def __init__(self, usos=3):
        super().__init__("Botas")
        self.usos = usos

    def aplicar(self, player, tile=None):
        """
        Diminui o custo do tile em 1, se houver usos restantes.
        """
        if self.usos > 0:
            self.usos -= 1
            return True
        return False


class Potion(Item):
    """Restaura HP do jogador."""
    def __init__(self, cura=20):
        super().__init__("Poção")
        self.cura = cura

    def aplicar(self, player, tile=None):
        """
        Aumenta o HP do jogador até o máximo.
        """
        player.hp += self.cura
        if player.hp > player.hp_max:
            player.hp = player.hp_max
        player.usar_item("Poção")  # Remove do inventário
        return True
