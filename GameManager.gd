extends Node2D

@export var stone_scene: PackedScene
@onready var turn_label = $UI/TurnLabel
@onready var game_over_panel = $UI/GameOverPanel
@onready var game_over_label = $UI/GameOverPanel/Label

var current_turn = 1 # 1: Player 1 (Black), 2: Player 2 (White)
var stones_p1 = []
var stones_p2 = []
var is_moving = false

func _ready():
	if game_over_panel:
		game_over_panel.visible = false
		
	# 글로벌에서 설정한 돌 개수로 스폰
	spawn_stones(Global.stone_count)
	update_turn_ui()

func spawn_stones(count):
	# 씬에 "Stones" 라는 Node2D를 만들어 돌들을 그룹화하는 것을 권장합니다.
	var stones_container = get_node_or_null("Stones")
	if not stones_container:
		stones_container = self
		
	# 화면 해상도 1280x720 기준 예시 배치
	# 왼쪽은 흑돌, 오른쪽은 백돌
	var start_y = 360 - ((count - 1) * 25) # 화면 중앙 기준으로 세로 정렬
	
	for i in range(count):
		# Player 1 (Black)
		var s1 = stone_scene.instantiate()
		stones_container.add_child(s1)
		s1.position = Vector2(200, start_y + i * 50)
		s1.setup(1, self)
		stones_p1.append(s1)
		
		# Player 2 (White)
		var s2 = stone_scene.instantiate()
		stones_container.add_child(s2)
		s2.position = Vector2(1080, start_y + i * 50)
		s2.setup(2, self)
		stones_p2.append(s2)

func _process(_delta):
	if is_moving:
		check_movement()

func check_movement():
	var any_moving = false
	var all_stones = stones_p1 + stones_p2
	
	for stone in all_stones:
		if is_instance_valid(stone):
			# 선형 속도가 5 이상이거나 회전 속도가 남아있을 경우 움직이는 것으로 간주
			if stone.linear_velocity.length() > 5.0 or abs(stone.angular_velocity) > 0.5:
				any_moving = true
				break
				
	if not any_moving:
		is_moving = false
		end_turn()

func on_stone_launched():
	is_moving = true

func end_turn():
	# 무효화된(낙사한) 돌들 정리
	stones_p1 = stones_p1.filter(func(s): return is_instance_valid(s) and s.is_inside_tree())
	stones_p2 = stones_p2.filter(func(s): return is_instance_valid(s) and s.is_inside_tree())

	# 승패 판정
	if stones_p1.size() == 0:
		show_game_over("Player 2 Wins!")
		return
	elif stones_p2.size() == 0:
		show_game_over("Player 1 Wins!")
		return
		
	# 턴 넘기기
	current_turn = 2 if current_turn == 1 else 1
	update_turn_ui()
	
	# 다음 플레이어의 돌 상호작용 활성화
	var all_stones = stones_p1 + stones_p2
	for stone in all_stones:
		if is_instance_valid(stone):
			stone.set_interactable(stone.player_id == current_turn)

func update_turn_ui():
	if not turn_label:
		return
		
	if current_turn == 1:
		turn_label.text = "Player 1's Turn (Black)"
	else:
		turn_label.text = "Player 2's Turn (White)"

func show_game_over(msg):
	if game_over_panel:
		game_over_panel.visible = true
		game_over_label.text = msg

# Area2D (Bounds) 노드의 body_exited 시그널에 연결할 함수
func _on_bounds_body_exited(body):
	if body.is_in_group("stone"):
		body.queue_free()

func _on_retry_button_pressed():
	get_tree().reload_current_scene()

func _on_main_menu_button_pressed():
	get_tree().change_scene_to_file("res://MainMenu.tscn")
