extends RigidBody2D

@export var max_drag_distance = 200.0
@export var power_multiplier = 7.0

var is_dragging = false
var drag_start = Vector2()
var player_id = 1
var interactable = false
var game_manager = null

@onready var line_2d = $Line2D
@onready var sprite = $Sprite2D
@onready var power_gauge = get_node_or_null("PowerGauge")

func _ready():
	add_to_group("stone")
	if line_2d:
		line_2d.visible = false
		# 시각적으로 궤적 선의 너비를 설정합니다
		line_2d.width = 5.0
		line_2d.default_color = Color(1.0, 0.0, 0.0, 0.6) # 빨간색 반투명
		
	if power_gauge:
		power_gauge.visible = false
		power_gauge.max_value = 100

	# 물리 속성 초기화 (통통 튀는 느낌 방지 및 미끄러짐 구현)
	gravity_scale = 0.0 # 위에서 내려다보는 2D 시점이므로 중력 0
	linear_damp = 1.5   # 미끄러지다 멈추도록 선형 저항 설정
	angular_damp = 2.0  # 회전 저항 설정
	
	# 충돌 시 이벤트를 받기 위해 필요
	input_pickable = true 

func setup(id, manager):
	player_id = id
	game_manager = manager
	
	if player_id == 1:
		sprite.modulate = Color(0.1, 0.1, 0.1) # 흑돌
	else:
		sprite.modulate = Color(1.0, 1.0, 1.0) # 백돌
		
	# 첫 턴(1P) 설정
	if game_manager != null and player_id == game_manager.current_turn:
		interactable = true

func set_interactable(val):
	interactable = val

func _input_event(_viewport, event, _shape_idx):
	if not interactable or (game_manager and game_manager.is_moving):
		return
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_dragging = true
			drag_start = get_global_mouse_position()
			if line_2d:
				line_2d.visible = true
				line_2d.points = [Vector2.ZERO, Vector2.ZERO]
			if power_gauge:
				power_gauge.visible = true
				power_gauge.value = 0

func _process(_delta):
	if is_dragging:
		var current_mouse = get_global_mouse_position()
		var drag_vector = drag_start - current_mouse
		
		# 드래그 최대 거리 제한
		if drag_vector.length() > max_drag_distance:
			drag_vector = drag_vector.normalized() * max_drag_distance
			
		# Line2D는 노드의 로컬 좌표를 사용하므로 drag_vector를 그대로 방향으로 사용
		if line_2d:
			line_2d.points[1] = drag_vector
			
		if power_gauge:
			power_gauge.value = (drag_vector.length() / max_drag_distance) * 100.0

func _input(event):
	if is_dragging and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		is_dragging = false
		if line_2d:
			line_2d.visible = false
		if power_gauge:
			power_gauge.visible = false
			
		var current_mouse = get_global_mouse_position()
		var drag_vector = drag_start - current_mouse
		
		if drag_vector.length() > max_drag_distance:
			drag_vector = drag_vector.normalized() * max_drag_distance
			
		# 일정 거리 이상 드래그했을 때만 발사
		if drag_vector.length() > 10.0:
			apply_central_impulse(drag_vector * power_multiplier)
			interactable = false # 발사 후 조작 불가
			
			if game_manager:
				game_manager.on_stone_launched()
