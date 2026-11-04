class_name ItemCatalog
extends RefCounted
const VERSION := 1 # Save content identity preserved; catalog schema is independent.
static var _definitions: Dictionary = {}
static var _revision := -1
static var missing_ids: Dictionary = {}
static func resolve(id: String) -> ItemDefinition:
	if _revision != ContentData.revision:
		_definitions.clear()
		for record: Dictionary in ContentData.rows("items"):
			_definitions[record.id] = ItemDefinition.new(record)
		_revision = ContentData.revision
	return _definitions.get(id,missing_ids.get(id))

static func orphan(id: String) -> ItemDefinition:
	if not missing_ids.has(id):
		missing_ids[id] = ItemDefinition.new({"id":id,"title":"[Missing content] "+id,"category":"RESOURCE","stack_limit":2147483647,"missing":true})
	return missing_ids[id]
