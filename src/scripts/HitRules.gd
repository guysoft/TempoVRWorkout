class_name HitRules
extends RefCounted

# Hit level rules ported from PowerBeatsVR GameManager.GetHitLevel.
# All thresholds are SQUARED velocities (m^2/s^2) for performance.
#
# PBVR reference (decompiled GameManager.cs:3079-3107):
#   Expert:   v2 < 1.0 -> TOOLOW (bounce, combo reset), 1.0..3.0 -> MIN, >= 3.0 -> FULL
#   Beginner/Advanced: v2 < 1.5 -> MIN (ball still breaks!), >= 1.5 -> FULL
#   PowerBall: v2 /= 4 before the check (needs 2x linear speed)
#   TOOLOW only exists on Expert.

enum HitLevel { TOOLOW, MINIMUMIMPACT, FULLIMPACT }

const HIT_SPEED_SQUARED_MIN = 1.0      # Expert: minimum for any scoring hit
const HIT_SPEED_SQUARED_FULL = 3.0     # Expert: full impact
const HIT_SPEED_SQUARED_CASUAL = 1.5   # Beginner..Advanced: semi below, full above

# Difficulties using PBVR's casual rules (ball always breaks, never TOOLOW).
# Anything else (Expert, ExpertPlus, unknown) uses Expert rules.
const CASUAL_DIFFICULTIES = ["Beginner", "Easy", "Normal", "Advanced"]


## difficulty is untyped on purpose: GameVariables.difficulty may be null early on.
static func calculate_hit_level(velocity_squared: float, difficulty, is_power_ball: bool = false) -> int:
	var effective_velocity = velocity_squared

	# PowerBalls: divide velocity by 4 (same as multiplying threshold by 4)
	if is_power_ball:
		effective_velocity = velocity_squared / 4.0

	if difficulty in CASUAL_DIFFICULTIES:
		return HitLevel.FULLIMPACT if effective_velocity >= HIT_SPEED_SQUARED_CASUAL else HitLevel.MINIMUMIMPACT

	if effective_velocity >= HIT_SPEED_SQUARED_FULL:
		return HitLevel.FULLIMPACT
	elif effective_velocity >= HIT_SPEED_SQUARED_MIN:
		return HitLevel.MINIMUMIMPACT
	return HitLevel.TOOLOW
