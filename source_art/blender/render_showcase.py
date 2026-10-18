"""Menu hero shots: each operative in its `showcase` pose (build_fighters.py showcase_clip), signature weapon
mounted, grounded, lit with key / fill / rim, and framed by its own low perspective camera.

Run:  blender -b --python source_art/blender/render_showcase.py   ->  evidence/fighters/<name>_showcase.png
then  python3 source_art/blender/make_portraits.py                ->  assets/ui/<name>.png
"""
import bpy, os, math
from mathutils import Matrix, Vector
HERE=os.path.dirname(os.path.abspath(__file__))
ROOT=os.path.abspath(os.path.join(HERE,'..','..'))
OUT=os.path.join(ROOT,'evidence','fighters')
GUN={'bastion':'minigun','ronin':'sword','marshal':'pistol','nova':'railrifle','hex':'gauntlet','kestrel':'sniper'}
BULK={'bastion':1.26,'ronin':.96,'hex':.95}  # build_fighters.py BULK (grip_point)
# camera position (fighter faces -Y, its right hand is +X), look-at height, focal length: low angles looking up,
# all from the fighter's left so every operative is seen side-on, aiming toward the right of the card
CAMS={
    'bastion':((-3.8,-2.4,0.70),0.95,50),
    'ronin':((-3.7,-2.5,0.80),1.20,36),
    'marshal':((-3.1,-3.3,1.10),1.10,52),
    'nova':((-3.7,-2.5,0.75),0.95,48),
    'hex':((-3.7,-2.6,0.75),1.10,48),
    'kestrel':((-3.6,-2.6,0.55),0.75,52),
}
names=os.environ.get('HERO_FILTER',','.join(GUN)).split(',')
for name in names:
    bpy.ops.wm.open_mainfile(filepath=os.path.join(HERE,name+'.blend'))
    scene=bpy.context.scene
    for col in bpy.data.collections:
        if '_Assets' in col.name and col.name not in scene.collection.children:
            scene.collection.children.link(col)
    gun=GUN[name]
    with bpy.data.libraries.load(os.path.join(HERE,'weapons.blend')) as (src,dst):
        dst.objects=[n for n in src.objects if n in ('W_'+gun,'Spin_'+gun)]
    for w in dst.objects: scene.collection.objects.link(w)
    rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
    for t in rig.animation_data.nla_tracks: t.mute=True
    act=next(a for a in bpy.data.actions if a.name.split('.')[0]=='showcase')
    rig.animation_data.action=act
    scene.frame_set(1); bpy.context.view_layer.update()
    # ground the pose: bent knees lift the feet, so drop the rig until the lowest leg piece touches the floor
    dg=bpy.context.evaluated_depsgraph_get()
    low=min((o.evaluated_get(dg).matrix_world@v.co).z for o in bpy.data.objects if o.type=='MESH' and o.parent==rig
            and any(k in o.name for k in ('boot','shin','knee')) for v in o.evaluated_get(dg).data.vertices)
    rig.location.z-=low
    bpy.context.view_layer.update()
    er=rig.evaluated_get(bpy.context.evaluated_depsgraph_get())
    pb=er.pose.bones['weapon']
    deform=er.matrix_world@pb.matrix@er.data.bones['weapon'].matrix_local.inverted()@er.matrix_world.inverted()
    rest=Matrix.Translation((.56*BULK.get(name,1.0),-.15,.64))  # grip_point() in build_fighters.py
    for w in dst.objects:
        if w.parent is None: w.matrix_world=deform@rest
    # look
    scene.render.engine='BLENDER_EEVEE'
    world=bpy.data.worlds.new('ShowcaseWorld'); world.use_nodes=True
    bg=world.node_tree.nodes.get('Background'); bg.inputs['Color'].default_value=(.55,.62,.75,1); bg.inputs['Strength'].default_value=.55
    scene.world=world
    for light_name,loc,power,size in [('Key',(-3,-4,6),950,3),('Fill',(4,-2,3),300,5),('Rim',(1.5,4.5,4.5),1400,2.5),('RimLow',(-3.5,3.5,1.2),500,2)]:
        data=bpy.data.lights.new(light_name,'AREA'); data.energy=power; data.shape='DISK'; data.size=size
        obj=bpy.data.objects.new(light_name,data); scene.collection.objects.link(obj); obj.location=loc
        obj.rotation_euler=(Vector((0,0,1))-obj.location).to_track_quat('-Z','Y').to_euler()
    scene.render.film_transparent=True
    scene.render.resolution_x=760; scene.render.resolution_y=760; scene.render.resolution_percentage=100
    cam_data=bpy.data.cameras.new('ShowcaseCam'); cam=bpy.data.objects.new('ShowcaseCam',cam_data); scene.collection.objects.link(cam)
    loc,look_z,lens=CAMS[name]
    cam_data.lens=lens; cam.location=loc; scene.camera=cam
    cam.rotation_euler=(Vector((0,-.2,look_z))-cam.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=os.path.join(OUT,name+'_showcase.png')
    bpy.ops.render.render(write_still=True)
    print('SHOWCASE',name,'grounded by %.2f m'%low)
