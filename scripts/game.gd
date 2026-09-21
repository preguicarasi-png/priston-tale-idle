extends Node

const MAX_LEVEL := 60
const SAVE_PATH := "user://savegame.json"

var rng := RandomNumberGenerator.new()
var player_files: Array[String] = []
var monster_files: Array[String] = []
var weapon_files: Array[String] = []

var world: Node3D
var hero_anchor: Node3D
var enemy_anchor: Node3D
var hero_visual: Node3D
var enemy_visual: Node3D
var camera: Camera3D
var ui: CanvasLayer

var hero_anim: AnimationPlayer
var enemy_anim: AnimationPlayer
var current_anim := ""
var current_enemy_file := ""
var current_armor := 0
var current_weapon := -1

var level := 1
var xp := 0.0
var gold := 0
var hp := 250.0
var max_hp := 250.0
var attack := 24.0
var defense := 8.0
var kills := 0
var boss_kills := 0
var wave := 1
var zone := 1
var attack_timer := 0.0
var enemy_attack_timer := 0.0
var enemy_hp := 100.0
var enemy_max_hp := 100.0
var paused_game := false
var mode := "Campo"
var last_save_unix := 0

var hp_bar: ProgressBar
var xp_bar: ProgressBar
var enemy_bar: ProgressBar
var lbl_top: Label
var lbl_stats: Label
var lbl_enemy: Label
var lbl_log: Label
var inventory_box: VBoxContainer
var quest_box: VBoxContainer
var import_overlay: Control

func _ready() -> void:
	rng.randomize()
	_build_world()
	_build_ui()
	_scan_imported_assets()
	if player_files.is_empty() or monster_files.is_empty():
		_show_import_overlay()
		return
	_load_save()
	_spawn_hero()
	_spawn_enemy()
	_refresh_ui()

func _process(delta: float) -> void:
	if paused_game or hero_anchor == null or enemy_anchor == null or enemy_visual == null:
		return
	attack_timer -= delta
	enemy_attack_timer -= delta
	var flat := enemy_anchor.global_position - hero_anchor.global_position
	flat.y = 0.0
	var distance := flat.length()
	if distance > 1.9:
		var speed := 2.8 + level * 0.012
		hero_anchor.global_position += flat.normalized() * speed * delta
		_face_toward(hero_anchor, enemy_anchor.global_position)
		_play_anim(hero_anim, ["run", "walk"], true)
	else:
		_face_toward(hero_anchor, enemy_anchor.global_position)
		if attack_timer <= 0.0:
			_do_attack()
	if distance < 2.3 and enemy_attack_timer <= 0.0:
		_enemy_attack()
	_refresh_bars_only()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

func _build_world() -> void:
	world = Node3D.new()
	world.name = "World"
	add_child(world)

	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("83969d")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("cfd6d1")
	environment.ambient_light_energy = 0.9
	environment.fog_enabled = true
	environment.fog_light_color = Color("9ba79f")
	environment.fog_density = 0.012
	env.environment = environment
	world.add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -38, 0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	world.add_child(sun)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(70, 70)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("526c46")
	gm.roughness = 1.0
	ground.material_override = gm
	world.add_child(ground)

	for i in range(28):
		var rock := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = rng.randf_range(0.16, 0.5)
		sm.height = sm.radius * 1.3
		rock.mesh = sm
		var rm := StandardMaterial3D.new()
		rm.albedo_color = Color("64705f")
		rm.roughness = 1.0
		rock.material_override = rm
		rock.position = Vector3(rng.randf_range(-24,24), sm.radius * 0.35, rng.randf_range(-17,17))
		rock.scale.y = rng.randf_range(0.35,0.7)
		world.add_child(rock)

	camera = Camera3D.new()
	camera.position = Vector3(0, 11.5, 15.5)
	camera.rotation_degrees = Vector3(-31, 0, 0)
	camera.current = true
	world.add_child(camera)

func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(root)

	var top := PanelContainer.new()
	top.position = Vector2(16, 14)
	top.size = Vector2(510, 114)
	root.add_child(top)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 5)
	top.add_child(tv)
	lbl_top = Label.new()
	lbl_top.text = "Priston Tale Idle 3D"
	lbl_top.add_theme_font_size_override("font_size", 19)
	tv.add_child(lbl_top)
	hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(480, 18)
	hp_bar.show_percentage = false
	tv.add_child(hp_bar)
	xp_bar = ProgressBar.new()
	xp_bar.custom_minimum_size = Vector2(480, 14)
	xp_bar.show_percentage = false
	tv.add_child(xp_bar)
	lbl_stats = Label.new()
	tv.add_child(lbl_stats)

	var enemy_panel := PanelContainer.new()
	enemy_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	enemy_panel.position = Vector2(-220, 14)
	enemy_panel.size = Vector2(440, 70)
	root.add_child(enemy_panel)
	var ev := VBoxContainer.new()
	enemy_panel.add_child(ev)
	lbl_enemy = Label.new()
	lbl_enemy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ev.add_child(lbl_enemy)
	enemy_bar = ProgressBar.new()
	enemy_bar.show_percentage = false
	ev.add_child(enemy_bar)

	var side := PanelContainer.new()
	side.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	side.position = Vector2(-322, 14)
	side.size = Vector2(306, 610)
	root.add_child(side)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 7)
	side.add_child(sv)

	var title := Label.new()
	title.text = "EQUIPAMENTO / DROPS"
	title.add_theme_font_size_override("font_size", 17)
	sv.add_child(title)

	var armor_btn := Button.new()
	armor_btn.text = "Próxima armadura"
	armor_btn.pressed.connect(_cycle_armor)
	sv.add_child(armor_btn)

	var weapon_btn := Button.new()
	weapon_btn.text = "Próxima arma"
	weapon_btn.pressed.connect(_cycle_weapon)
	sv.add_child(weapon_btn)

	var sep := HSeparator.new()
	sv.add_child(sep)
	inventory_box = VBoxContainer.new()
	sv.add_child(inventory_box)

	var qtitle := Label.new()
	qtitle.text = "QUESTS"
	qtitle.add_theme_font_size_override("font_size", 16)
	sv.add_child(qtitle)
	quest_box = VBoxContainer.new()
	sv.add_child(quest_box)

	var modes := HBoxContainer.new()
	for m in ["Campo","Torre","Dungeon"]:
		var b := Button.new()
		b.text = m
		b.pressed.connect(func(): _set_mode(m))
		modes.add_child(b)
	sv.add_child(modes)

	var bottom := PanelContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bottom.position = Vector2(16, -92)
	bottom.size = Vector2(610, 76)
	root.add_child(bottom)
	lbl_log = Label.new()
	lbl_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_log.text = "Preparando mundo..."
	bottom.add_child(lbl_log)

	var pause := Button.new()
	pause.text = "Pausar"
	pause.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	pause.position = Vector2(-150, -76)
	pause.size = Vector2(134, 50)
	pause.pressed.connect(func():
		paused_game = not paused_game
		pause.text = "Continuar" if paused_game else "Pausar"
	)
	root.add_child(pause)

func _show_import_overlay() -> void:
	import_overlay = ColorRect.new()
	import_overlay.color = Color(0.035,0.045,0.05,0.96)
	import_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(import_overlay)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-330,-155)
	box.size = Vector2(660,310)
	box.add_theme_constant_override("separation",12)
	import_overlay.add_child(box)
	var t := Label.new()
	t.text = "FALTA IMPORTAR OS MODELOS DO PRISTON"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size",24)
	box.add_child(t)
	var d := Label.new()
	d.text = "Este projeto não usa os bonecos improvisados antigos.\n\nExecute tools\\IMPORTAR_PRISTON.bat, escolha a pasta do seu Priston e aguarde a conversão. Depois volte ao Godot e execute novamente.\n\nEsperado:\nassets/imported/player/*.glb\nassets/imported/monsters/*.glb\nassets/imported/weapons/*.glb"
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(d)
	var rescan := Button.new()
	rescan.text = "Já importei — verificar novamente"
	rescan.pressed.connect(func():
		_scan_imported_assets()
		if not player_files.is_empty() and not monster_files.is_empty():
			import_overlay.queue_free()
			_load_save()
			_spawn_hero()
			_spawn_enemy()
			_refresh_ui()
		else:
			d.text += "\n\nAinda não encontrei GLBs de player e monstros."
	)
	box.add_child(rescan)

func _scan_imported_assets() -> void:
	player_files = _find_files_recursive("res://assets/imported/player", "glb")
	monster_files = _find_files_recursive("res://assets/imported/monsters", "glb")
	weapon_files = _find_files_recursive("res://assets/imported/weapons", "glb")
	player_files.sort()
	monster_files.sort()
	weapon_files.sort()

func _find_files_recursive(path: String, ext: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name != "." and name != "..":
			var full := path.path_join(name)
			if dir.current_is_dir():
				out.append_array(_find_files_recursive(full, ext))
			elif name.get_extension().to_lower() == ext:
				out.append(full)
		name = dir.get_next()
	dir.list_dir_end()
	return out

func _load_glb(path: String, target_height: float) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	var wrapper := Node3D.new()
	var inst := packed.instantiate()
	if inst is Node3D:
		wrapper.add_child(inst)
	else:
		inst.queue_free()
		return null
	world.add_child(wrapper)
	await get_tree().process_frame
	_normalize_model(wrapper, target_height)
	world.remove_child(wrapper)
	return wrapper

func _normalize_model(root: Node3D, target_height: float) -> void:
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(root, meshes)
	if meshes.is_empty():
		return
	var minp := Vector3(INF, INF, INF)
	var maxp := Vector3(-INF, -INF, -INF)
	for mi in meshes:
		var a := mi.get_aabb()
		for ix in [0,1]:
			for iy in [0,1]:
				for iz in [0,1]:
					var p := a.position + Vector3(a.size.x*ix, a.size.y*iy, a.size.z*iz)
					var gp := root.to_local(mi.to_global(p))
					minp = minp.min(gp)
					maxp = maxp.max(gp)
	var h := max(0.001, maxp.y - minp.y)
	var scale_factor := target_height / h
	root.scale = Vector3.ONE * scale_factor
	root.position.y = -minp.y * scale_factor

func _collect_meshes(n: Node, out: Array[MeshInstance3D]) -> void:
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		_collect_meshes(c, out)

func _find_anim_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var found := _find_anim_player(c)
		if found != null:
			return found
	return null

func _play_anim(ap: AnimationPlayer, tokens: Array[String], loop_hint := true) -> void:
	if ap == null:
		return
	var chosen := ""
	for lib_name in ap.get_animation_library_list():
		var lib := ap.get_animation_library(lib_name)
		for anim_name in lib.get_animation_list():
			var low := anim_name.to_lower()
			for tok in tokens:
				if low.contains(tok.to_lower()):
					chosen = anim_name
					break
			if chosen != "":
				break
		if chosen != "":
			break
	if chosen == "":
		return
	if ap.current_animation != chosen:
		ap.play(chosen)

func _spawn_hero() -> void:
	if hero_anchor != null:
		hero_anchor.queue_free()
	hero_anchor = Node3D.new()
	hero_anchor.name = "Hero"
	world.add_child(hero_anchor)
	hero_anchor.position = Vector3(-7,0,2)
	current_armor = clamp(current_armor, 0, max(0, player_files.size()-1))
	hero_visual = await _load_glb(player_files[current_armor], 2.65)
	if hero_visual != null:
		if hero_visual.get_parent():
			hero_visual.get_parent().remove_child(hero_visual)
		hero_anchor.add_child(hero_visual)
		hero_anim = _find_anim_player(hero_visual)
		_play_anim(hero_anim, ["idle"], true)
	_attach_weapon()

func _spawn_enemy() -> void:
	if enemy_anchor != null:
		enemy_anchor.queue_free()
	enemy_anchor = Node3D.new()
	enemy_anchor.name = "Enemy"
	world.add_child(enemy_anchor)
	var idx := (wave + zone - 2) % monster_files.size()
	current_enemy_file = monster_files[idx]
	enemy_visual = await _load_glb(current_enemy_file, 2.2 if wave % 10 != 0 else 3.1)
	if enemy_visual != null:
		if enemy_visual.get_parent():
			enemy_visual.get_parent().remove_child(enemy_visual)
		enemy_anchor.add_child(enemy_visual)
		enemy_anim = _find_anim_player(enemy_visual)
		_play_anim(enemy_anim, ["idle"], true)
	enemy_anchor.position = Vector3(7.5 + rng.randf_range(0,2.5),0,rng.randf_range(-5,5))
	var boss_mult := 4.6 if wave % 10 == 0 else 1.0
	enemy_max_hp = (80.0 + level*12.0 + zone*32.0 + wave*3.0) * boss_mult
	enemy_hp = enemy_max_hp
	enemy_attack_timer = 1.0
	_refresh_ui()

func _attach_weapon() -> void:
	if current_weapon < 0 or current_weapon >= weapon_files.size() or hero_visual == null:
		return
	var skeleton := _find_skeleton(hero_visual)
	if skeleton == null:
		return
	var attach := BoneAttachment3D.new()
	var candidates := ["Bip01 R Hand","Bip01_R_Hand","R Hand","RightHand","hand_r","Hand.R","r_hand"]
	var chosen := ""
	for bone_name in candidates:
		if skeleton.find_bone(bone_name) >= 0:
			chosen = bone_name
			break
	if chosen == "":
		return
	attach.bone_name = chosen
	skeleton.add_child(attach)
	var w := await _load_glb(weapon_files[current_weapon], 1.25)
	if w != null:
		if w.get_parent():
			w.get_parent().remove_child(w)
		attach.add_child(w)
		w.rotation_degrees = Vector3(90,0,0)

func _find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var s := _find_skeleton(c)
		if s != null:
			return s
	return null

func _face_toward(node: Node3D, target: Vector3) -> void:
	var t := target
	t.y = node.global_position.y
	if node.global_position.distance_to(t) > 0.01:
		node.look_at(t, Vector3.UP)

func _do_attack() -> void:
	attack_timer = max(0.45, 1.02 - level*0.004)
	_play_anim(hero_anim, ["attack", "atk", "skill"], false)
	var crit := rng.randf() < min(0.32, 0.07 + level*0.002)
	var weapon_bonus := 0.0 if current_weapon < 0 else 7.0 + current_weapon*2.5
	var damage := (attack + weapon_bonus) * rng.randf_range(0.88,1.15)
	if crit:
		damage *= 1.85
	enemy_hp -= damage
	lbl_log.text = ("CRÍTICO! " if crit else "") + "Você causou %d de dano." % int(damage)
	if enemy_hp <= 0:
		_enemy_dead()

func _enemy_attack() -> void:
	enemy_attack_timer = 1.25
	_play_anim(enemy_anim, ["attack","atk"], false)
	var incoming := max(1.0, (8.0 + zone*4.0 + wave*0.7) - defense*0.35)
	hp -= incoming
	if hp <= 0:
		hp = max_hp
		hero_anchor.position = Vector3(-7,0,2)
		lbl_log.text = "Você foi derrotado e voltou ao acampamento."

func _enemy_dead() -> void:
	_play_anim(enemy_anim, ["die","dead","death"], false)
	kills += 1
	if wave % 10 == 0:
		boss_kills += 1
	var gain_xp := (18.0 + zone*9.0 + wave*2.2) * (4.0 if wave%10==0 else 1.0)
	xp += gain_xp
	gold += int((9 + zone*5 + wave) * (4 if wave%10==0 else 1))
	lbl_log.text = "Monstro derrotado: +%d EXP, +%d ouro." % [int(gain_xp), int(9 + zone*5 + wave)]
	while level < MAX_LEVEL and xp >= _xp_need(level):
		xp -= _xp_need(level)
		level += 1
		max_hp += 28
		hp = max_hp
		attack += 4.3
		defense += 1.7
		lbl_log.text = "LEVEL UP! Você chegou ao nível %d." % level
	wave += 1
	if wave > 30:
		wave = 1
		zone = min(10, zone+1)
	hero_anchor.position = Vector3(-7,0,2)
	await get_tree().create_timer(0.45).timeout
	_spawn_enemy()
	_save_game()

func _xp_need(lv: int) -> float:
	return 160.0 * pow(1.31, lv-1)

func _cycle_armor() -> void:
	if player_files.is_empty():
		return
	current_armor = (current_armor + 1) % player_files.size()
	_spawn_hero()
	lbl_log.text = "Armadura/modelo equipado: " + player_files[current_armor].get_file()
	_save_game()

func _cycle_weapon() -> void:
	if weapon_files.is_empty():
		lbl_log.text = "Nenhuma arma GLB importada ainda."
		return
	current_weapon = (current_weapon + 1) % weapon_files.size()
	_spawn_hero()
	lbl_log.text = "Arma equipada: " + weapon_files[current_weapon].get_file()
	_save_game()

func _set_mode(m: String) -> void:
	mode = m
	if mode == "Torre":
		zone = max(zone, 3)
	elif mode == "Dungeon":
		zone = max(zone, 5)
	lbl_log.text = "Modo alterado para " + mode + "."
	_spawn_enemy()

func _refresh_bars_only() -> void:
	if hp_bar == null:
		return
	hp_bar.max_value = max_hp
	hp_bar.value = max(0,hp)
	xp_bar.max_value = _xp_need(level)
	xp_bar.value = xp
	enemy_bar.max_value = enemy_max_hp
	enemy_bar.value = max(0,enemy_hp)

func _refresh_ui() -> void:
	if lbl_top == null:
		return
	_refresh_bars_only()
	lbl_top.text = "Lv.%d  •  Zona %d  •  %s  •  Onda %d  •  %d ouro" % [level,zone,mode,wave,gold]
	lbl_stats.text = "HP %d/%d   ATQ %d   DEF %d   Abates %d   Chefes %d" % [int(hp),int(max_hp),int(attack),int(defense),kills,boss_kills]
	var enemy_name := current_enemy_file.get_file().get_basename() if current_enemy_file != "" else "Monstro"
	lbl_enemy.text = ("CHEFE • " if wave%10==0 else "") + enemy_name
	_refresh_inventory_ui()
	_refresh_quests()

func _refresh_inventory_ui() -> void:
	if inventory_box == null:
		return
	for c in inventory_box.get_children():
		c.queue_free()
	var info := Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.text = "Armaduras reais encontradas: %d\nArmas reais encontradas: %d" % [player_files.size(), weapon_files.size()]
	inventory_box.add_child(info)
	for i in range(min(player_files.size(),4)):
		var b := Button.new()
		b.text = ("✓ " if i==current_armor else "") + player_files[i].get_file().get_basename()
		b.pressed.connect(func(index=i):
			current_armor=index
			_spawn_hero()
			_save_game()
		)
		inventory_box.add_child(b)

func _refresh_quests() -> void:
	if quest_box == null:
		return
	for c in quest_box.get_children():
		c.queue_free()
	var quests := [
		["Caçador", kills, 25],
		["Veterano", kills, 100],
		["Matador de chefes", boss_kills, 5]
	]
	for q in quests:
		var l := Label.new()
		l.text = "%s: %d/%d" % [q[0], min(q[1],q[2]), q[2]]
		quest_box.add_child(l)

func _save_game() -> void:
	if player_files.is_empty():
		return
	var data := {
		"level":level,"xp":xp,"gold":gold,"hp":hp,"max_hp":max_hp,
		"attack":attack,"defense":defense,"kills":kills,"boss_kills":boss_kills,
		"wave":wave,"zone":zone,"armor":current_armor,"weapon":current_weapon,
		"mode":mode,"saved_at":Time.get_unix_time_from_system()
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))

func _load_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if not parsed is Dictionary:
		return
	level = int(parsed.get("level",1))
	xp = float(parsed.get("xp",0))
	gold = int(parsed.get("gold",0))
	hp = float(parsed.get("hp",250))
	max_hp = float(parsed.get("max_hp",250))
	attack = float(parsed.get("attack",24))
	defense = float(parsed.get("defense",8))
	kills = int(parsed.get("kills",0))
	boss_kills = int(parsed.get("boss_kills",0))
	wave = int(parsed.get("wave",1))
	zone = int(parsed.get("zone",1))
	current_armor = int(parsed.get("armor",0))
	current_weapon = int(parsed.get("weapon",-1))
	mode = str(parsed.get("mode","Campo"))
	var saved_at := int(parsed.get("saved_at",0))
	if saved_at > 0:
		var offline := clamp(int(Time.get_unix_time_from_system()) - saved_at, 0, 8*3600)
		if offline > 60:
			var offline_kills := int(offline / max(6.0, 10.0-level*0.03))
			var offline_gold := offline_kills * (6 + zone*3)
			var offline_xp := offline_kills * (10 + zone*4)
			kills += offline_kills
			gold += offline_gold
			xp += offline_xp
			while level < MAX_LEVEL and xp >= _xp_need(level):
				xp -= _xp_need(level)
				level += 1
				max_hp += 28
				attack += 4.3
				defense += 1.7
			hp = max_hp
			lbl_log.text = "Progresso offline: %d abates, +%d ouro." % [offline_kills,offline_gold]
