"""Reproducible Sector 03 hero generator.

Run headless:  blender -b -t 4 --factory-startup --python source_art/blender/build_fighters.py
Or execute through the Blender MCP add-on: each fighter is built in its own Fighter_<Name> scene,
so the scene open in the GUI is left alone.
"""
import bpy, bmesh, math, os
from mathutils import Euler, Matrix, Quaternion, Vector
try:
    HERE = os.path.dirname(os.path.abspath(__file__))
except NameError:
    HERE = '/home/clau/dev/RoboWar/source_art/blender'
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
OUT = os.path.join(ROOT, 'assets', 'models')
import sys; sys.path.insert(0, HERE)
from caster_hand import caster_hand
os.makedirs(OUT, exist_ok=True)
if bpy.app.background: bpy.ops.wm.read_factory_settings(use_empty=True)
HEROES = [('Bastion',(0.035,0.26,0.75)),('Ronin',(0.98,0.25,0.035)),('Marshal',(0.95,0.58,0.025)),('Nova',(0.015,0.66,0.72)),('Hex',(0.42,0.12,0.75)),('Kestrel',(0.68,0.025,0.07))]
ACTIVE_COLLECTION=None
BULK={'Bastion':1.26,'Ronin':.96,'Hex':.95}
def grip_point(name):
    # weapon grip = centre of the right fist at rest (arms down); weapons.glb guns have their origin here
    return Vector((.56*BULK.get(name,1.0),-.15,.64))

def in_project_collection(obj):
    for old in list(obj.users_collection): old.objects.unlink(obj)
    ACTIVE_COLLECTION.objects.link(obj)

def mat(name, color, metal=0.0, rough=.48, emit=0):
    m=bpy.data.materials.get(name) or bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*color,1); p.inputs['Metallic'].default_value=metal; p.inputs['Roughness'].default_value=rough
    if emit: p.inputs['Emission Color'].default_value=(*color,1); p.inputs['Emission Strength'].default_value=emit
    return m
white=mat('ceramic_off_white',(.80,.77,.70),.0,.42)
dark=mat('graphite_undersuit',(.022,.025,.03),.15,.55)
black=mat('black_visor',(.012,.023,.037),.28,.19)
metal=mat('gunmetal',(.12,.16,.20),.7)
trim=mat('panel_edges',(.62,.60,.55),.1,.5)

def _object(name, bm, loc, material):
    """Wrap a bmesh in a new smooth-shaded object. Data API only, so it is safe to run over MCP in the GUI."""
    me=bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    for p in me.polygons: p.use_smooth=True
    me.materials.append(material)
    o=bpy.data.objects.new(name,me); o.location=loc
    ACTIVE_COLLECTION.objects.link(o)
    o.modifiers.new('Weighted normals','WEIGHTED_NORMAL').keep_sharp=True
    return o

def cube(name, loc, scale, material, bevel=.035):
    bm=bmesh.new(); bmesh.ops.create_cube(bm,size=1.0)
    bmesh.ops.scale(bm,vec=scale,verts=bm.verts)
    if bevel:
        bmesh.ops.bevel(bm,geom=list(bm.verts)+list(bm.edges),offset=min(bevel,min(scale)*.45),segments=3,
                        affect='EDGES',profile=.5,clamp_overlap=True)
    return _object(name,bm,loc,material)

def cyl(name, loc, radius, depth, material, vertices=12, axis='Y'):
    bm=bmesh.new()
    bmesh.ops.create_cone(bm,cap_ends=True,segments=vertices,radius1=radius,radius2=radius,depth=depth)
    if axis=='Y': bmesh.ops.rotate(bm,verts=bm.verts,cent=(0,0,0),matrix=Matrix.Rotation(math.pi/2,3,'X'))
    elif axis=='X': bmesh.ops.rotate(bm,verts=bm.verts,cent=(0,0,0),matrix=Matrix.Rotation(math.pi/2,3,'Y'))
    o=_object(name,bm,loc,material)
    # cylinders keep hard caps: only side faces are smooth
    for p in o.data.polygons: p.use_smooth=len(p.vertices)==4
    return o

# ---------------------------------------------------------------------------------------------------------------
# Arm posing. Every hold is described by where the weapon is (grip point, barrel/blade direction, up or edge
# direction, Blender model space, front = -Y) plus a few body angles; the arms are then solved analytically:
# elbows are hinges, each elbow bends toward a pole direction (no free upper-arm twist), the right hand holds the
# weapon (the weapon bone never moves in the fist), the left glove sits on the weapon's support point, and the
# chest blades (turns) just enough for both hands to reach, with the head turned back to keep facing the target.
# Shoulder pauldrons ride on their own bones and follow the upper arm only part of the way, so they never flip.
# Motions are keyed as such holds and solved on every frame, so the hands never drift between keys.
# ---------------------------------------------------------------------------------------------------------------
SHOULDER_FOLLOW=.30
CHEST_TURN_MAX=18  # automatic chest turn limit, in 0.02 rad steps (0.36 rad, about 20 degrees)
DEFAULT_RPOLE=(.8,.45,-1.0)
DEFAULT_LPOLE=(-.8,.45,-1.0)

def hold(grip, dirv=(0,-1,0), up=(0,0,1), edge=None, body=None, support=None, left=None, rpole=DEFAULT_RPOLE, lpole=DEFAULT_LPOLE):
    """A weapon hold. grip: right-fist grip point; dirv: barrel/blade direction; up: weapon top (guns, no cant);
    edge: cutting-edge direction (katana, replaces up); support: left-glove point in weapon space (relative to the
    grip, weapon rest axes); left: free left-glove target when the weapon is one-handed; body: bone -> euler."""
    return {'grip':Vector(grip),'dir':Vector(dirv).normalized(),'up':Vector(edge if edge is not None else up).normalized(),
            'edge':edge is not None,'body':dict(body or {}),'support':Vector(support) if support is not None else None,
            'left':Vector(left) if left is not None else None,'rpole':Vector(rpole),'lpole':Vector(lpole)}

def moved(h, grip=(0,0,0), pitch=0.0, yaw=0.0, roll=0.0, body=None, support=None, left=None):
    """Copy of hold h, offset: grip moved by `grip`, weapon pitched (+ = muzzle up), yawed (+ = toward the fighter's
    right, +X) and rolled about its own axis (+ = top toward the left), body angles added, support/left optionally replaced."""
    out=dict(h); out['body']=dict(h['body'])
    out['grip']=h['grip']+Vector(grip)
    d=h['dir']; u=h['up']
    side=d.cross(Vector((0,0,1)))
    if side.length<1e-4: side=Vector((1,0,0))
    side.normalize()
    rot=Matrix.Rotation(pitch,3,side) if pitch else Matrix.Identity(3)
    rot=Matrix.Rotation(yaw,3,'Z')@rot
    d=rot@d; u=rot@u
    if roll: u=Matrix.Rotation(roll,3,d)@u
    out['dir']=d.normalized(); out['up']=u.normalized()
    for b,e in (body or {}).items():
        o=out['body'].get(b,(0,0,0)); out['body'][b]=(o[0]+e[0],o[1]+e[1],o[2]+e[2])
    if support is not None: out['support']=Vector(support)
    if left is not None: out['left']=Vector(left)
    return out

def blend_hold(a, b, t):
    def nl(x,y):
        v=x.lerp(y,t)
        return v.normalized() if v.length>1e-5 else y.copy()
    out={'grip':a['grip'].lerp(b['grip'],t),'dir':nl(a['dir'],b['dir']),'up':nl(a['up'],b['up']),'edge':b['edge'],
         'rpole':nl(a['rpole'],b['rpole']),'lpole':nl(a['lpole'],b['lpole']),'body':{}}
    for k in set(a['body'])|set(b['body']):
        x=a['body'].get(k,(0,0,0)); y=b['body'].get(k,(0,0,0)); out['body'][k]=tuple(p+(q-p)*t for p,q in zip(x,y))
    if (a['support'] is None)!=(b['support'] is None):
        # free hand <-> two-handed grip (e.g. Ronin's one-handed guard into a two-handed cut): move the glove
        # between the two absolute points, and take the grip exactly at the two-handed key
        pa=a['left'] if a['support'] is None else a['grip']+weapon_frame(a)@a['support']
        pb=b['left'] if b['support'] is None else b['grip']+weapon_frame(b)@b['support']
        if t>=1.0 and b['support'] is not None: out['support']=b['support'].copy(); out['left']=None
        else: out['support']=None; out['left']=pa.lerp(pb,t)
        return out
    for k in ('support','left'):
        x,y=a[k],b[k]
        out[k]=x.lerp(y,t) if (x is not None and y is not None) else (y if t>.5 else x)
    return out

def weapon_frame(h):
    """3x3 rotation of the weapon from its rest orientation (barrel -Y, top +Z, katana edge -X)."""
    y=-h['dir']
    if h['edge']:
        e=h['up']-y*h['up'].dot(y)
        if e.length<1e-4: e=Vector((0,0,-1))-y*(-y.z)
        x=-e.normalized(); z=x.cross(y)
    else:
        z=h['up']-y*h['up'].dot(y)
        if z.length<1e-4: z=Vector((0,0,1))
        z.normalize(); x=y.cross(z)
    m=Matrix((x,y,z)).transposed()
    return m

class Poser:
    """Analytic posing for one fighter rig (see the block comment above)."""
    ARM=('upper_arm','forearm','hand')

    def __init__(self, arm, objs, name):
        self.arm=arm; self.name=name
        self.loc={o.name.split('.')[0]:o.location.copy() for o in objs}
        self.rest={b.name:b.matrix_local.copy() for b in arm.data.bones}
        self.g0=grip_point(name)
        for pb in arm.pose.bones: pb.rotation_mode='XYZ'
        # Natural grip: in the rest pose the gun points forward while the forearm hangs down (a 90 degree wrist).
        # Turn the fist so the forearm runs behind the grip, forward and slightly up and in; the weapon bone takes
        # the opposite turn about the grip point, so the weapon itself is unaffected and stays in the fist.
        W0=self.head('R_hand'); E0=self.head('R_forearm')
        f0=(W0-E0).normalized()
        self.fore_dir=Vector((-.2,-.92,.22)).normalized()  # forearm (elbow -> wrist) in weapon space
        self.hoff=f0.rotation_difference(self.fore_dir).to_matrix()
        self.side={}
        for s in ('L','R'):
            S0=self.head(s+'_upper_arm'); E0=self.head(s+'_forearm'); W0=self.head(s+'_hand')
            end=W0 if s=='R' else self.loc['L_glove']  # right: wrist (hand turns with the weapon); left: glove, straight wrist
            a0=(E0-S0).normalized()
            h0=a0.cross(Vector((0,-1,0))).normalized()  # elbow hinge: flexing swings the forearm forward
            if ((Matrix.Rotation(.3,3,h0)@(end-E0))-(end-E0)).y>0: h0=-h0
            self.side[s]=dict(S0=S0,E0=E0,W0=W0,P0=end,h0=h0,L1=(E0-S0).length)
            # forearm flex samples: distance shoulder->end as a function of the hinge angle
            samples=[]
            for i in range(0,281):
                th=-.15+i*.01
                p=E0+Matrix.Rotation(th,3,h0)@(end-E0)
                samples.append((th,(p-S0).length))
            self.side[s]['samples']=samples
            self.side[s]['reach']=max(d for _,d in samples)

    def head(self, b): return self.rest[b].to_translation()

    def P(self, b):  # armature-space transform of a posed bone relative to rest
        return self.arm.pose.bones[b].matrix@self.rest[b].inverted()

    def _chest_P(self, chest_euler):
        """Chest transform for a chest rotation, with the spine as currently posed (no depsgraph update)."""
        r=self.rest['chest']
        return self.P('spine')@r@Euler(chest_euler,'XYZ').to_matrix().to_4x4()@r.inverted()

    def _arm_targets(self, h, Rw):
        s=self.side['R']
        wrist=h['grip']+Rw@self.hoff@(s['W0']-self.g0)
        left=h['grip']+Rw@h['support'] if h['support'] is not None else h['left']
        return wrist,left

    def _ratios(self, C, wrist, left):
        out=[]
        for s,t in (('R',wrist),('L',left)):
            if t is None: continue
            out.append(((t-C@self.side[s]['S0']).length)/self.side[s]['reach'])
        return max(out) if out else 0.0

    def _solve_arm(self, s, C3, S, T, pole):
        """Two-bone hinge IK. Returns (upper-arm rotation, forearm rotation, elbow position, end position)."""
        d=self.side[s]
        e=C3@(d['E0']-d['S0']); h=C3@d['h0']; tail=C3@(d['P0']-d['E0'])
        want=min((T-S).length, d['reach']*.999)
        # hinge angle: the most-flexed solution is never needed; take the first sample from straight that fits
        best=None
        for th,dist in d['samples']:
            if best is None or abs(dist-want)<abs(best[1]-want): best=(th,dist)
        th=best[0]
        fore=Matrix.Rotation(th,3,h)
        v=e+fore@tail  # shoulder->end with the elbow flexed, before swinging the arm
        u=(T-S).normalized() if (T-S).length>1e-5 else v.normalized()
        q=v.normalized().rotation_difference(u).to_matrix()
        # swivel about the shoulder->hand line so the elbow points along the pole
        el=q@e
        el_p=el-u*el.dot(u); po=pole-u*pole.dot(u)
        if el_p.length>1e-4 and po.length>1e-4:
            ang=el_p.normalized().angle(po.normalized())
            if el_p.normalized().cross(po.normalized()).dot(u)<0: ang=-ang
            q=Matrix.Rotation(ang,3,u)@q
        up=q@C3; fo=q@fore@C3
        E=S+q@e
        return up,fo,E,S+q@v

    def _set(self, b, R3, head):
        r=self.rest[b]
        M=Matrix.Translation(head)@R3.to_4x4()@Matrix.Translation(-r.to_translation())@r
        pb=self.arm.pose.bones[b]; pb.matrix=M
        bpy.context.view_layer.update()

    def solve(self, h):
        arm=self.arm
        for pb in arm.pose.bones: pb.rotation_euler=(0,0,0); pb.location=(0,0,0); pb.scale=(1,1,1)
        body=dict(h['body'])
        for b,e in body.items():
            if b!='chest': arm.pose.bones[b].rotation_euler=e
        bpy.context.view_layer.update()
        Rw=weapon_frame(h)
        wrist,left=self._arm_targets(h,Rw)
        # blade the chest just enough for both hands to reach (smallest extra turn), visor kept on target
        base=Vector(body.get('chest',(0,0,0)))
        extra=0.0
        if self._ratios(self._chest_P(base),wrist,left)>.95:
            cands=sorted((i*.02 for i in range(-CHEST_TURN_MAX,CHEST_TURN_MAX+1)),key=abs)
            best=(9,0.0)
            for dy in cands:
                r=self._ratios(self._chest_P(base+Vector((0,dy,0))),wrist,left)
                if r<=.95: best=(r,dy); break
                if r<best[0]: best=(r,dy)
            extra=best[1]
        self.last_turn=extra
        chest=base+Vector((0,extra,0))
        arm.pose.bones['chest'].rotation_euler=chest
        if extra:
            hd=Vector(arm.pose.bones['head'].rotation_euler); hd.y-=extra*.85; arm.pose.bones['head'].rotation_euler=hd
        bpy.context.view_layer.update()
        C=self.P('chest'); C3=C.to_3x3()
        out={}
        for s,T,pole in (('R',wrist,h['rpole']),('L',left,h['lpole'])):
            S=C@self.side[s]['S0']
            if T is None:
                continue
            if s=='R':  # aim the elbow where the forearm would run straight into the wrist (no bent wrist)
                ideal=wrist-Rw@self.fore_dir*(self.side['R']['W0']-self.side['R']['E0']).length
                pole=(ideal-S).normalized()*2.0+pole*.25
            up,fo,E,end=self._solve_arm(s,C3,S,T,pole)
            rel=(C3.inverted()@up).to_quaternion()
            pad=C3@Quaternion().slerp(rel,SHOULDER_FOLLOW).to_matrix()
            self._set(s+'_shoulder',pad,S)
            self._set(s+'_upper_arm',up,S)
            self._set(s+'_forearm',fo,E)
            if s=='R':
                self._set('R_hand',Rw@self.hoff,E+fo@(self.side['R']['W0']-self.side['R']['E0']))
                self._set('weapon',Rw,self.P('R_hand')@self.g0)  # weapon turns back about the grip in the fist
            else:
                self._set('L_hand',fo,E+fo@(self.side['L']['W0']-self.side['L']['E0']))
        for pb in arm.pose.bones:
            out[pb.name]=tuple(pb.rotation_euler)
            pb.location=(0,0,0)
        for pb in arm.pose.bones: pb.rotation_euler=(0,0,0); pb.scale=(1,1,1)
        bpy.context.view_layer.update()
        return out

def bake(poser, keys):
    """keys: [(frame, hold)] -> [(frame, pose)] solved on every frame, eased between keys."""
    keys=sorted(keys,key=lambda k:k[0])
    out=[]
    for f in range(keys[0][0],keys[-1][0]+1):
        for (f0,a),(f1,b) in zip(keys,keys[1:]):
            if f0<=f<=f1: break
        else:
            (f0,a),(f1,b)=keys[0],keys[0]
        t=0.0 if f1==f0 else (f-f0)/(f1-f0)
        t=t*t*(3-2*t)
        out.append((f,poser.solve(blend_hold(a,b,t))))
    return out

MG_HANDLE=(0,-.221,.39)  # left glove on the machine gun's carry handle (weapons.glb W_minigun)

def gun_stance_clips(poser, name):
    """Weapon-class stances plus stance-relative recoil and reload, all solved as holds."""
    k=BULK.get(name,1.0)
    # Holds follow "The Six" sheet: weapons carried low and forward, hands away from the body, elbows out,
    # torso close to square (the automatic chest turn is capped at CHEST_TURN_MAX).
    out_l=(-1,.15,-.55)   # support elbow out to the side, not tucked into the ribs
    stances={
        # shared rifles: shouldered at chest height (clearly above the heavy hip carry), support hand on the fore-end
        'gun':hold((.10*k,-.36,1.20),support=(-.03,-.25,-.06),body={'chest':(.05,0,0)},lpole=out_l),
        # grenade launcher: shouldered like the rifles, support hand out on the vertical foregrip ahead of the drum
        'launcher':hold((.10*k,-.26,1.18),support=(-.03,-.55,-.09),body={'chest':(.06,0,0)},lpole=out_l),
        # cheek weld: scope (31 cm over the grip) at the visor, stock in the shoulder, right elbow raised
        'sniper':hold((.08,-.30,1.31),support=(0,-.30,-.07),body={'chest':(.05,0,0),'head':(.10,0,0)},rpole=(1,.25,-.15),lpole=out_l),
        # Nova: long rail rifle at the hip, support hand far out along the barrel, leaning into it
        'rail':hold((.12*k,-.32,1.06),support=(-.02,-.34,-.03),body={'chest':(.08,0,0),'spine':(.04,0,0)},lpole=(-1,.05,-.35)),
        # Marshal: two-handed pro grip, arms extended, pistol just under the eye line; support glove wraps the grip
        'pistol':hold((.07,-.58,1.40),support=(-.17,.03,-.05),body={'chest':(.03,0,0),'head':(.03,0,0)},rpole=(.9,.3,-.8),lpole=(-.9,.3,-.8)),
        # Bastion: belt-fed machine gun low at the hip, off hand gripping the carry handle, leaning forward into it
        'heavy':hold((.20*k,-.26,.90),support=MG_HANDLE,body={'chest':(.06,0,0),'spine':(.05,0,0)},
                     rpole=(.35,.45,-1),lpole=(-.35,.45,-1)),  # elbows down by the sides: braced, not flared
        # rocket launcher on the right shoulder: tube on the pauldron (centre 1.74 m, beside the visor), right hand on
        # the rear grip, left hand on the forward grip, chest turned a little side-on so the left arm reaches
        'shoulder':hold((.45*k,-.32,1.616),support=(0,-.38,-.09),body={'chest':(0,.30,0),'head':(0,-.26,0)},
                        rpole=(.6,.3,-1),lpole=(-.3,.3,-1)),
        # Hex: right hand forward, palm up under her holo panel; left hand low and out, its palm glowing
        'cast':hold((.26*k,-.44,1.12),up=(1,0,0),body={'chest':(.03,0,0)},left=(-.58*k,-.22,.78),lpole=(-.3,.4,-1)),
    }
    clips={}
    for key,base in stances.items():
        br=moved(base,grip=(0,0,.008),body={'chest':(.015,0,0),'head':(-.015,0,0)})
        clips['aim_'+key]=bake(poser,[(1,base),(30,br),(60,base)])
        print('STANCE',name,key,'chest turn %.2f'%poser.last_turn)
        kick=moved(base,grip=(0,.05,.01),pitch=.10,body={'chest':(-.06,0,0)})
        if key=='sniper':
            # heavy kick, settle, then cycle the bolt: rifle canted, head lifted off the scope, back on target
            kick=moved(base,grip=(0,.08,.03),pitch=.22,body={'chest':(-.14,0,0),'head':(-.10,0,0),'spine':(-.04,0,0)})
            cant=moved(base,grip=(0,.04,-.04),pitch=.05,roll=-.35,body={'head':(-.14,0,0)})
            keys=[(1,base),(3,kick),(7,base),(10,cant),(14,cant),(19,base)]
        elif key=='heavy':
            keys=[(1,base),(2,moved(base,grip=(0,.02,0),pitch=.04,body={'chest':(-.04,0,0)})),(4,base)]
        elif key=='pistol':
            keys=[(1,base),(2,moved(base,grip=(0,.06,.04),pitch=.32,body={'chest':(-.04,0,0)})),(6,base)]
        elif key=='cast':
            keys=[(1,base),(3,moved(base,grip=(0,-.10,.02),left=base['left']+Vector((0,.06,-.02)),body={'chest':(.06,-.08,0)})),(7,base)]
        else:
            keys=[(1,base),(2,kick),(6,base)]
        clips['recoil_'+key]=bake(poser,keys)
        if key=='shoulder':  # lower the tube off the shoulder to chest height, hold while reloading, shoulder it again
            low=moved(base,grip=(-.05,.06,-.32),pitch=.18,body={'chest':(.06,0,0)})
            clips['reload_shoulder']=bake(poser,[(1,base),(6,low),(18,low),(24,base)])
            continue
        # reload: tip the weapon down and in, off hand to the magazine well, seat it, back to the fore-end
        down=moved(base,grip=(-.06,.08,-.08),pitch=-.45,yaw=-.25,roll=.25,body={'chest':(.08,0,0),'head':(.18,0,0)})
        if key=='pistol':  # fresh magazine into the bottom of the grip
            mag=moved(down,support=(-.02,.06,-.24))
            seat=moved(down,grip=(0,0,.02),support=(-.02,.06,-.15))
        elif key=='heavy':  # fresh belt box: off hand down to the ammo box, then back up
            mag=moved(down,support=(-.08,-.22,-.06))
            seat=moved(down,grip=(0,0,.02),support=(-.08,-.22,.03))
        elif base['support'] is not None:
            mag=moved(down,support=(0,-.06,-.20))
            seat=moved(down,grip=(0,0,.02),support=(0,-.06,-.12))
        else:
            mag=moved(down,left=down['grip']+Vector((-.02,.04,-.22)))
            seat=moved(down,left=down['grip']+Vector((-.02,.04,-.14)))
        clips['reload_'+key]=bake(poser,[(1,base),(5,down),(9,mag),(15,seat),(19,down),(24,base)])
    clips['aim']=clips.pop('aim_gun'); clips['recoil']=clips.pop('recoil_gun'); clips['reload']=clips.pop('reload_gun')
    print('GUN_STANCES',name)
    return clips

BLADE_SUPPORT=(0,.22,-.02)  # left glove down the tsuka, toward the pommel

def blade_clips(poser, name):
    """Samurai kenjutsu for the plasma katana: two-handed grip (right hand at the tsuba, left toward the pommel),
    chudan-no-kamae guard, kesa-giri / gyaku-kesa / shomen-uchi combo, and chiburi."""
    def S(r,bl,edge,body=None,rpole=DEFAULT_RPOLE,lpole=DEFAULT_LPOLE):
        return hold(r,bl,edge=edge,body=body,support=BLADE_SUPPORT,rpole=rpole,lpole=lpole)
    # chudan-no-kamae: hilt in front of the navel, blade forward and up toward the opponent's throat, edge down
    # ready guard from the sheet: katana low in the right hand, blade forward and down past the right foot,
    # left fist free and out from the body (both hands join the hilt for each cut)
    guard=hold((.42*BULK['Ronin'],-.30,.86),(.46,-.68,-.40),edge=(0,-.3,-1),body={'chest':(.04,.08,0)},
               left=(-.60*BULK['Ronin'],-.18,.74),lpole=(-.3,.4,-1),rpole=(1,.4,-.2))
    breathe=moved(guard,grip=(0,0,.012),body={'chest':(.015,0,0),'head':(-.015,0,0)})
    clips={'aim_blade':bake(poser,[(1,guard),(30,breathe),(60,guard)])}
    over=dict(rpole=(1,.1,.1),lpole=(-1,.1,.1))  # hands high: elbows out to the sides
    # 1 kesa-giri: raise over the right shoulder, cut diagonally down to the lower left, follow through
    w1=S((.26,-.20,1.52),(-.25,.35,.9),(-.3,.4,-.85),{'chest':(-.08,.32,0),'spine':(0,.1,0)},**over)
    k1=S((.06,-.56,1.12),(-.55,-.7,-.45),(-.55,-.25,-.8),{'chest':(.1,-.15,0)})
    f1=S((-.20,-.38,.90),(-.55,-.15,-.82),(-.3,.3,-.9),{'chest':(.22,-.42,0),'spine':(.12,-.14,0)},lpole=(-.6,.8,-.6))
    clips['slash_1']=bake(poser,[(1,guard),(5,w1),(8,k1),(11,f1),(19,guard)])
    # 2 gyaku-kesa: from the low left, rising diagonal cut back up to the upper right
    w2=S((-.20,-.36,.92),(-.6,-.3,-.72),(.4,-.3,.85),{'chest':(.18,-.4,0),'spine':(.1,-.12,0)},lpole=(-.6,.8,-.6))
    k2=S((.10,-.56,1.16),(.6,-.68,.42),(.55,-.2,.8),{'chest':(.05,.15,0)})
    f2=S((.32,-.26,1.46),(.5,.05,.86),(.3,.3,.9),{'chest':(-.05,.4,0),'spine':(0,.14,0)},**over)
    clips['slash_2']=bake(poser,[(1,guard),(5,w2),(8,k2),(11,f2),(19,guard)])
    # 3 shomen-uchi: jodan (sword raised overhead), step and cut straight down the centre, hold zanshin
    w3=S((.08,-.16,1.62),(0,.45,.89),(0,.9,-.4),{'chest':(-.14,0,0),'head':(-.05,0,0)},**over)
    k3=S((.08,-.60,1.16),(0,-.96,-.22),(0,-.25,-.97),{'chest':(.12,0,0)})
    z3=S((.08,-.54,.94),(0,-.62,-.78),(0,.6,-.8),{'chest':(.28,0,0),'spine':(.16,0,0),'head':(.06,0,0)})
    clips['slash_3']=bake(poser,[(1,guard),(6,w3),(9,k3),(12,z3),(18,z3),(26,guard)])
    clips['slash']=clips['slash_1']
    # chiburi: flick the blade out and down to the right to clear it, then settle back into chudan
    c1=S((.32,-.38,1.28),(.62,-.55,.55),(.2,-.3,-.93),{'chest':(0,.2,0)})
    c2=S((.40,-.32,.98),(.55,-.35,-.76),(.6,-.1,-.4),{'chest':(.08,.25,0)})
    clips['chiburi']=bake(poser,[(1,guard),(6,c1),(9,c2),(16,c2),(24,guard)])
    print('BLADE_CLIPS',name)
    return clips

def showcase_clip(poser, name):
    """One-frame hero pose for the menu portraits (render_showcase.py): signature weapon, braced or kneeling legs.
    Leg conventions (rig_parts): +X on a thigh swings the leg back, +X on a shin bends the knee, +Z on a thigh
    moves the foot toward -X; each foot is set to cancel its leg's pitch so the sole lands flat."""
    k=BULK.get(name,1.0)
    def legs(lt,ls,rt,rs,lz=0.0,rz=0.0,lf=None,rf=None):
        return {'L_thigh':(lt,0,lz),'L_shin':(ls,0,0),'L_foot':(-(lt+ls) if lf is None else lf,0,0),
                'R_thigh':(rt,0,rz),'R_shin':(rs,0,0),'R_foot':(-(rt+rs) if rf is None else rf,0,0)}
    kneel=legs(-1.15,1.25,.30,1.50,lz=.10,rz=-.06,rf=.35)  # left knee up, right knee on the ground
    H={
        # braced wide and low in profile, leaning into the minigun, barrels level at the target
        'Bastion':hold((.12*k,-.42,.94),(0,-1,-.02),support=MG_HANDLE,
                      body={'spine':(.14,0,0),'chest':(.08,-.06,0),'head':(-.12,.06,0),**legs(-.70,.85,.45,.40,lz=.12,rz=-.10)},
                      rpole=(.35,.45,-1),lpole=(-.5,.3,-1)),
        # deep forward lunge in profile, both hands on the hilt at the belly, the blade aimed forward and just above
        # level (chudan-no-kamae) like the others' weapons, kept close so the whole katana fits the card
        'Ronin':hold((.10,-.28,1.05),(0,-.985,.17),edge=(0,-.17,-.985),support=BLADE_SUPPORT,
                      body={'spine':(.12,0,0),'chest':(.06,.04,0),'head':(-.06,-.04,0),**legs(-.95,1.10,.60,.30,lz=.10,rz=-.08)},
                      rpole=(1,.3,-.5),lpole=(-1,.3,-.5)),
        # two-handed pistol, staggered stance, sights at the eye
        'Marshal':hold((.04,-.56,1.44),(0,-1,.02),support=(-.17,.03,-.05),
                    body={'chest':(.02,-.08,0),'head':(.04,.06,0),**legs(-.28,.32,.26,.28,lz=.14,rz=-.16)},
                    rpole=(.9,.3,-.8),lpole=(-.9,.3,-.8)),
        # long rail rifle shouldered in a deep forward lunge
        'Nova':hold((.10*k,-.36,1.22),(0,-1,-.03),support=(-.03,-.25,-.06),
                    body={'spine':(.08,0,0),'chest':(.06,0,0),'head':(.06,0,0),**legs(-.85,1.05,.50,.45,lz=.20,rz=-.24)},
                    lpole=(-1,.15,-.55)),
        # caster in profile: right arm reaching out, palm up under the holo panel; left hand drawn back, palm glowing
        'Hex':hold((.22*k,-.66,1.22),(0,-1,.06),up=(1,0,0),
                     body={'spine':(.10,0,0),'chest':(.04,.10,0),'head':(-.04,-.10,0),**legs(-.70,.85,.40,.35,lz=.12,rz=-.12)},
                     left=(-.52*k,.10,.98),lpole=(-.6,.6,-.6)),
        # sniper on one knee, cheek on the stock
        'Kestrel':hold((.08,-.30,1.31),support=(0,-.30,-.07),body={'chest':(.08,0,0),'head':(.12,0,0),**kneel},
                     rpole=(1,.25,-.15),lpole=(-1,.15,-.55)),
    }
    return {'showcase':[(1,poser.solve(H[name]))]}

def rig_parts(objs, name):
    arm_data=bpy.data.armatures.new(name+'_shared_skeleton')
    arm=bpy.data.objects.new(name+'_Rig',arm_data)
    ACTIVE_COLLECTION.objects.link(arm)
    bpy.ops.object.select_all(action='DESELECT'); arm.select_set(True); bpy.context.view_layer.objects.active=arm
    bpy.ops.object.mode_set(mode='EDIT')
    bones=[
        ('root',(0,0,.05),(0,0,.25),None),
        ('pelvis',(0,0,.68),(0,0,.94),'root'),
        ('spine',(0,0,.94),(0,0,1.24),'pelvis'),
        ('chest',(0,0,1.24),(0,0,1.47),'spine'),
        ('neck',(0,0,1.47),(0,0,1.57),'chest'),
        ('head',(0,0,1.57),(0,0,1.9),'neck'),
    ]
    k=BULK.get(name,1.0)
    for prefix,s in [('L',-1),('R',1)]:
        bones += [
            (prefix+'_shoulder',(s*.40*k,0,1.37),(s*.40*k,0,1.60),'chest'),  # pauldron: follows the arm part way
            (prefix+'_upper_arm',(s*.40*k,0,1.37),(s*.53*k,0,1.06),'chest'),
            (prefix+'_forearm',(s*.53*k,0,1.06),(s*.55*k,-.08,.75),prefix+'_upper_arm'),
            (prefix+'_hand',(s*.55*k,-.08,.75),(s*.56*k,-.17,.59),prefix+'_forearm'),
            (prefix+'_thigh',(s*.20,0,.76),(s*.205,0,.43),'pelvis'),
            (prefix+'_shin',(s*.205,0,.43),(s*.205,-.06,.14),prefix+'_thigh'),
            (prefix+'_foot',(s*.205,-.06,.14),(s*.205,-.30,.10),prefix+'_shin'),
        ]
    g=grip_point(name)
    bones.append(('weapon',tuple(g),(g.x,g.y-.4,g.z),'R_hand'))
    bones.append(('barrels',(.12,-.82,1.0),(.12,-1.20,1.0),'weapon'))
    for bone_name,head,tail,parent in bones:
        b=arm_data.edit_bones.new(bone_name); b.head=head; b.tail=tail
        if parent: b.parent=arm_data.edit_bones[parent]
    bpy.ops.object.mode_set(mode='OBJECT')
    def bone_for(part):
        if part.startswith(('barrel_','rotary_hub','muzzle_ring')): return 'barrels'
        if part.startswith(('L_','R_')):
            p=part[:2]
            if 'helmet' in part: return 'head'
            if 'shoulder_joint' in part or 'upper_arm' in part: return p+'upper_arm'
            if 'shoulder' in part: return p+'shoulder'
            if 'elbow' in part or 'forearm' in part or 'wrist' in part: return p+'forearm'
            if 'glove' in part: return p+'hand'
            if 'hip' in part or 'thigh' in part or 'knee' in part: return p+'thigh'
            if 'shin' in part: return p+'shin'
            if 'boot' in part: return p+'foot'
        if part.startswith(('helmet','visor','neck')): return 'head'
        if part.startswith(('chest','backpack')): return 'chest'
        if part.startswith(('abdomen',)): return 'spine'
        if part.startswith(('pelvis',)): return 'pelvis'
        return 'weapon'
    for obj in objs:
        vg=obj.vertex_groups.new(name=bone_for(obj.name))
        vg.add(list(range(len(obj.data.vertices))),1.0,'REPLACE')
        mod=obj.modifiers.new('Rigid armor skin','ARMATURE'); mod.object=arm
        obj.parent=arm
    arm.animation_data_create()
    # Rig conventions (front is -Y): +X on chest/spine leans forward, +X on a thigh swings the leg back,
    # +X on a shin bends the knee, +Z on a thigh moves the foot toward -X, +X on weapon tips the muzzle up.
    def stride(lead, trail, back=False):
        """16-frame run cycle for the legs only; the upper body is driven separately (aim layer)."""
        keys=[(-.55,.15,-.15),(-.12,.3,0),(.45,.55,.2),(.1,.95,.1)]  # (thigh, shin, foot) contact, pass, push, swing
        if back: keys=list(reversed(keys))
        out=[]
        for k in range(5):
            f=1+k*4
            l=keys[k%4]; r=keys[(k+2)%4]
            out.append((f,{lead+'_thigh':(l[0],0,0),lead+'_shin':(l[1],0,0),lead+'_foot':(l[2],0,0),
                           trail+'_thigh':(r[0],0,0),trail+'_shin':(r[1],0,0),trail+'_foot':(r[2],0,0),
                           'pelvis':(0,.08*(1 if k%2 else -1),0),'spine':(.07 if not back else -.03,-.06*(1 if k%2 else -1),0)}))
        return out
    def side(sign):
        """Side-step cycle toward Blender +X (sign=1) or -X (sign=-1)."""
        lead,trail=('R','L') if sign>0 else ('L','R')
        z=-.32*sign
        return [(1,{lead+'_thigh':(-.1,0,z),lead+'_shin':(.25,0,0),trail+'_thigh':(0,0,0),'pelvis':(0,0,.05*sign)}),
                (5,{lead+'_thigh':(0,0,z*.4),trail+'_thigh':(-.15,0,z*.7),trail+'_shin':(.55,0,0),'pelvis':(0,0,0)}),
                (9,{lead+'_thigh':(0,0,0),trail+'_thigh':(0,0,z*.15),lead+'_shin':(.1,0,0),'pelvis':(0,0,-.05*sign)}),
                (13,{lead+'_thigh':(-.15,0,z*.8),lead+'_shin':(.55,0,0),trail+'_thigh':(0,0,0),'pelvis':(0,0,0)}),
                (17,{lead+'_thigh':(-.1,0,z),lead+'_shin':(.25,0,0),trail+'_thigh':(0,0,0),'pelvis':(0,0,.05*sign)})]
    clips={
        'idle':[(1,{}),(16,{'chest':(.025,0,0),'head':(-.02,0,0)}),(31,{})],
        'aim':[(1,{}),(24,{'chest':(.02,0,.01),'head':(-.02,.02,0),'spine':(.01,0,0)}),(48,{})],
        'run':stride('L','R'),
        'run_back':stride('L','R',True),
        'strafe_left':side(1),   # Blender +X is the fighter's left once Godot turns the model to face -Z
        'strafe_right':side(-1),
        'recoil':[(1,{}),(2,{'chest':(-.09,0,0),'spine':(-.04,0,0),'weapon':(.12,0,0),'head':(.04,0,0)}),(7,{})],
        'reload':[(1,{}),(6,{'weapon':(-.55,0,.1),'chest':(.08,0,0),'head':(.18,0,0),'L_upper_arm':(.25,0,0)}),
                  (16,{'weapon':(-.5,0,.12),'chest':(.08,0,0),'head':(.15,0,0),'L_upper_arm':(.35,0,-.1)}),(24,{})],
        'attack':[(1,{}),(2,{'chest':(-.09,0,0),'weapon':(.12,0,0)}),(7,{})],
        'special':[(1,{}),(8,{'chest':(-.15,0,0),'weapon':(.35,0,0),'head':(-.1,0,0)}),(18,{})],
        'dodge':[(1,{}),(5,{'spine':(.35,0,0),'L_thigh':(-.6,0,0),'R_thigh':(.3,0,0),'L_shin':(.8,0,0),'R_shin':(.6,0,0)}),(13,{})],
        'hit':[(1,{}),(3,{'chest':(-.18,0,.06),'head':(-.15,0,0),'spine':(-.05,0,0)}),(12,{})],
        'death':[(1,{}),(24,{'root':(1.2,0,0),'head':(.3,0,0)})],
        'downed':[(1,{}),(18,{'root':(.6,0,0),'head':(.18,0,0)})],
        'revive':[(1,{'root':(.6,0,0)}),(18,{})],
        'victory':[(1,{}),(14,{'weapon':(.9,0,0),'chest':(-.12,0,0),'head':(-.2,0,0)}),(29,{})],
        'charge':[(1,{}),(12,{'chest':(.05,0,0),'head':(.05,0,0)}),(23,{'chest':(.05,0,0),'head':(.05,0,0)})],
        'cast':[(1,{}),(10,{'chest':(-.12,0,0),'weapon':(.25,0,0),'head':(-.12,0,0)}),(23,{})],
    }
    poser=Poser(arm,objs,name)
    if name=='Ronin': clips.update(blade_clips(poser,name))  # the katana is Ronin's only
    clips.update(gun_stance_clips(poser,name))
    clips.update(showcase_clip(poser,name))
    for clip,poses in clips.items():
        action=bpy.data.actions.new(clip)
        arm.animation_data.action=action
        for frame,pose in poses:
            for bone_name,_,_,_ in bones:
                pb=arm.pose.bones[bone_name]
                pb.rotation_mode='XYZ'; pb.rotation_euler=pose.get(bone_name,(0,0,0))
                pb.keyframe_insert(data_path='rotation_euler',frame=frame,group=bone_name)
        arm.animation_data.action=None
        track=arm.animation_data.nla_tracks.new(); track.name=clip
        track.strips.new(clip,1,action)
    for pb in arm.pose.bones: pb.rotation_euler=(0,0,0)  # leave the rig at rest (keying left the last clip's pose)
    return arm

def hero(name, rgb):
    global ACTIVE_COLLECTION
    ACTIVE_COLLECTION=bpy.data.collections.new(name+'_Assets')
    bpy.context.scene.collection.children.link(ACTIVE_COLLECTION)
    accent=mat(name+'_accent',rgb,.42); glow=mat(name+'_emission',rgb,.12,.24,4.0)
    objs=[]
    def C(*a,**k): objs.append(cube(*a,**k))
    def Y(*a,**k): objs.append(cyl(*a,**k))
    # Per-character details taken from "The Six" sheet.
    st={
        'Bastion':dict(bulk=BULK['Bastion'],eye='wide',helm=None,shoulder='outer_big',forearm=True,hip=False,thigh=False),
        'Ronin':dict(bulk=BULK['Ronin'],eye='side',helm=None,shoulder='top',forearm=False,hip=True,thigh=False),
        'Marshal':dict(bulk=1.0,eye='side',helm='L',shoulder='outer',forearm=False,hip=True,thigh=False),
        'Nova':dict(bulk=1.0,eye='wide',helm='both',shoulder='outer',forearm=False,hip=False,thigh=False),
        'Hex':dict(bulk=BULK['Hex'],eye='wide',helm='both',shoulder='outer',forearm=False,hip=False,thigh=False),
        'Kestrel':dict(bulk=1.0,eye='side',helm='both',shoulder='outer',forearm=False,hip=True,thigh=True),
    }[name]
    bulk=st['bulk']
    sx=.50*bulk  # shoulder pad centre
    # ---- torso: black undersuit, cream chest vest and belly plate, belt with hanging hip plates
    C('pelvis_core',(0,0,.78),(.46*bulk,.31,.26),dark,.06)
    C('pelvis_belt',(0,-.01,.89),(.50*bulk,.34,.08),dark,.03)
    C('pelvis_belt_plate',(0,-.175,.90),(.18*bulk,.04,.07),white,.02)
    C('abdomen_joint',(0,0,1.03),(.40*bulk,.29,.24),dark,.06)
    C('abdomen_plate',(0,-.155,1.04),(.30*bulk,.05,.15),white,.04)
    for i,z in enumerate((.975,1.105)):
        C('abdomen_rib_%d'%i,(0,-.15,z),(.34*bulk,.025,.03),metal,.01)
    C('chest_armor',(0,-.01,1.28),(.62*bulk,.42,.42),dark,.11)
    C('chest_plate',(0,-.185,1.31),(.52*bulk,.12,.32),white,.08)
    C('chest_plate_side_L',(-.24*bulk,-.12,1.27),(.10,.16,.26),white,.05)
    C('chest_plate_side_R',(.24*bulk,-.12,1.27),(.10,.16,.26),white,.05)
    C('chest_seam',(0,-.247,1.22),(.38*bulk,.012,.016),dark,.004)
    C('chest_slot',(0,-.248,1.36),(.14,.014,.035),accent,.006)
    C('chest_collar',(0,-.02,1.48),(.42*bulk,.34,.08),dark,.03)
    C('backpack',(0,.25,1.26),(.46*bulk,.17,.38),dark,.07)
    C('backpack_plate',(0,.34,1.28),(.34*bulk,.03,.24),white,.04)
    C('neck',(0,0,1.54),(.25,.25,.13),dark,.04)
    # ---- helmet: tall rounded cream block, dark lower faceplate, glowing eye, accent side panels
    C('helmet',(0,-.02,1.81),(.58,.56,.64),white,.11)
    C('helmet_top',(0,-.02,2.13),(.46,.44,.02),white,.008)
    C('helmet_brow',(0,-.30,1.76),(.50,.03,.04),white,.012)
    C('visor_frame',(0,-.285,1.65),(.48,.06,.17),dark,.06)
    C('visor',(0,-.312,1.655),(.40,.02,.11),black,.035)
    if st['eye']=='wide':
        C('visor_light',(0,-.326,1.66),(.26,.008,.03),glow,.008)
    else:
        C('visor_light',(.10,-.326,1.665),(.09,.008,.034),glow,.008)
    C('helmet_chin',(0,-.22,1.52),(.30,.12,.06),dark,.025)
    for sgn,sd in [('L',-1),('R',1)]:
        on=st['helm']=='both' or st['helm']==sgn
        C(sgn+'_helmet_ear',(sd*.305,.0,1.78),(.05,.38,.40),accent if on else white,.035)
        C(sgn+'_helmet_vent',(sd*.33,.05,1.74),(.02,.16,.12),dark,.008)
    for sign,s in [('L',-1),('R',1)]:
        # ---- arms: big rounded pauldrons with accent plates, cream elbow and forearm, fat black gloves
        C(sign+'_shoulder_joint',(s*.41*bulk,0,1.37),(.23,.25,.25),dark,.07)
        C(sign+'_shoulder_armor',(s*sx,-.01,1.43),(.36*bulk,.42,.32),white,.11)
        if st['shoulder']=='top':
            C(sign+'_shoulder_cap',(s*sx,-.04,1.60),(.30*bulk,.32,.06),accent,.025)
            C(sign+'_shoulder_accent',(s*(sx+.06),-.2,1.47),(.18*bulk,.04,.16),accent,.02)
        else:
            big=st['shoulder']=='outer_big'
            C(sign+'_shoulder_accent',(s*(sx+.16*bulk),-.01,1.42),(.09 if big else .07,.40 if big else .36,.30 if big else .26),accent,.035)
            C(sign+'_shoulder_cap',(s*sx,-.01,1.60),(.28*bulk,.32,.04),white,.02)
        C(sign+'_upper_arm',(s*.51*bulk,-.01,1.17),(.19*bulk,.21,.24),dark,.06)
        C(sign+'_upper_arm_plate',(s*(.51*bulk+.06),-.01,1.18),(.08,.18,.17),accent if st['forearm'] else white,.03)
        C(sign+'_elbow',(s*.53*bulk,-.02,1.055),(.21,.22,.15),white,.06)  # on the elbow pivot
        C(sign+'_forearm_plate',(s*.55*bulk,-.07,.85),(.26*bulk,.30,.29),white,.09)
        if st['forearm']:
            C(sign+'_forearm_accent',(s*(.55*bulk+.13*bulk),-.07,.86),(.06,.28,.24),accent,.02)
        C(sign+'_wrist_band',(s*.55*bulk,-.10,.71),(.25*bulk,.28,.06),dark,.02)
        C(sign+'_glove',(s*.56*bulk,-.13,.62),(.27*bulk,.29,.23),dark,.08)
        C(sign+'_glove_knuckle',(s*.56*bulk,-.28,.645),(.22*bulk,.04,.09),metal,.015)
        # ---- legs: black thighs with cream front plates, cream knee and shin guards, chunky boots
        C(sign+'_hip_plate',(s*.21*bulk,-.15,.77),(.22*bulk,.08,.22),white,.04)
        C(sign+'_hip_accent',(s*.34*bulk,-.02,.81),(.06,.24,.20),accent if st['hip'] else dark,.02)
        C(sign+'_thigh_joint',(s*.215*bulk,0,.62),(.22*bulk,.24,.26),dark,.06)
        C(sign+'_thigh_armor',(s*.215*bulk,-.11,.57),(.21*bulk,.10,.20),white,.04)
        if st['thigh']:
            C(sign+'_thigh_accent',(s*(.215*bulk+.11),-.02,.58),(.04,.18,.18),accent,.015)
        C(sign+'_knee',(s*.215*bulk,-.16,.43),(.21*bulk,.10,.13),white,.045)
        C(sign+'_knee_joint',(s*.215*bulk,-.02,.42),(.21*bulk,.23,.14),dark,.045)
        C(sign+'_shin',(s*.215*bulk,-.06,.28),(.25*bulk,.28,.25),white,.08)
        C(sign+'_shin_stripe',(s*.215*bulk,-.203,.31),(.06,.012,.12),accent,.005)
        C(sign+'_boot',(s*.215*bulk,-.10,.10),(.31*bulk,.50,.21),dark,.08)
        C(sign+'_boot_toe',(s*.215*bulk,-.31,.115),(.29*bulk,.15,.14),white,.06)
        C(sign+'_boot_heel',(s*.215*bulk,.13,.09),(.26*bulk,.06,.12),white,.03)
        C(sign+'_boot_sole',(s*.215*bulk,-.10,.015),(.32*bulk,.51,.03),metal,.01)
    if name=='Hex':  # left caster hand, the mirror twin of W_gauntlet in weapons.glb (worn on the right fist)
        g=Vector((-.56*bulk,-.15,.64))
        M={'slate':mat('caster_slate',(.042,.05,.064),.25,.5),'inset':mat('caster_inset',(.016,.019,.025),.2,.55),
           'orange':mat('caster_orange',(.888,.354,.013),.1,.4),'glow':glow}  # W_gauntlet's SLATE/INSET/orange
        for i,(c,m) in enumerate(caster_hand(-1)):
            x,y,z=c[1]; p=tuple(g+Vector((x,-z,y)))  # hand frame (fingers -Y, knuckles +Z) -> rest (fingers down, knuckles -Y)
            if c[0]=='box': C('L_glove_caster_%02d'%i,p,(c[2][0],c[2][2],c[2][1]),M[m],c[3])
            else: Y('L_glove_caster_%02d'%i,p,c[2],c[3],M[m],20,axis='X')
    # Arm pieces stay on their bones (arms down at rest); every hold is a solved pose, so posing never
    # separates a forearm or glove from its arm. Godot mounts weapons.glb models on the Grip socket in the fist.
    arm=rig_parts(objs,name)
    # Grip socket on the weapon bone, at the top of the right fist. Computed from the REST bone (bone parents
    # attach at the tail), never from the evaluated pose: the NLA stack would otherwise bake a clip's tilt in.
    grip=bpy.data.objects.new('Grip_'+name,None); grip.empty_display_size=.08
    ACTIVE_COLLECTION.objects.link(grip)
    grip.parent=arm; grip.parent_type='BONE'; grip.parent_bone='weapon'
    bone=arm.data.bones['weapon']
    tail_rest=arm.matrix_world@bone.matrix_local@Matrix.Translation((0,bone.length,0))
    grip.matrix_parent_inverse=Matrix.Identity(4)
    grip.matrix_basis=tail_rest.inverted()@Matrix.Translation(grip_point(name))
    objs.append(grip)
    for sc in bpy.data.scenes:
        for vl in sc.view_layers:
            for o in sc.objects:
                try: o.select_set(False, view_layer=vl)
                except RuntimeError: pass
    for o in objs: o.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active=arm
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,name.lower()+'.glb'), export_format='GLB', use_selection=True, export_animations=True, export_animation_mode='NLA_TRACKS', export_apply=True)

def build_all():
    # Build and export in the active scene (exporting an animated rig from a freshly switched scene
    # crashes Blender 5.2), save the fighter's collection to its .blend, then park it in a
    # Fighter_<Name> scene so the scene open in the GUI stays as it was.
    host=bpy.context.scene
    only=[x.strip().lower() for x in os.environ.get('FIGHTERS','').split(',') if x.strip()]
    for n,c in HEROES:
        if only and n.lower() not in only: continue
        old=bpy.data.scenes.get('Fighter_'+n)
        if old:
            for o in list(old.objects): bpy.data.objects.remove(o)
            bpy.data.scenes.remove(old)
        hero(n,c)
        bpy.data.libraries.write(os.path.join(HERE,n.lower()+'.blend'),{ACTIVE_COLLECTION},fake_user=True,compress=True)
        if not bpy.app.background:
            sc=bpy.data.scenes.new('Fighter_'+n)
            sc.collection.children.link(ACTIVE_COLLECTION)
            host.collection.children.unlink(ACTIVE_COLLECTION)

build_all()
print('Exported six armored fighters to',OUT)
