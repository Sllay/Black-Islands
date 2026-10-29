class_name AtomicBatch
extends RefCounted
## Roll-forward journal protects ownership spanning independently owned documents.
static func commit(path: String, documents: Array[AtomicDocument], payloads: Array[Dictionary]) -> Error:
	var recovery := recover(path)
	if recovery != OK:
		return recovery
	var journal := AtomicDocument.new(path,1,{"kind":"ownership_commit"})
	var participants: Array = []
	for index: int in documents.size():
		var doc := documents[index]
		participants.append({"path":doc.path,"schema":doc.schema,"identity":doc.identity,
			"revision":doc.revision,"data":payloads[index]})
	var error := journal.commit({"participants":participants})
	if error != OK:
		return error
	error = recover(path)
	if error == OK:
		for doc: AtomicDocument in documents:
			error = doc.read()
			if error != OK:
				return error
	return error

static func recover(path: String) -> Error:
	var journal := AtomicDocument.new(path,1,{"kind":"ownership_commit"})
	var error := journal.read()
	if error != OK or journal.loaded.is_empty():
		return error
	for row: Dictionary in journal.loaded.participants:
		var doc := AtomicDocument.new(row.path,int(row.schema),row.identity)
		error = doc.read()
		if error != OK:
			return error
		if doc.revision == int(row.revision)+1 and JSON.stringify(doc.loaded,"",true) == JSON.stringify(row.data,"",true):
			continue
		if doc.revision != int(row.revision):
			return ERR_ALREADY_IN_USE
		error = doc.commit(row.data)
		if error != OK:
			return error
	for suffix: String in [".bak",".tmp",""]:
		if FileAccess.file_exists(path+suffix):
			error = DirAccess.remove_absolute(path+suffix)
			if error != OK:
				return error
	return OK
