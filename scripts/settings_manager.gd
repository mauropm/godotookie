# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Fortune Cookie: A Little Luck contributors

extends Node
## Persists the small set of user preferences in user://settings.json.

signal changed(key: String, value: Variant)

const SETTINGS_VERSION := 1
const DEFAULT_LANGUAGE := "en"
const SETTINGS_FILE := "user://settings.json"
const SUPPORTED_FALLBACK := [
    "en", "es", "zh", "hi", "ar", "fr", "pt", "bn", "ru", "id", "ur", "de",
    "ja", "pcm", "mr", "te", "tr", "ta", "vi", "ko", "it", "th", "fa", "sw",
    "ha", "yo", "nl", "pl", "fil", "he",
]

var settings_path := SETTINGS_FILE
var language := DEFAULT_LANGUAGE
var sound_enabled := true
var reduced_motion := false
var low_effects := false

var _supported: Array[String] = []
var _loaded := false


func _ready() -> void:
    _load_supported_locales()
    load_settings()


func _load_supported_locales() -> void:
    _supported.clear()
    var file := FileAccess.open("res://data/locales.json", FileAccess.READ)
    if file != null:
        var parsed: Variant = JSON.parse_string(file.get_as_text())
        if parsed is Dictionary and parsed.get("locales") is Array:
            for item in parsed["locales"]:
                if item is Dictionary and item.has("code"):
                    _supported.append(str(item["code"]))
    if _supported.is_empty():
        for code in SUPPORTED_FALLBACK:
            _supported.append(code)


func supported_locales() -> Array[String]:
    return _supported.duplicate()


func is_supported(code: String) -> bool:
    return _supported.has(code)


func load_settings() -> void:
    language = _os_default_language()
    sound_enabled = true
    reduced_motion = false
    low_effects = false
    _loaded = false

    if not FileAccess.file_exists(settings_path):
        _loaded = true
        return

    var file := FileAccess.open(settings_path, FileAccess.READ)
    if file == null:
        push_warning("Could not read settings; using defaults.")
        _loaded = true
        return
    var text := file.get_as_text()
    var parser := JSON.new()
    var error := parser.parse(text)
    if error != OK or not parser.data is Dictionary:
        push_warning("Corrupt settings file; quarantining it and using defaults.")
        _quarantine_corrupt_settings()
        _loaded = true
        return

    var data: Dictionary = parser.data
    var candidate_language := str(data.get("language", language))
    if is_supported(candidate_language):
        language = candidate_language
    sound_enabled = _read_bool(data, "sound", true)
    reduced_motion = _read_bool(data, "reduced_motion", false)
    low_effects = _read_bool(data, "low_effects", false)
    _loaded = true


func _read_bool(data: Dictionary, key: String, fallback: bool) -> bool:
    var value: Variant = data.get(key, fallback)
    return value if value is bool else fallback


func _os_default_language() -> String:
    var raw := OS.get_locale().to_lower()
    var base := raw.get_slice("_", 0).get_slice("-", 0)
    if is_supported(base):
        return base
    return DEFAULT_LANGUAGE


func set_language(code: String, save := true) -> bool:
    if not is_supported(code):
        push_error("Unsupported locale: %s" % code)
        return false
    if language == code:
        return false
    language = code
    if save:
        _save()
    changed.emit("language", code)
    return true


func set_sound_enabled(value: bool, save := true) -> void:
    if sound_enabled == value:
        return
    sound_enabled = value
    if save:
        _save()
    changed.emit("sound", value)


func set_reduced_motion(value: bool, save := true) -> void:
    if reduced_motion == value:
        return
    reduced_motion = value
    if save:
        _save()
    changed.emit("reduced_motion", value)


func set_low_effects(value: bool, save := true) -> void:
    if low_effects == value:
        return
    low_effects = value
    if save:
        _save()
    changed.emit("low_effects", value)


func _save() -> void:
    if not _loaded:
        return
    var data := {
        "version": SETTINGS_VERSION,
        "language": language,
        "sound": sound_enabled,
        "reduced_motion": reduced_motion,
        "low_effects": low_effects,
    }
    var tmp_path := settings_path + ".tmp"
    var file := FileAccess.open(tmp_path, FileAccess.WRITE)
    if file == null:
        push_error("Could not write settings to %s" % tmp_path)
        return
    file.store_string(JSON.stringify(data, "\t"))
    file.close()

    var directory_path := settings_path.get_base_dir()
    var directory := DirAccess.open(directory_path)
    if directory == null:
        push_error("Could not open settings directory.")
        return
    var target_name := settings_path.get_file()
    var tmp_name := tmp_path.get_file()
    if directory.file_exists(target_name):
        directory.remove(target_name)
    var error := directory.rename(tmp_name, target_name)
    if error != OK:
        push_error("Could not finalise settings file (%s)." % error_string(error))


func _quarantine_corrupt_settings() -> void:
    var source := ProjectSettings.globalize_path(settings_path)
    var target := ProjectSettings.globalize_path(settings_path + ".corrupt")
    if FileAccess.file_exists(target):
        target = "%s.%d" % [target, int(Time.get_unix_time_from_system())]
    var error := DirAccess.rename_absolute(source, target)
    if error != OK:
        push_warning("Could not quarantine corrupt settings (%s)." % error_string(error))


func snapshot() -> Dictionary:
    return {
        "language": language,
        "sound": sound_enabled,
        "reduced_motion": reduced_motion,
        "low_effects": low_effects,
    }
