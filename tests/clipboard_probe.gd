# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Fortune Cookie: A Little Luck contributors

extends Node
## Graphical clipboard round-trip test. Run on a desktop session.

func _ready() -> void:
    await get_tree().create_timer(0.2).timeout
    var original := DisplayServer.clipboard_get()
    var probe := "Fortune Cookie clipboard probe"
    var copied := ClipboardService.copy_text(probe)
    await get_tree().create_timer(0.25).timeout
    var observed := DisplayServer.clipboard_get()
    ClipboardService.copy_text(original)
    var passed := copied and observed == probe
    print("CLIPBOARD_COPY=%s OBSERVED_MATCH=%s RESULT=%s" % [copied, observed == probe, "PASS" if passed else "FAIL"])
    get_tree().quit(0 if passed else 1)
