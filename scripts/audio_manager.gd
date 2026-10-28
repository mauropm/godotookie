# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Fortune Cookie: A Little Luck contributors

extends Node
## Tiny original SFX manager. Never autoplays and tolerates missing audio.

const FILES := {
    "crack": "res://assets/audio/crack.wav",
    "paper": "res://assets/audio/paper.wav",
    "chime": "res://assets/audio/chime.wav",
    "click": "res://assets/audio/click.wav",
}
const VOLUMES := {
    "crack": -5.0,
    "paper": -10.0,
    "chime": -9.0,
    "click": -15.0,
}

var _players: Dictionary = {}


func _ready() -> void:
    for key in FILES:
        if not ResourceLoader.exists(FILES[key]):
            push_warning("Optional sound missing: %s" % FILES[key])
            continue
        var stream := load(FILES[key]) as AudioStream
        if stream == null:
            continue
        var player := AudioStreamPlayer.new()
        player.name = "SFX_" + str(key)
        player.stream = stream
        player.volume_db = float(VOLUMES.get(key, -8.0))
        add_child(player)
        _players[key] = player
    if SettingsManager != null:
        SettingsManager.changed.connect(_on_setting_changed)


func _on_setting_changed(key: String, value: Variant) -> void:
    if key == "sound" and value is bool and not bool(value):
        stop_all()


func play(key: String, allow_overlap := false) -> void:
    if SettingsManager != null and not SettingsManager.sound_enabled:
        return
    if not _players.has(key):
        return
    var player: AudioStreamPlayer = _players[key]
    if player.playing:
        if not allow_overlap:
            return
        player.stop()
    player.play()


func play_crack() -> void:
    play("crack", false)


func play_paper() -> void:
    play("paper", true)


func play_chime() -> void:
    play("chime", true)


func play_click() -> void:
    play("click", true)


func stop_all() -> void:
    for player in _players.values():
        (player as AudioStreamPlayer).stop()


func available_sounds() -> Array[String]:
    var result: Array[String] = []
    for key in _players:
        result.append(str(key))
    return result
