extends Node2D

@export var stone_scene: PackedScene
@onready var turn_label = $UI/TurnLabel
@onready var game_over_panel = $UI/GameOverPanel
@onready var game_over_label = $UI/GameOverPanel/Label

enum GameState { COIN_TOSS, PLACEMENT, BATTLE }
var current_state = GameState.COIN_TOSS

var current_turn = 1 # 1: Player 1 (Black), 2: Player 2 (White)
var first_player = 1
var stones_p1 = []
var stones_p2 = []
var is_moving = false

var total_stones_to_place = 0
var stones_placed = 0

func _ready():
	if game_over_panel:
		game_over_panel.visible = false
		
	total_stones_to_place = Global.stone_count * 2
	start_coin_toss()

func start_coin_toss():
	current_state = GameState.COIN_TOSS
	randomize()
	first_player = randi() % 2 + 1
	current_turn = first_player
	
	if turn_label:
		if first_player == 1:
			turn_label.text = "동전 던지기 결과: 흑돌(1P) 선공 및 먼저 배치!"
		else:
			turn_label.text = "동전 던지기 결과: 백돌(2P) 선공 및 먼저 배치!"
	
	await get_tree().create_timer(2.0).timeout
	current_state = GameState.PLACEMENT
	update_turn_ui()

func _unhandled_input(event):
	if current_state != GameState.PLACEMENT:
		return
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var click_pos = get_global_mouse_position()
		
		# 바둑판 영역 검사 (가로 300~980, 세로 20~700)
		if click_pos.x < 300 or click_pos.x > 980 or click_pos.y < 20 or click_pos.y > 700:
			return
			
		# 진영 규칙: 흑은 왼쪽(< 640), 백은 오른쪽(> 640)
		if current_turn == 1 and click_pos.x >= 640:
			return
		if current_turn == 2 and click_pos.x <= 640:
			return
			
		# 다른 돌과 겹치는지 검사 (반지름 20이므로 최소 40 이상 떨어져야 함)
		var all_stones = stones_p1 + stones_p2
		for s in all_stones:
			if is_instance_valid(s) and s.position.distance_to(click_pos) < 42.0:
				return
				
		place_stone(click_pos)

func place_stone(pos):
	var stones_container = get_node_or_null("Stones")
	if not stones_container:
		stones_container = self
		
	var s = stone_scene.instantiate()
	stones_container.add_child(s)
	s.position = pos
	s.setup(current_turn, self)
	
	# 배치 단계에서는 바로 조작 불가
	s.set_interactable(false)
	
	if current_turn == 1:
		stones_p1.append(s)
	else:
		stones_p2.append(s)
		
	stones_placed += 1
	
	if stones_placed >= total_stones_to_place:
		start_battle()
	else:
		current_turn = 2 if current_turn == 1 else 1
		update_turn_ui()

func start_battle():
	current_state = GameState.BATTLE
	current_turn = first_player # 선공 유저가 먼저 공격
	update_turn_ui()
	
	var all_stones = stones_p1 + stones_p2
	for stone in all_stones:
		if is_instance_valid(stone):
			stone.set_interactable(stone.player_id == current_turn)

func _process(_delta):
	var all_stones = stones_p1 + stones_p2
	var dropped_any = false
	for stone in all_stones:
		if is_instance_valid(stone) and not stone.is_queued_for_deletion():
			if stone.position.x < 300 or stone.position.x > 980 or stone.position.y < 20 or stone.position.y > 700:
				stone.queue_free()
				dropped_any = true
				
	if dropped_any:
		call_deferred("check_win_condition_immediately")

	if is_moving:
		check_movement()

func check_movement():
	var any_moving = false
	var all_stones = stones_p1 + stones_p2
	
	for stone in all_stones:
		if is_instance_valid(stone):
			if stone.linear_velocity.length() > 5.0 or abs(stone.angular_velocity) > 0.5:
				any_moving = true
				break
				
	if not any_moving:
		is_moving = false
		end_turn()

func on_stone_launched():
	is_moving = true

func end_turn():
	stones_p1 = stones_p1.filter(func(s): return is_instance_valid(s) and s.is_inside_tree() and not s.is_queued_for_deletion())
	stones_p2 = stones_p2.filter(func(s): return is_instance_valid(s) and s.is_inside_tree() and not s.is_queued_for_deletion())

	if stones_p1.size() == 0:
		show_game_over("Player 2 Wins!")
		return
	elif stones_p2.size() == 0:
		show_game_over("Player 1 Wins!")
		return
		
	current_turn = 2 if current_turn == 1 else 1
	update_turn_ui()
	
	var all_stones = stones_p1 + stones_p2
	for stone in all_stones:
		if is_instance_valid(stone):
			stone.set_interactable(stone.player_id == current_turn)

func update_turn_ui():
	if not turn_label:
		return
		
	if current_state == GameState.PLACEMENT:
		if current_turn == 1:
			turn_label.text = "[배치] Player 1 (흑) - 왼쪽 진영 클릭"
		else:
			turn_label.text = "[배치] Player 2 (백) - 오른쪽 진영 클릭"
	elif current_state == GameState.BATTLE:
		if current_turn == 1:
			turn_label.text = "Player 1's Turn (Black)"
		else:
			turn_label.text = "Player 2's Turn (White)"

func show_game_over(msg):
	if game_over_panel:
		game_over_panel.visible = true
		game_over_label.text = msg

func _on_bounds_body_exited(body):
	if body.is_in_group("stone"):
		body.queue_free()
		call_deferred("check_win_condition_immediately")

func check_win_condition_immediately():
	stones_p1 = stones_p1.filter(func(s): return is_instance_valid(s) and s.is_inside_tree() and not s.is_queued_for_deletion())
	stones_p2 = stones_p2.filter(func(s): return is_instance_valid(s) and s.is_inside_tree() and not s.is_queued_for_deletion())
	
	if stones_p1.size() == 0:
		show_game_over("Player 2 Wins!")
	elif stones_p2.size() == 0:
		show_game_over("Player 1 Wins!")

func _on_retry_button_pressed():
	get_tree().reload_current_scene()

func _on_main_menu_button_pressed():
	get_tree().change_scene_to_file("res://MainMenu.tscn")
