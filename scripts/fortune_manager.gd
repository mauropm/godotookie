# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Fortune Cookie: A Little Luck contributors

extends Node
## Offline fortune library and bounded no-repeat selection.

signal fortune_selected(record: Dictionary)

const FORTUNE_PATH := "res://data/fortunes/%s.json"
const RECENT_LIMIT := 64
const HISTORY_TRIES := 12

var current_locale := ""
var current_fortune: Dictionary = {}
var last_error := ""
var total_draws := 0

var _records: Dictionary = {}
var _bags: Dictionary = {}
var _history: Dictionary = {}
var _last_index: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _fallback_logged: Dictionary = {}


func _ready() -> void:
    _rng.randomize()


func set_seed(seed_value: int) -> void:
    _rng.seed = seed_value


func next_fortune(locale := "") -> Dictionary:
    var code := locale if not locale.is_empty() else SettingsManager.language
    var records := _ensure_locale(code)
    if records.is_empty():
        return _fallback_fortune(code)
    if not _bags.has(code) or (_bags[code] as Array).is_empty():
        _bags[code] = _make_bag(records.size())

    var bag: Array = _bags[code]
    var history: Array = _history.get(code, [])
    var last_index := int(_last_index.get(code, -1))
    var index := int(bag.pop_back())

    if index == last_index and not bag.is_empty():
        var swap_index := bag.size() - 1
        var swapped := int(bag[swap_index])
        bag[swap_index] = index
        index = swapped

    var tries := 0
    while history.has(index) and tries < HISTORY_TRIES and not bag.is_empty():
        var alternate := int(bag.pop_back())
        if not history.has(alternate):
            index = alternate
            break
        bag.push_front(alternate)
        tries += 1

    if index == last_index and records.size() > 1:
        var alternate_index := (index + 1 + _rng.randi_range(0, records.size() - 2)) % records.size()
        if not history.has(alternate_index):
            index = alternate_index

    var record: Dictionary = records[index]
    history.append(index)
    while history.size() > RECENT_LIMIT:
        history.pop_front()
    _history[code] = history
    _last_index[code] = index
    current_locale = code
    current_fortune = record.duplicate()
    total_draws += 1
    fortune_selected.emit(current_fortune)
    return current_fortune


func _make_bag(size: int) -> Array:
    var bag: Array = []
    for index in range(size):
        bag.append(index)
    for i in range(size - 1, 0, -1):
        var j := _rng.randi_range(0, i)
        var tmp: Variant = bag[i]
        bag[i] = bag[j]
        bag[j] = tmp
    return bag


func _ensure_locale(code: String) -> Array:
    if not _records.has(code):
        var loaded := _load_locale(code)
        if loaded == 0 and code != "en":
            loaded = _load_locale("en")
            if loaded > 0:
                push_warning("Fortune locale '%s' unavailable; using English." % code)
    return _records.get(code, [])


func _load_locale(code: String) -> int:
    return load_from_file(FORTUNE_PATH % code, code)


func load_from_file(path: String, code: String) -> int:
    last_error = ""
    if not FileAccess.file_exists(path):
        last_error = "missing file: %s" % path
        push_warning("Fortune data %s" % last_error)
        _records[code] = []
        return 0
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        last_error = "cannot open %s" % path
        push_error(last_error)
        _records[code] = []
        return 0
    var text := file.get_as_text()
    var parser := JSON.new()
    var error := parser.parse(text)
    if error != OK:
        last_error = "JSON error in %s at line %d: %s" % [path, parser.get_error_line(), parser.get_error_message()]
        push_error(last_error)
        _records[code] = []
        return 0
    var data: Variant = parser.data
    if not data is Array:
        last_error = "%s must contain a JSON array" % path
        push_error(last_error)
        _records[code] = []
        return 0

    var records: Array = []
    var ids: Dictionary = {}
    for item in data:
        if not item is Dictionary:
            continue
        var item_dict: Dictionary = item
        var id := str(item_dict.get("id", "")).strip_edges()
        var fortune_text := str(item_dict.get("text", "")).strip_edges()
        var record_locale := str(item_dict.get("locale", code))
        if id.is_empty() or fortune_text.is_empty() or ids.has(id):
            continue
        ids[id] = true
        records.append({
            "id": id,
            "locale": record_locale,
            "text": fortune_text,
            "category": str(item_dict.get("category", "hope")),
        })
    if records.is_empty():
        last_error = "%s contained no valid records" % path
        push_error(last_error)
    elif records.size() < 2000:
        push_warning("%s contains only %d valid records." % [path, records.size()])
    _records[code] = records
    return records.size()


func _fallback_fortune(code: String) -> Dictionary:
    if not _fallback_logged.has(code):
        push_error("No fortunes available for '%s'; using the localised fallback." % code)
        _fallback_logged[code] = true
    var message := "A little luck is already on its way to you."
    if LocalizationManager != null:
        message = LocalizationManager.t("fallback_fortune")
    current_locale = code
    current_fortune = {
        "id": "fallback-%s" % code,
        "locale": code,
        "text": message,
        "category": "hope",
    }
    return current_fortune


func records_for(locale := "") -> Array:
    var code := locale if not locale.is_empty() else SettingsManager.language
    return _ensure_locale(code).duplicate(true)


func count_for(locale := "") -> int:
    var code := locale if not locale.is_empty() else SettingsManager.language
    return _ensure_locale(code).size()


func clear_cache() -> void:
    _records.clear()
    _bags.clear()
    _history.clear()
    _last_index.clear()
    _fallback_logged.clear()
    current_fortune = {}


func recent_indexes(locale := "") -> Array:
    var code := locale if not locale.is_empty() else current_locale
    return (_history.get(code, []) as Array).duplicate()
