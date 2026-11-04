extends SceneTree
func _init() -> void:
	var issues := ContentValidator.validate(ContentData.all())
	for row: Dictionary in issues:
		print(row.severity," ",row.section,"/",row.definition,": ",row.message)
	print("CONTENT_VALIDATION ","FAIL" if ContentValidator.has_errors(issues) else "PASS")
	quit(1 if ContentValidator.has_errors(issues) else 0)
