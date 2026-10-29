class_name MobSimulation
extends Node3D
## Tiers own presentation residency; entity identity/health remain authoritative.
var runtime: SurfaceRuntime
var domain: MobDomain
var actors: Dictionary = {}
var tiers: Dictionary = {}
var _poll := 0.0
var _regional_clock := 0.0
var _proxy_clock := 0.0
var _proxies: Dictionary = {}
var _regions: Dictionary = {}

func configure(surface: SurfaceRuntime, restored: Dictionary) -> void:
	runtime = surface
	domain = MobDomain.new(runtime.ledger,runtime.containers)
	domain.states = restored.duplicate(true)
	if not runtime.ledger.flags.get("mob_population",false):
		for definition: String in SurfaceCatalog.data().mobs:
			var rng := RandomNumberGenerator.new()
			rng.seed = (str(runtime.terrain.field.world_seed)+definition).hash()
			var angle := rng.randf_range(-PI,PI)
			var point := Vector3(cos(angle),0,sin(angle))*rng.randf_range(10,20)
			point.y = runtime.terrain.field.top_surface(point.x,point.z)+.05
			domain.spawn("mob:%d:%s:0" % [runtime.terrain.field.world_seed,definition],definition,point)
		runtime.ledger.flags.mob_population = true

func _process(delta: float) -> void:
	if not runtime.player.spawned or runtime.player.inventory.is_open:
		return
	_poll += delta
	_regional_clock += delta
	_proxy_clock += delta
	if _poll < .25:
		return
	_poll = 0
	domain.evaluate()
	reconcile()

func sync_positions() -> void:
	for id: String in actors:
		if domain.states[id].life == "ALIVE":
			var point: Vector3 = actors[id].global_position
			var previous: Array = domain.states[id].position
			if Vector3(previous[0],previous[1],previous[2]).distance_squared_to(point) > .0025:
				domain.states[id].position = [point.x,point.y,point.z]
				domain.changed.emit(id)

func reconcile() -> void:
	sync_positions()
	_regions.clear()
	for id: String in domain.states:
		var row: Dictionary = domain.states[id]
		if row.life != "ALIVE":
			continue
		var point := MobDomain._point(row)
		var region := Vector2i(floori(point.x/16),floori(point.z/16))
		if not _regions.has(region):
			_regions[region] = []
		_regions[region].append(id)
	var proxies: Dictionary = {}
	for id: String in domain.states:
		var state: Dictionary = domain.states[id]
		var point := MobDomain._point(state)
		var distance := runtime.player.position.distance_to(point)
		var tier := MobBrain.tier(distance) if state.life != "REMOVED" else "STASIS"
		tiers[id] = tier
		if tier != "ACTIVE" and actors.has(id):
			actors[id].brain.deactivate()
			actors[id].collision_layer = 0
			actors[id].set_physics_process(false)
			actors[id].visible = false
			actors[id].queue_free()
			actors.erase(id)
		if state.life == "REMOVED":
			continue
		if tier == "ACTIVE":
			if not actors.has(id):
				var actor: MobActor = load("res://scenes/surface/MobActor.tscn").instantiate()
				actor.system = self
				actor.entity_id = id
				actor.position = point
				add_child(actor)
				actors[id] = actor
			var definition: Dictionary = SurfaceCatalog.data().mobs[state.definition]
			var context := {"clock":runtime.ledger.clock,"distance":distance,"attacked":runtime.ledger.clock < state.attacked_until,"player_in_range":distance < 12,
				"territory_violation":distance < float(definition.territory),"time_of_day":"NIGHT" if fmod(runtime.ledger.clock/SurfaceLedger.DAY,1) >= .5 else "DAY",
				"pack_count":_pack_count(state,point),"health":state.health,"health_ratio":float(state.health)/float(definition.health)}
			if not runtime.player.targeter.has_line_of_sight(point):
				context.player_in_range = false
			if state.life == "ALIVE":
				actors[id].brain.tick(context,runtime.player.global_position)
			else:
				actors[id].brain.deactivate()
			actors[id].sync_life()
		elif tier == "NEAR_PROXY":
			if _proxy_clock >= 1 and state.life == "ALIVE":
				_logical_step(state,.2)
			if not proxies.has(state.definition):
				proxies[state.definition] = []
			proxies[state.definition].append(point)
		elif tier == "REGIONAL" and _regional_clock >= 5 and state.life == "ALIVE":
			state.intent = "REGIONAL_WANDER" # Logical update, no rigid body/path.
			_logical_step(state,1.0)
	if _regional_clock >= 5:
		_regional_clock = 0
	if _proxy_clock >= 1:
		_proxy_clock = 0
	_update_proxies(proxies)

func _pack_count(source: Dictionary, point: Vector3) -> int:
	var count := 0
	var center := Vector2i(floori(point.x/16),floori(point.z/16))
	for z: int in range(center.y-1,center.y+2):
		for x: int in range(center.x-1,center.x+2):
			for id: String in _regions.get(Vector2i(x,z),[]):
				var row: Dictionary = domain.states[id]
				if row.definition == source.definition and MobDomain._point(row).distance_squared_to(point) <= 144:
					count += 1
	return count

func _logical_step(state: Dictionary, distance: float) -> void:
	var angle := float(posmod(str(state.id).hash()+int(runtime.ledger.clock/5),628))/100.0
	var point := MobDomain._point(state)+Vector3(cos(angle),0,sin(angle))*distance
	var height := runtime.terrain.field.top_surface(point.x,point.z)
	if is_finite(height) and height > 1:
		state.position = [point.x,height+.05,point.z]
		domain.changed.emit(state.id)

func _update_proxies(groups: Dictionary) -> void:
	for id: String in SurfaceCatalog.data().mobs:
		if not _proxies.has(id):
			var view := MultiMeshInstance3D.new()
			view.multimesh = MultiMesh.new()
			view.multimesh.transform_format = MultiMesh.TRANSFORM_3D
			view.multimesh.mesh = load("res://resources/surface/"+str(SurfaceCatalog.data().mobs[id].visual)+".res")
			view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(view)
			_proxies[id] = view
		var batch: MultiMesh = _proxies[id].multimesh
		var points: Array = groups.get(id,[])
		batch.instance_count = points.size()
		for index: int in points.size():
			batch.set_instance_transform(index,Transform3D(Basis.IDENTITY,points[index]))

func harvest_corpse(id: String) -> Dictionary:
	var item := runtime.player.inventory.state.active_definition()
	if item == null or not SurfaceCatalog.data().tools.has(item.id) or domain.states[id].life != "CORPSE":
		return {"error":ERR_INVALID_DATA}
	if not runtime.player.state.consume(5):
		return {"error":ERR_UNAVAILABLE}
	var state: Dictionary = domain.states[id]
	if runtime.player.position.distance_to(MobDomain._point(state)) > 4:
		return {"error":ERR_UNAUTHORIZED}
	var result := domain.harvest(id,item.id,runtime.ledger.new_id("corpse_strike"),int(state.harvest.revision),runtime.player.inventory.state)
	if result.error == OK:
		if not result.overflow.is_empty():
			runtime.create_bag(MobDomain._point(state),result.overflow)
		runtime.player.visual.play_semantic(LPCActionResolver.MELEE_SLASH,.4)
	return result

func report() -> Dictionary:
	var counts := {"ACTIVE":0,"NEAR_PROXY":0,"REGIONAL":0,"STASIS":0}
	for tier: String in tiers.values():
		counts[tier] += 1
	return {"tiers":counts,"actors":actors.size(),"entities":domain.states.size()}
