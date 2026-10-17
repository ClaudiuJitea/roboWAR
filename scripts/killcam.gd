class_name KillCam
extends Node3D
# Kill cam: every 9th robot destroyed (and the boss) gets a 4-5 s cinematic, chosen by how it died.
#   BULLET CAM   (guns)       time nearly freezes, the camera rides behind a glowing round from the muzzle to the
#                             robot, then swings round the suspended wreck as time ramps back.
#   IMPACT ZOOM  (guns, alt.) fast push-in from the shooter's shoulder onto the robot as it breaks apart.
#   BLAST CRANE  (explosives) low inside the blast, craning up and away.
#   BLADE CUT    (katana)     predicted: when a swing starts that will make the 9th kill, time slows at once and the
#                             camera comes in on the real cut. A blade kill that was not predicted (e.g. a robot that
#                             walked into the arc) falls back to a replay: the robot is held while the cut replays, the camera
#                             side-on to the arc; the blade connects, the robot is sliced in two along the real
#                             blade plane, the top half slides off and the camera swings round as both halves burn up.
# Everything runs on the real-time clock (Engine.time_scale is driven here), then hands back to the gameplay
# camera. It eases in (camera glides over while time slows) and eases out (glides back while time recovers). Letterbox bars and a caption frame the shot; the music dips meanwhile.

const EVERY := 9
const DURATION := {"bullet":5.0,"zoom":4.1,"crane":4.0,"orbit":5.6}
const CUT_REPLAY_AT := .6  # real seconds into the blade shot when the replayed swing starts
const CUT_HOLD := 2.0      # real seconds the two halves stay on screen before they burn up
const CUT_CLOSE := 1.3     # real seconds the camera holds the close-up on the cut, time nearly frozen
const EASE_IN := 1.1   # glide from the gameplay view into the shot while time slows down
const EASE_OUT := 1.2  # glide back to the gameplay view while time speeds back up

var game: Node
var active := false
var style := ""
var t := 0.0  # real seconds since the start
var cam: Camera3D
var killer_pos := Vector3.ZERO
var muzzle := Vector3.ZERO
var target := Vector3.ZERO
var size := 1.0
var color := Color.WHITE
var slug: Node3D
var streak: MeshInstance3D
var bars: Array[ColorRect] = []
var caption: Label
var layer: CanvasLayer
var _gun_alt := 0
var _impacted := false
var shot_scale := 1.0  # time scale the current shot asks for; blended with 1.0 at the start and end
var _boom := Callable()  # destroys the held robot (game.enemy_killed); called at the on-screen impact
# blade cut
var killer: SectorActor
var victim: SectorActor
var cut_index := 0
var side_sign := 1.0          # which side of the fight the camera films from (the one clear of walls)
var live := false             # blade cut filmed as it happens (predicted at the start of the swing), not a replay
var cut_from := Vector3.ZERO  # where the swordsman stood when the cut-down started; he lunges in from here
var cut_spot := Vector3.ZERO
var cut_at := -1.0            # real time the replayed blade connected (<0 = not yet)
var cut_radius := 3.0         # camera distance at the moment of the cut, so the swing-round starts there
var cut_eye := Vector3.ZERO   # camera pose at the moment of the cut, so the push-in starts there
var cut_look := Vector3.ZERO
var cut_n := Vector3.UP       # cut plane (world) at the moment of the cut
var cut_p := Vector3.ZERO
var slide := Vector3.ZERO     # direction the top half slides off along the cut
var halves: Array[Node3D] = []
var half_mats: Array = [[],[]]
var upper_base := Transform3D.IDENTITY
var cut_line: MeshInstance3D
static var _clip_shader: Shader
var _last_us := 0
var _pull := [1.0,1.0,1.0]  # per camera pose: distance kept clear of walls (fraction of the wanted distance)

func _ready() -> void:
	layer=CanvasLayer.new(); layer.layer=5; add_child(layer)
	for i in range(2):
		var r:=ColorRect.new(); r.color=Color(0.02,0.03,0.05,0.96); r.mouse_filter=Control.MOUSE_FILTER_IGNORE
		layer.add_child(r); bars.append(r)
	caption=Label.new(); caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
	caption.add_theme_font_size_override("font_size",22); caption.add_theme_color_override("font_color",Color("f4f1ea"))
	layer.add_child(caption)
	layer.visible=false

# Called for every destroyed robot; starts a scene on every 9th kill and on the boss.
func on_kill(e: SectorActor, kills: int, boom: Callable = Callable()) -> bool:
	if active and live and e==victim and not _boom.is_valid():
		_boom=boom; e._set_flash(false)  # the predicted kill: hold the robot for the slice
		return true
	if active or game.settings.get("killcam",1.0)<.5 or game.state!="playing": return false
	if kills%EVERY!=0 and not e.boss: return false
	killer=e.last_attacker if is_instance_valid(e.last_attacker) and e.last_attacker.hero else null
	if killer==null:
		for h in game.heroes:
			if is_instance_valid(h) and not h.dead: killer=h; break
	if killer==null: return false
	var w: Dictionary=killer.loadout[killer.weapon] if not killer.loadout.is_empty() else {}
	var kind: String=w.get("kind","hitscan")
	if kind=="melee": style="orbit"
	elif e.last_damage_type=="explosive" or kind in ["rocket","grenade"]: style="crane"
	else:
		style="bullet" if _gun_alt%2==0 else "zoom"; _gun_alt+=1
	killer_pos=killer.global_position
	muzzle=killer.muzzle_position()
	target=e.global_position+Vector3.UP*(.75*e.body_scale() if e.boss else .85)
	size=e.model.scale.x if is_instance_valid(e.model) else 1.0
	color=killer.weapon_color()
	_boom=boom
	victim=e; cut_index=killer.combo; cut_at=-1.0; live=false
	_begin(kills,e.boss)
	# bullet cam, impact zoom and the blade cut keep the robot standing (frozen) until the shot connects on screen
	if style not in ["bullet","zoom","orbit"]: _fire_boom()
	elif is_instance_valid(e): e._set_flash(false)  # the hit flash is on game time: clear it so the held robot reads
	return true

# Called as a blade swing starts: if it will make the 9th kill (or kill the boss), start the blade cut now so the
# camera is already in, and time already slowed, when the real blade connects.
func predict_cut(by: SectorActor, w: Dictionary, amount: float) -> void:
	if active or game.settings.get("killcam",1.0)<.5 or game.state!="playing": return
	var n:=0
	for e in game.melee_targets(by,by.aim,w):
		var dmg:=amount
		if e.enemy_id==4 and e.aim.dot((by.global_position-e.global_position).normalized())>.25: dmg*=.3  # shield
		if e.invulnerable>0 or e.hp>dmg: continue
		n+=1
		if (game.kills+n)%EVERY!=0 and not e.boss: continue
		killer=by; victim=e; live=true; style="orbit"; cut_index=by.combo; cut_at=-1.0
		killer_pos=by.global_position; muzzle=by.muzzle_position()
		target=e.global_position+Vector3.UP*(.75*e.body_scale() if e.boss else .85)
		size=e.model.scale.x if is_instance_valid(e.model) else 1.0
		color=by.weapon_color()
		_boom=Callable()
		_begin(game.kills+n,e.boss)
		set_meta("replayed",true)  # the real swing is already under way: nothing to replay
		cut_spot=cut_from          # and no lunge: he is already in reach
		return

func _fire_boom() -> void:
	if _boom.is_valid(): _boom.call()
	_boom=Callable()

func _begin(kills: int, boss: bool) -> void:
	active=true; t=0.0; _last_us=Time.get_ticks_usec(); _impacted=false; shot_scale=1.0
	cam=Camera3D.new(); cam.fov=52.0; cam.near=.05; cam.far=200.0; add_child(cam)
	cam.global_transform=game.camera.global_transform
	cam.current=true
	for h in game.heroes:  # nobody dies off-screen during the shot
		if is_instance_valid(h): h.invulnerable=maxf(h.invulnerable,3.0)
	caption.text=("BOSS DOWN" if boss else "KILL #%d" % kills)+"   //   "+{"bullet":"BULLET CAM","zoom":"IMPACT","crane":"BLAST","orbit":"BLADE"}[style]
	layer.visible=true
	if style=="bullet": _make_slug()
	if style=="orbit": _setup_cut()
	game.play_sfx("windup")

func stop() -> void:
	if not active: return
	active=false
	_fire_boom()
	Engine.time_scale=1.0
	if is_instance_valid(cam): cam.queue_free()
	if is_instance_valid(game.camera): game.camera.current=true
	if is_instance_valid(slug): slug.queue_free()
	if is_instance_valid(streak): streak.queue_free()
	_clear_cut()
	layer.visible=false

func music_duck() -> float:
	return .35 if active else 1.0

func _process(delta: float) -> void:
	if not active: return
	var now:=Time.get_ticks_usec(); var real:=(now-_last_us)/1000000.0; _last_us=now
	if game.state!="playing":
		if game.state!="paused": stop()
		return
	t+=minf(real,.1)  # wall clock, so the shot keeps pace with real time; one hitch moves it at most .1 s
	var total: float=DURATION[style]
	if t>=total: stop(); return
	# one weight drives everything: 0 = gameplay view at full speed, 1 = the cinematic shot at its own pace
	var w:=minf(_smooth(clampf(t/(.6 if live else EASE_IN),0,1)),_smooth(clampf((total-t)/EASE_OUT,0,1)))
	var shot:=Transform3D.IDENTITY
	match style:
		"bullet": shot=_bullet(t)
		"zoom": shot=_zoom(t)
		"crane": shot=_crane(t)
		"orbit": shot=_orbit(t)
	if style=="orbit": _update_cut(t,total)
	cam.global_transform=game.camera.global_transform.interpolate_with(shot,w)
	cam.fov=lerpf(game.camera.fov,52.0,w)
	# a live cut has to slow time at once: the blade connects about 0.2 s of game time after the swing starts
	var wt:=minf(_smooth(clampf(t/.12,0,1)),_smooth(clampf((total-t)/EASE_OUT,0,1))) if live else w
	Engine.time_scale=lerpf(1.0,shot_scale,wt)
	_bars(w)

# ---------------------------------------------------------------- shots
func _bullet(s: float) -> Transform3D:
	var start:=EASE_IN*.8  # the round leaves once the camera has settled behind the muzzle
	var flight:=1.5
	var dir:=(target-muzzle); var dist:=dir.length(); dir=dir.normalized() if dist>.01 else Vector3.FORWARD
	var side:=dir.cross(Vector3.UP).normalized()
	if s<start+flight:
		shot_scale=.03
		var k:=clampf((s-start)/flight,0,1)
		var p:=muzzle.lerp(target,_smooth(k))
		if is_instance_valid(slug):
			slug.global_position=p; slug.look_at(p+dir,Vector3.UP)
			_update_streak(muzzle,p)
		var eye:=p-dir*1.5+Vector3.UP*.38+side*.28
		return _look(eye,p+dir*2.5,sin(s*1.2)*.05)
	if not _impacted: _impact()
	# hang on the burst, then swing slowly round the wreck as time ramps back
	var k2:=clampf((s-start-flight)/(DURATION.bullet-start-flight),0,1)
	shot_scale=lerpf(.05,.35,_smooth(k2))
	var back:=-dir.rotated(Vector3.UP,lerpf(0,1.6,_smooth(k2)))
	var eye:=target+back*lerpf(1.6,3.4,_smooth(k2))*size+Vector3.UP*lerpf(.3,1.3,_smooth(k2))
	return _look(eye,target,0.0)

func _zoom(s: float) -> Transform3D:
	var hit:=1.5  # the push-in lands, the robot bursts
	var dir:=(target-killer_pos); dir.y=0; dir=dir.normalized() if dir.length()>.01 else Vector3.FORWARD
	var side:=dir.cross(Vector3.UP).normalized()
	var shoulder:=killer_pos+Vector3.UP*1.9-dir*1.2+side*.7
	var close:=target-dir*2.2*size+Vector3.UP*.5+side*.45
	var k:=_smooth(clampf(s/hit,0,1))
	var punch:=0.0
	if s<hit: shot_scale=.04  # frozen while the camera pushes in on the robot
	else:
		if not _impacted: _impact()
		shot_scale=lerpf(.06,.3,_smooth(clampf((s-hit)/1.6,0,1)))
		punch=(1.0-_smooth(clampf((s-hit)/.45,0,1)))*.3  # small kick back on impact, settling
	var drift:=side*_smooth(clampf((s-hit)/2.0,0,1))*.6  # slow sideways drift while the robot breaks apart
	return _look(shoulder.lerp(close,k)-dir*punch+drift,target,lerpf(0,-.07,k))

func _crane(s: float) -> Transform3D:
	if not _impacted: _impact()
	var k:=_smooth(clampf(s/(DURATION.crane-.3),0,1))
	shot_scale=lerpf(.08,.35,k)
	var away:=(target-killer_pos); away.y=0; away=away.normalized() if away.length()>.01 else Vector3.FORWARD
	var eye:=target-away*lerpf(1.4,5.5,k)+Vector3.UP*lerpf(.25,4.5,k)+away.cross(Vector3.UP)*lerpf(.6,1.8,k)
	return _look(eye,target+Vector3.UP*lerpf(.2,0,k),0.0)

func _orbit(s: float) -> Transform3D:
	var dir:=(target-cut_from); dir.y=0; dir=dir.normalized() if dir.length()>.01 else Vector3.FORWARD
	var side:=dir.cross(Vector3.UP).normalized()*side_sign
	var reach:=maxf(1.0,size*.8)
	var hero_at:=killer.global_position if is_instance_valid(killer) else cut_spot
	var mid:=(hero_at+Vector3.UP*.95).lerp(target,.5)
	if cut_at<0:
		# the swing in slow motion: side-on to the arc, pushing in slowly as the blade comes round
		shot_scale=.12 if live else .2
		cut_radius=(lerpf(3.4,2.7,_smooth(clampf(s/1.2,0,1))) if live else lerpf(4.2,3.4,_smooth(clampf(s/1.6,0,1))))*reach
		cut_look=mid+Vector3.UP*.3
		cut_eye=_clear_of_walls(mid,mid+side*cut_radius+dir*.35+Vector3.UP*.75,0)
		return _look(cut_eye,cut_look,0.0)
	var h:=s-cut_at
	# the blade connects: time all but stops, the camera snaps in on the cut while the top half slides off,
	# then time creeps back while the camera pulls out and swings round behind the robot
	shot_scale=.03 if h<CUT_CLOSE-.1 else lerpf(.06,.35,_smooth(clampf((h-CUT_CLOSE+.1)/2.0,0,1)))
	var shake:=Vector3(sin(h*71.0),sin(h*53.0+1.3),cos(h*67.0))*.04*maxf(0,1.0-h/.4)
	# close-up: side-on to the way the top half slides, from the camera's side, a little above the cut
	var flat_slide:=Vector3(slide.x,0,slide.z); flat_slide=flat_slide.normalized() if flat_slide.length()>.1 else dir
	var across:=Vector3.UP.cross(flat_slide).normalized()
	if across.dot(cut_eye-cut_p)<0: across=-across
	across=across.rotated(Vector3.UP,.3*_smooth(clampf(h/CUT_CLOSE,0,1)))  # slow drift while held
	var close_at:=cut_p+Vector3.UP*.1*size+slide*.1*size
	var close_eye:=_clear_of_walls(close_at,close_at+across*2.3*size+Vector3.UP*.4*size,1)
	var a:=_smooth(clampf(h/.3,0,1))
	var eye:=cut_eye.lerp(close_eye,a); var at:=cut_look.lerp(close_at,a)
	# pull out and swing round
	var k:=_smooth(clampf((h-CUT_CLOSE)/(DURATION.orbit-cut_at-CUT_CLOSE-.2),0,1))
	if k>0:
		var center:=mid.lerp(target,.6)
		var wide:=_clear_of_walls(center,center+across.rotated(Vector3.UP,lerpf(0,1.0,k))*lerpf(2.3*size,4.4*reach,k)+Vector3.UP*lerpf(.45*size,1.3,k),2)
		eye=eye.lerp(wide,k); at=at.lerp(center,k)
	return _look(eye+shake,at,lerpf(0,.06,k))

# Pulls a camera position in towards the subject so a wall or crate never comes between them.
func _clear_of_walls(at: Vector3, eye: Vector3, slot: int) -> Vector3:
	var q:=PhysicsRayQueryParameters3D.create(at,eye,1)
	var hit:=get_world_3d().direct_space_state.intersect_ray(q)
	var f:=1.0 if hit.is_empty() else at.distance_to(hit.position)/maxf(at.distance_to(eye),.01)*.85
	_pull[slot]=f if f<_pull[slot] else lerpf(_pull[slot],f,.06)  # in at once, back out gently
	return at.lerp(eye,_pull[slot])

# ---------------------------------------------------------------- blade cut
func _setup_cut() -> void:
	if not is_instance_valid(killer): return
	cut_from=killer.global_position; cut_n=Vector3.UP; cut_p=Vector3.ZERO; _pull=[1.0,1.0,1.0]
	var flat:=target-cut_from; flat.y=0
	var dir:=flat.normalized() if flat.length()>.01 else Vector3.FORWARD
	cut_spot=Vector3(target.x,cut_from.y,target.z)-dir*(1.15+.35*size)
	if flat.length()<cut_from.distance_to(cut_spot)+.01: cut_spot=cut_from  # already in reach: no step back
	killer.cutscene=true; killer.aim=dir; killer.velocity=Vector3.ZERO; killer.target=null
	if is_instance_valid(victim): victim._set_flash(false)
	# film from whichever side of the fight has more open floor
	var mid:=(cut_from+Vector3.UP*.95).lerp(target,.5); var across:=dir.cross(Vector3.UP).normalized()
	var space:=func(d: Vector3) -> float:
		var hit:=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(mid,mid+d*5.0+Vector3.UP*.75,1))
		return 5.0 if hit.is_empty() else mid.distance_to(hit.position)
	side_sign=1.0 if space.call(across)>=space.call(-across) else -1.0
	# draw the slice shader once now, behind the camera's near plane, so it is compiled before the cut lands
	var warm:=MeshInstance3D.new(); var q:=QuadMesh.new(); q.size=Vector2.ONE*.01; warm.mesh=q
	warm.material_override=_clip_mat(null,-1.0,[])  # keeps nothing above the floor: invisible
	cam.add_child(warm); warm.position=Vector3(0,0,-.2)
	get_tree().create_timer(.3,true,false,true).timeout.connect(warm.queue_free)

func _update_cut(s: float, total: float) -> void:
	if cut_at<0:
		if is_instance_valid(killer) and not killer.dead and not killer.downed:
			if s>=CUT_REPLAY_AT and killer.swing_time<=0 and killer.swing_impact<=0 and not has_meta("replayed"):
				set_meta("replayed",true); killer.replay_cut(cut_index)
			if has_meta("replayed"):
				# lunge in during the wind-up (fumikomi), landing at the strike
				var k:=clampf((s-CUT_REPLAY_AT)/.55,0,1)
				killer.global_position=cut_from.lerp(cut_spot,_smooth(k))
		if s>CUT_REPLAY_AT+2.0: blade_connects(null)  # the swing never landed (fighter downed): cut anyway
		return
	var h:=s-cut_at
	if halves.size()==2 and is_instance_valid(halves[0]):
		var k:=clampf(h/(CUT_HOLD*.8),0,1); k=1.0-(1.0-k)*(1.0-k)  # starts sliding at once, eases out
		var top:=halves[0]
		# slides off along the cut, tipping over about the cut point
		var tip:=Basis(cut_n.cross(slide).normalized(),-.7*k)
		var off:=slide*.9*size*k+cut_n*.07*size*minf(1,h*5.0)
		top.global_transform=Transform3D(Basis.IDENTITY,off)*Transform3D(tip,cut_p-tip*cut_p)*upper_base
		var d:=top.global_transform*upper_base.affine_inverse()
		var n:=(d.basis*cut_n).normalized(); var p:=d*cut_p
		for m in half_mats[0]: (m as ShaderMaterial).set_shader_parameter("plane",Vector4(n.x,n.y,n.z,n.dot(p)))
		var glow:=maxf(0,1.0-h/CUT_HOLD)
		for side in half_mats: for m in side: (m as ShaderMaterial).set_shader_parameter("heat",glow)
	if is_instance_valid(cut_line):
		var f:=clampf(h/.45,0,1)
		cut_line.scale=Vector3(1.0+f*.4,maxf(.02,1.0-f),maxf(.02,1.0-f))
		(cut_line.material_override as StandardMaterial3D).albedo_color.a=1.0-f
		if f>=1.0: cut_line.queue_free()
	if h>=CUT_HOLD and not halves.is_empty():
		_fire_boom(); _clear_halves()
	if s>total-EASE_OUT and is_instance_valid(killer): killer.cutscene=false  # hand control back as time recovers

# Called by the swordsman on the strike frame of the replayed cut: slices the held robot along the blade plane.
func blade_connects(by: SectorActor) -> void:
	if cut_at>=0: return
	cut_at=t
	var size_h:=1.35*size
	cut_p=(victim.global_position if is_instance_valid(victim) else target)+Vector3.UP*size_h*.55
	var dir:=(target-cut_from); dir.y=0; dir=dir.normalized() if dir.length()>.01 else Vector3.FORWARD
	var motion:=dir.cross(Vector3.UP)+Vector3.DOWN*.8  # fallback: a diagonal kesa cut
	var blade:=dir
	if is_instance_valid(by) and by.trail_prev.size()==2 and by.weapon<by.weapon_nodes.size() and is_instance_valid(by.weapon_nodes[by.weapon]):
		var tip:=by.muzzle_position(); var hilt:=by.weapon_nodes[by.weapon].global_position.lerp(tip,.18)
		if tip.distance_to(by.trail_prev[1])>.01: motion=tip-by.trail_prev[1]; blade=tip-hilt
	var n:=blade.cross(motion)
	if n.length()<.001: n=dir.cross(Vector3.UP).cross(motion)
	cut_n=n.normalized()
	if cut_n.y<0: cut_n=-cut_n
	if cut_n.y>.97: cut_n=(cut_n+dir*.3).normalized()  # keep a level cut slightly tilted so the top can slide
	var down:=Vector3.DOWN-cut_n*cut_n.dot(Vector3.DOWN)
	var along:=motion-cut_n*cut_n.dot(motion)
	slide=(down.normalized()+along.normalized()*.6).normalized() if down.length()>.05 else along.normalized()
	# no robot to slice (or the predicted kill did not happen): just the hit
	if not is_instance_valid(victim) or not is_instance_valid(victim.model) or live and not _boom.is_valid():
		_impact(); return
	_impacted=true
	victim._set_flash(false)
	for keep in [1.0,-1.0]:
		var half:=victim.model.duplicate() as Node3D
		add_child(half); half.global_transform=victim.model.global_transform
		half_mats[0 if keep>0 else 1]=_clip(half,keep)
		halves.append(half)
	upper_base=halves[0].global_transform
	victim.visible=false
	_make_cut_line(along.normalized() if along.length()>.01 else dir.cross(Vector3.UP))
	game.fx.sparks(cut_p,color,18,6.5)
	game.play_sfx("blade_hit"); game.play_sfx("sword")
	game.shake_amount=maxf(game.shake_amount,.25)

# Glowing line through the robot along the cut, flaring out over half a second (real time).
func _make_cut_line(along: Vector3) -> void:
	cut_line=MeshInstance3D.new(); var b:=BoxMesh.new(); b.size=Vector3(2.6*size,.025,.025); cut_line.mesh=b
	var m:=_glow(color,8.0,1.0); m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA; m.blend_mode=BaseMaterial3D.BLEND_MODE_ADD
	cut_line.material_override=m; cut_line.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(cut_line)
	var x:=along.normalized(); var y:=cut_n.cross(x).normalized()
	cut_line.global_transform=Transform3D(Basis(x,cut_n,-y).orthonormalized(),cut_p)

# Swaps every material under a robot copy for one that keeps only one side of the cut plane, with the cut face glowing.
func _clip(root: Node3D, keep: float) -> Array:
	var made: Array=[]
	var nodes: Array=root.find_children("*","MeshInstance3D",true,false)
	if root is MeshInstance3D: nodes.append(root)
	for mi: MeshInstance3D in nodes:
		mi.material_overlay=null
		if mi.mesh==null: continue
		if mi.material_override: mi.material_override=_clip_mat(mi.material_override,keep,made)
		else:
			for i in range(mi.mesh.get_surface_count()): mi.set_surface_override_material(i,_clip_mat(mi.get_active_material(i),keep,made))
	return made

func _clip_mat(src: Material, keep: float, made: Array) -> ShaderMaterial:
	if _clip_shader==null:
		_clip_shader=Shader.new(); _clip_shader.code=CLIP_SHADER
	var m:=ShaderMaterial.new(); m.shader=_clip_shader
	m.set_shader_parameter("plane",Vector4(cut_n.x,cut_n.y,cut_n.z,cut_n.dot(cut_p)))
	m.set_shader_parameter("keep",keep); m.set_shader_parameter("glow_color",color)
	if src is BaseMaterial3D:
		var b:=src as BaseMaterial3D
		m.set_shader_parameter("albedo",b.albedo_color); m.set_shader_parameter("metallic",b.metallic); m.set_shader_parameter("roughness",b.roughness)
		if b.albedo_texture: m.set_shader_parameter("albedo_tex",b.albedo_texture)
		if b.emission_enabled: m.set_shader_parameter("emission",b.emission*b.emission_energy_multiplier)
	made.append(m)
	return m

const CLIP_SHADER := """shader_type spatial;
render_mode cull_disabled;
uniform vec4 albedo : source_color = vec4(.16, .17, .2, 1.0);
uniform sampler2D albedo_tex : source_color, hint_default_white;
uniform float metallic = 0.0;
uniform float roughness = 1.0;
uniform vec3 emission = vec3(0.0);
uniform vec4 plane = vec4(0.0, 1.0, 0.0, 0.0);
uniform float keep = 1.0;
uniform vec3 glow_color : source_color = vec3(1.0, .55, .16);
uniform float heat = 1.0;
varying vec3 world;
void vertex() { world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float side = (dot(world, plane.xyz) - plane.w) * keep;
	if (side < 0.0) discard;
	vec4 c = albedo * texture(albedo_tex, UV);
	ALBEDO = c.rgb; METALLIC = metallic; ROUGHNESS = roughness;
	float edge = 1.0 - smoothstep(0.0, .045, side);
	// back faces seen through the cut are the molten inside of the robot
	EMISSION = emission + glow_color * heat * (edge * 5.0 + (FRONT_FACING ? 0.0 : 3.0));
}
"""

func _clear_halves() -> void:
	for half in halves: if is_instance_valid(half): half.queue_free()
	halves.clear(); half_mats=[[],[]]

func _clear_cut() -> void:
	_clear_halves()
	if is_instance_valid(cut_line): cut_line.queue_free()
	if is_instance_valid(killer): killer.cutscene=false
	if has_meta("replayed"): remove_meta("replayed")
	killer=null; victim=null; live=false

# ---------------------------------------------------------------- pieces
func _impact() -> void:
	_impacted=true
	_fire_boom()
	game.fx.sparks(target,color,14,6.0)
	game.fx._flash_mesh(target,color,.28*size,.12)
	game.fx._ring(target,color,.8*size,.3)
	game.play_sfx("blade_hit" if style=="orbit" else "damage")
	if is_instance_valid(slug): slug.queue_free()

func _make_slug() -> void:
	slug=Node3D.new(); add_child(slug)
	var m:=MeshInstance3D.new(); var cap:=CapsuleMesh.new(); cap.radius=.045; cap.height=.34; m.mesh=cap
	m.rotation.x=PI/2; m.material_override=_glow(color,6.0); slug.add_child(m)
	var light:=OmniLight3D.new(); light.light_color=color; light.light_energy=2.5; light.omni_range=2.2; slug.add_child(light)
	slug.global_position=muzzle
	streak=MeshInstance3D.new(); var cyl:=CylinderMesh.new(); cyl.top_radius=.018; cyl.bottom_radius=.004; cyl.height=1.0; cyl.radial_segments=6
	streak.mesh=cyl; streak.material_override=_glow(color,3.0,.55); add_child(streak)

func _update_streak(a: Vector3, b: Vector3) -> void:
	if not is_instance_valid(streak): return
	var span:=a.distance_to(b)
	if span<.05: streak.visible=false; return
	streak.visible=true
	streak.global_position=(a+b)*.5
	streak.look_at(b,Vector3.UP if absf((b-a).normalized().y)<.98 else Vector3.RIGHT)
	streak.rotate_object_local(Vector3.RIGHT,PI/2)
	streak.scale=Vector3(1,span,1)

func _glow(c: Color, energy: float, alpha := 1.0) -> StandardMaterial3D:
	var m:=StandardMaterial3D.new(); m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color=Color(c.lightened(.35),alpha); m.emission_enabled=true; m.emission=c; m.emission_energy_multiplier=energy
	if alpha<1.0: m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA; m.blend_mode=BaseMaterial3D.BLEND_MODE_ADD
	return m

func _bars(w: float) -> void:
	var vp:=get_viewport().get_visible_rect().size
	var h:=vp.y*.11*w
	bars[0].position=Vector2(0,0); bars[0].size=Vector2(vp.x,h)
	bars[1].position=Vector2(0,vp.y-h); bars[1].size=Vector2(vp.x,h)
	caption.position=Vector2(vp.x*.05,vp.y-h+h*.28)
	caption.modulate.a=clampf((w-.5)/.5,0,1)

func _look(eye: Vector3, at: Vector3, roll: float) -> Transform3D:
	var tr:=Transform3D.IDENTITY.translated(eye)
	if eye.distance_to(at)<.01: return tr
	tr=tr.looking_at(at,Vector3.UP)
	return tr.rotated_local(Vector3.FORWARD,roll)

func _smooth(x: float) -> float:  # smootherstep: zero velocity and acceleration at both ends
	return x*x*x*(x*(x*6.0-15.0)+10.0)
