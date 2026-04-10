extends Node3D
## =============================================================================
## GROUND SEAM DETECTOR v3
## =============================================================================
##
## Detects the visual seam between dual ground meshes using two approaches:
##
## APPROACH 1 - SINGLE FRAME SPATIAL ANALYSIS:
## Uses a fixed camera at the player's position. In each frame, scans for a
## horizontal line of discontinuity — a row of pixels where the color jumps
## more than expected compared to neighboring rows. This detects the permanent
## seam line between mesh A and mesh B.
##
## APPROACH 2 - TEMPORAL TELEPORT DETECTION:
## Uses a fixed camera. Compares the frame just before teleport to the frame
## just after teleport. Since the camera doesn't move, any visual change at
## the teleport moment is a genuine artifact.
##
## The detector also auto-saves frame pairs around teleport events for manual
## visual inspection.
##
## CONTROLS:
##   F5 - Force single-frame analysis & print result
##   F6 - Toggle continuous monitoring
##   F7 - Save current frame as PNG
##   F8 - Print statistical summary
## =============================================================================

# Configuration
const VIEWPORT_SIZE := Vector2i(512, 512)

# Fixed camera position — matches the player's VR viewpoint
# Player stands at origin, looking forward (-Z), ground is below
const CAMERA_POS := Vector3(0, 1.7, 0)  # Standing height
const CAMERA_PITCH_DEG := -30.0  # Looking slightly down at ground

# Spatial analysis: when scanning a single frame for horizontal seam
const SCAN_ROW_WINDOW := 5  # Compare each row to +-N neighbors
const SEAM_SPIKE_THRESHOLD := 2.0  # Row gradient spike > 2x neighbors = seam

# Temporal analysis: comparing frames across teleport
const TELEPORT_DIFF_RATIO_THRESHOLD := 1.5  # Teleport frame diff > 1.5x normal

# State
var ground: Node = null
var detect_viewport: SubViewport = null
var detect_camera: Camera3D = null

var prev_frame: Image = null
var continuous_monitoring := true
var frame_count := 0
var save_counter := 0

# Teleport tracking
var last_mesh_a_z := 0.0
var last_mesh_b_z := 0.0
var teleport_this_frame := false
var teleport_which := ""

# Statistics - temporal (frame-to-frame)
var normal_diffs: Array[float] = []
var teleport_diffs: Array[float] = []

# Statistics - spatial (single-frame seam scan)
var normal_seam_scores: Array[float] = []  # Max row spike in non-teleport frames
var teleport_seam_scores: Array[float] = []  # Max row spike in teleport frames

# Auto-save on teleport
var teleport_save_count := 0
const MAX_TELEPORT_SAVES := 5

# File-based logging (since print() isn't always visible via MCP)
var log_lines: Array[String] = []

# Auto-summary: write results file after collecting enough teleports
var summary_written := false
const AUTO_SUMMARY_AFTER_TELEPORTS := 5


func _log(msg: String):
	print(msg)
	log_lines.append(msg)


func _write_log_file():
	var f = FileAccess.open("user://seam_detector_log.txt", FileAccess.WRITE)
	if f:
		for line in log_lines:
			f.store_line(line)
		f.close()


func _write_summary_file():
	var lines: Array[String] = []
	lines.append("=== GroundSeamDetector v3 Summary ===")
	lines.append("Frames analyzed: %d" % frame_count)
	lines.append("DEBUG_AMPLIFY_TELEPORT: %s" % str(ground.DEBUG_AMPLIFY_TELEPORT))
	lines.append("")
	
	if normal_seam_scores.size() > 0:
		var sorted = normal_seam_scores.duplicate()
		sorted.sort()
		lines.append("--- Spatial seam scan (single-frame) ---")
		lines.append("  Normal:   mean=%.2f  p95=%.2f  max=%.2f  (n=%d)" % [
			_array_mean(normal_seam_scores),
			sorted[int(sorted.size() * 0.95)],
			sorted[sorted.size() - 1],
			sorted.size(),
		])
	if teleport_seam_scores.size() > 0:
		var sorted = teleport_seam_scores.duplicate()
		sorted.sort()
		lines.append("  Teleport: mean=%.2f  max=%.2f  (n=%d)" % [
			_array_mean(teleport_seam_scores),
			sorted[sorted.size() - 1],
			sorted.size(),
		])
	
	if normal_diffs.size() > 0:
		var sorted = normal_diffs.duplicate()
		sorted.sort()
		lines.append("")
		lines.append("--- Temporal frame diff ---")
		lines.append("  Normal:   mean=%.6f  p95=%.6f  max=%.6f  (n=%d)" % [
			_array_mean(normal_diffs),
			sorted[int(sorted.size() * 0.95)],
			sorted[sorted.size() - 1],
			sorted.size(),
		])
	if teleport_diffs.size() > 0:
		var sorted = teleport_diffs.duplicate()
		sorted.sort()
		var avg_n = _array_mean(normal_diffs) if normal_diffs.size() > 0 else 0.0001
		lines.append("  Teleport: mean=%.6f  max=%.6f  ratio=%.2f  (n=%d)" % [
			_array_mean(teleport_diffs),
			sorted[sorted.size() - 1],
			_array_mean(teleport_diffs) / max(avg_n, 0.0001),
			sorted.size(),
		])
	
	lines.append("")
	lines.append("Teleport frames saved: %d / %d" % [teleport_save_count, MAX_TELEPORT_SAVES])
	
	# Verdict
	lines.append("")
	if teleport_diffs.size() > 0 and normal_diffs.size() > 0:
		var avg_n = _array_mean(normal_diffs)
		var avg_t = _array_mean(teleport_diffs)
		var ratio = avg_t / max(avg_n, 0.0001)
		if ratio > TELEPORT_DIFF_RATIO_THRESHOLD:
			lines.append("VERDICT: TELEPORT ARTIFACT DETECTED (temporal ratio=%.2f > %.1f)" % [ratio, TELEPORT_DIFF_RATIO_THRESHOLD])
		else:
			lines.append("VERDICT: No significant teleport artifact (temporal ratio=%.2f <= %.1f)" % [ratio, TELEPORT_DIFF_RATIO_THRESHOLD])
	
	if teleport_seam_scores.size() > 0:
		var max_seam = teleport_seam_scores.duplicate()
		max_seam.sort()
		if max_seam[max_seam.size() - 1] > SEAM_SPIKE_THRESHOLD:
			lines.append("VERDICT: SPATIAL SEAM DETECTED (max spike=%.2f > %.1f)" % [max_seam[max_seam.size() - 1], SEAM_SPIKE_THRESHOLD])
		else:
			lines.append("VERDICT: No spatial seam detected (max spike=%.2f <= %.1f)" % [max_seam[max_seam.size() - 1], SEAM_SPIKE_THRESHOLD])
	
	lines.append("=====================================")
	
	var f = FileAccess.open("user://seam_detector_summary.txt", FileAccess.WRITE)
	if f:
		for line in lines:
			f.store_line(line)
			print(line)
		f.close()
		_log("Summary written to user://seam_detector_summary.txt")


func _ready():
	ground = _find_ground(get_parent())
	if not ground:
		push_error("GroundSeamDetector: No Ground node found!")
		return
	
	# Ensure debug mode is OFF for realistic rendering
	ground.set_debug_mode(false)
	
	_setup_viewport()
	_log("GroundSeamDetector v3: Ready (fixed camera, normal rendering)")
	_log("  Spatial seam scan + temporal teleport diff")
	_log("  Controls: F5=analyze, F6=monitor, F7=save, F8=summary")
	_log("  Camera at %s pitch %.0f deg" % [CAMERA_POS, CAMERA_PITCH_DEG])
	_log("  DEBUG_AMPLIFY_TELEPORT: %s" % str(ground.DEBUG_AMPLIFY_TELEPORT))


func _find_ground(root: Node) -> Node:
	if root == null:
		return null
	if root.has_node("GroundShapeA"):
		return root
	for child in root.get_children():
		var found = _find_ground(child)
		if found:
			return found
	return null


func _setup_viewport():
	detect_viewport = SubViewport.new()
	detect_viewport.name = "SeamDetectViewport"
	detect_viewport.size = VIEWPORT_SIZE
	detect_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	detect_viewport.transparent_bg = false
	detect_viewport.disable_3d = false
	detect_viewport.world_3d = get_viewport().world_3d
	detect_viewport.own_world_3d = false
	add_child(detect_viewport)
	
	detect_camera = Camera3D.new()
	detect_camera.name = "SeamDetectCamera"
	detect_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	detect_camera.fov = 75.0
	detect_camera.near = 0.1
	detect_camera.far = 200.0
	detect_viewport.add_child(detect_camera)
	detect_camera.current = true
	
	# FIXED camera - never moves
	detect_camera.position = CAMERA_POS
	detect_camera.rotation_degrees = Vector3(CAMERA_PITCH_DEG, 0, 0)


func _process(delta: float):
	if not ground or not ground.mesh_a or not ground.mesh_b:
		return
	
	# Detect teleport
	var mesh_a_z = ground.mesh_a.position.z
	var mesh_b_z = ground.mesh_b.position.z
	
	teleport_this_frame = false
	teleport_which = ""
	
	if frame_count > 5:
		var a_jumped = abs(mesh_a_z - last_mesh_a_z) > ground.teleport_threshold * 0.5
		var b_jumped = abs(mesh_b_z - last_mesh_b_z) > ground.teleport_threshold * 0.5
		if a_jumped or b_jumped:
			teleport_this_frame = true
			teleport_which = "A" if a_jumped else "B"
	
	last_mesh_a_z = mesh_a_z
	last_mesh_b_z = mesh_b_z
	
	if continuous_monitoring:
		_do_analysis()
	
	frame_count += 1


func _do_analysis():
	var img = detect_viewport.get_texture().get_image()
	if img == null:
		return
	
	# --- SPATIAL ANALYSIS: scan this frame for horizontal seam ---
	var spatial = _scan_for_horizontal_seam(img)
	var seam_spike: float = spatial["spike"]
	var seam_row: int = spatial["row"]
	var seam_diff: float = spatial["row_diff"]
	
	# --- TEMPORAL ANALYSIS: compare to previous frame ---
	var temporal_diff := 0.0
	if prev_frame != null and prev_frame.get_size() == img.get_size():
		temporal_diff = _compute_frame_diff(prev_frame, img)
	
	if teleport_this_frame:
		teleport_seam_scores.append(seam_spike)
		teleport_diffs.append(temporal_diff)
		
		var avg_normal_diff = _array_mean(normal_diffs) if normal_diffs.size() > 0 else 0.0
		var avg_normal_seam = _array_mean(normal_seam_scores) if normal_seam_scores.size() > 0 else 0.0
		var diff_ratio = temporal_diff / max(avg_normal_diff, 0.0001)
		var seam_ratio = seam_spike / max(avg_normal_seam, 0.0001)
		
		var temporal_detected = diff_ratio > TELEPORT_DIFF_RATIO_THRESHOLD
		var spatial_detected = seam_spike > SEAM_SPIKE_THRESHOLD
		
		_log("TELEPORT [%s] frame=%d" % [teleport_which, frame_count])
		_log("  temporal: diff=%.6f avg_normal=%.6f ratio=%.2f %s" % [
			temporal_diff, avg_normal_diff, diff_ratio,
			"DETECTED" if temporal_detected else "ok"
		])
		_log("  spatial:  spike=%.2f@row%d diff=%.4f avg_normal=%.2f ratio=%.2f %s" % [
			seam_spike, seam_row, seam_diff, avg_normal_seam, seam_ratio,
			"DETECTED" if spatial_detected else "ok"
		])
		
		# Auto-save
		if teleport_save_count < MAX_TELEPORT_SAVES:
			_save_teleport_pair(img)
		
		# Auto-write summary after enough teleports collected
		if teleport_diffs.size() >= AUTO_SUMMARY_AFTER_TELEPORTS and not summary_written:
			summary_written = true
			_write_summary_file()
			_write_log_file()
	else:
		normal_seam_scores.append(seam_spike)
		normal_diffs.append(temporal_diff)
		
		# Bound arrays
		if normal_diffs.size() > 300:
			normal_diffs = normal_diffs.slice(150)
			normal_seam_scores = normal_seam_scores.slice(150)
	
	prev_frame = img.duplicate()


func _scan_for_horizontal_seam(img: Image) -> Dictionary:
	## Scan a single frame for a horizontal discontinuity line.
	##
	## For each row, compute the average gradient (color difference) between
	## that row and the row below it. A seam between two meshes will show as
	## a row where the gradient is significantly higher than neighboring rows.
	##
	## Returns {spike: float, row: int, row_diff: float}
	
	var w = img.get_width()
	var h = img.get_height()
	var step_x := 2
	
	# Compute per-row gradient (difference between row Y and row Y+1)
	var row_gradients: Array[float] = []
	for y in range(h - 1):
		var total := 0.0
		var count := 0
		for x in range(0, w, step_x):
			var ca = img.get_pixel(x, y)
			var cb = img.get_pixel(x, y + 1)
			total += _color_dist(ca, cb)
			count += 1
		row_gradients.append(total / float(max(count, 1)))
	
	# Find spike: row with max gradient relative to neighbors
	var max_spike := 0.0
	var max_row := 0
	var max_diff := 0.0
	
	for y in range(SCAN_ROW_WINDOW, row_gradients.size() - SCAN_ROW_WINDOW):
		# Skip top 10% (sky area) and bottom 5% (edge)
		if y < int(h * 0.1) or y > int(h * 0.95):
			continue
		
		var neighbor_sum := 0.0
		var nc := 0
		for dy in range(-SCAN_ROW_WINDOW, SCAN_ROW_WINDOW + 1):
			if dy != 0:
				neighbor_sum += row_gradients[y + dy]
				nc += 1
		var neighbor_avg = neighbor_sum / float(max(nc, 1))
		
		if neighbor_avg > 0.0005:  # Need some minimum gradient to avoid div-by-zero noise
			var spike = row_gradients[y] / neighbor_avg
			if spike > max_spike:
				max_spike = spike
				max_row = y
				max_diff = row_gradients[y]
	
	return {"spike": max_spike, "row": max_row, "row_diff": max_diff}


func _compute_frame_diff(img_a: Image, img_b: Image) -> float:
	## Average per-pixel color distance between two frames.
	var w = img_a.get_width()
	var h = img_a.get_height()
	var total := 0.0
	var count := 0
	var step := 2
	
	for y in range(0, h, step):
		for x in range(0, w, step):
			total += _color_dist(img_a.get_pixel(x, y), img_b.get_pixel(x, y))
			count += 1
	
	return total / float(max(count, 1))


func _save_teleport_pair(post_img: Image):
	var post_path = "user://tp_%d_post.png" % teleport_save_count
	post_img.save_png(post_path)
	
	if prev_frame:
		var pre_path = "user://tp_%d_pre.png" % teleport_save_count
		prev_frame.save_png(pre_path)
		
		# Save amplified diff image
		var diff_path = "user://tp_%d_diff10x.png" % teleport_save_count
		_save_diff_image(prev_frame, post_img, diff_path, 10.0)
		print("  Saved: %s %s %s" % [pre_path, post_path, diff_path])
	else:
		print("  Saved: %s (no prev frame)" % post_path)
	
	# Also save a gradient visualization of the post-teleport frame
	var grad_path = "user://tp_%d_gradient.png" % teleport_save_count
	_save_gradient_image(post_img, grad_path)
	print("  Saved gradient: %s" % grad_path)
	
	teleport_save_count += 1


func _save_diff_image(img_a: Image, img_b: Image, path: String, amplify: float = 5.0):
	var w = img_a.get_width()
	var h = img_a.get_height()
	var diff_img = Image.create(w, h, false, Image.FORMAT_RGB8)
	
	for y in range(h):
		for x in range(w):
			var ca = img_a.get_pixel(x, y)
			var cb = img_b.get_pixel(x, y)
			var dr = clampf(abs(ca.r - cb.r) * amplify, 0.0, 1.0)
			var dg = clampf(abs(ca.g - cb.g) * amplify, 0.0, 1.0)
			var db = clampf(abs(ca.b - cb.b) * amplify, 0.0, 1.0)
			diff_img.set_pixel(x, y, Color(dr, dg, db))
	
	diff_img.save_png(path)


func _save_gradient_image(img: Image, path: String):
	## Save a visualization of vertical gradients (row-to-row differences).
	## High gradient = bright, low = dark. The seam should appear as a bright line.
	var w = img.get_width()
	var h = img.get_height()
	var grad_img = Image.create(w, h, false, Image.FORMAT_RGB8)
	
	for y in range(h - 1):
		for x in range(w):
			var ca = img.get_pixel(x, y)
			var cb = img.get_pixel(x, y + 1)
			var d = _color_dist(ca, cb)
			# Amplify 10x and show as grayscale
			var v = clampf(d * 10.0, 0.0, 1.0)
			grad_img.set_pixel(x, y, Color(v, v, v))
	
	# Last row = black
	for x in range(w):
		grad_img.set_pixel(x, h - 1, Color.BLACK)
	
	grad_img.save_png(path)


func _color_dist(a: Color, b: Color) -> float:
	var dr = a.r - b.r
	var dg = a.g - b.g
	var db = a.b - b.b
	return sqrt(dr * dr + dg * dg + db * db)


func _array_mean(arr: Array[float]) -> float:
	if arr.size() == 0:
		return 0.0
	var total := 0.0
	for v in arr:
		total += v
	return total / float(arr.size())


func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F5:
				var img = detect_viewport.get_texture().get_image()
				if img:
					var result = _scan_for_horizontal_seam(img)
					print("Manual scan: spike=%.2f @ row %d, diff=%.4f" % [
						result["spike"], result["row"], result["row_diff"]
					])
					var path = "user://manual_scan_%d.png" % save_counter
					img.save_png(path)
					var grad_path = "user://manual_scan_%d_gradient.png" % save_counter
					_save_gradient_image(img, grad_path)
					save_counter += 1
					print("  Saved: %s, %s" % [path, grad_path])
			KEY_F6:
				continuous_monitoring = not continuous_monitoring
				print("GroundSeamDetector: Monitoring %s" % ("ON" if continuous_monitoring else "OFF"))
			KEY_F7:
				var img = detect_viewport.get_texture().get_image()
				if img:
					var path = "user://frame_%d.png" % save_counter
					img.save_png(path)
					save_counter += 1
					print("Saved: %s" % path)
			KEY_F8:
				_print_summary()


func _print_summary():
	_write_summary_file()
	_write_log_file()
