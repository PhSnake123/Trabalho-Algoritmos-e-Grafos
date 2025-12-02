# res://scripts/player.gd
extends CharacterBody2D

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
#var sfx_teste = preload("res://Audio/sounds/hurt.wav") 

const TILE_SIZE := 16   
const SPEED := 80.0    

# --- CONFIGURAÇÃO DE TURNOS E COOLDOWN ---
const TURN_DELAY_TIME: float = 0.08 
const ATTACK_COOLDOWN: float = 0.25 # Tempo que o ataque "trava" o input (Ritmo de combate)

var turn_timer: float = 0.0
var input_cooldown: float = 0.0 # NOVO: Impede spam de ações de combate

var grid_pos := Vector2i(1, 1)

var moving := false
var move_dir := Vector2.ZERO
var last_facing := "down"
var target_pos := Vector2.ZERO 
var stats = {}

@onready var main_script = get_parent()

func _ready():
	add_to_group("player")
	global_position = (Vector2(grid_pos) * TILE_SIZE) + (Vector2.ONE * TILE_SIZE / 2.0)
	target_pos = global_position
	stats = Game_State.stats_jogador.duplicate()
	SaveManager.register_player(self)

func _physics_process(delta):
	# Decrementa timers
	if turn_timer > 0: turn_timer -= delta
	if input_cooldown > 0: input_cooldown -= delta # NOVO

	if not moving:
		handle_input()
	else:
		move_towards_target(delta)

func _get_input_direction() -> Vector2:
	if Input.is_action_pressed("ui_right"): return Vector2.RIGHT
	if Input.is_action_pressed("ui_left"): return Vector2.LEFT
	if Input.is_action_pressed("ui_down"): return Vector2.DOWN
	if Input.is_action_pressed("ui_up"): return Vector2.UP
	return Vector2.ZERO

func _get_facing_from_dir(dir: Vector2) -> String:
	if dir == Vector2.RIGHT: return "right"
	if dir == Vector2.LEFT: return "left"
	if dir == Vector2.DOWN: return "down"
	if dir == Vector2.UP: return "up"
	return last_facing

func handle_input():
	# Se estiver em cooldown de combate, ignora inputs
	if Game_State.is_dialogue_active:
		return
	if input_cooldown > 0: return

	var input_dir = _get_input_direction()
	
	if input_dir != Vector2.ZERO:
		var desired_facing = _get_facing_from_dir(input_dir)
		if desired_facing != last_facing:
			last_facing = desired_facing
			anim.play("idle_" + last_facing)
			turn_timer = TURN_DELAY_TIME 
		else:
			if turn_timer <= 0:
				start_moving(input_dir)
	else:
		anim.play("idle_" + last_facing)

func start_moving(dir: Vector2):
	
	if input_cooldown > 0:
		return
	# Segurança: Se o Main não existe mais (troca de cena), não faz nada
	if not is_instance_valid(main_script) or not main_script.is_inside_tree():
		return
	
	var target_grid_pos = grid_pos + Vector2i(dir)
		
	# 1. Checa Combate PRIMEIRO
	
	if main_script.is_tile_occupied_by_enemy(target_grid_pos):
		
		# Toca animação
		last_facing = _get_facing_from_dir(dir)
		anim.play("attack_" + last_facing)
		
		# ATAQUE!
		_atacar_inimigo_no_tile(target_grid_pos)
		
		# Aplica Cooldown para impedir que segurar a tecla rode 10 ataques seguidos
		input_cooldown = ATTACK_COOLDOWN
		
		# O turno passa mesmo atacando parado
		get_tree().call_group("inimigos", "tomar_turno")
		return # Retorna para não andar
		
	# Bloqueia se tiver baú
	if main_script.is_tile_occupied_by_chest(target_grid_pos):
		# Opcional: Tocar som de colisão ou feedback
		print("Player: Bloqueado por baú.")
		return
	
	# Se estiver no Hub E tiver um NPC no alvo, bloqueia o passo.
	if Game_State.is_in_hub:
		if main_script.is_tile_occupied_by_npc(target_grid_pos):
			print("Player: NPC bloqueando caminho no Hub.")
			return
	
	# 2. Se livre, anda normal
	if main_script.is_tile_passable(target_grid_pos):
		#AudioManager.play_sfx(sfx_teste)
		
		var player_snapshot = {
			"pos": grid_pos,
			"hp": Game_State.vida_jogador,
			"time": Game_State.tempo_jogador,
			"inventory": Game_State.inventario_jogador.items.duplicate(true)
		}
		Game_State.log_player_action(player_snapshot)
		
		grid_pos = target_grid_pos
		move_dir = dir
		moving = true
		target_pos = (Vector2(grid_pos) * TILE_SIZE) + (Vector2.ONE * TILE_SIZE / 2.0)
		
		last_facing = _get_facing_from_dir(dir)
		anim.play("walk_" + last_facing)
		
		# "Ei sistema, avise todo mundo no grupo 'inimigos' para tomar seu turno agora!"
		get_tree().call_group("inimigos", "tomar_turno")
	else:
		anim.play("idle_" + last_facing)
		moving = false

func move_towards_target(delta):
	var step = SPEED * delta
	var dist = target_pos - global_position

	if dist.length() <= step:
		global_position = target_pos
		
		Game_State.log_player_position(grid_pos)
		
		var tile_data: MapTileData = main_script.get_tile_data(grid_pos)
		if tile_data:
			# Só soma o tempo se NÃO estiver no Hub
			if not Game_State.is_in_hub:
				# --- LÓGICA DAS BOTAS (Início) ---
				var custo_final = tile_data.custo_tempo
				
				# Verifica se o terreno é difícil (> 1) para aplicar a bota
				if custo_final > 1.0:
					# 1. Procura a melhor bota no inventário
					var melhores_botas: ItemData = null
					var maior_efeito = -1.0
					
					for item in Game_State.inventario_jogador.items:
						if item.efeito == ItemData.EFEITO_PASSIVA_BOTAS: # Certifique-se que essa const existe no ItemData
							if item.valor_efeito > maior_efeito:
								maior_efeito = item.valor_efeito
								melhores_botas = item
					
					# 2. Se encontrou, aplica o efeito
					if melhores_botas:
						# Fórmula: max(tempo - efeito, 1)
						custo_final = max(custo_final - melhores_botas.valor_efeito, 1.0)
						print("Botas reduziram custo para: ", custo_final)
						
						# 3. Reduz durabilidade por ter pisado em terreno difícil
						if melhores_botas.durabilidade > 0:
							melhores_botas.durabilidade -= 1
							if melhores_botas.durabilidade <= 0:
								Game_State.inventario_jogador.remover_item(melhores_botas)
								if Game_State.item_equipado == melhores_botas:
									Game_State.equipar_item(null)
								print("Player: Botas quebraram!")

				# Aplica o tempo calculado
				Game_State.tempo_jogador += custo_final
				
				if custo_final > 0:
					var txt = "-%d" % custo_final
					main_script.spawn_floating_text(global_position + Vector2(0, -24), txt, Color.CYAN)
				# --- LÓGICA DAS BOTAS (Fim) ---
		
			if tile_data.dano_hp > 0:
				Game_State.vida_jogador -= tile_data.dano_hp
				main_script.spawn_floating_text(global_position + Vector2(-16, -8), "-%d" % tile_data.dano_hp, Color.RED)
				print("DANO AMBIENTAL: %s! Vida: %s" % [tile_data.dano_hp, Game_State.vida_jogador])
				if Game_State.vida_jogador <= 0:
					_morrer()
			
				
				# Cria um tween rápido para piscar vermelho
				var t = create_tween()
				t.tween_property(self, "modulate", Color.RED, 0.1)
				t.tween_property(self, "modulate", Color.WHITE, 0.1)
				
				# (Opcional) Som de dano (ainda não temos)
				# AudioManager.play_sfx(preload("res://Audio/sounds/hurt.wav"))
		
		main_script.update_fog(grid_pos)
		
		var next_input = _get_input_direction()
		
		if next_input != Vector2.ZERO:
			moving = false
			start_moving(next_input)
			if moving == false: 
				anim.play("idle_" + last_facing)
		else:
			moving = false
			anim.play("idle_" + last_facing)
			
	else:
		global_position += move_dir * step

func reset_state_on_load():
	moving = false
	target_pos = global_position
	move_dir = Vector2.ZERO
	turn_timer = 0.0
	stats = Game_State.stats_jogador.duplicate()
	if is_node_ready() and anim:
		anim.play("idle_" + last_facing)

func _usar_drone_avancado(efeito: String, tipo: ItemData.ItemTipo):
	var item = Game_State.inventario_jogador.get_item_especifico(efeito, tipo)
	if item:
		print("Player: Usando item '%s'..." % item.nome_item)
		main_script.usar_item(item)
		if item.durabilidade > 0:
			item.durabilidade -= 1
			if item.durabilidade <= 0:
				Game_State.inventario_jogador.remover_item(item)
				
				# Verificamos se o item que acabou de quebrar é EXATAMENTE o mesmo
				# que está na mão do jogador (comparação de objeto/instância).
				if Game_State.item_equipado == item:
					Game_State.equipar_item(null)
	else:
		print("Player: Item (Efeito: %s | Tipo: %s) não encontrado." % [efeito, tipo])
		
func _unhandled_input(event):
	#Se estivermos no meio de um diálogo, ignora ação.
	if Game_State.is_dialogue_active:
		return
	
	# Se estivermos no Hub, bloqueamos teclas de atalho (1-5) e uso de item equipado.
	if Game_State.is_in_hub:
		# Verifica se apertou teclas de atalho ou botão de usar item
		var tentou_usar_drone = (event is InputEventKey and event.pressed and event.keycode >= KEY_1 and event.keycode <= KEY_5)
		var tentou_usar_mao = event.is_action_pressed("usar_item_equipado")
		
		if tentou_usar_drone or tentou_usar_mao:
			print("Player: Uso de itens/drones bloqueado nesta área segura.")
			return # Cancela a ação
	
	if event is InputEventKey and event.pressed and event.keycode == KEY_1:
		_usar_drone_avancado(ItemData.EFEITO_DRONE_PATH_ASTAR, ItemData.ItemTipo.DRONE_TEMPORARIO)
	if event is InputEventKey and event.pressed and event.keycode == KEY_2:
		_usar_drone_avancado(ItemData.EFEITO_DRONE_PATH_DIJKSTRA, ItemData.ItemTipo.DRONE)
	if event is InputEventKey and event.pressed and event.keycode == KEY_3:
		_usar_drone_avancado(ItemData.EFEITO_DRONE_PATH_ASTAR, ItemData.ItemTipo.DRONE)
	if event is InputEventKey and event.pressed and event.keycode == KEY_4:
		_usar_drone_avancado(ItemData.EFEITO_DRONE_SCANNER, ItemData.ItemTipo.DRONE)
	if event is InputEventKey and event.pressed and event.keycode == KEY_5:
		_usar_drone_avancado(ItemData.EFEITO_DRONE_TERRAFORMER, ItemData.ItemTipo.DRONE)
		
	if event.is_action_pressed("atacar_kill9"): # Configure "atacar_arma" no mapa de inputs ou use ui_select
		tentar_disparar_kill9()
	
	# Lógica da Chave
	if event.is_action_pressed("usar_chave"):
		var minha_pos = grid_pos
		var direcao_olhar = Vector2i.ZERO
		match last_facing:
			"up": direcao_olhar = Vector2i.UP
			"down": direcao_olhar = Vector2i.DOWN
			"left": direcao_olhar = Vector2i.LEFT
			"right": direcao_olhar = Vector2i.RIGHT
		
		var tile_alvo = minha_pos + direcao_olhar
		print("Player: Tentando usar chave em ", tile_alvo)
		main_script.tentar_abrir_porta(tile_alvo)

	# Lógica de Interação Unificada
	if event.is_action_pressed("interagir"):
		
		# 1. Calcula onde o jogador está olhando
		var direcao_olhar = Vector2i.ZERO
		match last_facing:
			"up": direcao_olhar = Vector2i.UP
			"down": direcao_olhar = Vector2i.DOWN
			"left": direcao_olhar = Vector2i.LEFT
			"right": direcao_olhar = Vector2i.RIGHT
		
		var tile_frente = grid_pos + direcao_olhar
		
		# 2. Prioridade: NPC à frente
		# Usa a função auxiliar que criamos no Main
		if main_script.has_method("get_npc_at_position"):
			var npc = main_script.get_npc_at_position(tile_frente)
			if npc:
				print("Player: NPC encontrado. Conversando...")
				npc.interagir()
				return # Sai da função, não interage com chão
		
		# --- CHECK DE LOJA ---
		if main_script.has_method("get_shop_at_position"):
			var shop = main_script.get_shop_at_position(tile_frente)
			if shop:
				print("Player: Loja encontrada.")
				shop.interagir()
				return
		
		if main_script.has_method("get_chest_at_position"):
			var bau = main_script.get_chest_at_position(tile_frente)
			if bau:
				print("Player: Interagindo com baú.")
				bau.interagir()
				return
		
		# 3. Se não tem NPC nem baú, interage com o chão (Save/Terminal)
		# Checa vitória primeiro
		if grid_pos == main_script.vertice_fim and main_script.saida_destrancada:
			main_script.chegou_saida(grid_pos)
			return
			
		var current_tile: MapTileData = main_script.get_tile_data(grid_pos)
		if current_tile:
			if current_tile.tipo == "SavePoint":
				SaveManager.save_player_game()
				print("JOGO SALVO (Save Point)!")
			
			elif current_tile.tipo == "Terminal":
				# Chama a nova função pública do Main
				main_script.tentar_ativar_terminal(grid_pos)
		
# NOVO: Usar Item Equipado
	if event.is_action_pressed("usar_item_equipado"):
		var item = Game_State.item_equipado
		if item:
			print("Player: Usando item equipado -> ", item.nome_item)
			# Chama a função de usar item do Main
			# (Assumindo que main_script é o Main.gd)
			main_script.usar_item(item)
			
			# Lógica de Consumo (Durabilidade)
			if item.durabilidade > 0: # Se não for infinito (-1)
				item.durabilidade -= 1
				if item.durabilidade <= 0:
					Game_State.inventario_jogador.remover_item(item)
					Game_State.equipar_item(null) # Tira da mão
			# Opcional: Tocar animação ou som
		else:
			print("Player: Nenhum item equipado!")
		
		# --- QUICK EQUIP (Atalhos Q / E) ---
	if event is InputEventKey and event.pressed:
		
		# Q: Cicla para a Esquerda (Anterior)
		if event.keycode == KEY_Q:
			print("Player: Quick Equip Anterior")
			Game_State.ciclar_item_equipado(-1)
			
		# E (ou W): Cicla para a Direita (Próximo)
		# Mudei para KEY_E para evitar conflito com andar para Cima (W)
		elif event.keycode == KEY_W: 
			print("Player: Quick Equip Próximo")
			Game_State.ciclar_item_equipado(1)

# --- SISTEMA DE DANO E KNOCKBACK DO PLAYER ---

func receber_dano(atk_inimigo: int, kb_power: int, pos_atacante: Vector2i):
	var dano = max(0, atk_inimigo - stats.def)
	Game_State.vida_jogador -= dano
	print("Player tomou %d de dano! Vida restante: %d" % [dano, Game_State.vida_jogador])
	
	if dano > 0:
		# Vermelho Sangue para dano sofrido
		var pos_visual = global_position + Vector2(-16, -16)
		main_script.spawn_floating_text(pos_visual, "-%d" % dano, Color(1, 0.2, 0.2))
	else:
		# Se a defesa for muito alta
		var pos_visual = global_position + Vector2(-16, -16)
		main_script.spawn_floating_text(pos_visual, "BLOCK", Color.GRAY)
	# Feedback Visual de Dano
	var t = create_tween()
	t.tween_property(self, "modulate", Color.RED, 0.1)
	t.tween_property(self, "modulate", Color.WHITE, 0.1)
	
	# Lógica de Knockback
	var forca_empurrao = kb_power - stats.poise
	if forca_empurrao > 0:
		print("Player sofreu knockback de força %d!" % forca_empurrao)
		_aplicar_knockback_player(pos_atacante, forca_empurrao)
	
	# --- NOVO: CHECAGEM DE MORTE ---
	if Game_State.vida_jogador <= 0:
		_morrer()

func _morrer():
	print("Player: Vida zerou. Game Over.")
	
	# Desativa processamento do player para ele não andar morto
	set_physics_process(false)
	set_process_unhandled_input(false)
	
	# Carrega a cena de Game Over
	# Opção A: carregar como uma cena nova (substitui o jogo):
	get_tree().change_scene_to_file("res://scenes/GameOver.tscn")
	
	# Opção B: Instancia a tela por cima de tudo sem fechar o Main
	# var game_over_screen = load("res://scenes/ui/GameOver.tscn").instantiate()
	# get_tree().root.add_child(game_over_screen)


func _aplicar_knockback_player(origem_impacto: Vector2i, forca: int):
	# 1. Calcula direção oposta ao impacto
	var diff = grid_pos - origem_impacto
	var dir = Vector2i(clamp(diff.x, -1, 1), clamp(diff.y, -1, 1))
	
	if dir == Vector2i.ZERO: return
	
	var dest = grid_pos
	var bateu_obstaculo = false
	
	# 2. Verifica se o destino é válido (Lógica simplificada: empurra X tiles ou para se bater)
	for i in range(forca):
		var proximo_teste = dest + dir
		
		# Checa Parede
		if not main_script.is_tile_passable(proximo_teste):
			bateu_obstaculo = true
			break
			
		# Checa se vai cair em cima de outro inimigo
		if main_script.is_tile_occupied_by_enemy(proximo_teste):
			bateu_obstaculo = true
			break
		dest = proximo_teste
	
	# 3. Aplica o movimento se mudou de lugar
	if dest != grid_pos:
		# Interrompe movimento normal de caminhada para forçar o empurrão
		moving = false 
		
		# Stun breve para dar peso ao golpe
		input_cooldown = 0.2 
		
		grid_pos = dest
		target_pos = (Vector2(grid_pos) * TILE_SIZE) + (Vector2.ONE * TILE_SIZE / 2.0)
		
		# Usa Tween para o movimento rápido de impacto
		var t = create_tween()
		t.tween_property(self, "global_position", target_pos, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		
		print("Player empurrado para: ", grid_pos)
	
	# 4. Wall Slam (Se foi bloqueado)
	if bateu_obstaculo:
		print("Player bateu contra obstáculo! Dano extra.")
		Game_State.vida_jogador -= 5 # Dano de impacto
		
		# Shake visual no sprite (não no corpo todo para não desalinhar)
		var t = create_tween()
		t.tween_property(anim, "position", Vector2(dir) * 4, 0.05)
		t.tween_property(anim, "position", Vector2.ZERO, 0.05)

func _atacar_inimigo_no_tile(pos: Vector2i):
	var inimigos = get_tree().get_nodes_in_group("inimigos")
	for ini in inimigos:
		if ini.grid_pos == pos:
			print(">>> Player atacou Inimigo!")
			ini.receber_dano(stats.atk, stats.knockback, grid_pos)
			break

func tentar_disparar_kill9():
	# 1. Verifica Munição
	if stats["kill9_ammo"] > 0:
		
		# 2. Define Direção
		var dir_vec = Vector2i.DOWN
		match last_facing:
			"up": dir_vec = Vector2i.UP
			"down": dir_vec = Vector2i.DOWN
			"left": dir_vec = Vector2i.LEFT
			"right": dir_vec = Vector2i.RIGHT
			
		# 3. Chama o Main para calcular o tiro (Raycast)
		# Passamos o DANO e KNOCKBACK dinâmicos do dicionário
		main_script.disparar_kill9(grid_pos, dir_vec, stats["kill9_dmg"], stats["kill9_kb"])
		
		# 4. Consome Munição
		stats["kill9_ammo"] -= 1
		
		# 5. Atualiza o Mestre (GameState) imediatamente para não perder dados
		Game_State.stats_jogador["kill9_ammo"] = stats["kill9_ammo"]
		
		Game_State.municao_kill9_alterada.emit(stats["kill9_ammo"])
		
		print("Player: Kill-9 disparada! Restam: ", stats["kill9_ammo"])
		
		# Cooldown visual/lógico
		input_cooldown = ATTACK_COOLDOWN
		anim.play("attack_" + last_facing) # Ou uma animação de tiro se tiver
		
	else:
		print("Player: Kill-9 sem munição! *Click*")
		main_script.spawn_floating_text(global_position + Vector2(0, -24), "SEM BALA", Color.GRAY)

# Chamado pelo GameState quando compramos um upgrade
func sincronizar_stats_com_gamestate():
	# 1. Atualiza Dicionário
	stats = Game_State.stats_jogador.duplicate()
	
	# Feedback Visual Rápido (Piscar Verde ou Partículas)
	var t = create_tween()
	t.tween_property(self, "modulate", Color.GREEN, 0.2)
	t.tween_property(self, "modulate", Color.WHITE, 0.2)
	
	# 2. Atualiza Feedback Visual (Opcional, ex: som de powerup)
	print("Player: Stats sincronizados. Novo ATK: %d | Kill-9 DMG: %d" % [stats["atk"], stats["kill9_dmg"]])
	
	# Se você tiver lógica de HP no Player, atualize aqui também, 
	# mas geralmente o Player lê direto do Game_State.vida_jogador no _process ou receber_dano.
