extends SceneTree
# Each campaign chapter: its briefing screen and a fight in its environment with its robots and boss on the field.
# Saves evidence/campaign_<n>_briefing.png, evidence/campaign_<n>_fight.png and evidence/campaign_sheet.png.

func _initialize() -> void:
 call_deferred("run")

func _shot(name: String) -> Image:
 var img: Image=root.get_viewport().get_texture().get_image()
 img.save_png("res://evidence/%s.png" % name)
 return img

func run() -> void:
 var game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
 game.settings.killcam=0.0
 game.unlocked=3  # the setup screen shows two chapters still locked
 game.ui.show_menu(); await create_timer(.3).timeout
 _shot("campaign_menu")
 game.campaign=true; game.start_chapter=1; game.mode=1; game.ui.show_selection(); await create_timer(.3).timeout
 _shot("campaign_setup")
 game.unlocked=5
 var fights: Array[Image]=[]
 for ch in range(5):
  game.campaign=true; game.start_chapter=ch; game.mode=1; game.selected=[1,3]
  game.start_run()
  await create_timer(.3).timeout
  _shot("campaign_%d_briefing" % (ch+1))
  game.deploy(); game.spawn_left=0; game.wave_wait=9999
  for h in game.heroes: h.invulnerable=999
  var c: Dictionary=game.Campaign.CHAPTERS[ch]
  var hero=game.heroes[0]; hero.global_position=Vector3(-3,0,4)
  game.heroes[1].global_position=Vector3(0,0,5)
  var ids: Array=c.waves[2][1].keys()
  for k in range(9):
   var p:=Vector3(-9+k*2.2,0,-2+(k%3)*1.4)
   if game.arena.valid_spawn(p): game.spawn_enemy_at(int(ids[k%ids.size()]),p).speed=0.0
  var b=game.spawn_enemy_at(int(c.boss),Vector3(2,0,-6))
  game.radio("boss")
  game.wave=4
  for k in range(70):
   for h in game.heroes: h.invulnerable=999; h.hp=h.max_hp
   await physics_frame
  if ch==1: game.hazard(Vector3(-1,0,0),1.6,8.0,0.0,Color("ff6a1a"))
  game.heroes[0].apply_powerup("overcharge"); game.heroes[0].apply_powerup("haste")
  game._pickup(Vector3(-5,0,2),"rapid"); game._pickup(Vector3(-6.5,0,3),"barrier")
  await create_timer(.25).timeout
  fights.append(_shot("campaign_%d_fight" % (ch+1)))
  print("CAPTURE chapter ",ch+1)
 # contact sheet of the five fights: 3 x 2 at half size
 var w: int=fights[0].get_width()/2; var hh: int=fights[0].get_height()/2
 var sheet:=Image.create(w*3,hh*2,false,fights[0].get_format())
 for i in range(fights.size()):
  var s: Image=fights[i].duplicate(); s.resize(w,hh)
  sheet.blit_rect(s,Rect2i(0,0,w,hh),Vector2i((i%3)*w,(i/3)*hh))
 sheet.save_png("res://evidence/campaign_sheet.png")
 game._clear_run(); game.queue_free(); await create_timer(.1).timeout
 quit()
