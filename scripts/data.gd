extends RefCounted

const HEROES := ["Magnus", "Albert", "Theo", "Iris", "Seren", "Nadia"]
const COLORS := [Color("1678df"), Color("ff6a20"), Color("f4b52a"), Color("19c5d1"), Color("9545cf"), Color("d22b43")]
const HP := [155.0, 135.0, 105.0, 100.0, 108.0, 95.0]
const SPEED := [5.0, 6.2, 6.4, 5.7, 5.9, 5.7]
const DAMAGE := [8.0, 23.0, 17.0, 52.0, 16.0, 55.0]
const RATE := [0.12, 0.34, 0.20, 1.25, 0.38, 0.94]
const SPECIAL_CD := [16.0, 10.0, 14.0, 14.0, 16.0, 13.0]
# Swappable weapons (Q / R, keys 1-7, mouse wheel, pad bumpers). Each has a magazine that reloads automatically when empty. kind: hitscan, rail, rocket, grenade, plasma.
const WEAPONS := [
 {"id":"rifle","stance":"gun","mag":30,"reload":1.4,"name":"RIFLE","kind":"hitscan","rate":.2,"damage":20.0,"pellets":1,"spread":.015,"range":24.0,"pierce":0,"tracer":.03,"color":Color("ffd86a"),"sfx":"rifle","shake":.05,"knock":.6,"shells":true},
 {"id":"smg","stance":"gun","mag":40,"reload":1.6,"name":"SMG","kind":"hitscan","rate":.075,"damage":9.0,"pellets":1,"spread":.09,"range":16.0,"pierce":0,"tracer":.022,"color":Color("8ef0ff"),"sfx":"smg","shake":.025,"knock":.3,"shells":true},
 {"id":"shotgun","stance":"gun","mag":6,"reload":1.8,"name":"SHOTGUN","kind":"hitscan","rate":.72,"damage":10.0,"pellets":9,"spread":.3,"range":10.0,"pierce":0,"tracer":.02,"color":Color("ffa24a"),"sfx":"shotgun","shake":.22,"knock":2.6,"shells":true},
 {"id":"railgun","stance":"sniper","mag":6,"reload":1.8,"name":"RAILGUN","kind":"rail","charge":.3,"rate":.32,"damage":95.0,"range":36.0,"color":Color("6fe8ff"),"sfx":"rail","shake":.3,"knock":3.0},
 {"id":"rocket","stance":"shoulder","mag":1,"reload":.95,"name":"ROCKET","kind":"rocket","rate":1.0,"damage":75.0,"radius":3.4,"speed":26.0,"color":Color("ff6a3c"),"sfx":"rocket","shake":.1,"knock":5.0},
 {"id":"grenade","stance":"gun","mag":8,"reload":2.0,"name":"GRENADE","kind":"grenade","rate":.85,"damage":60.0,"radius":3.0,"range":13.0,"color":Color("9be35a"),"sfx":"grenade","shake":.06,"knock":4.0},
 {"id":"plasma","stance":"gun","mag":40,"reload":1.8,"name":"PLASMA","kind":"plasma","rate":.19,"damage":16.0,"radius":1.1,"speed":32.0,"color":Color("b06cff"),"sfx":"plasma","shake":.03,"knock":.8},
]
const PLAYER_COLORS := [Color("f2c230"), Color("33c6e8")]  # slot 0 = you / P1, slot 1 = partner / P2
# Signature weapons from "The Six" sheet: each operative's weapon 1 (the 7 shared guns follow as 2-8).
const SIGNATURES := [
 {"id":"minigun","stance":"heavy","name":"MINIGUN","kind":"hitscan","mag":150,"reload":2.6,"rate":.055,"damage":8.0,"pellets":1,"spread":.1,"range":17.0,"pierce":0,"tracer":.024,"color":Color("4f9dff"),"sfx":"minigun","shake":.035,"knock":.35,"shells":true,"spin":true},
 {"id":"sword","stance":"blade","name":"PLASMA KATANA","kind":"melee","mag":0,"reload":0.0,"rate":.48,"damage":36.0,"radius":3.2,"arc":1.2,"color":Color("ff8a2a"),"sfx":"sword","shake":.12,"knock":3.0},
 {"id":"pistol","stance":"pistol","name":"SIDEARM","kind":"hitscan","mag":12,"reload":1.0,"rate":.19,"damage":26.0,"pellets":1,"spread":.02,"range":20.0,"pierce":0,"tracer":.03,"color":Color("ffc94a"),"sfx":"pistol","shake":.06,"knock":1.0,"shells":true},
 {"id":"railrifle","stance":"rail","name":"RAIL RIFLE","kind":"rail","mag":8,"reload":1.8,"charge":.4,"rate":.3,"damage":80.0,"range":34.0,"color":Color("3ff0e6"),"sfx":"rail","shake":.25,"knock":2.5},
 {"id":"gauntlet","stance":"cast","name":"ARC GAUNTLETS","kind":"plasma","mag":30,"reload":1.5,"rate":.2,"damage":20.0,"radius":1.3,"speed":30.0,"color":Color("b45cff"),"sfx":"bolt","shake":.03,"knock":1.0},
 {"id":"sniper","stance":"sniper","name":"SNIPER","kind":"hitscan","mag":5,"reload":2.0,"rate":.8,"damage":75.0,"pellets":1,"spread":0.0,"range":36.0,"pierce":2,"tracer":.05,"color":Color("ff4a5a"),"sfx":"sniper","shake":.18,"knock":3.0,"shells":false,"laser":true,"bolt":true},
]

static func loadout(hero_id: int) -> Array:
 return [SIGNATURES[hero_id]] + WEAPONS
# Each operative's right-click move (scripts/specials.gd).
const SPECIALS := ["Bullet Hurricane", "Hundred Cuts", "Dead Eye", "Halo Array", "Singularity", "Orbital Lance"]
# Robots. boss: has phases, a top-of-screen health bar and a name card. hit: body radius for shot tests. body/eye: tint
# applied to the shared enemy kit (null keeps the kit's graphite and ember). ids 0-5 are the original roster.
const ENEMIES := [
 {"name":"Grunt","hp":30.0,"speed":3.0,"damage":10.0,"cadence":1.3,"scale":1.0,"hit":.46,"score":1,"xp":1},
 {"name":"Runner","hp":20.0,"speed":4.4,"damage":7.0,"cadence":1.3,"scale":.8,"hit":.36,"score":1,"xp":1},
 {"name":"Brute","hp":100.0,"speed":2.0,"damage":23.0,"cadence":1.3,"scale":1.35,"hit":.6,"score":2,"xp":3},
 {"name":"Shooter","hp":28.0,"speed":2.6,"damage":9.0,"cadence":2.0,"scale":1.0,"hit":.46,"score":1,"xp":1},
 {"name":"Shield","hp":60.0,"speed":2.55,"damage":12.0,"cadence":1.3,"scale":1.0,"hit":.46,"score":2,"xp":2},
 {"name":"Warden","title":"Dock security chief","boss":true,"hp":1500.0,"speed":2.3,"damage":20.0,"cadence":1.3,"scale":2.15,"hit":1.05,"score":25,"xp":30},
 {"name":"Bomber","hp":18.0,"speed":5.2,"damage":28.0,"cadence":1.0,"scale":.85,"hit":.4,"score":1,"xp":1,"body":Color("c4521f"),"eye":Color("ffb000")},
 {"name":"Mortar","hp":40.0,"speed":2.2,"damage":16.0,"cadence":3.2,"scale":1.1,"hit":.5,"score":2,"xp":2,"body":Color("7d8f45"),"eye":Color("ffd24a")},
 {"name":"Lancer","hp":45.0,"speed":2.4,"damage":22.0,"cadence":3.0,"scale":1.05,"hit":.48,"score":2,"xp":2,"body":Color("3f66b0"),"eye":Color("4ad8ff")},
 {"name":"Medic","hp":35.0,"speed":2.8,"damage":0.0,"cadence":2.6,"scale":.95,"hit":.44,"score":2,"xp":2,"body":Color("eef1f4"),"eye":Color("3aff9a")},
 {"name":"Splitter","hp":70.0,"speed":2.8,"damage":12.0,"cadence":1.3,"scale":1.2,"hit":.55,"score":2,"xp":2,"body":Color("8c3fa3"),"eye":Color("ff5ad8")},
 {"name":"Forge Titan","title":"The molten hand","boss":true,"hp":2200.0,"speed":2.0,"damage":28.0,"cadence":1.0,"scale":2.5,"hit":1.2,"score":30,"xp":30,"body":Color("9a3a18"),"eye":Color("ff7a1a")},
 {"name":"Hive Mother","title":"Queen of the swarm","boss":true,"hp":2000.0,"speed":2.4,"damage":16.0,"cadence":1.0,"scale":2.3,"hit":1.1,"score":30,"xp":30,"body":Color("67802c"),"eye":Color("c6ff3a")},
 {"name":"Lancer Prime","title":"The burning line","boss":true,"hp":2100.0,"speed":2.8,"damage":24.0,"cadence":1.0,"scale":2.2,"hit":1.05,"score":30,"xp":30,"body":Color("2f5596"),"eye":Color("3ae8ff")},
 {"name":"Overseer","title":"Mind of Meridian","boss":true,"hp":3600.0,"speed":2.4,"damage":24.0,"cadence":1.0,"scale":2.7,"hit":1.25,"score":60,"xp":30,"body":Color("4a2a70"),"eye":Color("c050ff")},
]
const ELITE_COLOR := Color("ffc83a")

static func enemy_name(id: int) -> String:
 return String(ENEMIES[id].name)

# Environments: menu name and description, HUD accent, whether the HUD uses its dark palette there, and the Survival boss.
const ARENA_ORDER := ["white","black","cryo","toxic","core"]
const ARENAS := {
 "white":{"accent":Color("3a6df0"),"name":"SECTOR 03","desc":"Docks, white deck","dark":false,"boss":5},
 "black":{"accent":Color("e8283a"),"name":"SECTOR 07","desc":"Assembly, black and red","dark":true,"boss":11},
 "cryo":{"accent":Color("2aa8d8"),"name":"CRYO VAULT 11","desc":"Frozen vault, pillars","dark":false,"boss":12},
 "toxic":{"accent":Color("8fe02a"),"name":"REFINERY 19","desc":"Acid lanes, tanks","dark":true,"boss":13},
 "core":{"accent":Color("b05cff"),"name":"THE CORE 00","desc":"Reactor ring, open","dark":true,"boss":14},
}

# Timed power-ups dropped by robots (elites always drop one, bosses several). time 0 = instant.
const POWERUPS := {
 "health":{"name":"REPAIR","glyph":"+","color":Color("3ae6ae"),"time":0.0},
 "overcharge":{"name":"OVERCHARGE","glyph":"DMG","color":Color("ff7a2a"),"time":10.0},
 "rapid":{"name":"RAPID FIRE","glyph":"ROF","color":Color("ffd23a"),"time":10.0},
 "barrier":{"name":"BARRIER","glyph":"SHD","color":Color("3ac8ff"),"time":12.0},
 "surge":{"name":"SURGE","glyph":"SP","color":Color("b06cff"),"time":0.0},
 "haste":{"name":"HASTE","glyph":"SPD","color":Color("e8f4ff"),"time":10.0},
}
const TIMED_BUFFS := ["overcharge","rapid","barrier","haste"]

const UPGRADES := [
 {"name":"Reinforced plating", "desc":"Max health +25, heal 25", "key":"health", "value":25.0, "cap":5},
 {"name":"Servo boost", "desc":"Movement speed +10%", "key":"speed", "value":0.10, "cap":4},
 {"name":"Sharpened payload", "desc":"Primary damage +15%", "key":"damage", "value":0.15, "cap":5},
 {"name":"Fast cycling", "desc":"Attack interval -10%", "key":"rate", "value":0.10, "cap":4},
 {"name":"Rapid recharge", "desc":"Special cooldown -13%", "key":"special", "value":0.13, "cap":4},
 {"name":"Evasive hydraulics", "desc":"Dodge cooldown -15%", "key":"dodge", "value":0.15, "cap":4},
 {"name":"Ceramic weave", "desc":"Incoming damage -8%", "key":"armor", "value":0.08, "cap":4},
 {"name":"Vitality capacitor", "desc":"Heal 35 at every wave", "key":"regen", "value":35.0, "cap":2},
 {"name":"High voltage", "desc":"Special damage +20%", "key":"ability_damage", "value":0.20, "cap":4},
 {"name":"Overpenetration", "desc":"Primary shots pierce one more target", "key":"pierce", "value":1.0, "cap":3},
 {"name":"Coolant loop", "desc":"Railgun charges 15% faster", "key":"heat", "value":0.15, "cap":4},
 {"name":"Medical reserve", "desc":"Revives restore 20 more health", "key":"revive", "value":20.0, "cap":3},
 {"name":"Scavenger", "desc":"Power-ups drop 40% more often and last 40% longer", "key":"scavenger", "value":0.40, "cap":2},
 {"name":"Vampiric rounds", "desc":"Heal 2 for every robot you destroy", "key":"vampiric", "value":2.0, "cap":3},
 {"name":"Volatile salvage", "desc":"Robots you destroy burst for 18 damage", "key":"volatile", "value":18.0, "cap":3},
 {"name":"Critical optics", "desc":"+10% chance to land a critical hit (x1.5)", "key":"crit", "value":0.10, "cap":3},
 {"name":"Blast dodge", "desc":"Dodging releases a 25 damage shockwave", "key":"blast_dodge", "value":25.0, "cap":3},
]

static func upgrade_value(actor: Node, key: String) -> float:
 return float(actor.upgrades.get(key, 0))
