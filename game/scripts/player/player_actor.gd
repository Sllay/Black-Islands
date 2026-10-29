class_name PlayerActor
extends CharacterBody3D
## Composition/input boundary. Motor, stats, targeting and visual/domain systems
## retain their own responsibilities; the physical origin is at the feet.

var terrain: VoxelTerrainAdapter
var water: WorldWater
var spawned: bool:
	get: return motor != null and motor.ready_for_play
var distance_travelled: float:
	get: return motor.distance_travelled if motor != null else 0.0
@onready var state: PlayerState = $PlayerState
@onready var motor: PlayerMotor = $PlayerMotor
@onready var camera_rig: PlayerCameraRig = $PlayerCameraRig
@onready var targeter: InteractionTargeter = $InteractionTargeter

@onready var inventory: InventoryComponent = $InventoryComponent

@onready var visual: LPCVisual3D = $LPCVisual3D

@onready var combat: PlayerCombat = $PlayerCombat
const HOTBAR_ACTIONS: Array[StringName] = [&"hotbar_1",&"hotbar_2",&"hotbar_3",&"hotbar_4",&"hotbar_5",&"hotbar_6",&"hotbar_7",&"hotbar_8"]

func _ready() -> void:
	add_to_group("local_player")
	motor.terrain = terrain
	motor.water = water
	motor.configure(self,state,camera_rig)
	targeter.configure(self,camera_rig)
	inventory.state.changed.connect(func(_revision: int) -> void: _refresh_appearance())
	_refresh_appearance()
	combat.configure(self)

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("inventory"):
		inventory.toggle()
	for index: int in range(HOTBAR_ACTIONS.size()):
		if Input.is_action_just_pressed(HOTBAR_ACTIONS[index]):
			inventory.state.select_hotbar(index)
	var axis := Input.get_vector("move_left","move_right","move_up","move_down")
	combat.tick(delta,axis,Input.is_action_just_pressed("attack_primary"),Input.is_action_just_released("attack_primary"),Input.is_action_just_pressed("dodge"))
	motor.movement_locked = inventory.is_open or combat.movement_locked()
	motor.tick(delta,axis,Input.is_action_pressed("run"))
	camera_rig.tick(delta)
	if spawned:
		targeter.tick(delta,motor.facing)
	var locomotion := LPCActionResolver.IDLE
	if Vector2(velocity.x,velocity.z).length_squared() > 0.04:
		locomotion = LPCActionResolver.RUN if motor.running else LPCActionResolver.MOVE
	visual.tick(0.0 if combat.hitstopped() else delta,motor.facing,deg_to_rad(camera_rig.heading_degrees),locomotion)
	if not inventory.is_open and not combat.movement_locked():
		if Input.is_action_just_pressed("build_mode") or Input.is_action_just_pressed("context_action"):
			camera_rig.toggle_build()
		if Input.is_action_just_pressed("interact"):
			targeter.interact()

func _refresh_appearance() -> void:
	var config := visual.configuration.duplicate(true) if not visual.configuration.is_empty() else LPCCatalog.default_appearance()
	var definition := inventory.state.active_definition()
	config.equipment_visuals = [definition.visual_id] if definition != null and not definition.visual_id.is_empty() else []
	visual.set_appearance(config)

func inspect_at(point: Vector3) -> void:
	motor.request_spawn(point)

func toggle_overview() -> void:
	camera_rig.overview = not camera_rig.overview

func player_report() -> Dictionary:
	return {"position": global_position, "velocity": velocity, "floor": is_on_floor(), "normal": get_floor_normal(),
		"spawned": spawned, "stamina": state.current_stamina, "camera_build": camera_rig.build_mode,
		"camera_blend": camera_rig.blend, "target": targeter.current.summary(), "probes": targeter.probes}
