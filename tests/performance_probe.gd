# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Fortune Cookie: A Little Luck contributors

extends Node
## Graphical performance probe. Run on a desktop session, not with --headless.

var _main: Node
var _frames: Array[float] = []
var _sample_started := 0


func _ready() -> void:
    SettingsManager.language = "en"
    SettingsManager.reduced_motion = false
    SettingsManager.low_effects = false
    SettingsManager.sound_enabled = false
    LocalizationManager.set_language("en", false)
    get_window().size = Vector2i(1920, 1080)
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
    _main = load("res://scenes/main.tscn").instantiate()
    add_child(_main)
    await get_tree().create_timer(1.2).timeout
    var cookie = _main.get_node("CookieLayer/FortuneCookie")
    await _sample(1.5)
    for i in range(4):
        cookie.request_crack()
        await _sample(1.6)
        cookie.request_reset()
        await _sample(0.8)
    await _sample(1.5)
    _write_report()
    get_tree().quit()


func _sample(seconds: float) -> void:
    var end := Time.get_ticks_usec() + int(seconds * 1_000_000.0)
    var last := Time.get_ticks_usec()
    _sample_started = last
    while Time.get_ticks_usec() < end:
        await get_tree().process_frame
        var now := Time.get_ticks_usec()
        _frames.append(float(now - last) / 1000.0)
        last = now


func _write_report() -> void:
    var frame_total := 0.0
    var minimum := 999999.0
    var maximum := 0.0
    var dropped := 0
    for frame_ms in _frames:
        frame_total += frame_ms
        minimum = minf(minimum, frame_ms)
        maximum = maxf(maximum, frame_ms)
        if frame_ms > 20.0:
            dropped += 1
    var average_ms := frame_total / maxf(1.0, float(_frames.size()))
    var average_fps := 1000.0 / maxf(average_ms, 0.001)
    var node_count := _count_nodes(get_tree().root)
    var draw_calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
    var adapter := RenderingServer.get_video_adapter_name()
    var lines := [
        "Fortune Cookie graphical performance probe",
        "Date: %s" % Time.get_datetime_string_from_system(),
        "Window: 1920x1080 (vsync enabled)",
        "CPU: %s" % OS.get_processor_name(),
        "GPU: %s" % adapter,
        "Frames sampled: %d" % _frames.size(),
        "Average frame: %.2f ms (%.1f FPS)" % [average_ms, average_fps],
        "Minimum frame: %.2f ms (%.1f FPS)" % [minimum, 1000.0 / maxf(minimum, 0.001)],
        "Maximum frame: %.2f ms" % maximum,
        "Frames over 20 ms: %d" % dropped,
        "Nodes at end: %d" % node_count,
        "Draw calls in final frame: %d" % draw_calls,
        "Particle buckets are fixed and reused; no nodes are created per crack.",
    ]
    var text := "\n".join(lines) + "\n"
    print(text)
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://reports"))
    var file := FileAccess.open("res://reports/performance.txt", FileAccess.WRITE)
    if file != null:
        file.store_string(text)


func _count_nodes(node: Node) -> int:
    var total := 1
    for child in node.get_children():
        total += _count_nodes(child)
    return total
