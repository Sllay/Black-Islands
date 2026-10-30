class_name WorldIdentity
extends RefCounted
## Accepted generation inputs live in profile metadata, independent of scene lifetime.

static func establish(metadata: Dictionary) -> Error:
	var save_id: String = metadata.get("save_id", "")
	if save_id.length() != 32 or not save_id.is_valid_hex_number(false) or save_id.contains("-") or save_id.contains("+"):
		return ERR_INVALID_DATA
	if metadata.has("world_generation_version") and not WorldGenerationProfile.supported(int(metadata.world_generation_version),str(metadata.get("world_profile",""))):
		return ERR_UNAVAILABLE
	if not metadata.has("world_seed"):
		if metadata.has("world_generation_version") or metadata.has("world_profile"):
			return ERR_INVALID_DATA
		metadata["world_seed"] = save_id.sha256_text().substr(0, 8).hex_to_int() & 0x7fffffff
		metadata["world_generation_version"] = IslandField.VERSION
		metadata["world_profile"] = IslandField.PROFILE_ID
	if not (metadata.world_seed is int or metadata.world_seed is float):
		return ERR_INVALID_DATA
	if metadata.world_seed != int(metadata.world_seed) or metadata.world_seed < 0 or metadata.world_seed > 0x7fffffff:
		return ERR_INVALID_DATA
	if not WorldGenerationProfile.supported(int(metadata.get("world_generation_version",0)),str(metadata.get("world_profile",""))):
		return ERR_UNAVAILABLE
	return OK
