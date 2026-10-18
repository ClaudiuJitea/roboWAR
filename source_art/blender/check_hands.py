"""Two-handed grip check: worst distance (m) between the left glove and its support point on the weapon, per clip,
on every other frame. Run: blender -b --python source_art/blender/check_hands.py  (fails above 5 cm)."""
import bpy, math
from mathutils import Matrix, Vector
import os
B=(0,.22,-.02)  # BLADE_SUPPORT in build_fighters.py
SUPPORT={'aim_blade':None,'slash_1':B,'slash_2':B,'slash_3':B,'chiburi':B,
         'aim_sniper':(0,-.30,-.07),'recoil_sniper':(0,-.30,-.07),'aim_heavy':(-.15,-.17,-.01),'recoil_heavy':(-.15,-.17,-.01),
         'aim':(-.03,-.25,-.06),'recoil':(-.03,-.25,-.06),'aim_rail':(-.02,-.34,-.03),'recoil_rail':(-.02,-.34,-.03),
         'aim_pistol':(-.17,.03,-.05),'recoil_pistol':(-.17,.03,-.05),'aim_cast':None}
# katana clips start and end in the one-handed guard: both hands are on the hilt between these frames
TWO_HANDED={'slash_1':(5,11),'slash_2':(5,11),'slash_3':(6,18),'chiburi':(6,16)}
GUNS=('aim','aim_sniper','aim_heavy','aim_pistol','aim_cast','aim_rail')
only=[x for x in os.environ.get('FIGHTERS','').lower().split(',') if x]
for hero in [h for h in ['bastion','ronin','marshal','nova','hex','kestrel'] if not only or h in only]:
    bpy.ops.wm.open_mainfile(filepath='/home/clau/dev/RoboWar/source_art/blender/%s.blend'%hero)
    sc=bpy.context.scene
    for c in bpy.data.collections:
        if '_Assets' in c.name and c.name not in sc.collection.children: sc.collection.children.link(c)
    rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
    for t in rig.animation_data.nla_tracks: t.mute=True
    glove=next(o for o in bpy.data.objects if o.name.split('.')[0]=='L_glove')
    piece=lambda n: next(o for o in bpy.data.objects if o.name.split('.')[0]==n)
    rglove=piece('R_glove')
    # arm chains: (piece, bone) pairs whose rest distance must survive posing (arm stays in one piece)
    chains=[(('R_glove','R_hand'),('R_wrist_band','R_forearm')),(('R_forearm_plate','R_forearm'),('R_elbow','R_forearm')),(('R_elbow','R_forearm'),('R_upper_arm','R_upper_arm')),
            (('L_glove','L_hand'),('L_wrist_band','L_forearm')),(('L_elbow','L_forearm'),('L_upper_arm','L_upper_arm'))]
    grip=Vector((.56*{'bastion':1.26,'ronin':.96,'hex':.95}.get(hero,1.0),-.15,.64))  # grip_point() in build_fighters.py
    out=[]; worst_r=[0.0,0.0]; worst_pad=[1.0,'']; worst_chain=['']; worst_lift=[0.0,'']; worst_elbow=[-9.0,'']
    for clip,off in SUPPORT.items():
        if clip in ('aim_blade','slash_1','slash_2','slash_3','chiburi') and hero!='ronin': continue  # the katana is Ronin's only
        act=next((a for a in bpy.data.actions if a.name.split('.')[0]==clip),None)
        if not act: continue
        rig.animation_data.action=act
        worst=0
        for f in range(1,27):
            sc.frame_set(f); bpy.context.view_layer.update()
            er=rig.evaluated_get(bpy.context.evaluated_depsgraph_get())
            def M(b): return er.pose.bones[b].matrix@er.data.bones[b].matrix_local.inverted()
            for side in 'LR':
                pad=(M(side+'_shoulder').to_3x3()@Vector((0,0,1))).z  # pauldron top stays facing up
                if pad<worst_pad[0]: worst_pad=[pad,clip]
                if clip in GUNS or clip=='aim_blade':
                    ua=(M(side+'_upper_arm').to_3x3()@(er.data.bones[side+'_upper_arm'].tail_local-er.data.bones[side+'_upper_arm'].head_local)).normalized()
                    lift=math.degrees(ua.angle(Vector((0,0,-1))))
                    if lift>worst_lift[0]: worst_lift=[lift,clip+':'+side]
                    el=(M(side+'_forearm')@er.data.bones[side+'_forearm'].head_local).z-(M(side+'_upper_arm')@er.data.bones[side+'_upper_arm'].head_local).z
                    if el>worst_elbow[0]: worst_elbow=[el,clip]
            if off is not None and TWO_HANDED.get(clip,(0,99))[0]<=f<=TWO_HANDED.get(clip,(0,99))[1]:
                want=M('weapon')@(grip+Vector(off))
                have=M('L_hand')@glove.location
                worst=max(worst,(want-have).length)
            rgap=(M('weapon')@grip-M('R_hand')@rglove.location).length-(grip-rglove.location).length
            worst_r[0]=max(worst_r[0],rgap)
            for (a,ba),(b,bb) in chains:
                pa,pb=piece(a).location,piece(b).location
                st=abs((M(ba)@pa-M(bb)@pb).length-(pa-pb).length)
                if st>worst_r[1]: worst_r[1]=st; worst_chain[:]=[a,b,clip,f]
        if off is not None: out.append('%s=%.2f'%(clip,worst))
    print('HANDS',hero,' '.join(out))
    print('HANDS',hero,'right_hand_off_grip=%.3f arm_stretch=%.3f pauldron_up=%.2f(%s) elbow_over_shoulder=%.2f(%s)'%(worst_r[0],worst_r[1],*worst_pad,*worst_elbow))
    assert worst_pad[0]>(.35 if worst_pad[1].startswith('slash') else .6), (hero,'pauldron tipped over',worst_pad)
    assert worst_elbow[0]<.05, (hero,'elbow raised above the shoulder in a stance',worst_elbow)
    bad=[x for x in out if float(x.split('=')[1])>.05]
    assert not bad, (hero,bad)
    assert worst_r[0]<.05, (hero,'right hand off grip',worst_r[0])
    print('HANDS',hero,'worst stretch at',worst_chain,'upper-arm lift %.0f deg (%s)'%tuple(worst_lift))
    assert worst_lift[0]<75, (hero,'arm raised too high in a stance',worst_lift)
    assert worst_r[1]<.06, (hero,'arm pieces separate',worst_r[1])
print('HANDS PASS')
