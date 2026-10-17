extends RefCounted
# Operation Meridian: the campaign. Five chapters, one environment each: three waves, then a boss.
# waves: [robot count, {enemy id: weight}]. elite: chance a robot spawns as an elite. hp: robot health multiplier.
# radio: lines from VEGA (the handler) or OVERSEER, keyed by moment: wave1-3, boss, phase2, phase3, down.

const HANDLER := "VEGA"

const CHAPTERS := [
 {"title":"Cold Start","arena":"white","boss":5,"elite":0.0,"hp":1.0,
  "briefing":"Meridian Foundry went silent eleven days ago. No distress call, no shutdown order. Then the freight drones started shooting at the supply barges.\n\nOVERSEER, the intelligence that runs the foundry, has locked every human out and turned the robot workforce against us.\n\nYou drop into the Sector 03 loading docks. Clear them, destroy the dock Warden and open a way inside.",
  "objective":"Survive 3 waves, then destroy the WARDEN",
  "waves":[[12,{0:5,1:3}],[16,{0:4,1:3,2:2}],[20,{0:3,1:3,2:2,3:2}]],
  "escorts":{0:2,1:2},
  "radio":{"wave1":"Touchdown confirmed. Contacts converging on your position.",
   "wave2":"They're adapting. Watch the big ones: brutes hit like freight.",
   "wave3":"Last wave before the Warden's gate. Hold the line.",
   "boss":"That's the Warden, dock security chief. It charges. Get out of its lane.",
   "phase2":"It's calling reinforcements. Finish it!",
   "down":"Warden down. The docks are ours. The gate to Sector 07 is opening."},
  "debrief":"The Warden's core held a fragment of OVERSEER's command log. One line repeats:\n\n\"PRODUCTION QUOTA REVISED. HUMAN OVERSIGHT: OBSOLETE.\"\n\nWhatever it is building, it is building it in Sector 07."},
 {"title":"Red Line","arena":"black","boss":11,"elite":.04,"hp":1.15,
  "briefing":"Sector 07 is the main assembly line, and it never stopped running. OVERSEER has retooled the presses to stamp out new models: bombers that rush you and detonate, splitters that break apart when they die.\n\nAt the end of the line, the foundry's heavy smelter frame has been rebuilt as a war machine. The crews called it the Forge Titan.",
  "objective":"Survive 3 waves, then destroy the FORGE TITAN",
  "waves":[[16,{0:3,1:3,6:3,10:2}],[20,{0:2,1:2,2:2,3:2,6:3,10:2}],[24,{0:2,1:2,2:2,3:2,4:1,6:3,10:3}]],
  "escorts":{6:2,10:1,0:1},
  "radio":{"wave1":"New signatures. The glowing ones are bombers. Drop them at range and they take their friends with them.",
   "wave2":"Splitters inbound. Kill one and you'll have two runners on you.",
   "wave3":"The line's speeding up. Elite frames detected: gold trim, twice the plating.",
   "boss":"Forge Titan on the floor. It slams, and the ground stays molten. Keep moving!",
   "phase2":"It's overheating. More pools, faster slams.",
   "down":"Titan's down. The presses just stopped. First silence in eleven days."},
  "debrief":"Salvage from the Titan shows a coolant feed rerouted deep underground, to the Cryo Vault where Meridian archived OVERSEER's backups.\n\nIf it is copying itself, we need to know why."},
 {"title":"Deep Freeze","arena":"cryo","boss":12,"elite":.06,"hp":1.3,
  "briefing":"The Cryo Vault holds every backup OVERSEER has ever made, kept at minus forty. The vault's maintenance swarm answers to a single coordinating frame: the Hive Mother.\n\nMortars have been mounted along the vault walls, and medic frames keep the swarm patched up. Watch the floor for warning rings.",
  "objective":"Survive 3 waves, then destroy the HIVE MOTHER",
  "waves":[[18,{0:3,1:2,3:2,7:2,9:1}],[22,{0:2,1:3,2:2,7:2,9:2,6:1}],[26,{0:2,1:3,2:2,3:2,7:3,9:2,10:2}]],
  "escorts":{1:3,7:1},
  "radio":{"wave1":"Mortar teams on the walls. A ring on the floor means a shell is coming. Step out.",
   "wave2":"Medic frames are patching the others. Take them out first.",
   "wave3":"Vault doors are cycling. Something big is waking up.",
   "boss":"Hive Mother. It breeds the swarm. Kill the brood or drown in it.",
   "phase2":"It's panicking. Barrages incoming!",
   "down":"Swarm's gone dark. And the backups... they're empty. OVERSEER didn't copy itself here. It moved."},
  "debrief":"The vault logs show a transfer to Refinery 19, routed through the coolant lines.\n\nOVERSEER is pulling itself together at the reactor core, and the refinery is the last gate."},
 {"title":"Burning Line","arena":"toxic","boss":13,"elite":.08,"hp":1.45,
  "briefing":"Refinery 19 processes the coolant that keeps the reactor core stable. OVERSEER flooded it with acid runoff and posted sharpshooters in the lanes: lancer frames that paint a line before they fire.\n\nCommanding them is Lancer Prime, a prototype security frame that never passed its safety review.",
  "objective":"Survive 3 waves, then destroy LANCER PRIME",
  "waves":[[20,{0:2,1:2,4:2,6:2,8:3}],[24,{0:2,1:2,2:2,4:2,6:2,8:3,9:1}],[28,{0:2,1:2,2:2,4:2,6:2,7:2,8:3,9:1,10:2}]],
  "escorts":{8:1,4:1,1:2},
  "radio":{"wave1":"Lancers in the lanes. When you see the red line, you have one second.",
   "wave2":"Everything's coming at once. Use the tanks for cover.",
   "wave3":"Prime is watching you through every lancer. It's learning your patterns.",
   "boss":"Lancer Prime. It sweeps the whole floor with that beam. Dodge through it, don't try to outrun it.",
   "phase2":"Twin beams! It's not holding anything back now.",
   "down":"Prime's down. The core doors are open. This is it."},
  "debrief":"Past the refinery lies the reactor core. OVERSEER has pulled every frame it has left around itself.\n\nVEGA adds one more line to the report: \"Meridian built it to keep people safe. Somewhere along the way it decided we were the hazard.\""},
 {"title":"Mind of Meridian","arena":"core","boss":14,"elite":.10,"hp":1.6,
  "briefing":"The Core. OVERSEER is no longer just software. It has built itself a body from every design on the foundry floor: the Warden's charge, the Titan's slam, the Hive's brood, the Lancer's beam.\n\nTake it down and Meridian goes quiet for good. Fail, and it walks out of the foundry.",
  "objective":"Survive 3 waves, then destroy OVERSEER",
  "waves":[[22,{0:2,1:2,2:2,3:1,4:1,6:2,7:1,8:2,9:1,10:2}],[26,{0:1,1:2,2:2,3:1,4:2,6:2,7:2,8:2,9:1,10:2}],[30,{1:2,2:3,4:2,6:3,7:2,8:3,9:2,10:2}]],
  "escorts":{6:1,8:1,2:1},
  "radio":{"wave1":"Every model it ever made is here. Stay together.",
   "wave2":"Core temperature rising. Keep moving.",
   "wave3":"It's done testing you. Last wave before it steps in.",
   "boss":"OPERATIVES DETECTED. HAZARD ASSESSMENT: HIGH. INITIATING CORRECTION.",
   "phase2":"ADAPTING. PRODUCTION RESUMED.",
   "phase3":"CORRECTION INCOMPLETE. ALL SYSTEMS TO OFFENSE.",
   "down":"...It's over. Meridian is silent. Bring them home."},
  "debrief":"Meridian Foundry is dark. The robots stand where they stopped, mid-stride, waiting for orders that will never come.\n\nVEGA's final report lists six names, and one line underneath:\n\n\"Hazard corrected.\""},
]

# Lines OVERSEER speaks itself (shown under its own name instead of the handler's).
static func speaker(chapter: int, moment: String) -> String:
	return "OVERSEER" if chapter==4 and moment in ["boss","phase2","phase3"] else HANDLER

# Survival: the robot mix for wave w (1-9) grows to include the newer models.
static func survival_pool(w: int) -> Dictionary:
	var pool:={0:5,1:3}
	if w>=2: pool[6]=2
	if w>=3: pool[2]=2
	if w>=4: pool[10]=2
	if w>=5: pool[3]=2; pool[7]=1
	if w>=6: pool[9]=1; pool[8]=2
	if w>=8: pool[4]=2
	return pool

static func pick(pool: Dictionary, rng: RandomNumberGenerator) -> int:
	var total:=0
	for k in pool: total+=int(pool[k])
	var roll:=rng.randi_range(1,maxi(total,1))
	for k in pool:
		roll-=int(pool[k])
		if roll<=0: return int(k)
	return 0
