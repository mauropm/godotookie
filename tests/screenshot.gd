extends Node
## Graphical screenshot harness used for visual QA on a desktop session.

var _main: Node


func _ready() -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/screenshots"))
    get_window().size = Vector2i(1280, 720)
    _main = load("res://scenes/main.tscn").instantiate()
    add_child(_main)
    await get_tree().create_timer(0.8).timeout
    await _capture("01_idle_desktop.png")

    var cookie = _main.get_node("CookieLayer/FortuneCookie")
    var ui = _main.get_node("UI/GameUI")
    cookie.request_crack()
    await get_tree().create_timer(0.74).timeout
    await _capture("02_fortune_reveal.png")
    await get_tree().create_timer(1.0).timeout
    await _capture("03_fortune_display.png")
    print("FORTUNE: ", ui.current_text)

    ui.open_settings()
    await get_tree().create_timer(0.25).timeout
    await _capture("04_settings.png")
    ui.open_language_selector()
    await get_tree().create_timer(0.25).timeout
    await _capture("05_languages.png")
    ui.close_modals()
    LocalizationManager.set_language("ar", false)
    await get_tree().create_timer(0.6).timeout
    await _capture("06_arabic_rtl.png")
    LocalizationManager.set_language("zh", false)
    await get_tree().create_timer(0.6).timeout
    await _capture("07_chinese.png")
    LocalizationManager.set_language("hi", false)
    await get_tree().create_timer(0.6).timeout
    await _capture("08_hindi.png")

    LocalizationManager.set_language("en", false)
    cookie.request_reset()
    await get_tree().create_timer(0.8).timeout
    get_window().size = Vector2i(390, 844)
    await get_tree().create_timer(0.6).timeout
    await _capture("09_mobile_idle.png")
    cookie.request_crack()
    await get_tree().create_timer(1.8).timeout
    await _capture("10_mobile_fortune.png")

    cookie.request_reset()
    await get_tree().create_timer(0.8).timeout
    get_window().size = Vector2i(320, 568)
    await get_tree().create_timer(0.6).timeout
    await _capture("11_small_idle.png")
    cookie.request_crack()
    await get_tree().create_timer(1.8).timeout
    await _capture("12_small_fortune.png")

    LocalizationManager.set_language("ar", false)
    await get_tree().create_timer(0.6).timeout
    ui.open_language_selector()
    await get_tree().create_timer(0.3).timeout
    await _capture("13_arabic_languages.png")
    ui.close_modals()
    ui.open_settings()
    await get_tree().create_timer(0.3).timeout
    await _capture("14_arabic_settings.png")
    ui.close_modals()
    LocalizationManager.set_language("en", false)
    cookie.request_reset()
    await get_tree().create_timer(0.8).timeout
    for entry in [
        [Vector2i(1920, 1080), "15_1920x1080.png"],
        [Vector2i(1440, 900), "16_1440x900.png"],
        [Vector2i(768, 1024), "17_tablet_768x1024.png"],
        [Vector2i(375, 812), "18_mobile_375x812.png"],
    ]:
        get_window().size = entry[0]
        await get_tree().create_timer(0.5).timeout
        await _capture(entry[1])
    get_tree().quit()


func _capture(name: String) -> void:
    await get_tree().process_frame
    await get_tree().process_frame
    var image := get_viewport().get_texture().get_image()
    var path := ProjectSettings.globalize_path("res://docs/screenshots/" + name)
    var error := image.save_png(path)
    print("screenshot ", name, " -> ", error_string(error))
