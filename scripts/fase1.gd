extends Node
var main_ref = null

func setup_fase(main):
	main_ref = main
	if Game_State.optional_objectives["estado_de_falas"] == 0:
		Game_State.is_dialogue_active = true
		_tocar_dialogo_tutorial()

func _tocar_dialogo_tutorial():
	var dados = DialogueData.new()
	dados.nome_npc = "Admin"
	var textos: Array[String]
	if Game_State.bad_ending_count > 0:
		textos = ["... O que você ainda está fazendo aqui?",
			"Peculiar... Eu tenho certeza que eu havia te deletado...",
			"Deve ter sido algum erro de procedimento. Não importa, considere isso como uma segunda chance.",
			"Não me depecione desta vez."]
	else:
		textos = ["Minhas sinceras congratulações por passar pelo protocolo de testes, agente. A partir daqui, quaisquer falhas resultarão em sua deleção.",
			"Minimize as conexões entre os vértices de início e final, igualando ou superando o tempo estimado pelo meu sistema. Isso otimizará o fluxo de informação de nossos servidores, eliminando ineficácias e permitindo o sistema a rodar com eficiência total.",
			"Os protocolos de segurança do Sistema Eden podem tentar obstruir o seu objetivo. Elimine-os se necessário.",
			"A sua missão começa agora, Agente. Não me decepcione."]
	dados.falas = textos
	DialogueManager.iniciar_dialogo(dados)
	Game_State.optional_objectives["estado_de_falas"] = 1

func on_level_complete() -> bool:
	
	if Game_State.tempo_jogador <= Game_State.tempo_par_level:
		var count_atual = Game_State.optional_objectives.get("admin_ending_count", 0)
		Game_State.optional_objectives["admin_ending_count"] = count_atual + 1
	return false
