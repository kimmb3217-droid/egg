extends RigidBody2D

@export var max_drag_distance = 200.0
@export var power_multiplier = 7.0

var is_dragging = false
var drag_start = Vector2()
var player_id = 1
var interactable = false
var game_manager = null
var gauge_style = StyleBoxFlat.new()
var power_gradient = Gradient.new()

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
		power_gauge.top_level = true # 부모의 회전에 영향을 받지 않도록 분리
		
		# 파워 게이지 색상 그라데이션 설정
		power_gradient.set_color(0, Color.LIGHT_GREEN)
		power_gradient.set_color(1, Color.RED)
		power_gradient.add_point(0.25, Color.GREEN)
		power_gradient.add_point(0.5, Color.YELLOW)
		power_gradient.add_point(0.75, Color.ORANGE)
		
		# ProgressBar 채우기 스타일 설정
		power_gauge.add_theme_stylebox_override("fill", gauge_style)

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
			
		# Line2D는 노드의 로컬 좌표를 사용하므로 바둑알이 회전했을 경우를 대비해 역회전시켜 줍니다.
		if line_2d:
			line_2d.points[1] = drag_vector.rotated(-global_rotation)
			
		if power_gauge:
			var percentage = (drag_vector.length() / max_drag_distance) * 100.0
			power_gauge.value = percentage
			
			# 부드러운 색상 전환 적용
			gauge_style.bg_color = power_gradient.sample(percentage / 100.0)
			
			# 쏘는 방향(drag_vector.x)에 따라 게이지 위치를 돌의 왼쪽(-50) 또는 오른쪽(35)으로 배치
			var side_offset = 35.0
			if drag_vector.x > 0: # 오른쪽으로 쏠 때
				side_offset = -50.0
			
			# 부모의 회전에 영향을 받지 않게 글로벌 좌표로 고정
			power_gauge.global_position = global_position + Vector2(side_offset, -25.0)

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
