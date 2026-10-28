# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Fortune Cookie: A Little Luck contributors

class_name ClipboardService
extends RefCounted
## Thin, testable wrapper around the platform clipboard.

static var force_failure := false
static var last_error := ""


static func copy_text(text: String) -> bool:
    last_error = ""
    if force_failure:
        last_error = "forced failure"
        return false
    if text.strip_edges().is_empty():
        last_error = "empty text"
        return false
    if DisplayServer.get_name() == "headless":
        last_error = "headless display server"
        return false
    DisplayServer.clipboard_set(text)
    return true


static func is_available() -> bool:
    return DisplayServer.get_name() != "headless" and not force_failure
