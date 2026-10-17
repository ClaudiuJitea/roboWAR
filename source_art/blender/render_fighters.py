"""Render front, side, and gameplay-angle previews from the saved Blender sources."""
import bpy, os, math
from mathutils import Matrix, Vector
ROOT=os.path.abspath(os.path.join(os.path.dirname(__file__),'..','..'))
OUT=os.path.join(ROOT,'evidence','fighters')
os.makedirs(OUT,exist_ok=True)
names=tuple(os.environ.get('HERO_FILTER','magnus,albert,theo,iris,seren,nadia').split(','))
for name in names:
    bpy.ops.wm.open_mainfile(filepath=os.path.join(os.path.dirname(__file__),name+'.blend'))
    scene=bpy.context.scene
    for col in bpy.data.collections:  # fighter .blend files store the fighter as a collection
        if '_Assets' in col.name and col.name not in scene.collection.children:
            scene.collection.children.link(col)
    # mount the operative's starting gun (same mapping as Data.HERO_WEAPON) on its Grip socket
    gun={'magnus':'minigun','albert':'sword','theo':'pistol','iris':'railrifle','seren':'gauntlet','nadia':'sniper'}[name]  # signature weapons (Data.SIGNATURES)
    with bpy.data.libraries.load(os.path.join(os.path.dirname(__file__),'weapons.blend')) as (src,dst):
        dst.objects=[n for n in src.objects if n in ('W_'+gun,'Spin_'+gun)]
    grip=next((o for o in bpy.data.objects if o.name.startswith('Grip_')),None)
    for w in dst.objects:
        scene.collection.objects.link(w)
    rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
    for t in rig.animation_data.nla_tracks: t.mute=True  # rest pose unless a pose clip is chosen below
    for b in rig.pose.bones: b.rotation_mode='XYZ'; b.rotation_euler=(0,0,0)
    # each portrait shows the operative's signature stance (same clips Godot uses)
    pose={'magnus':'aim_heavy','albert':'aim_blade','theo':'aim_pistol','iris':'aim_rail','seren':'aim_cast','nadia':'aim_sniper'}[name]
    act=next((a for a in bpy.data.actions if a.name.split('.')[0]==pose),None)
    if act: rig.animation_data.action=act
    scene.frame_set(1); bpy.context.view_layer.update()
    er=rig.evaluated_get(bpy.context.evaluated_depsgraph_get())
    pb=er.pose.bones['weapon']
    deform=er.matrix_world@pb.matrix@er.data.bones['weapon'].matrix_local.inverted()@er.matrix_world.inverted()
    for w in dst.objects:
        if grip and w.parent is None:
            # Grip rest position (build_fighters.py); the saved empty matrix can be stale, so use it directly
            rest=Matrix.Translation((.56*{'magnus':1.26,'albert':.96,'seren':.95}.get(name,1.0),-.15,.64))  # grip_point() in build_fighters.py
            w.matrix_world=deform@rest  # same rigid deform the meshes get
    scene.render.engine='BLENDER_EEVEE'
    world=bpy.data.worlds.new('PreviewWorld'); world.use_nodes=True
    world.node_tree.nodes.get('Background').inputs['Color'].default_value=(.55,.64,.78,1)
    world.node_tree.nodes.get('Background').inputs['Strength'].default_value=.8
    scene.world=world
    for light_name,loc,power,size in [('Key',(3,-4,7),900,4),('Fill',(-4,-1,4),450,5)]:
        data=bpy.data.lights.new(light_name,'AREA'); data.energy=power; data.shape='DISK'; data.size=size
        obj=bpy.data.objects.new(light_name,data); scene.collection.objects.link(obj); obj.location=loc
        obj.rotation_euler=(Vector((0,0,1))-obj.location).to_track_quat('-Z','Y').to_euler()
    scene.render.film_transparent=True
    scene.render.resolution_x=650; scene.render.resolution_y=650; scene.render.resolution_percentage=100
    camera_data=bpy.data.cameras.new('PreviewCamera'); camera=bpy.data.objects.new('PreviewCamera',camera_data); scene.collection.objects.link(camera)
    scene.camera=camera; camera_data.type='ORTHO'; camera_data.ortho_scale=2.8
    target=Vector((0,-.25,1.0))
    # Albert: slightly higher three-quarter view so the katana's curve and length read
    front=(3.4,-4.4,3.4) if name=='albert' else (3,-5,2.7)
    # portrait: three-quarter view from the fighter's left, like "The Six" sheet, so weapons read in profile
    # pointing to the viewer's right (menu cards: make_portraits.py)
    for view,loc in [('front',front),('side',(5,0,1.55)),('gameplay',(4,-5,6.0)),('portrait',(-3.6,-4.6,2.6))]:
        camera.location=loc
        direction=target-camera.location
        camera.rotation_euler=direction.to_track_quat('-Z','Y').to_euler()
        scene.render.filepath=os.path.join(OUT,name+'_'+view+'.png')
        bpy.ops.render.render(write_still=True)
    print('Rendered',name)
