class_name KillCam
extends Node3D
# Kill cam: every 9th robot destroyed (and the boss) gets a 5-7 s cinematic, chosen by how it died.
#   BULLET CAM   (guns)       time nearly freezes, the camera rides behind a glowing round from the muzzle to the
#                             robot, then swings round the suspended wreck as time ramps back.
#   IMPACT ZOOM  (guns, alt.) push in from the shooter's shoulder as the round flies in, then the robot breaks apart.
#   BLAST CRANE  (explosives) low inside the blast, craning up and away.
#   BLADE CUT    (katana)     predicted: when a swing starts that will make the 9th kill, time slows at once and the
#                             camera comes in on the real cut. A blade kill that was not predicted (e.g. a robot that
#                             walked into the arc) falls back to a replay: the robot is held while the cut replays, the camera
#                             side-on to the arc; the blade connects, the robot is sliced in two along the real
#                             blade plane, the top half slides off and the camera swings round as both halves burn up.
# Everything runs on the real-time clock (Engine.time_scale is driven here), then hands back to the gameplay
# camera. The action waits while the camera glides in, then plays from its beginning; the camera and time ease
# back to gameplay together. Letterbox bars and a caption frame the shot; the music dips meanwhile.

const EVERY := 9
const DURATION := {"bullet":5.0,"zoom":4.1,"crane":4.0,"orbit":5.6}
const CUT_REPLAY_AT := .6  # real seconds into the blade shot when the replayed swing starts
const CUT_HOLD := 2.0      # real seconds the two halves stay on screen before they burn up
const CUT_CLOSE := 1.3     # real seconds the camera holds the close-up on the cut, time nearly frozen
const EASE_IN := 1.1   # establish the camera before starting the action clock
const EASE_OUT := 1.2  # glide back to the gameplay view while time speeds back up
const SETUP_SCALE := .001  # hold the wind-up and effects while the camera gets into place

var game: Node
var active := false
var style := ""
var t := 0.0  # real seconds since the start
var shot_time := 0.0  # action clock: starts only once the camera is in place
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
var shot_scale := 1.0  # shot pace after setup; blended back to 1.0 at the end
var _boom := Callable()  # destroys the held robot (game.enemy_killed); called at the on-screen impact
# blade cut
var killer: SectorActor
var victim: SectorActor
var cut_index := 0
var side_sign := 1.0          # which side of the fight the camera films from (the one clear of walls)
var live := false             # blade cut filmed as it happens (predicted at the start of the swing), not a replay
var cut_from := Vector3.ZERO  # where the swordsman stood when the cut-down started; he lunges in from here
var cut_spot := Vector3.ZERO
var cut_at := -1.0            # action-clock time the blade connected (<0 = not yet)
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
var _blade_previous := PackedVector3Array()
var _blade_contact := {}  # first actual edge/body contact in the strike, including its sweep direction
var _cut_requested := false
var _cut_surfaces: Array[MeshInstance3D] = []
static var _clip_shader: Shader
static var _strike_paths := {}  # sampled from the real rig/weapon once, then reused for cinematic footwork
var _last_us := 0
var _pull := [1.0,1.0,1.0]  # per camera pose: distance kept clear of walls (fraction of the wanted distance)

func _ready() -> void:
	process_priority=100  # sample after the AnimationTree has advanced the visible blade pose
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
	# Every style holds the robot until its on-screen impact, including the blast crane.
	if is_instance_valid(e): e._set_flash(false)  # clear the hit flash so the held robot reads
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
		return

func _fire_boom() -> void:
	var boom:=_boom
	_boom=Callable()
	if boom.is_valid(): boom.call()

func _begin(kills: int, boss: bool) -> void:
	active=true; t=0.0; shot_time=0.0; _last_us=Time.get_ticks_usec(); _impacted=false; shot_scale=SETUP_SCALE
	_pull=[1.0,1.0,1.0]
	# Do this in the triggering physics frame: waiting for _process lets a live cut run ahead of the camera.
	Engine.time_scale=SETUP_SCALE
	cam=Camera3D.new(); cam.fov=52.0; cam.near=.05; cam.far=200.0; add_child(cam)
	cam.global_transform=game.camera.global_transform
	cam.current=true
	for h in game.heroes:  # nobody dies off-screen during the shot
		if is_instance_valid(h): h.invulnerable=maxf(h.invulnerable,3.0)
	caption.text=("BOSS DOWN" if boss else "KILL #%d" % kills)+"   //   "+{"bullet":"BULLET CAM","zoom":"IMPACT","crane":"BLAST","orbit":"BLADE"}[style]
	layer.visible=true
	if style in ["bullet","zoom"]: _make_slug()
	if style=="orbit": _setup_cut()
	game.play_sfx("windup")

func stop() -> void:
	if not active: return
	_fire_boom()
	active=false
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
	var total: float=EASE_IN+DURATION[style]
	if t>=total: stop(); return
	shot_time=maxf(0,t-EASE_IN)
	var out_weight:=_smooth(clampf((total-t)/EASE_OUT,0,1))
	var w:=minf(_smooth(clampf(t/EASE_IN,0,1)),out_weight)
	var shot:=Transform3D.IDENTITY
	match style:
		"bullet": shot=_bullet(shot_time)
		"zoom": shot=_zoom(shot_time)
		"crane": shot=_crane(shot_time)
		"orbit": shot=_orbit(shot_time)
	if style=="orbit" and t>=EASE_IN: _update_cut(shot_time,DURATION[style])
	if style=="orbit" and t>=EASE_IN and cut_at<0: _sample_blade()
	cam.global_transform=game.camera.global_transform.interpolate_with(shot,w)
	cam.fov=lerpf(game.camera.fov,52.0,w)
	Engine.time_scale=SETUP_SCALE if t<EASE_IN else lerpf(1.0,shot_scale,out_weight)
	_bars(w)

# ---------------------------------------------------------------- shots
func _bullet(s: float) -> Transform3D:
	var start:=.15  # a short hold at the muzzle, after the camera is fully in place
	var flight:=1.5
	var dir:=(target-muzzle); var dist:=dir.length(); dir=dir.normalized() if dist>.01 else Vector3.FORWARD
	var side:=dir.cross(Vector3.UP).normalized()
	if s<start+flight:
		shot_scale=.03
		var k:=clampf((s-start)/flight,0,1)
		var p:=_move_slug(k)
		var eye:=p-dir*1.5+Vector3.UP*.38+side*.28
		return _look(_clear_of_walls(p,eye,0),p+dir*2.5,sin(s*1.2)*.05)
	if not _impacted: _impact()
	# hang on the burst, then swing slowly round the wreck as time ramps back
	var k2:=clampf((s-start-flight)/(DURATION.bullet-start-flight),0,1)
	shot_scale=lerpf(.05,.35,_smooth(k2))
	var back:=-dir.rotated(Vector3.UP,lerpf(0,1.6,_smooth(k2)))
	var eye:=target+back*lerpf(1.6,3.4,_smooth(k2))*size+Vector3.UP*lerpf(.3,1.3,_smooth(k2))
	return _look(_clear_of_walls(target,eye,1),target,0.0)

func _zoom(s: float) -> Transform3D:
	var hit:=1.5  # the push-in lands, the robot bursts
	var dir:=(target-killer_pos); dir.y=0; dir=dir.normalized() if dir.length()>.01 else Vector3.FORWARD
	var side:=dir.cross(Vector3.UP).normalized()
	var shoulder:=killer_pos+Vector3.UP*1.9-dir*1.2+side*.7
	var close:=target-dir*2.2*size+Vector3.UP*.5+side*.45
	var k:=_smooth(clampf(s/hit,0,1))
	var punch:=0.0
	if s<hit:
		shot_scale=.04
		_move_slug((s-.3)/(hit-.3))  # show the round leaving the muzzle during the push-in, before impact
	else:
		if not _impacted: _impact()
		shot_scale=lerpf(.06,.3,_smooth(clampf((s-hit)/1.6,0,1)))
		punch=(1.0-_smooth(clampf((s-hit)/.45,0,1)))*.3  # small kick back on impact, settling
	var drift:=side*_smooth(clampf((s-hit)/2.0,0,1))*.6  # slow sideways drift while the robot breaks apart
	return _look(_clear_of_walls(target,shoulder.lerp(close,k)-dir*punch+drift,0),target,lerpf(0,-.07,k))

func _crane(s: float) -> Transform3D:
	if s>0 and not _impacted: _impact()
	var k:=_smooth(clampf(s/(DURATION.crane-.3),0,1))
	shot_scale=lerpf(.08,.35,k)
	var away:=(target-killer_pos); away.y=0; away=away.normalized() if away.length()>.01 else Vector3.FORWARD
	var eye:=target-away*lerpf(1.4,5.5,k)+Vector3.UP*lerpf(.25,4.5,k)+away.cross(Vector3.UP)*lerpf(.6,1.8,k)
	var at:=target+Vector3.UP*lerpf(.2,0,k)
	return _look(_clear_of_walls(at,eye,0),at,0.0)

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
	_blade_previous=PackedVector3Array(); _blade_contact={}; _cut_requested=false; _cut_surfaces.clear()
	if is_instance_valid(victim) and is_instance_valid(victim.torso_mesh):
		# An outstretched arm is touched before the body: use the body crossing for the robot's main split.
		_cut_surfaces.append(victim.torso_mesh)
	var flat:=target-cut_from; flat.y=0
	var dir:=flat.normalized() if flat.length()>.01 else Vector3.FORWARD
	var body_at:=victim.torso_mesh.to_global(victim.torso_mesh.mesh.get_aabb().get_center()) if is_instance_valid(victim) and is_instance_valid(victim.torso_mesh) else target
	var contact:=_strike_offset(body_at.y-cut_from.y)
	var yaw:=atan2(-dir.x,-dir.z)
	contact=contact.rotated(Vector3.UP,yaw)
	cut_spot=Vector3(body_at.x-contact.x,cut_from.y,body_at.z-contact.z)
	killer.cutscene=true; killer.aim=dir; killer.velocity=Vector3.ZERO; killer.target=null
	killer.model.rotation=Vector3(0,yaw,0)
	if not live:  # discard the tail of the original swing; replay the whole cut once the camera is ready
		killer.swing_time=0; killer.swing_impact=-1; killer.trail_prev.clear()
	if is_instance_valid(victim):
		victim._set_flash(false); victim.cutscene=true; victim.velocity=Vector3.ZERO
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

# The redesigned katana's length and curve need different footing for each combo. Choose the foot position
# from actual animated edge poses at body height, so the blade crosses the body instead of an arbitrary plane.
func _strike_offset(height: float) -> Vector3:
	var key:=killer.hero_id
	if not _strike_paths.has(key):
		var probe:=SectorActor.new(); probe.setup(game,true,key,-1); probe.visible=false
		game.add_child(probe); probe.set_process(false); probe.set_physics_process(false)
		probe.collision_layer=0; probe.collision_mask=0
		probe.tree.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		probe.tree.advance(.5)
		var skeletons:=probe.model.find_children("*","Skeleton3D",true,false)
		var attachments:=probe.model.find_children("*","BoneAttachment3D",true,false)
		var paths: Array=[]
		for combo in range(3):
			var samples: Array=[]; probe.replay_cut(combo)
			for frame in range(90):
				probe.tree.advance(1.0/240.0)
				for skeleton in skeletons: skeleton.force_update_all_bone_transforms()
				for attachment in attachments: attachment.on_skeleton_update()
				var phase: float=(frame+1)/240.0
				if phase>=.12 and phase<=.3: samples.append({"time":phase,"edge":probe.blade_edge_points()})
			paths.append(samples); probe.tree.advance(.8)
		_strike_paths[key]=paths
		probe.tree.active=false; probe.queue_free()
	var best:=INF; var offset:=Vector3(0,height,-2)
	var strike:=.23 if cut_index==2 else .2
	for sample in _strike_paths[key][cut_index]:
		var edge: PackedVector3Array=sample.edge
		for i in range(1,edge.size()-1):
			var a:=edge[i]; var b:=edge[i+1]
			var u:=clampf((height-a.y)/(b.y-a.y),0,1) if absf(b.y-a.y)>.00001 else .5
			var point:=a.lerp(b,u)
			var score:=absf(point.y-height)*100+absf(sample.time-strike)*3+absf((i+u)/(edge.size()-1)-.75)*.1
			if score<best: best=score; offset=point
	return offset

func _update_cut(s: float, total: float) -> void:
	if cut_at<0:
		if is_instance_valid(killer) and not killer.dead and not killer.downed:
			if s>=CUT_REPLAY_AT and killer.swing_time<=0 and killer.swing_impact<=0 and not has_meta("replayed"):
				set_meta("replayed",true); killer.replay_cut(cut_index)
			if has_meta("replayed"):
				# lunge in during the wind-up (fumikomi), landing at the strike
				var k:=clampf((s-(0.0 if live else CUT_REPLAY_AT))/.55,0,1)
				killer.global_position=cut_from.lerp(cut_spot,_smooth(k))
		if s>CUT_REPLAY_AT+2.0 and not _impacted:
			# A missed/interrupted blade has no cut plane. Finish the held destruction without inventing a slice.
			cut_at=s; cut_p=target; slide=Vector3.DOWN; _impact()
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

# Sample the curved edge in rendered animation poses. The physics strike timer may request a cut, but it
# cannot choose its plane or make the body split before the visible blade actually reaches it.
func _sample_blade() -> void:
	if not is_instance_valid(killer) or killer.dead or killer.downed or cut_at>=0: return
	if killer.loadout.is_empty() or killer.loadout[killer.weapon].kind!="melee": return
	for skeleton in killer.model.find_children("*","Skeleton3D",true,false): skeleton.force_update_all_bone_transforms()
	for attachment in killer.model.find_children("*","BoneAttachment3D",true,false): attachment.on_skeleton_update()
	var edge:=killer.blade_edge_points()
	if _blade_previous.size()==edge.size() and edge.size()>1 and killer.swing_time>0 and killer.swing_impact<.09:
		if _blade_contact.is_empty(): _blade_contact=_blade_intersection(_blade_previous,edge)
		if not _blade_contact.is_empty():
			if killer.swing_impact>0: killer.land_cut()  # align the filmed damage with visual contact
			if _cut_requested: _slice_blade()
	_blade_previous=edge

func _blade_intersection(previous: PackedVector3Array, edge: PackedVector3Array) -> Dictionary:
	var travel:=0.0
	for i in range(edge.size()): travel=maxf(travel,edge[i].distance_to(previous[i]))
	if travel<.000001: return {}
	# Substeps keep the sweep from tunnelling through a limb on a slow rendered frame.
	var steps:=clampi(ceili(travel/.025),1,64)
	for step in range(1,steps+1):
		var f:=float(step)/steps
		for i in range(edge.size()-1):
			var a:=previous[i].lerp(edge[i],f); var b:=previous[i+1].lerp(edge[i+1],f)
			var blade:=(b-a).normalized()
			for surface in _cut_surfaces:
				if not is_instance_valid(surface): continue
				var hit=surface.mesh.get_aabb().intersects_segment(surface.to_local(a),surface.to_local(b))
				if hit==null: continue
				var point: Vector3=surface.to_global(hit)
				var u:=clampf((point-a).dot(b-a)/maxf(a.distance_squared_to(b),.00000001),0,1)
				var motion: Vector3=(edge[i]-previous[i]).lerp(edge[i+1]-previous[i+1],u)
				if motion.length_squared()<.000000000001: continue
				var normal:=blade.cross(motion.normalized())
				if normal.length_squared()<.000001: continue
				return {"point":point,"normal":normal.normalized(),"motion":motion.normalized(),"a":a,"b":b,"segment":i}
	return {}

# Called at the gameplay strike key. A real swept-edge contact, rather than this timer, defines the slice.
func blade_connects(by: SectorActor) -> void:
	if cut_at>=0: return
	if by!=killer: return
	_cut_requested=true
	if not _blade_contact.is_empty(): _slice_blade()

func _slice_blade() -> void:
	if cut_at>=0 or _blade_contact.is_empty(): return
	cut_at=shot_time
	cut_p=_blade_contact.point
	cut_n=_blade_contact.normal
	if cut_n.y<0: cut_n=-cut_n
	var motion: Vector3=_blade_contact.motion
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
	_make_cut_line(along.normalized())
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
	if is_instance_valid(victim): victim.cutscene=false
	if has_meta("replayed"): remove_meta("replayed")
	killer=null; victim=null; live=false
	_blade_previous=PackedVector3Array(); _blade_contact={}; _cut_surfaces.clear(); _cut_requested=false

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
	streak.visible=false

func _move_slug(progress: float) -> Vector3:
	var p:=muzzle.lerp(target,_smooth(clampf(progress,0,1)))
	var dir:=(target-muzzle).normalized()
	if is_instance_valid(slug):
		slug.global_position=p
		if dir.length_squared()>.001: slug.look_at(p+dir,Vector3.UP if absf(dir.y)<.98 else Vector3.RIGHT)
		_update_streak(muzzle,p)
	return p

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
