"""Sector 03 arena + enemy kit generator.

Run headless:  blender -b -t 4 --factory-startup --python source_art/blender/build_arena.py
Or execute through the Blender MCP add-on (it builds in its own scene and leaves the open scene alone).
Layout comes from assets/arena_layout.json (Godot coordinates); Godot builds collision from the same file.
"""
import bpy, bmesh, json, math, os
from mathutils import Matrix, Vector

try:
    ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
except NameError:
    ROOT = '/home/clau/dev/RoboWar'
THEME = os.environ.get('ARENA_THEME', globals().get('ARENA_THEME', 'white'))
# each environment may have its own wall layout (assets/arena_layout_<theme>.json); Godot reads the same file
_own_layout = os.path.join(ROOT, 'assets', 'arena_layout_%s.json' % THEME)
LAYOUT = json.load(open(_own_layout if os.path.exists(_own_layout) else os.path.join(ROOT, 'assets', 'arena_layout.json')))
OUT = os.path.join(ROOT, 'assets', 'models')
SRC = os.path.join(ROOT, 'source_art', 'blender')
FONT_PATHS = ['/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf']


def gp(x, y, z):
    """Godot position -> Blender position (glTF export converts back)."""
    return Vector((x, -z, y))


def gs(x, y, z):
    """Godot size -> Blender dimensions."""
    return Vector((x, z, y))


# ---------------------------------------------------------------- materials
def mat(name, color, rough=.62, metal=0.0, emit=0.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Roughness'].default_value = rough
    p.inputs['Metallic'].default_value = metal
    if emit:
        p.inputs['Emission Color'].default_value = (*color, 1)
        p.inputs['Emission Strength'].default_value = emit
    return m


def srgb(h):
    h = h.lstrip('#')
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4 for v in c)


# Themes share geometry builders and material slots; the palette (and for the campaign arenas, the layout) changes.
#   white : Sector 03 docks, cream walls, blue bays, yellow safety trim (default)
#   black : Sector 07 assembly, black walls, red accents and glowing red trim, charcoal floor
#   cryo  : Cryo Vault 11, frosted white-blue walls, glowing ice-cyan bays, pale floor
#   toxic : Refinery 19, olive-black walls, acid green bays and trim
#   core  : The Core 00, violet-black walls, glowing violet bays, magenta trim
PALETTES = {
    'white': {'white': ('eef0ec', .55, 0, 0), 'cap': ('f7f8f5', .5, 0, 0), 'seam': ('c9cfd1', .6, 0, 0), 'floor': ('dfe2df', .78, 0, 0),
              'tile': ('c6ccce', .8, 0, 0), 'blue': ('1d4fb8', .5, 0, 0), 'blue_floor': ('2457c4', .7, 0, 0), 'navy': ('0f2a62', .6, 0, 0),
              'yellow': ('f2c230', .5, 0, 0), 'dark': ('2b3640', .55, .2, 0), 'steel': ('5d6a73', .35, .6, 0), 'grate': ('3a444c', .7, .3, 0),
              'paint': ('f4f6f3', .7, 0, 0)},
    'black': {'white': ('141518', .42, .15, 0), 'cap': ('1e2024', .38, .2, 0), 'seam': ('2a2c31', .5, .2, 0), 'floor': ('4a4d54', .62, .1, 0),
              'tile': ('393b41', .7, .1, 0), 'blue': ('b3121e', .4, .1, 1.6), 'blue_floor': ('2a1517', .6, .1, 0), 'navy': ('0b0b0d', .5, .2, 0),
              'yellow': ('ff2433', .35, 0, 3.0), 'dark': ('0d0e10', .5, .3, 0), 'steel': ('3a3d43', .3, .7, 0), 'grate': ('1a1b1e', .6, .4, 0),
              'paint': ('d0202c', .55, 0, 1.2)},
    'cryo': {'white': ('e3edf4', .35, .05, 0), 'cap': ('f4f9fc', .3, 0, 0), 'seam': ('b9cbd8', .45, 0, 0), 'floor': ('c9d7e1', .55, .05, 0),
             'tile': ('aebfcc', .6, 0, 0), 'blue': ('3cc4ee', .3, 0, 1.4), 'blue_floor': ('9fd3ea', .4, 0, 0), 'navy': ('274a63', .5, .1, 0),
             'yellow': ('8ae6ff', .3, 0, 2.2), 'dark': ('3d4f5e', .45, .3, 0), 'steel': ('8aa1b2', .25, .7, 0), 'grate': ('56697a', .6, .3, 0),
             'paint': ('3aa7d6', .5, 0, .6)},
    'toxic': {'white': ('2a2e24', .5, .1, 0), 'cap': ('343a2c', .45, .15, 0), 'seam': ('1b1e17', .55, .2, 0), 'floor': ('3e4237', .7, .05, 0),
              'tile': ('2f322a', .75, .05, 0), 'blue': ('5fd31f', .4, 0, 1.8), 'blue_floor': ('263519', .6, .05, 0), 'navy': ('11140e', .5, .2, 0),
              'yellow': ('d8f23a', .35, 0, 2.6), 'dark': ('15170f', .5, .3, 0), 'steel': ('4a5040', .3, .7, 0), 'grate': ('1d2018', .6, .4, 0),
              'paint': ('9fe02a', .55, 0, 1.0)},
    'core': {'white': ('1b1624', .38, .2, 0), 'cap': ('262033', .35, .25, 0), 'seam': ('2f2740', .45, .2, 0), 'floor': ('2c2738', .5, .15, 0),
             'tile': ('3a3349', .55, .1, 0), 'blue': ('8a3cff', .3, 0, 2.2), 'blue_floor': ('251a3d', .5, .1, 0), 'navy': ('0d0a14', .5, .2, 0),
             'yellow': ('ff4fd8', .3, 0, 2.8), 'dark': ('0e0b14', .5, .3, 0), 'steel': ('4a4260', .25, .8, 0), 'grate': ('19141f', .6, .4, 0),
             'paint': ('b07cff', .5, 0, 1.3)},
}
M = {k: mat(('%s_' % THEME if THEME != 'white' else '') + {'white': 'ceramic_white', 'cap': 'cap_white', 'seam': 'panel_seam', 'floor': 'floor_concrete',
         'tile': 'floor_seam', 'blue': 'signal_blue', 'blue_floor': 'blue_floor', 'navy': 'recess_navy', 'yellow': 'safety_yellow',
         'dark': 'graphite', 'steel': 'steel_pipe', 'grate': 'vent_grate', 'paint': 'floor_paint'}[k], srgb(c), r, m, e)
     for k, (c, r, m, e) in PALETTES[THEME].items()}
SUFFIX = '' if THEME == 'white' else '_' + THEME
ORDER = list(M.keys())


# ---------------------------------------------------------------- bmesh builder
class Builder:
    """Accumulates bevelled boxes into one bmesh with per-material indices.

    Each primitive is built in its own small bmesh (bevel ops reuse the element
    tag flags, so they cannot be used to track new geometry) and then appended.
    """

    def __init__(self, order=None):
        self.order = order or ORDER
        self.bm = bmesh.new()
        self.scratch = bpy.data.meshes.new('_builder_scratch')

    def _commit(self, t, material, matrix=None):
        idx = self.order.index(material)
        for f in t.faces:
            f.material_index = idx
        if matrix is not None:
            bmesh.ops.transform(t, matrix=matrix, verts=t.verts)
        t.to_mesh(self.scratch)
        t.free()
        self.bm.from_mesh(self.scratch)

    def box(self, pos, size, material, bevel=0.0, segments=2, rot_z=0.0):
        t = bmesh.new()
        r = bmesh.ops.create_cube(t, size=1.0)
        bmesh.ops.scale(t, vec=size, verts=r['verts'])
        if bevel > 0:
            b = min(bevel, min(size) * .45)
            bmesh.ops.bevel(t, geom=list(t.verts) + list(t.edges), offset=b, segments=segments,
                            affect='EDGES', profile=.5, clamp_overlap=True)
        self._commit(t, material, Matrix.Translation(pos) @ Matrix.Rotation(rot_z, 4, 'Z'))

    def g(self, gpos, gsize, material, bevel=0.0, **kw):
        self.box(gp(*gpos), gs(*gsize), material, bevel, **kw)

    def cylinder(self, pos, radius, depth, material, axis='X', segs=12):
        t = bmesh.new()
        bmesh.ops.create_cone(t, cap_ends=True, segments=segs, radius1=radius, radius2=radius, depth=depth)
        rot = {'X': Matrix.Rotation(math.pi / 2, 4, 'Y'), 'Y': Matrix.Rotation(math.pi / 2, 4, 'X')}.get(axis, Matrix.Identity(4))
        self._commit(t, material, Matrix.Translation(pos) @ rot)

    def mesh_from(self, mesh, matrix, material):
        t = bmesh.new()
        t.from_mesh(mesh)
        self._commit(t, material, matrix)

    def to_object(self, name, collection):
        me = bpy.data.meshes.new(name)
        for key in self.order:
            me.materials.append(M[key] if isinstance(key, str) else key)
        bpy.data.meshes.remove(self.scratch)
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=1e-5)
        self.bm.to_mesh(me)
        self.bm.free()
        for p in me.polygons:
            p.use_smooth = False
        ob = bpy.data.objects.new(name, me)
        collection.objects.link(ob)
        # weighted normals keep bevels crisp but soft
        wn = ob.modifiers.new('weighted', 'WEIGHTED_NORMAL')
        wn.keep_sharp = True
        return ob


# ---------------------------------------------------------------- arena pieces
def wall_module(B, pos, size, perimeter=False):
    x, y, z = pos
    sx, sy, sz = size
    base = y - sy / 2
    long_x = sx >= sz
    B.g((x, y + .03, z), (sx, sy - .06, sz), 'white', bevel=.09, segments=3)
    # top cap: recessed lighter slab with a thin rim
    B.g((x, base + sy - .005, z), (sx - .34, .04, sz - .34), 'cap', bevel=.03)
    # dark plinth band around the base
    B.g((x, base + .07, z), (sx + .07, .14, sz + .07), 'dark', bevel=.02)
    length = sx if long_x else sz
    depth = sz if long_x else sx
    # vertical panel seams every ~2.4 m
    n = max(1, int(length / 2.4))
    for side in (-1, 1):
        face = depth / 2 * side
        for i in range(1, n):
            t = -length / 2 + i * length / n
            if long_x:
                B.g((x + t, y + .05, z + face), (.035, sy - .32, .03), 'seam')
            else:
                B.g((x + face, y + .05, z + t), (.03, sy - .32, .035), 'seam')
        # recessed blue bay (navy frame + blue panel) with a yellow safety edge
        bay_w = min(length * .62, 5.2 if not perimeter else 3.2)
        bay_h = sy * (.58 if not perimeter else .74)
        cy = base + .14 + bay_h / 2
        bays = [0.0] if not perimeter else [k * 9.0 for k in range(-int(length / 18), int(length / 18) + 1)]
        for off in bays:
            if long_x:
                B.g((x + off, cy, z + face + .012 * side), (bay_w + .14, bay_h + .1, .05), 'navy', bevel=.015)
                B.g((x + off, cy - .03, z + face + .03 * side), (bay_w - .08, bay_h - .08, .04), 'blue', bevel=.01)
                B.g((x + off + bay_w / 2 + .13, cy, z + face + .025 * side), (.1, bay_h + .1, .06), 'yellow', bevel=.01)
            else:
                B.g((x + face + .012 * side, cy, z + off), (.05, bay_h + .1, bay_w + .14), 'navy', bevel=.015)
                B.g((x + face + .03 * side, cy - .03, z + off), (.04, bay_h - .08, bay_w - .08), 'blue', bevel=.01)
                B.g((x + face + .025 * side, cy, z + off + bay_w / 2 + .13), (.06, bay_h + .1, .1), 'yellow', bevel=.01)
    if perimeter:
        # pilasters break up the long boundary walls
        for k in range(-int(length / 6), int(length / 6) + 1):
            t = k * 6.0 + 3.0
            if abs(t) > length / 2 - .6:
                continue
            if long_x:
                B.g((x + t, y + .08, z), (.7, sy + .16, sz + .3), 'white', bevel=.08)
            else:
                B.g((x, y + .08, z + t), (sx + .3, sy + .16, .7), 'white', bevel=.08)


def cargo(B, c):
    x, y, z = c['pos']
    sx, sy, sz = c['size']
    B.g((x, y - 1.05, z), (sx + .6, .38, sz + .6), 'dark', bevel=.05)
    B.g((x, y, z), (sx, sy, sz), 'white', bevel=.1, segments=3)
    B.g((x, y + sy / 2 + .02, z), (sx - .5, .05, sz - .5), 'cap', bevel=.02)
    for k in range(-2, 3):
        B.g((x + k * 2.0, y + sy / 2 + .07, z), (.12, .1, sz - .3), 'seam', bevel=.02)
    for side in (-1, 1):
        fz = z + sz / 2 * side
        B.g((x, y - .25, fz + .02 * side), (sx * .78, 1.1, .05), 'seam', bevel=.01)
        for end in (-1, 1):
            ex = x + end * (sx / 2 - .32)
            B.g((ex, y - .02, fz + .04 * side), (.55, sy - .2, .1), 'blue', bevel=.02)
            for s in range(3):
                B.g((ex - .18 + s * .18, y - .02, fz + .1 * side), (.06, sy - .5, .05), 'yellow')
    for end in (-1, 1):
        B.g((x + end * (sx / 2 + .03), y - .05, z), (.08, sy - .3, sz - .3), 'blue', bevel=.02)
        for s in range(4):
            B.g((x + end * (sx / 2 + .08), y - .05, z - .9 + s * .6), (.05, sy - .6, .16), 'yellow')


def floor(B, F):
    fx, fy, fz = F['floor']['pos']
    sx, sy, sz = F['floor']['size']
    top = fy + sy / 2
    B.g((fx, fy, fz), (sx, sy, sz), 'floor')
    for x in range(-24, 25, 2):
        B.g((x, top + .002, 0), (.03, .004, sz), 'tile')
    for z in range(-30, 31, 2):
        B.g((0, top + .003, z), (sx, .004, .03), 'tile')
    for (cx, cz), (w, d) in F['blue_zones']:
        B.g((cx, top + .006, cz), (w, .01, d), 'blue_floor')
        inset = .35
        for s in (-1, 1):
            B.g((cx, top + .013, cz + s * (d / 2 - inset)), (w - 2 * inset, .006, .07), 'paint')
            B.g((cx + s * (w / 2 - inset), top + .013, cz), (.07, .006, d - 2 * inset), 'paint')
    for hx, hz in F['hazards']:
        for i in range(6):
            B.g((hx + i * .42, top + .016, hz), (.2, .006, 2.6), 'yellow', rot_z=.5)
    for (ax, az) in F['arrows']:
        s = 1 if ax < 0 else -1
        tri = bmesh.new()
        for vx, vz in [(0, -.6), (0, .6), (1.0, 0)]:
            tri.verts.new(gp(ax + vx * s, top + .016, az + vz))
        tri.faces.new(tri.verts)
        me = bpy.data.meshes.new('_arrow')
        tri.to_mesh(me)
        tri.free()
        B.mesh_from(me, Matrix.Identity(4), 'yellow')
        bpy.data.meshes.remove(me)
    # docking bays by the north wall
    for dx in LAYOUT['doors']:
        B.g((dx, top + .01, -18.15), (3, .012, 1), 'navy')
        for s in (-1, 1):
            B.g((dx + s * 1.6, top + .014, -18.1), (.13, .01, 1.2), 'yellow')
    # vent grates along long walls
    for (wx, wy, wz), (wsx, wsy, wsz) in F['walls']:
        if wsx > wsz and wsy > 2:
            B.g((wx, top + .01, wz + wsz / 2 + .45), (wsx * .7, .012, .45), 'grate')
            for i in range(int(wsx * .7 / .2)):
                B.g((wx - wsx * .35 + .1 + i * .2, top + .018, wz + wsz / 2 + .45), (.05, .008, .4), 'dark')
    # sector number painted on the floor
    sn = F['sector_number']
    font_path = next((p for p in FONT_PATHS if os.path.exists(p)), None)
    cu = bpy.data.curves.new('sector_no', 'FONT')
    cu.body = {'black': '07'}.get(THEME, sn['text'])  # each sector paints its own number
    if font_path:
        cu.font = bpy.data.fonts.load(font_path, check_existing=True)
    cu.size = sn['size']
    cu.align_x = 'CENTER'
    cu.align_y = 'CENTER'
    cu.space_character = .92
    tmp = bpy.data.objects.new('sector_no', cu)
    bpy.context.scene.collection.objects.link(tmp)
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(tmp.evaluated_get(dg))
    bpy.data.objects.remove(tmp)
    bpy.data.curves.remove(cu)
    sx_, sz_ = sn['pos']
    B.mesh_from(me, Matrix.Translation(gp(sx_, top + .018, sz_)), 'paint')
    bpy.data.meshes.remove(me)


def rails(B, F):
    top = 0.0
    for rz in F['rails']:
        B.g((0, .02, rz), (48, .04, .42), 'dark')
        for dz in (-.13, .13):
            B.cylinder(gp(0, .32, rz + dz), .05, 47.2, 'steel')
        for x in range(-22, 23, 3):
            B.g((x, .17, rz), (.14, .3, .42), 'dark', bevel=.02)


# ---------------------------------------------------------------- enemy kit
def enemy_kit(col):
    """Chunky graphite drones with ember eyes. Sizes match actor.gd part sizes (Godot units)."""
    body = mat('enemy_graphite', srgb('2a2e35'), .45, .25)
    joint = mat('enemy_joint', srgb('14181e'), .5, .3)
    eye = mat('enemy_eye', srgb('ff5a2c'), .3, 0, 6.0)
    plate = mat('enemy_plate', srgb('3b414b'), .4, .3)
    objs = []

    def part(name, items):
        order = []
        for item in items:
            if item[2] not in order:
                order.append(item[2])
        b = Builder(order)
        for (pos, size, m, bev) in items:
            b.g(pos, size, m, bevel=bev)
        objs.append(b.to_object(name, col))

    part('enemy_torso', [((0, 0, 0), (.45, .54, .32), body, .06),
                         ((0, .06, -.165), (.26, .2, .03), plate, .01),
                         ((-.07, .06, -.183), (.05, .05, .02), eye, 0),
                         ((.07, .06, -.183), (.05, .05, .02), eye, 0)])
    part('enemy_head', [((0, 0, 0), (.48, .45, .45), body, .07),
                        ((0, -.03, -.226), (.36, .14, .03), joint, .01),
                        ((-.09, -.03, -.243), (.09, .06, .02), eye, 0),
                        ((.09, -.03, -.243), (.09, .06, .02), eye, 0),
                        ((0, .245, .04), (.22, .05, .22), plate, .015)])
    part('enemy_arm', [((0, 0, 0), (.17, .44, .22), joint, .04),
                       ((0, .13, 0), (.2, .16, .25), body, .04)])
    part('enemy_leg', [((0, 0, 0), (.18, .5, .23), joint, .04),
                       ((0, .05, -.02), (.2, .14, .25), body, .03)])
    part('enemy_foot', [((0, 0, 0), (.2, .15, .32), body, .04)])
    part('enemy_shield', [((0, 0, 0), (.6, .75, .12), plate, .04),
                          ((0, 0, -.065), (.4, .08, .02), eye, 0)])
    part('enemy_gun', [((0, 0, 0), (.17, .15, .51), joint, .03),
                       ((0, 0, -.27), (.08, .08, .08), eye, 0)])
    part('enemy_crown', [((0, 0, 0), (.55, .23, .52), plate, .05),
                         ((0, 0, -.265), (.4, .08, .02), eye, 0)])
    return objs


# ---------------------------------------------------------------- export
def export(objs, path, scene):
    for sc in bpy.data.scenes:
        for vl in sc.view_layers:
            for o in sc.objects:
                try:
                    o.select_set(o in objs, view_layer=vl)
                except RuntimeError:
                    pass
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True,
                              export_apply=True, export_yup=True, export_materials='EXPORT')


def build():
    prev = bpy.context.window.scene if bpy.context.window else None
    for name in ('SectorArena' + SUFFIX,):
        if name in bpy.data.scenes:
            old = bpy.data.scenes[name]
            for o in list(old.objects):
                bpy.data.objects.remove(o)
            bpy.data.scenes.remove(old)
    for o in list(bpy.data.objects):  # only orphans (objects in no scene); each theme's own scene was removed above
        if o.name.startswith(('ArenaFloor', 'ArenaProps', 'enemy_')) and not o.users_scene:
            bpy.data.objects.remove(o)
    for me in list(bpy.data.meshes):
        if me.users == 0:
            bpy.data.meshes.remove(me)
    scene = bpy.data.scenes.new('SectorArena' + SUFFIX)
    win = bpy.context.window or (bpy.context.window_manager.windows[0] if bpy.context.window_manager.windows else None)
    if win:
        prev = win.scene
        win.scene = scene
    arena_col = bpy.data.collections.new('Arena')
    kit_col = bpy.data.collections.new('EnemyKit')
    scene.collection.children.link(arena_col)
    scene.collection.children.link(kit_col)

    with bpy.context.temp_override(window=win, scene=scene) if win else _null():
        fb = Builder()
        floor(fb, LAYOUT)
        floor_ob = fb.to_object('ArenaFloor', arena_col)
        pb = Builder()
        for pos, size in LAYOUT['perimeter']:
            wall_module(pb, pos, size, perimeter=True)
        for pos, size in LAYOUT['walls']:
            wall_module(pb, pos, size)
        cargo(pb, LAYOUT['cargo'])
        rails(pb, LAYOUT)
        props_ob = pb.to_object('ArenaProps', arena_col)
        kit = enemy_kit(kit_col)
        for o in kit:
            o.location.x += 30 + kit.index(o) * 1.2  # spread out for viewing; exported transforms are reset below
        os.makedirs(OUT, exist_ok=True)
        export([floor_ob, props_ob], os.path.join(OUT, 'arena%s.glb' % SUFFIX), scene)
        for o in kit:
            o.location.x = 0
        if THEME == 'white': export(kit, os.path.join(OUT, 'enemy_kit.glb'), scene)  # enemies are shared across themes
        for i, o in enumerate(kit):
            o.location.x = 30 + i * 1.2
        bpy.data.libraries.write(os.path.join(SRC, 'arena%s.blend' % SUFFIX), {scene}, fake_user=True, compress=True)
    if win and prev and not bpy.app.background:
        win.scene = prev
    print('ARENA_OK', len(props_ob.data.polygons), len(floor_ob.data.polygons))


class _null:
    def __enter__(self): return self
    def __exit__(self, *a): return False


build()
