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

# BPM ranges for ball flight duration (from PowerBeatsVR Song.GetBPMRange)
const BPM_MID_THRESHOLD = 100
const BPM_HIGH_THRESHOLD = 145

# Ball flight duration in beats by BPM range + difficulty.
# From PowerBeatsVR GameManager.SetBallFlightDuration (GameManager.cs:1288-1342).
# Higher difficulties fly balls faster (fewer beats = less time to react).
const FLIGHT_DURATION_BEATS = {
	"Low": {"Beginner": 3, "Advanced": 2, "Expert": 2},
	"Mid": {"Beginner": 4, "Advanced": 3, "Expert": 2},
	"High": {"Beginner": 5, "Advanced": 3, "Expert": 3},
}


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


## Ball flight duration in beats for a given BPM + difficulty (PBVR SetBallFlightDuration).
## difficulty is untyped: null/unknown falls back to Expert timing.
static func get_ball_flight_duration(bpm: float, difficulty) -> int:
	var bpm_range = "Low"
	if bpm >= BPM_HIGH_THRESHOLD:
		bpm_range = "High"
	elif bpm >= BPM_MID_THRESHOLD:
		bpm_range = "Mid"
	var diff_key = str(difficulty) if difficulty != null else "Expert"
	if diff_key not in ["Beginner", "Advanced", "Expert"]:
		diff_key = "Expert"
	return FLIGHT_DURATION_BEATS[bpm_range][diff_key]
