class_name DirtyWorldStore
extends RefCounted
## Immutable regional segments + atomic manifest; only dirty regions serialize.
## Unreferenced staged files are harmless. Terrain chunks retain the P02 format.
const DOMAINS := ["props","suppression","farms","structures","containers","mobs"]
var document: AtomicDocument
var directory: String
var runtime: SurfaceRuntime
var dirty: Dictionary = {}
var members: Dictionary = {}
var locations: Dictionary = {}
var last_writes := 0
var last_records := 0

func _init(root: String, world_id: String) -> void:
	directory = root
	document = AtomicDocument.new(root.path_join("world.json"),2,{"world_id":world_id})

func load_world() -> Error:
	var old := directory.path_join("surface.json")
	if not FileAccess.file_exists(document.path) and FileAccess.file_exists(old):
		var error := DirAccess.copy_absolute(old,document.path)
		if error != OK:
			return error
	return SchemaMigrations.read(document,{1:migrate_1_to_2})

func migrate_1_to_2(data: Dictionary) -> Dictionary:
	var surface: Dictionary = data.get("surface",{})
	var global := surface.duplicate(true)
	var manifest := {"global":global,"sessions":data.get("sessions",{}),"played_seconds":data.get("played_seconds",0),"segments":{}}
	for domain: String in DOMAINS:
		global.erase(domain)
		var rows: Dictionary = surface.get(domain,{})
		if rows.is_empty():
			continue
		# One-time migration bucket; first runtime reconciliation regionalizes it.
		var key := domain+"/legacy"
		var file := "segments/"+key+"/migration.json"
		var doc := AtomicDocument.new(directory.path_join(file),1,{"world_id":document.identity.world_id,"region":key})
		var error := doc.read()
		if error == OK:
			error = doc.commit({"rows":rows})
		if error != OK:
			return {"error":error}
		manifest.segments[key] = {"file":file,"revision":doc.revision,"domain":domain}
	return {"error":OK,"data":manifest}

func restore_surface() -> Dictionary:
	var surface: Dictionary = document.loaded.get("global",{}).duplicate(true)
	if surface.is_empty():
		return {}
	for domain: String in DOMAINS:
		surface[domain] = {}
	for key: String in document.loaded.get("segments",{}):
		var segment: Dictionary = document.loaded.segments[key]
		var doc := AtomicDocument.new(directory.path_join(segment.file),1,{"world_id":document.identity.world_id,"region":key})
		if doc.read() != OK or doc.revision != int(segment.revision):
			return {"load_error":ERR_FILE_CORRUPT}
		surface[segment.domain].merge(doc.loaded.rows)
	return surface

func sources() -> Dictionary:
	return {"props":runtime.ledger.props,"suppression":runtime.ledger.suppression,"farms":runtime.farms.plots,
		"structures":runtime.building.pieces,"containers":runtime.containers.records,"mobs":runtime.mobs.domain.states}

func bind(surface: SurfaceRuntime) -> void:
	runtime = surface
	for domain: String in DOMAINS:
		for id: String in sources()[domain]:
			mark(domain,id)
	# One initial reconciliation covers mutations during restore (e.g. lost support).
	for key: String in document.loaded.get("segments",{}):
		dirty[key] = true
	runtime.ledger.changed.connect(mark)
	runtime.farms.changed.connect(func(id: String) -> void: mark("farms",id))
	runtime.building.changed.connect(func(id: String) -> void: mark("structures",id))
	runtime.containers.changed.connect(func(id: String) -> void: mark("containers",id))
	runtime.mobs.domain.changed.connect(func(id: String) -> void: mark("mobs",id))

func mark(domain: String, id: String) -> void:
	var owner := domain+":"+id
	if locations.has(owner):
		var previous: String = locations[owner]
		members[previous].erase(id)
		dirty[previous] = true
	var rows: Dictionary = sources()[domain]
	if not rows.has(id):
		locations.erase(owner)
		return
	var row: Dictionary = rows[id]
	var point: Array = row.get("position",row.get("cell",[0,0,0])) if domain != "suppression" else id.split(",")
	var region := Vector3i(floori(float(point[0])/64),floori(float(point[1])/64),floori(float(point[2])/64))
	var key := "%s/%d_%d_%d"%[domain,region.x,region.y,region.z]
	if not members.has(key):
		members[key] = {}
	members[key][id] = true
	locations[owner] = key
	dirty[key] = true

func stage(global: Dictionary, sessions: Dictionary, played: float) -> Dictionary:
	last_writes = 0
	last_records = 0
	var manifest := document.loaded.duplicate(true)
	manifest.global = global
	manifest.sessions = sessions
	manifest.played_seconds = played
	if not manifest.has("segments"):
		manifest.segments = {}
	var tables := sources()
	for key: String in dirty:
		var domain := key.get_slice("/",0)
		var rows: Dictionary = {}
		for id: String in members.get(key,{}):
			if not tables[domain].has(id):
				continue
			rows[id] = tables[domain][id].duplicate(true)
			if domain == "containers":
				rows[id].inventory = runtime.containers.inventories[id].snapshot()
		last_records += rows.size()
		var file := "segments/"+key+"/"+Crypto.new().generate_random_bytes(12).hex_encode()+".json"
		var doc := AtomicDocument.new(directory.path_join(file),1,{"world_id":document.identity.world_id,"region":key})
		var error := doc.commit({"rows":rows})
		if error != OK:
			return {"error":error}
		manifest.segments[key] = {"file":file,"revision":doc.revision,"domain":domain}
		last_writes += 1
	return {"error":OK,"data":manifest}

func committed() -> void:
	var keep: Dictionary = {}
	for segment: Dictionary in document.loaded.get("segments",{}).values():
		keep[segment.file] = true
	var previous := document.inspect(document.path+".bak")
	if previous.error == OK:
		for segment: Dictionary in previous.data.get("segments",{}).values():
			keep[segment.file] = true
	for key: String in dirty:
		var folder := directory.path_join("segments/"+key)
		for file: String in DirAccess.get_files_at(folder):
			var relative := "segments/"+key+"/"+file
			if not keep.has(relative):
				DirAccess.remove_absolute(directory.path_join(relative))
	dirty.clear()

static func global_state(surface: SurfaceRuntime) -> Dictionary:
	var ledger := surface.ledger
	return {"schema_version":1,"content_version":SurfaceCatalog.VERSION,"structure_module_version":2,
		"bags":{},"clock":ledger.clock,"active_seconds":ledger.active_seconds,"sequence":ledger.sequence,"flags":ledger.flags.duplicate(true)}
