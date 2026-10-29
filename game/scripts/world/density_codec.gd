class_name DensityCodec
extends RefCounted
## Black Island save codec: signed 16-bit distance, +/-250 metres world range.
## The current 0.5m native SDF16 adapter maps these codes without requantizing.
## A future backend decodes physical distance through this versioned boundary.

const ID := "density_s16_250m_v1"
const RANGE_METRES := 250.0

static func metres(code: int) -> float:
	return clampf(float(code) / 32767.0, -1.0, 1.0) * RANGE_METRES
