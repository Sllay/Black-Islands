class_name CraftJob
extends RefCounted
var id := "job_"+Crypto.new().generate_random_bytes(12).hex_encode()
var recipe_id := ""
var original_requested := 0
var requested_remaining := 0
var context: Dictionary = {}
func snapshot() -> Dictionary:
	return {"id":id,"recipe_id":recipe_id,"original_requested":original_requested,"requested_remaining":requested_remaining,"context":context.duplicate(true)}
