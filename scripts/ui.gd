extends Control

const Data = preload("res://scripts/data.gd")
const Campaign = preload("res://scripts/campaign.gd")
var game: Node
var panel: Control
var hud: Control
var announcement: Label
var ann_time := 0.0
var hero_labels: Array[Label] = []
var remapping := ""
var settings_return := "menu"

# Menu theme: light deck plating, navy ink, lime selection, blue edge strip (matches the arena palette).
const BG := Color("e4e6ea")
const TILE := Color("d8dbe3")
const TILE_HOVER := Color("cbd0dc")
const NAVY := Color("111b35")
const LIME := Color("c3ef3c")
const MUTED := Color("4a5470")
const EDGE := Color("3a6df0")
const P1_COLOR := Color("f2c230")
const P2_COLOR := Color("33c6e8")
var weapon_tags: Array = []  # [actor, panel, pointer, time]
const MODES := [["SOLO","Just you"],["SOLO + BOT","You + AI partner"],["COUCH","Keyboard + controller"],["TWO PADS","Two controllers"]]
var display_font: FontVariation
var mono_font: FontVariation
var portraits: Array[Texture2D] = []

func bind(g: Node) -> void:
	game=g
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	_theme()

func _theme() -> void:
	display_font=FontVariation.new(); display_font.base_font=load("res://assets/fonts/Orbitron.ttf")
	display_font.variation_opentype={TextServerManager.get_primary_interface().name_to_tag("wght"):700}
	mono_font=FontVariation.new(); mono_font.base_font=load("res://assets/fonts/ShareTechMono-Regular.ttf")
	var t:=Theme.new(); t.default_font=mono_font; t.default_font_size=16
	var track:=StyleBoxFlat.new(); track.bg_color=Color("b9bfcd"); track.content_margin_top=3; track.content_margin_bottom=3
	var fill:=StyleBoxFlat.new(); fill.bg_color=NAVY; fill.content_margin_top=3; fill.content_margin_bottom=3
	t.set_stylebox("slider","HSlider",track)
	t.set_stylebox("grabber_area","HSlider",fill)
	t.set_stylebox("grabber_area_highlight","HSlider",fill)
	var grab:=Image.create(12,22,false,Image.FORMAT_RGBA8); grab.fill(NAVY)
	var grab_hi:=Image.create(12,22,false,Image.FORMAT_RGBA8); grab_hi.fill(LIME); grab_hi.fill_rect(Rect2i(2,2,8,18),NAVY)
	t.set_icon("grabber","HSlider",ImageTexture.create_from_image(grab))
	t.set_icon("grabber_highlight","HSlider",ImageTexture.create_from_image(grab_hi))
	set_theme(t)
	for name in Data.HEROES:
		var path: String="res://assets/ui/"+name.to_lower()+".png"
		portraits.append(load(path) if ResourceLoader.exists(path) else null)

func _clear() -> void:
	for c in get_children(): c.queue_free()
	panel=null; hud=null; announcement=null; hero_labels.clear(); weapon_tags.clear()

func _box(parent: Control, color: Color, min_size: Vector2=Vector2.ZERO) -> PanelContainer:
	var p:=PanelContainer.new(); var style:=StyleBoxFlat.new(); style.bg_color=color; style.set_content_margin_all(12); p.add_theme_stylebox_override("panel",style); p.custom_minimum_size=min_size; parent.add_child(p); return p

func _label(parent: Control, value: String, size:=16, color:=NAVY, display:=false) -> Label:
	var l:=Label.new(); l.text=value; l.add_theme_font_size_override("font_size",size); l.add_theme_color_override("font_color",color)
	if display: l.add_theme_font_override("font",display_font)
	l.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(l); return l

func _section(parent: Control, value: String) -> Label:
	return _label(parent,value.to_upper()+":",13,NAVY)

# Page frame: light plate, blue edge strip, big title, then two columns.
func _page(title: String, left_width := 560) -> Array[VBoxContainer]:
	_clear()
	var bg:=ColorRect.new(); bg.color=BG; bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(bg)
	var edge:=ColorRect.new(); edge.color=EDGE; edge.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE); edge.offset_right=6; add_child(edge)
	var margin:=MarginContainer.new(); margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,{"left":46,"right":40,"top":26,"bottom":22}[side])
	add_child(margin)
	var page:=VBoxContainer.new(); page.add_theme_constant_override("separation",14); margin.add_child(page)
	_label(page,title,46,NAVY,true)
	var cols:=HBoxContainer.new(); cols.add_theme_constant_override("separation",48); cols.size_flags_vertical=Control.SIZE_EXPAND_FILL; page.add_child(cols)
	var left:=VBoxContainer.new(); left.custom_minimum_size.x=left_width; left.add_theme_constant_override("separation",8); cols.add_child(left)
	var right:=VBoxContainer.new(); right.size_flags_horizontal=Control.SIZE_EXPAND_FILL; right.add_theme_constant_override("separation",14); cols.add_child(right)
	panel=left
	return [left,right]

# Selectable / clickable tile with a display-font title and a mono description.
func _tile(parent: Control, title: String, desc: String, selected: bool, cb: Callable, group: ButtonGroup = null, stacked := false, min_h := 50.0) -> Button:
	var b:=Button.new(); b.custom_minimum_size=Vector2(0,min_h); b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	b.toggle_mode=group!=null; b.button_group=group
	b.add_theme_stylebox_override("normal",SlantBox.make(TILE,14))
	b.add_theme_stylebox_override("hover",SlantBox.make(TILE_HOVER,14))
	b.add_theme_stylebox_override("pressed",SlantBox.make(NAVY,14))
	b.add_theme_stylebox_override("hover_pressed",SlantBox.make(NAVY,14))
	b.add_theme_stylebox_override("focus",SlantBox.make(Color(0,0,0,0),14).outline(EDGE,2.0))
	var m:=MarginContainer.new(); m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); m.mouse_filter=Control.MOUSE_FILTER_IGNORE
	m.add_theme_constant_override("margin_left",14); m.add_theme_constant_override("margin_right",28)
	b.add_child(m)
	var box: BoxContainer=VBoxContainer.new() if stacked else HBoxContainer.new()
	box.alignment=BoxContainer.ALIGNMENT_CENTER if stacked else BoxContainer.ALIGNMENT_BEGIN; box.mouse_filter=Control.MOUSE_FILTER_IGNORE; box.add_theme_constant_override("separation",2 if stacked else 18); m.add_child(box)
	var t:=_label(box,title,19,NAVY,true); t.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	if not stacked: t.custom_minimum_size.x=150
	var d:=_label(box,desc,13,MUTED) if desc!="" else null
	if d: d.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	var paint:=func(on: bool):
		t.add_theme_color_override("font_color",LIME if on else NAVY)
		if d: d.add_theme_color_override("font_color",Color("dfe4ee") if on else MUTED)
	if group: b.toggled.connect(paint)
	b.button_pressed=selected and group!=null
	paint.call(selected)
	b.pressed.connect(func(): game.play_sfx("ui"); cb.call())
	parent.add_child(b)
	return b

# Card with a clipped corner; rows of KEY / VALUE separated by navy rules.
func _card(parent: Control, title: String) -> VBoxContainer:
	var p:=PanelContainer.new(); p.add_theme_stylebox_override("panel",SlantBox.make(TILE,0,16,Vector4(20,14,20,18))); parent.add_child(p)
	var v:=VBoxContainer.new(); v.add_theme_constant_override("separation",6); p.add_child(v)
	_label(v,title,20,NAVY,true)
	return v

func _card_heading(v: Control, value: String, swatch: Color) -> void:
	var h:=HBoxContainer.new(); h.add_theme_constant_override("separation",7); v.add_child(h)
	var sq:=ColorRect.new(); sq.color=swatch; sq.custom_minimum_size=Vector2(11,11); sq.size_flags_vertical=Control.SIZE_SHRINK_CENTER; h.add_child(sq)
	_label(h,value.to_upper(),12)

func _row(v: Control, key: String, value: String) -> void:
	var h:=HBoxContainer.new(); v.add_child(h)
	var k:=_label(h,key.to_upper()+":",12); k.custom_minimum_size.x=96
	var val:=_label(h,value,14); val.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; val.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var rule:=ColorRect.new(); rule.color=NAVY; rule.custom_minimum_size.y=1; v.add_child(rule)

func _button(parent: Control, value: String, cb: Callable) -> Button:
	return _tile(parent,value,"",false,cb)

func show_menu() -> void:
	var cols:=_page("Sector 03")
	var left:=cols[0]; var right:=cols[1]
	var bar:=ColorRect.new(); bar.color=P1_COLOR; bar.custom_minimum_size=Vector2(56,5); bar.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN; left.add_child(bar)
	_label(left,"OPERATION MERIDIAN  //  INDUSTRIAL ARENA",14,MUTED)
	_label(left,"Six operatives. Five sectors. One rogue intelligence.",16)
	var spacer:=Control.new(); spacer.custom_minimum_size.y=10; left.add_child(spacer)
	var deploy:=_tile(left,"CAMPAIGN","Operation Meridian: %d of %d chapters open" % [game.unlocked,Campaign.CHAPTERS.size()],true,func(): game.campaign=true; show_selection(),null,false,58)
	_paint_primary(deploy)
	_tile(left,"SURVIVAL","Ten waves and a boss, in any arena",false,func(): game.campaign=false; show_selection(),null,false,58)
	_tile(left,"SETTINGS","Audio, feel and key bindings",false,func(): show_settings("menu"),null,false,58)
	_tile(left,"QUIT","Back to the desktop",false,func(): game.quit_game(),null,false,58)
	var spacer2:=Control.new(); spacer2.custom_minimum_size.y=6; left.add_child(spacer2)
	_label(left,"BEST SCORE   %d" % game.best,14)
	deploy.grab_focus()
	_section(right,"The six")
	var grid:=GridContainer.new(); grid.columns=3; grid.add_theme_constant_override("h_separation",10); grid.add_theme_constant_override("v_separation",10); right.add_child(grid)
	for i in range(Data.HEROES.size()):
		var card:=PanelContainer.new(); card.add_theme_stylebox_override("panel",SlantBox.make(TILE,0,12,Vector4(6,6,6,8))); grid.add_child(card)
		var v:=VBoxContainer.new(); v.add_theme_constant_override("separation",0); card.add_child(v)
		_portrait(v,i,Vector2(128,128))
		var name_row:=HBoxContainer.new(); v.add_child(name_row)
		var sw:=ColorRect.new(); sw.color=Data.COLORS[i]; sw.custom_minimum_size=Vector2(4,14); sw.size_flags_vertical=Control.SIZE_SHRINK_CENTER; name_row.add_child(sw)
		_label(name_row," "+Data.HEROES[i].to_upper(),14,NAVY,true)

func _paint_primary(b: Button) -> void:
	for state in ["normal","hover","pressed","hover_pressed"]: b.add_theme_stylebox_override(state,SlantBox.make(NAVY,14))
	var labels:=b.find_children("*","Label",true,false)
	if labels.size()>0: labels[0].add_theme_color_override("font_color",LIME)
	if labels.size()>1: labels[1].add_theme_color_override("font_color",Color("dfe4ee"))

func _portrait(parent: Control, i: int, size: Vector2) -> void:
	var tr:=TextureRect.new(); tr.texture=portraits[i]; tr.custom_minimum_size=size
	tr.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; tr.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; tr.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(tr)

func show_selection() -> void:
	var cols:=_page("Campaign" if game.campaign else "Survival",600)
	var left:=cols[0]; var right:=cols[1]
	_section(left,"Squad")
	var squad:=GridContainer.new(); squad.columns=2; squad.add_theme_constant_override("h_separation",8); squad.add_theme_constant_override("v_separation",8); left.add_child(squad)
	var mode_group:=ButtonGroup.new()
	# SOLO, plus one two-player choice: the AI partner, or the local co-op mode picked in Settings
	var duo: int=1+int(game.settings.coop)
	if game.mode!=0 and game.mode!=duo: game.mode=duo
	for i in [0,duo]:
		var idx: int=i
		_tile(squad,MODES[i][0],MODES[i][1],game.mode==i,func(): game.mode=idx; show_selection(),mode_group,true,46)
	if game.campaign:
		_section(left,"Chapter")
		var chapters:=GridContainer.new(); chapters.columns=3; chapters.add_theme_constant_override("h_separation",8); chapters.add_theme_constant_override("v_separation",6); left.add_child(chapters)
		var chapter_group:=ButtonGroup.new()
		game.start_chapter=mini(game.start_chapter,game.unlocked-1)
		for i in range(Campaign.CHAPTERS.size()):
			var idx:=i
			var ch: Dictionary=Campaign.CHAPTERS[i]
			var open: bool=i<game.unlocked
			var b:=_tile(chapters,"%02d %s" % [i+1,ch.title.to_upper() if open else "LOCKED"],
				Data.ARENAS[ch.arena].name if open else "Clear chapter %02d" % i,
				game.start_chapter==i,func(): game.start_chapter=idx; show_selection(),chapter_group,true,40)
			b.disabled=not open
			_small_title(b)
	else:
		_section(left,"Arena")
		var arenas:=GridContainer.new(); arenas.columns=3; arenas.add_theme_constant_override("h_separation",8); arenas.add_theme_constant_override("v_separation",6); left.add_child(arenas)
		var arena_group:=ButtonGroup.new()
		for key in Data.ARENA_ORDER:
			var k: String=key
			_small_title(_tile(arenas,Data.ARENAS[k].name,Data.ARENAS[k].desc,game.survival_arena==k,func(): game.survival_arena=k; game.save_preferences(); show_selection(),arena_group,true,40))
	_section(left,"Operative  (P1)")
	_operative_row(left,0)
	if game.mode!=0:
		_section(left,"Partner  (%s)" % ("BOT" if game.mode==1 else "P2"))
		_operative_row(left,1,true)
	var card:=_card(right,"Controls")
	_card_heading(card,"You (P1)",P1_COLOR)
	if game.mode==3:
		_row(card,"Move / aim","Left stick / right stick")
		_row(card,"Fire","Right trigger, special on left trigger")
	else:
		_row(card,"Move","W A S D")
		_row(card,"Aim","Mouse")
		_row(card,"Fire","Left click, special on right click")
	_row(card,"Dodge","Space  /  south button")
	_row(card,"Weapons","1 signature, 2-8 guns, Q / R or wheel  /  bumpers")
	if game.mode==1:
		_card_heading(card,"Partner (bot)",P2_COLOR)
		_row(card,"Role","Covers you, and comes to revive you when you go down.")
	elif game.mode>=2:
		_card_heading(card,"Partner (P2 pad)",P2_COLOR)
		_row(card,"Move / aim","Left stick / right stick")
		_row(card,"Revive","Hold west button near a downed partner")
	_row(card,"Pause","Esc  /  menu button")
	var start_title: String="START CHAPTER %02d" % (game.start_chapter+1) if game.campaign else "START RUN"
	var start_desc: String=("Boss: %s" % Data.enemy_name(Campaign.CHAPTERS[game.start_chapter].boss)) if game.campaign else "10 waves, boss: %s" % Data.enemy_name(Data.ARENAS[game.survival_arena].boss)
	var start:=_tile(right,start_title,start_desc,true,func():
		game.save_preferences(); game.start_run(),null,false,56)
	_paint_primary(start)
	_tile(right,"BACK","",false,func(): show_menu(),null,false,44)
	start.grab_focus()

# Three-across tiles (chapters, arenas) use a smaller title so the names fit.
func _small_title(b: Button) -> void:
	var labels:=b.find_children("*","Label",true,false)
	if not labels.is_empty(): (labels[0] as Label).add_theme_font_size_override("font_size",15)

func _operative_row(parent: Control, slot: int, compact := false) -> void:
	var row:=HBoxContainer.new(); row.add_theme_constant_override("separation",6); parent.add_child(row)
	var group:=ButtonGroup.new()
	for i in range(Data.HEROES.size()):
		var idx:=i
		var b:=Button.new(); b.toggle_mode=true; b.button_group=group; b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		b.custom_minimum_size=Vector2(0,46 if compact else 132)
		b.add_theme_stylebox_override("normal",SlantBox.make(TILE,0,10,Vector4(4,4,4,6)))
		b.add_theme_stylebox_override("hover",SlantBox.make(TILE_HOVER,0,10,Vector4(4,4,4,6)))
		b.add_theme_stylebox_override("pressed",SlantBox.make(NAVY,0,10,Vector4(4,4,4,6)))
		b.add_theme_stylebox_override("hover_pressed",SlantBox.make(NAVY,0,10,Vector4(4,4,4,6)))
		b.add_theme_stylebox_override("focus",SlantBox.make(Color(0,0,0,0),0,10).outline(EDGE,2.0))
		var v:=VBoxContainer.new(); v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); v.alignment=BoxContainer.ALIGNMENT_CENTER; v.mouse_filter=Control.MOUSE_FILTER_IGNORE; v.add_theme_constant_override("separation",0); b.add_child(v)
		if not compact: _portrait(v,i,Vector2(0,92))
		var name_l:=_label(v,Data.HEROES[i].to_upper(),12,NAVY,true); name_l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		var accent:=ColorRect.new(); accent.color=Data.COLORS[i]; accent.custom_minimum_size=Vector2(0,3); accent.mouse_filter=Control.MOUSE_FILTER_IGNORE; v.add_child(accent)
		b.toggled.connect(func(on: bool): name_l.add_theme_color_override("font_color",LIME if on else NAVY))
		b.button_pressed=game.selected[slot]==i
		name_l.add_theme_color_override("font_color",LIME if game.selected[slot]==i else NAVY)
		b.pressed.connect(func(): game.play_sfx("ui"); game.selected[slot]=idx; _show_weapon(parent,slot,idx))
		row.add_child(b)
	var info:=_label(parent,_loadout(game.selected[slot]),13,MUTED); info.name="weapon_info_%d" % slot

func _show_weapon(parent: Control, slot: int, idx: int) -> void:
	var info:=parent.find_child("weapon_info_%d" % slot,false,false) as Label
	if info: info.text=_loadout(idx)

# In-game HUD: WAVE / TIME / KILLS strip at the top, one card per player in the bottom corners
# (YOU bottom-left, PARTNER or P2 bottom-right) tinted with that player's ring colour.
var hud_stats := {}
var hud_cards: Array[Dictionary] = []

# HUD palette follows the arena: light plates on Sector 03, dark smoked glass with red accents on Sector 07.
var hud_pal := {}

func _dark() -> bool:
	return bool(Data.ARENAS.get(game.arena_theme,{}).get("dark",false))

func _accent() -> Color:
	return Data.ARENAS.get(game.arena_theme,{}).get("accent",EDGE)

func _hud_palette() -> Dictionary:
	if _dark():
		return {"panel":Color(.05,.05,.06,.78),"edge":_accent(),"ink":Color("f2f2f4"),"muted":Color("9a9ca3"),"empty":Color(1,1,1,.12)}
	return {"panel":Color(BG,.92),"edge":_accent(),"ink":NAVY,"muted":MUTED,"empty":Color("c3c8d3")}

func _hud_panel(skew: float, margin: Vector4) -> PanelContainer:
	var p:=PanelContainer.new()
	p.add_theme_stylebox_override("panel",SlantBox.make(hud_pal.panel,skew,0,margin).outline(Color(hud_pal.edge,.55),1.0))
	p.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return p

func show_hud() -> void:
	_clear()
	hud_cards.clear()
	hud_pal=_hud_palette()
	hud=Control.new(); hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); hud.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(hud)
	var top:=CenterContainer.new(); top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE); top.offset_top=8; top.mouse_filter=Control.MOUSE_FILTER_IGNORE; hud.add_child(top)
	var strip:=_hud_panel(10,Vector4(14,4,22,5)); top.add_child(strip)
	var row:=HBoxContainer.new(); row.add_theme_constant_override("separation",22); row.mouse_filter=Control.MOUSE_FILTER_IGNORE; strip.add_child(row)
	for key in ["wave","time","kills"]:
		var col:=VBoxContainer.new(); col.add_theme_constant_override("separation",-3); col.mouse_filter=Control.MOUSE_FILTER_IGNORE; row.add_child(col)
		_label(col,key.to_upper(),9,hud_pal.muted)
		hud_stats[key]=_label(col,"",16,hud_pal.ink,true)
	for i in range(game.heroes.size()): hud_cards.append(_player_card(game.heroes[i],i))
	announcement=Label.new(); announcement.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP); announcement.position.y=90
	announcement.add_theme_font_override("font",display_font); announcement.add_theme_font_size_override("font_size",28)
	announcement.add_theme_color_override("font_color",hud_pal.edge if _dark() else P1_COLOR); announcement.add_theme_color_override("font_outline_color",Color(0,0,0,.85) if _dark() else NAVY); announcement.add_theme_constant_override("outline_size",8)
	announcement.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; announcement.grow_horizontal=Control.GROW_DIRECTION_BOTH; hud.add_child(announcement)
	var hint:=_label(hud,"ESC  PAUSE",10,hud_pal.muted); hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT); hint.offset_left=-86; hint.offset_top=12
	_build_boss_bar(); _build_radio(); _build_boss_card()
	update_hud()

# Boss health bar under the top strip, shown while a boss is on the field.
var boss_panel: PanelContainer
var boss_name: Label
var boss_fill: ColorRect
func _build_boss_bar() -> void:
	var holder:=CenterContainer.new(); holder.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE); holder.offset_top=58; holder.mouse_filter=Control.MOUSE_FILTER_IGNORE; hud.add_child(holder)
	boss_panel=_hud_panel(10,Vector4(14,4,22,7)); holder.add_child(boss_panel); boss_panel.visible=false
	var v:=VBoxContainer.new(); v.add_theme_constant_override("separation",3); v.mouse_filter=Control.MOUSE_FILTER_IGNORE; boss_panel.add_child(v)
	boss_name=_label(v,"",12,hud_pal.ink,true); boss_name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var track:=ColorRect.new(); track.color=hud_pal.empty; track.custom_minimum_size=Vector2(460,9); track.mouse_filter=Control.MOUSE_FILTER_IGNORE; v.add_child(track)
	boss_fill=ColorRect.new(); boss_fill.color=Color("e5484d"); boss_fill.mouse_filter=Control.MOUSE_FILTER_IGNORE; track.add_child(boss_fill)
	boss_fill.set_anchors_preset(Control.PRESET_FULL_RECT)

# Radio subtitles: who is speaking and the line, above the player cards; kept across HUD rebuilds.
var radio_panel: PanelContainer
var radio_who: Label
var radio_text: Label
var radio_msg := ["","",0.0]
func _build_radio() -> void:
	var holder:=CenterContainer.new(); holder.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE); holder.offset_top=-150; holder.offset_bottom=-92; holder.mouse_filter=Control.MOUSE_FILTER_IGNORE; hud.add_child(holder)
	radio_panel=_hud_panel(10,Vector4(14,6,24,7)); holder.add_child(radio_panel)
	var v:=VBoxContainer.new(); v.add_theme_constant_override("separation",1); v.mouse_filter=Control.MOUSE_FILTER_IGNORE; radio_panel.add_child(v)
	radio_who=_label(v,"",10,hud_pal.edge,true)
	radio_text=_label(v,"",14,hud_pal.ink); radio_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; radio_text.custom_minimum_size.x=520
	_show_radio()

func radio(speaker: String, text: String, seconds: float) -> void:
	radio_msg=[speaker,text,seconds]
	_show_radio()

func _show_radio() -> void:
	if not is_instance_valid(radio_panel): return
	radio_panel.visible=radio_msg[2]>0
	radio_who.text="%s  //  RADIO" % radio_msg[0]
	radio_text.text=radio_msg[1]

# Boss name card: big name and title in the middle of the screen as the boss arrives.
var card_box: VBoxContainer
var card_title: Label
var card_sub: Label
var card_time := 0.0
var card_pending := ["",""]
func _build_boss_card() -> void:
	card_box=VBoxContainer.new(); card_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER); card_box.grow_horizontal=Control.GROW_DIRECTION_BOTH; card_box.grow_vertical=Control.GROW_DIRECTION_BOTH
	card_box.offset_top=-150; card_box.mouse_filter=Control.MOUSE_FILTER_IGNORE; hud.add_child(card_box)
	card_title=_label(card_box,"",52,hud_pal.edge if _dark() else NAVY,true); card_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	card_title.add_theme_color_override("font_outline_color",Color(0,0,0,.85) if _dark() else Color(1,1,1,.9)); card_title.add_theme_constant_override("outline_size",10)
	card_sub=_label(card_box,"",18,hud_pal.ink); card_sub.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	card_sub.add_theme_color_override("font_outline_color",Color(0,0,0,.85) if _dark() else Color(1,1,1,.9)); card_sub.add_theme_constant_override("outline_size",6)
	card_title.text=card_pending[0]; card_sub.text=card_pending[1]; card_box.visible=card_time>0

func boss_card(a: SectorActor) -> void:
	var spec: Dictionary=Data.ENEMIES[a.enemy_id]
	card_pending=[String(spec.name).to_upper(),"-  %s  -" % String(spec.get("title","")).to_upper()]
	card_time=3.2
	if is_instance_valid(card_box): card_title.text=card_pending[0]; card_sub.text=card_pending[1]; card_box.visible=true
	game.play_sfx("wave")

func _player_card(h: SectorActor, index: int) -> Dictionary:
	var color: Color=Data.PLAYER_COLORS[mini(index,1)]
	var p:=_hud_panel(10,Vector4(10,6,20,6))
	p.custom_minimum_size.x=220; hud.add_child(p)
	if index==0:
		p.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT); p.grow_vertical=Control.GROW_DIRECTION_BEGIN; p.offset_left=12; p.offset_bottom=-12
	else:
		p.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT); p.grow_vertical=Control.GROW_DIRECTION_BEGIN; p.grow_horizontal=Control.GROW_DIRECTION_BEGIN; p.offset_right=-12; p.offset_bottom=-12
	var v:=VBoxContainer.new(); v.add_theme_constant_override("separation",3); v.mouse_filter=Control.MOUSE_FILTER_IGNORE; p.add_child(v)
	var head:=HBoxContainer.new(); head.mouse_filter=Control.MOUSE_FILTER_IGNORE; v.add_child(head)
	var sq:=ColorRect.new(); sq.color=color; sq.custom_minimum_size=Vector2(8,8); sq.size_flags_vertical=Control.SIZE_SHRINK_CENTER; head.add_child(sq)
	var who: String="YOU" if index==0 else ("PARTNER" if h.input_id==-1 else "P2")
	_label(head," "+who+" - "+Data.HEROES[h.hero_id].to_upper(),9,hud_pal.muted)
	var gap:=Control.new(); gap.size_flags_horizontal=Control.SIZE_EXPAND_FILL; head.add_child(gap)
	var hp_label:=_label(head,"",17,hud_pal.ink,true)
	var bar:=HBoxContainer.new(); bar.add_theme_constant_override("separation",2); bar.mouse_filter=Control.MOUSE_FILTER_IGNORE; v.add_child(bar)
	var segs: Array[ColorRect]=[]
	for k in range(10):
		var seg:=ColorRect.new(); seg.custom_minimum_size=Vector2(0,6); seg.size_flags_horizontal=Control.SIZE_EXPAND_FILL; bar.add_child(seg); segs.append(seg)
	var wrow:=HBoxContainer.new(); wrow.mouse_filter=Control.MOUSE_FILTER_IGNORE; v.add_child(wrow)
	_label(wrow,"WEAPON ",8,hud_pal.muted)
	var weapon_label:=_label(wrow,"",11,hud_pal.ink,true)
	var gap2:=Control.new(); gap2.size_flags_horizontal=Control.SIZE_EXPAND_FILL; wrow.add_child(gap2)
	var ammo_key:=_label(wrow,"AMMO ",8,hud_pal.muted)
	var ammo_label:=_label(wrow,"",11,hud_pal.ink,true)
	var status:=_label(v,"",8,hud_pal.muted)
	var buffs:=_label(v,"",9,hud_pal.ink,true); buffs.visible=false
	return {"actor":h,"color":color,"hp":hp_label,"segs":segs,"weapon":weapon_label,"ammo":ammo_label,"ammo_key":ammo_key,"status":status,"buffs":buffs}

func update_hud() -> void:
	if not is_instance_valid(hud): return
	if hud_stats.has("wave"):
		hud_stats.wave.text=game.wave_label()
		hud_stats.time.text="%02d:%02d" % [int(game.elapsed)/60,int(game.elapsed)%60]
		hud_stats.kills.text="%d" % game.kills
	if is_instance_valid(boss_panel):
		var b=game.boss_actor
		boss_panel.visible=is_instance_valid(b) and not b.dead
		if boss_panel.visible:
			boss_name.text="%s  -  %d%%" % [Data.enemy_name(b.enemy_id).to_upper(),ceili(100.0*b.hp/b.max_hp)]
			boss_fill.anchor_right=clampf(b.hp/b.max_hp,0,1); boss_fill.offset_right=0
	for card in hud_cards:
		if not is_instance_valid(card.actor): continue
		var h: SectorActor=card.actor
		var frac:=clampf(h.hp/maxf(h.max_hp,1.0),0,1)
		var lit:=ceili(frac*10.0)
		var blink: bool=(h.downed or frac<.3) and int(Time.get_ticks_msec()/250)%2==0
		for k in range(10): card.segs[k].color=(card.color if not blink else Color("e5484d")) if k<lit else hud_pal.get("empty",Color("c3c8d3"))
		var w: Dictionary=h.loadout[h.weapon]
		card.weapon.text=w.name
		if h.downed:
			card.hp.text="DOWN"; card.ammo_key.text=""; card.ammo.text="%ds" % ceili(h.downed_time)
			card.status.text="DOWNED  -  TEAMMATE HOLDS E / WEST BUTTON TO REVIVE"
			continue
		card.hp.text="OUT" if h.dead else "%d" % ceili(h.hp)
		card.ammo_key.text="AMMO "
		if h.reload>0: card.ammo.text="RELOAD"
		elif w.kind=="rail" and h.charge>0: card.ammo.text="%d%%" % int(h.charge*100)
		elif int(w.mag)<=0: card.ammo.text="INF"
		else: card.ammo.text="%d/%d" % [h.ammo[h.weapon],w.mag]
		var special: String="READY" if h.special_timer<=0 else "%ds" % ceili(h.special_timer)
		var dodge: String="READY" if h.dodge_timer<=0 else "%ds" % ceili(h.dodge_timer)
		var shield: String=("    SHIELD %d" % ceili(h.shield_health)) if h.hero_id==2 and h.shield_time>0 else ""
		card.status.text="%s: %s    DODGE: %s%s" % [Data.SPECIALS[h.hero_id].to_upper(),special,dodge,shield]
		# running power-ups with their seconds left, in the first one's colour
		var parts: Array[String]=[]
		for k in Data.TIMED_BUFFS:
			if h.buffs.has(k): parts.append("%s %d" % [Data.POWERUPS[k].name,ceili(h.buffs[k])])
		card.buffs.visible=not parts.is_empty()
		if card.buffs.visible:
			card.buffs.text="  ".join(parts)
			for k in Data.TIMED_BUFFS:
				if h.buffs.has(k): card.buffs.add_theme_color_override("font_color",Data.POWERUPS[k].color.darkened(0.0 if _dark() else .35)); break

func announce(message: String, seconds: float) -> void:
	if not is_instance_valid(announcement): return
	announcement.text=message; ann_time=seconds

func _process(delta: float) -> void:
	for t in weapon_tags.duplicate():
		t[3]-=delta
		if t[3]<=0 or not is_instance_valid(t[0]) or not is_instance_valid(t[1]) or not is_instance_valid(game.camera):
			if is_instance_valid(t[1]): t[1].queue_free(); t[2].queue_free()
			weapon_tags.erase(t); continue
		var screen: Vector2=game.camera.unproject_position(t[0].global_position+Vector3.UP*2.9)
		t[1].position=screen-Vector2(t[1].size.x*.5,t[1].size.y+8)
		t[2].position=screen-Vector2(0,8)
		for o in weapon_tags:  # two operatives side by side: stack the newer tag above the older one
			if o==t: break
			if is_instance_valid(o[1]) and Rect2(t[1].position,t[1].size).grow(2).intersects(Rect2(o[1].position,o[1].size)):
				t[1].position.y=o[1].position.y-t[1].size.y-4
		var a:=clampf(t[3]/.3,0,1); t[1].modulate.a=a; t[2].modulate.a=a
	if ann_time>0:
		ann_time-=delta
		if ann_time<=0 and is_instance_valid(announcement): announcement.text=""
	if radio_msg[2]>0 and game.state=="playing":
		radio_msg[2]-=delta
		if radio_msg[2]<=0: _show_radio()
	if card_time>0:
		card_time-=delta
		if is_instance_valid(card_box):
			card_box.modulate.a=clampf(card_time/.5,0,1)
			if card_time<=0: card_box.visible=false

func show_pause() -> void:
	var cols:=_page("Paused")
	var left:=cols[0]
	var resume:=_tile(left,"RESUME","Back into the fight",true,func(): game.state="playing"; show_hud(),null,false,56)
	_paint_primary(resume)
	_tile(left,"SETTINGS","Audio, feel and key bindings",false,func(): show_settings("pause"),null,false,56)
	_tile(left,"RESTART","Start chapter %02d again" % (game.chapter+1) if game.campaign else "Start the run again from wave 01",false,func():
		if game.campaign: game.start_chapter=game.chapter
		game.start_run(),null,false,56)
	_tile(left,"MAIN MENU","Abandon this run",false,func(): game._clear_run(); game.state="menu"; show_menu(),null,false,56)
	var card:=_card(cols[1],"Run status")
	if game.campaign:
		_row(card,"Chapter","%02d  %s" % [game.chapter+1,Campaign.CHAPTERS[game.chapter].title])
		_row(card,"Wave","Boss" if game.wave>=4 else "%d / 3" % game.wave)
	else: _row(card,"Wave","%02d / 10" % game.wave)
	_row(card,"Score","%d   (best %d)" % [game.score,game.best])
	_row(card,"Time","%02d:%02d" % [int(game.elapsed)/60,int(game.elapsed)%60])
	for h in game.heroes: _row(card,Data.HEROES[h.hero_id],"DOWN" if h.downed else ("OUT" if h.dead else "%d / %d HP" % [ceili(h.hp),ceili(h.max_hp)]))
	resume.grab_focus()

func show_settings(return_to: String) -> void:
	settings_return=return_to
	var cols:=_page("Settings",600)
	var left:=cols[0]; var right:=cols[1]
	_section(left,"Audio")
	for key in ["master","music","sfx"]: _slider_row(left,key)
	_section(left,"Feel")
	for key in ["shake","effects","sensitivity"]: _slider_row(left,key)
	var toggles:=HBoxContainer.new(); toggles.add_theme_constant_override("separation",8); left.add_child(toggles)
	for opt in [["autoaim","AUTO AIM","Locks onto the robot nearest your aim"],["killcam","KILL CAM","Cinematic every 9th kill"]]:
		var key: String=opt[0]
		var on: bool=game.settings[key]>=.5
		_tile(toggles,"%s  %s" % [opt[1],"ON" if on else "OFF"],opt[2],on,func():
			game.settings[key]=0.0 if game.settings[key]>=.5 else 1.0
			game.save_preferences(); show_settings(return_to),ButtonGroup.new(),true,48)
	_section(left,"Display")
	var row:=HBoxContainer.new(); row.add_theme_constant_override("separation",8); left.add_child(row)
	for opt in [["fullscreen","FULLSCREEN","F11 / Alt+Enter"],["vsync","V-SYNC","Caps frame rate"]]:
		var key: String=opt[0]
		var on: bool=game.settings[key]>=.5
		_tile(row,"%s  %s" % [opt[1],"ON" if on else "OFF"],opt[2],on,func():
			game.settings[key]=0.0 if game.settings[key]>=.5 else 1.0
			game.apply_display(); game.save_preferences(); show_settings(return_to),ButtonGroup.new(),true,48)
	_section(left,"Local co-op")
	var coop:=HBoxContainer.new(); coop.add_theme_constant_override("separation",8); left.add_child(coop)
	var coop_group:=ButtonGroup.new()
	for opt in [[0,"OFF","Partner is the AI bot"],[1,MODES[2][0],MODES[2][1]],[2,MODES[3][0],MODES[3][1]]]:
		var value: float=opt[0]
		_small_title(_tile(coop,opt[1],opt[2],int(game.settings.coop)==int(value),func():
			game.settings.coop=value; game.save_preferences(); show_settings(return_to),coop_group,true,48))
	var card:=_card(right,"Key bindings")
	_card_heading(card,"You (P1)  -  click a row, then press a key",P1_COLOR)
	for action in ["move_up","move_left","move_down","move_right","dodge","interact","weapon_prev","weapon_next"]:
		var events:=InputMap.action_get_events(action)
		var current: String=OS.get_keycode_string(events[0].physical_keycode) if not events.is_empty() and events[0] is InputEventKey else "?"
		var b:=Button.new(); b.flat=true; b.alignment=HORIZONTAL_ALIGNMENT_LEFT; b.custom_minimum_size.y=26
		b.add_theme_stylebox_override("hover",SlantBox.make(TILE_HOVER,0,0,Vector4(4,2,4,2)))
		b.add_theme_stylebox_override("focus",SlantBox.make(Color(0,0,0,0),0,0).outline(EDGE,1.5))
		b.add_theme_font_size_override("font_size",14); b.add_theme_color_override("font_color",NAVY); b.add_theme_color_override("font_hover_color",NAVY)
		var waiting: bool=remapping==action
		b.text="%-14s %s" % [_action_name(action)+":","PRESS A KEY..." if waiting else current]
		if waiting: b.add_theme_color_override("font_color",EDGE)
		b.pressed.connect(func(): game.play_sfx("ui"); remapping=action; show_settings(return_to))
		card.add_child(b)
		var rule:=ColorRect.new(); rule.color=NAVY; rule.custom_minimum_size.y=1; card.add_child(rule)
	_label(card,"Esc cancels a rebind. Controllers use fixed buttons.",12,MUTED)
	var back:=_tile(right,"BACK","Saved automatically",true,func():
		remapping=""
		if return_to=="pause": show_pause()
		else: show_menu(),null,false,52)
	_paint_primary(back)

func _action_name(action: String) -> String:
	return {"move_up":"Move up","move_left":"Move left","move_down":"Move down","move_right":"Move right","dodge":"Dodge","interact":"Revive","weapon_prev":"Prev weapon","weapon_next":"Next weapon"}.get(action,action).to_upper()

func _loadout(i: int) -> String:
	return "%s  /  %s" % [Data.SIGNATURES[i].name,Data.SPECIALS[i]]

# Yellow name tag that pops above a fighter when they switch weapons.
func weapon_tag(actor: Node3D, text: String, color: Color) -> void:
	for t in weapon_tags:
		if t[0]==actor and is_instance_valid(t[1]): t[1].queue_free(); t[2].queue_free()
	weapon_tags=weapon_tags.filter(func(t): return t[0]!=actor)
	# arena HUD panel (dark or light) framed in the operative's own colour (Kestrel red, Nova cyan...);
	# `color` (the item's colour) is only the fallback for a non-hero actor
	var pal: Dictionary=_hud_palette()
	var hero_color: Color=Data.COLORS[actor.hero_id] if actor is SectorActor and actor.hero else color
	var p:=PanelContainer.new(); var st:=StyleBoxFlat.new(); st.bg_color=Color(pal.panel,.9)
	st.content_margin_left=0; st.content_margin_right=8; st.content_margin_top=0; st.content_margin_bottom=0
	st.border_color=hero_color; st.set_border_width_all(1)
	p.add_theme_stylebox_override("panel",st); p.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var row:=HBoxContainer.new(); row.add_theme_constant_override("separation",6); row.mouse_filter=Control.MOUSE_FILTER_IGNORE; p.add_child(row)
	var stripe:=ColorRect.new(); stripe.color=hero_color; stripe.custom_minimum_size=Vector2(4,0); stripe.mouse_filter=Control.MOUSE_FILTER_IGNORE; row.add_child(stripe)
	var l:=_label(row,text,12,pal.ink,true); l.custom_minimum_size.y=20; l.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	var pointer:=Polygon2D.new(); pointer.color=hero_color; pointer.polygon=PackedVector2Array([Vector2(-5,0),Vector2(5,0),Vector2(0,6)])
	add_child(p); add_child(pointer)
	weapon_tags.append([actor,p,pointer,1.3])

func _slider_row(parent: Control, key: String) -> void:
	var p:=PanelContainer.new(); p.add_theme_stylebox_override("panel",SlantBox.make(TILE,14,0,Vector4(14,6,30,6))); parent.add_child(p)
	var h:=HBoxContainer.new(); h.add_theme_constant_override("separation",16); p.add_child(h)
	var t:=_label(h,{"master":"MASTER","music":"MUSIC","sfx":"EFFECTS SFX","shake":"SHAKE","effects":"VISUALS","sensitivity":"AIM SENS"}[key],16,NAVY,true)
	t.custom_minimum_size.x=150; t.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	var s:=HSlider.new(); s.size_flags_horizontal=Control.SIZE_EXPAND_FILL; s.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	s.min_value=0; s.max_value=2 if key=="sensitivity" else 1; s.step=.05; s.value=game.settings[key]
	h.add_child(s)
	var value:=_label(h,"",14,MUTED); value.custom_minimum_size.x=48; value.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	var show:=func(v: float): value.text=("%.2fx" % v) if key=="sensitivity" else ("%d%%" % roundi(v*100))
	show.call(s.value)
	s.value_changed.connect(func(v: float): game.settings[key]=v; game.save_preferences(); show.call(v))

func _input(event: InputEvent) -> void:
	if remapping=="" or not event is InputEventKey or not event.pressed or event.echo: return
	accept_event()
	if event.physical_keycode!=KEY_ESCAPE:
		InputMap.action_erase_events(remapping)
		var ev:=InputEventKey.new(); ev.physical_keycode=event.physical_keycode; InputMap.action_add_event(remapping,ev)
		game.save_preferences()
	remapping=""
	show_settings(settings_return)

func show_upgrades(h: SectorActor, offers: Array[Dictionary]) -> void:
	var cols:=_page("Upgrade",620)
	var left:=cols[0]
	_section(left,"%s  -  choose one" % Data.HEROES[h.hero_id])
	var first: Button
	for i in range(offers.size()):
		var u: Dictionary=offers[i]; var idx:=i
		var b:=_tile(left,u.name.to_upper(),u.desc,false,func(): game.pick_upgrade(idx),null,true,62)
		if first==null: first=b
	_label(left,"Choices stack up to their individual caps.",13,MUTED)
	var card:=_card(cols[1],"Operative")
	_portrait(card,h.hero_id,Vector2(0,170))
	_row(card,"Name",Data.HEROES[h.hero_id])
	_row(card,"Health","%d / %d" % [ceili(h.hp),ceili(h.max_hp)])
	if game.campaign: _row(card,"Next","Chapter %02d" % (game.chapter+2) if game.state=="upgrade" and game.wave>=4 else "Wave %d / 3" % (game.wave+1))
	else: _row(card,"Next","Wave %02d" % (game.wave+1))
	if first: first.grab_focus()

func show_results(win: bool) -> void:
	var cols:=_page(("Meridian silent" if game.campaign else "Sector secured") if win else "Mission failed")
	var left:=cols[0]
	var bar:=ColorRect.new(); bar.color=LIME if win else Color("e5484d"); bar.custom_minimum_size=Vector2(56,5); bar.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN; left.add_child(bar)
	_label(left,"VICTORY" if win else "DEFEAT",14,MUTED)
	var again:=_tile(left,"RESTART","Same squad, chapter %02d" % (game.start_chapter+1) if game.campaign else "Same squad, wave 01",true,func(): game.start_run(),null,false,56)
	_paint_primary(again)
	_tile(left,"MAIN MENU","Change squad or settings",false,func(): game._clear_run(); game.state="menu"; show_menu(),null,false,56)
	var card:=_card(cols[1],"Debrief")
	if game.campaign: _row(card,"Chapter","%d / %d" % [game.chapter+1,Campaign.CHAPTERS.size()])
	else: _row(card,"Waves","%d / 10" % game.wave)
	_row(card,"Score","%d" % game.score)
	_row(card,"Best","%d" % game.best)
	_row(card,"Time","%02d:%02d" % [int(game.elapsed)/60,int(game.elapsed)%60])
	again.grab_focus()

# ---------------------------------------------------------------- campaign story screens
func _story_text(parent: Control, text: String, width := 600) -> void:
	var l:=_label(parent,text,16,NAVY); l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; l.custom_minimum_size.x=width

# Before each chapter: where, why, what to kill.
func show_briefing(ch: int) -> void:
	var c: Dictionary=Campaign.CHAPTERS[ch]
	var cols:=_page("Chapter %02d" % (ch+1),620)
	var left:=cols[0]; var right:=cols[1]
	var bar:=ColorRect.new(); bar.color=Data.ARENAS[c.arena].accent; bar.custom_minimum_size=Vector2(56,5); bar.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN; left.add_child(bar)
	_label(left,c.title.to_upper(),28,NAVY,true)
	_label(left,"%s  //  %s" % [Data.ARENAS[c.arena].name,Data.ARENAS[c.arena].desc.to_upper()],13,MUTED)
	_section(left,"Briefing from %s" % Campaign.HANDLER)
	_story_text(left,c.briefing)
	_section(left,"Objective")
	_label(left,c.objective,16,NAVY,true)
	var go:=_tile(left,"DEPLOY","Drop into %s" % Data.ARENAS[c.arena].name,true,func(): game.deploy(),null,false,56)
	_paint_primary(go)
	_tile(left,"MAIN MENU","Abandon the operation",false,func(): game._clear_run(); game.state="menu"; show_menu(),null,false,44)
	var card:=_card(right,"Intel")
	var b: Dictionary=Data.ENEMIES[c.boss]
	_card_heading(card,"Target",Color("e5484d"))
	_row(card,"Boss","%s, %s" % [b.name,String(b.get("title","")).to_lower()])
	_row(card,"Robots",", ".join(_chapter_robots(c)))
	if float(c.elite)>0: _row(card,"Elites","%d%% of robots, gold trim, always drop a power-up" % roundi(float(c.elite)*100))
	_card_heading(card,"Squad",P1_COLOR)
	for h in game.heroes: _row(card,Data.HEROES[h.hero_id],"%d / %d HP   %d upgrades" % [ceili(h.hp),ceili(h.max_hp),_upgrade_count(h)])
	go.grab_focus()

func _chapter_robots(c: Dictionary) -> Array[String]:
	var ids: Array[int]=[]
	for w in c.waves:
		for id in w[1]: if not ids.has(int(id)): ids.append(int(id))
	ids.sort()
	var names: Array[String]=[]
	for id in ids: names.append(Data.enemy_name(id))
	return names

func _upgrade_count(h: SectorActor) -> int:
	var n:=0
	for k in h.upgrades: n+=int(h.upgrades[k])
	return n

# After each boss: what was found, then on to the upgrade picks.
func show_debrief(ch: int) -> void:
	var c: Dictionary=Campaign.CHAPTERS[ch]
	var last: bool=ch>=Campaign.CHAPTERS.size()-1
	var cols:=_page("Operation complete" if last else "Chapter %02d clear" % (ch+1),620)
	var left:=cols[0]; var right:=cols[1]
	var bar:=ColorRect.new(); bar.color=LIME; bar.custom_minimum_size=Vector2(56,5); bar.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN; left.add_child(bar)
	_label(left,c.title.to_upper(),28,NAVY,true)
	_section(left,"Final report" if last else "Debrief")
	_story_text(left,c.debrief)
	var next: String="See the final report" if last else "Pick upgrades, then chapter %02d: %s" % [ch+2,Campaign.CHAPTERS[ch+1].title]
	var go:=_tile(left,"CONTINUE",next,true,func(): game.continue_after_debrief(),null,false,56)
	_paint_primary(go)
	var card:=_card(right,"Chapter stats")
	_row(card,"Destroyed",Data.enemy_name(c.boss))
	_row(card,"Kills","%d" % game.kills)
	_row(card,"Score","%d" % game.score)
	_row(card,"Time","%02d:%02d" % [int(game.elapsed)/60,int(game.elapsed)%60])
	for h in game.heroes: _row(card,Data.HEROES[h.hero_id],"DOWN" if h.downed or h.dead else "%d / %d HP" % [ceili(h.hp),ceili(h.max_hp)])
	go.grab_focus()
