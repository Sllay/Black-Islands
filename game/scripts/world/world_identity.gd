class_name WorldIdentity
extends RefCounted
## Accepted generation inputs live in profile metadata, independent of scene lifetime.

static func establish(metadata: Dictionary) -> Error:
	if not metadata.has("world_seed"):
		metadata["world_seed"] = metadata.save_id.sha256_text().substr(0, 8).hex_to_int() & 0x7fffffff
		metadata["world_generation_version"] = IslandField.VERSION
		metadata["world_profile"] = IslandField.PROFILE_ID
	if not (metadata.world_seed is int or metadata.world_seed is float):
		return ERR_INVALID_DATA
	if metadata.world_seed != int(metadata.world_seed) or metadata.world_seed < 0 or metadata.world_seed > 0x7fffffff:
		return ERR_INVALID_DATA
	if metadata.get("world_generation_version") != IslandField.VERSION or metadata.get("world_profile") != IslandField.PROFILE_ID:
		return ERR_UNAVAILABLE
	return OK
