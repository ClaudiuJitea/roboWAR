"""Sector 03 weapon kit: seven guns plus rocket and grenade projectiles -> assets/models/weapons.glb.

Run headless:  blender -b -t 4 --factory-startup --python source_art/blender/build_weapons.py
Or execute through the Blender MCP add-on (builds in the active scene, then parks the kit in a WeaponKit scene).
Each gun's origin is the grip (top of the right fist), it points along -Y like the fighters, and it carries
a Muzzle_<id> empty at the barrel tip. Godot mounts the guns on each fighter's Grip_<Name> socket.
"""
import bpy, bmesh, math, os, sys
from mathutils import Matrix, Vector

try:
    HERE = os.path.dirname(os.path.abspath(__file__))
except NameError:
    HERE = '/home/clau/dev/RoboWar/source_art/blender'
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, HERE)
from caster_hand import caster_hand  # noqa: E402
OUT = os.path.join(ROOT, 'assets', 'models', 'weapons.glb')


def srgb(h):
    h = h.lstrip('#')
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4 for v in c)


def mat(name, color, metal=0.0, rough=.45, emit=0.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Metallic'].default_value = metal
    p.inputs['Roughness'].default_value = rough
    if emit:
        p.inputs['Emission Color'].default_value = (*color, 1)
        p.inputs['Emission Strength'].default_value = emit
    return m


WHITE = mat('wpn_ceramic', (.80, .77, .70), 0, .42)
DARK = mat('wpn_graphite', (.022, .025, .03), .2, .5)
METAL = mat('wpn_gunmetal', (.12, .14, .17), .7, .35)
GLASS = mat('wpn_lens', (.10, .25, .30), .3, .05)
ACCENTS = {
    'minigun': '1d5fe0', 'sword': 'ff7a1a', 'pistol': 'f0b020', 'railrifle': '18c8c8',
    'gauntlet': '9a4ae8', 'sniper': 'f2a01e',
    'rifle': 'f2a01e', 'smg': 'f2a01e', 'shotgun': 'f2a01e', 'railgun': '6fe8ff',
    'rocket': 'f2a01e', 'grenade': '7ddc3a', 'plasma': 'b06cff',
}



class Part:
    """One multi-material mesh assembled from bevelled boxes and cylinders (bmesh only)."""

    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.mats = []
        self.scratch = bpy.data.meshes.new('_wpn_scratch')

    def _commit(self, t, material, matrix, smooth=True):
        if material not in self.mats:
            self.mats.append(material)
        for f in t.faces:
            f.material_index = self.mats.index(material)
            f.smooth = smooth
        bmesh.ops.transform(t, matrix=matrix, verts=t.verts)
        t.to_mesh(self.scratch)
        t.free()
        self.bm.from_mesh(self.scratch)

    def box(self, pos, size, material, bevel=.02):
        t = bmesh.new()
        bmesh.ops.create_cube(t, size=1.0)
        bmesh.ops.scale(t, vec=size, verts=t.verts)
        if bevel:
            bmesh.ops.bevel(t, geom=list(t.verts) + list(t.edges), offset=min(bevel, min(size) * .45),
                            segments=2, affect='EDGES', profile=.5, clamp_overlap=True)
        self._commit(t, material, Matrix.Translation(pos))

    def cyl(self, pos, radius, depth, material, axis='Y', segs=14, radius2=None, spin=0.0, flat=False):
        t = bmesh.new()
        bmesh.ops.create_cone(t, cap_ends=True, segments=segs, radius1=radius,
                              radius2=radius if radius2 is None else radius2, depth=depth)
        if spin:  # turn about its own axis, e.g. pi/8 puts an octagon's flats on top
            bmesh.ops.rotate(t, verts=t.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(spin, 3, 'Z'))
        rot = {'Y': Matrix.Rotation(math.pi / 2, 4, 'X'), 'X': Matrix.Rotation(math.pi / 2, 4, 'Y')}.get(axis, Matrix.Identity(4))
        self._commit(t, material, Matrix.Translation(pos) @ rot, smooth=not flat)

    def prism(self, outline, thickness, material):
        """Flat solid from a 2D outline (x, y) in the XY plane, `thickness` along Z (concave outlines are fine)."""
        t = bmesh.new()
        top = [t.verts.new((x, y, thickness / 2)) for x, y in outline]
        bot = [t.verts.new((x, y, -thickness / 2)) for x, y in outline]
        t.faces.new(top)
        t.faces.new(list(reversed(bot)))
        n = len(outline)
        for i in range(n):
            j = (i + 1) % n
            t.faces.new((top[i], bot[i], bot[j], top[j]))
        bmesh.ops.recalc_face_normals(t, faces=t.faces)
        self._commit(t, material, Matrix.Identity(4))

    def side(self, outline, width, material, x=0.0, bevel=.006):
        """Side-profile solid: 2D outline in (y, z) extruded `width` along X, centred on `x`, edges softened."""
        t = bmesh.new()
        a = [t.verts.new((x + width / 2, y, z)) for y, z in outline]
        b = [t.verts.new((x - width / 2, y, z)) for y, z in outline]
        t.faces.new(a)
        t.faces.new(list(reversed(b)))
        n = len(outline)
        for i in range(n):
            j = (i + 1) % n
            t.faces.new((a[i], b[i], b[j], a[j]))
        bmesh.ops.recalc_face_normals(t, faces=t.faces)
        if bevel:
            rim = [e for e in t.edges if len(e.link_faces) == 2 and abs(e.verts[0].co.x - e.verts[1].co.x) < 1e-6]
            bmesh.ops.bevel(t, geom=rim, offset=min(bevel, width * .4), segments=2, affect='EDGES', profile=.5, clamp_overlap=True)
        bmesh.ops.triangulate(t, faces=[f for f in t.faces if len(f.verts) > 4])
        self._commit(t, material, Matrix.Identity(4))

    def sphere(self, pos, radius, material):
        t = bmesh.new()
        bmesh.ops.create_uvsphere(t, u_segments=12, v_segments=8, radius=radius)
        self._commit(t, material, Matrix.Translation(pos))

    def finish(self, col, muzzle=None, tilt=0.0, yaw=0.0, scale=1.0):
        if scale != 1.0:  # uniform scale about the grip (origin)
            bmesh.ops.scale(self.bm, vec=(scale, scale, scale), verts=self.bm.verts)
            if muzzle is not None:
                muzzle = tuple(scale * c for c in muzzle)
        if tilt or yaw:  # bake pitch/yaw into the mesh so Godot can mount the node with an identity transform
            rot = Matrix.Rotation(yaw, 3, 'Z') @ Matrix.Rotation(tilt, 3, 'X')
            bmesh.ops.rotate(self.bm, verts=self.bm.verts, cent=(0, 0, 0), matrix=rot)
            if muzzle is not None:
                muzzle = tuple(rot @ Vector(muzzle))
        me = bpy.data.meshes.new(self.name)
        for m in self.mats:
            me.materials.append(m)
        self.bm.to_mesh(me)
        self.bm.free()
        bpy.data.meshes.remove(self.scratch)
        ob = bpy.data.objects.new(self.name, me)
        col.objects.link(ob)
        ob.modifiers.new('weighted', 'WEIGHTED_NORMAL').keep_sharp = True
        objs = [ob]
        if muzzle is not None:
            tip = bpy.data.objects.new('Muzzle_' + self.name[2:], None)
            tip.empty_display_size = .05
            col.objects.link(tip)
            tip.parent = ob
            tip.location = muzzle
            objs.append(tip)
        return objs


def guns(col):
    out = []
    A = {k: mat('wpn_accent_' + k, srgb(v), .1, .4) for k, v in ACCENTS.items()}
    G = {k: mat('wpn_glow_' + k, srgb(v), 0, .3, 5.0) for k, v in ACCENTS.items()}

    # Shared rifle and SMG: chunky game-style guns traced from reference sheets (slate body, orange accents).
    # Grip origin is the top of the right fist; the 'gun' stance puts the left glove at (-.03, -.25, -.06).
    SLATE = mat('wpn_slate', srgb('3a3f47'), .25, .5)
    INSET = mat('wpn_slate_dark', srgb('22262c'), .2, .55)
    SILVER = mat('wpn_silver', srgb('b9bdc3'), .9, .28)
    def warhead(p):  # rocket: orange body, dark charge band, nose cone, tail rod with fins, exhaust glow (origin = body)
        for y, r, d, m, r2 in ((.0, .028, .2, SILVER, None), (-.04, .115, .074, A['rocket'], None),
                               (-.132, .105, .111, INSET, None), (-.27, .115, .166, A['rocket'], .03)):
            p.cyl((0, y, 0), r, d, m, segs=8, radius2=r2, spin=math.pi / 8, flat=True)
        for a in range(4):
            r = Matrix.Rotation(a * math.pi / 2, 4, 'Y')
            p.box(r @ Vector((.07, .08, 0)), (.08, .1, .012) if a % 2 == 0 else (.012, .1, .08), SLATE, .004)
        p.cyl((0, .11, 0), .03, .02, G['rocket'], segs=12)

    p = Part('W_rifle')  # chunky game assault rifle (AK-like): traced from the reference side view, 1 px = 3 mm
    ORANGE = A['rifle']
    p.box((0, -.087, .081), (.09, .366, .162), SLATE, .008)                  # receiver
    p.box((0, -.39, .081), (.084, .252, .12), SLATE, .008)                   # handguard
    p.box((0, -.39, .132), (.05, .24, .03), INSET, .005)                     # gas tube cover
    p.box((0, -.533, .095), (.06, .045, .13), SLATE, .006)                   # front sight block
    p.box((0, -.533, .175), (.022, .02, .04), SLATE, .004)                   # front sight post
    p.cyl((0, -.63, .081), .021, .18, SILVER, segs=16)                       # barrel
    p.cyl((0, -.722, .081), .011, .004, INSET, segs=10)                      # bore
    for y in (-.47, -.43):
        p.box((.043, y, .062), (.008, .03, .03), ORANGE, .003)               # handguard accents (right)
    p.box((-.043, -.45, .062), (.008, .07, .026), ORANGE, .003)              # handguard accent (left)
    p.box((0, -.255, .167), (.05, .03, .022), ORANGE, .004)                  # top tab
    p.box((.046, -.19, .102), (.012, .096, .024), ORANGE, .003)              # charging handle (right)
    p.box((.046, .06, .052), (.01, .048, .045), ORANGE, .003)                # rear accent block
    p.box((-.046, -.10, .078), (.008, .135, .024), SILVER, .003)             # ejection port (left)
    p.box((-.046, -.20, .045), (.01, .05, .03), ORANGE, .003)                # selector
    # red-dot on the receiver: two-tier block with a glowing lens
    p.box((0, -.096, .172), (.05, .07, .022), INSET, .004)
    p.box((0, -.10, .205), (.036, .05, .045), SLATE, .004)
    p.box((0, -.126, .205), (.026, .004, .028), G['rifle'], .001)
    p.box((0, -.074, .205), (.026, .004, .028), GLASS, .001)
    # lower: trigger guard, curved orange magazine with a dark base, raked grip
    p.side([(-.015, .005), (-.015, -.04), (-.105, -.04), (-.105, .005), (-.095, .005), (-.095, -.03), (-.025, -.03), (-.025, .005)], .02, SLATE, bevel=.003)
    p.side([(-.05, -.0), (-.058, -.0), (-.064, -.03), (-.056, -.03)], .01, INSET, bevel=0)  # trigger
    p.side([(-.24, .005), (-.105, .005), (-.11, -.07), (-.14, -.165), (-.195, -.25), (-.29, -.205), (-.262, -.13), (-.248, -.06)], .058, ORANGE, bevel=.007)  # magazine
    p.side([(-.195, -.25), (-.29, -.205), (-.305, -.232), (-.205, -.28)], .064, INSET, bevel=.004)  # mag base plate
    p.side([(-.024, .005), (.075, .005), (.114, -.159), (.015, -.159)], .07, SLATE, bevel=.008)  # grip
    # solid wedge stock with a dark butt pad
    p.side([(.096, .10), (.395, .096), (.395, -.084), (.096, -.009)], .07, SLATE, bevel=.008)
    p.side([(.395, .098), (.41, .098), (.41, -.086), (.395, -.086)], .076, INSET, bevel=.004)
    out += p.finish(col, (0, -.722, .081), scale=1.15)  # sized for the chunky gloves

    p = Part('W_smg')  # chunky game SMG (UMP-like): slate box receiver, orange straight mag, skeleton stock, silver stub
    # traced from the reference side view: 1 px = 2.3 mm, grip top (fist) at the origin
    ORANGE = A['smg']
    p.box((0, -.065, .094), (.088, .315, .098), SLATE, .008)                 # main receiver
    p.box((0, -.31, .087), (.080, .17, .085), SLATE, .008)                   # front block
    p.box((0, -.31, .082), (.090, .11, .052), INSET, .005)                   # dark side panels
    p.box((0, -.36, .142), (.026, .03, .026), SLATE, .004)                   # front sight post
    p.cyl((0, -.42, .082), .022, .08, SILVER, segs=16)                       # barrel stub
    p.cyl((0, -.458, .082), .012, .004, INSET, segs=10)                      # bore
    p.box((0, .02, .147), (.06, .06, .014), ORANGE, .003)                    # rear top plate
    p.box((.045, -.11, .112), (.012, .115, .022), ORANGE, .003)              # charging handle (right)
    p.box((-.045, -.035, .112), (.008, .10, .02), SILVER, .003)              # ejection port (left)
    p.box((.045, .055, .085), (.01, .04, .05), ORANGE, .003)                 # rear accent block
    p.box((-.045, -.20, .07), (.01, .035, .03), ORANGE, .003)                # selector
    # red-dot: two-tier block with a glowing lens
    p.box((0, -.085, .158), (.05, .07, .03), INSET, .004)
    p.box((0, -.09, .19), (.036, .05, .035), SLATE, .004)
    p.box((0, -.116, .19), (.026, .004, .022), G['smg'], .001)
    p.box((0, -.064, .19), (.026, .004, .022), GLASS, .001)
    # lower: trigger guard, straight orange magazine, angled grip
    p.side([(-.03, .046), (-.03, -.005), (-.095, -.005), (-.095, .046), (-.085, .046), (-.085, .006), (-.04, .006), (-.04, .046)], .02, SLATE, bevel=.003)
    p.side([(-.06, .03), (-.068, .03), (-.074, -.0), (-.066, -.0)], .01, INSET, bevel=0)  # trigger
    p.box((0, -.165, -.065), (.055, .085, .22), ORANGE, .006)                # magazine
    p.box((0, -.165, -.177), (.064, .095, .022), INSET, .004)                # mag base plate
    p.side([(.045, .048), (-.03, .048), (-.02, -.02), (.012, -.13), (.088, -.13), (.072, -.05), (.06, .048)], .07, SLATE, bevel=.008)  # grip, raked back
    # skeleton stock: top bar, diagonal lower strut and butt plate
    p.box((0, .21, .11), (.036, .25, .034), SLATE, .006)
    p.side([(.09, .06), (.09, .02), (.31, -.03), (.31, .01)], .036, SLATE, bevel=.006)
    p.box((0, .315, .04), (.046, .04, .18), SLATE, .006)
    p.box((0, .338, .04), (.05, .008, .17), INSET, .003)                     # butt pad
    out += p.finish(col, (0, -.46, .082), scale=1.3)  # sized for the chunky gloves

    p = Part('W_shotgun')  # chunky game pump shotgun: traced from the reference side view, 1 px = 3 mm
    # scaled 1.3x and built wide so it reads from the top-down camera; the pump sits racked back against a slightly shorter receiver so the
    # 'gun' support glove (y = -.25) still lands on it after scaling
    ORANGE = A['shotgun']
    RIB = mat('wpn_pump_groove', srgb('a8680c'), .1, .5)
    p.side([(.095, .125), (.42, .105), (.42, -.07), (.095, .025)], .09, SLATE, bevel=.008)    # wedge stock
    p.side([(.42, .107), (.434, .107), (.434, -.072), (.42, -.072)], .096, INSET, bevel=.004)  # butt pad
    p.box((0, -.0375, .075), (.115, .265, .15), SLATE, .01)                  # receiver
    p.box((0, -.045, .17), (.066, .09, .04), SLATE, .005)                    # rear sight base
    p.box((0, -.04, .203), (.034, .045, .03), INSET, .004)                   # rear sight
    p.box((.058, -.12, .117), (.008, .09, .036), SILVER, .003)               # ejection port (right)
    p.box((.062, -.12, .117), (.004, .07, .012), INSET, .001)
    p.box((.058, -.145, .042), (.01, .04, .018), ORANGE, .003)               # safety
    p.box((-.058, -.11, .06), (.01, .06, .02), ORANGE, .003)                 # shell latch (left)
    p.side([(-.054, .005), (.051, .005), (.102, -.15), (.006, -.15)], .085, SLATE, bevel=.008)  # raked grip
    p.side([(-.02, .005), (-.02, -.03), (-.115, -.03), (-.115, .005), (-.105, .005), (-.105, -.02), (-.03, -.02), (-.03, .005)], .02, SLATE, bevel=.003)
    p.side([(-.05, .0), (-.06, .0), (-.066, -.028), (-.056, -.028)], .012, ORANGE, bevel=0)  # trigger
    p.cyl((0, -.411, .111), .036, .49, SILVER, segs=18)                      # barrel
    p.cyl((0, -.391, .045), .031, .45, SILVER, segs=16)                      # magazine tube
    p.cyl((0, -.618, .045), .026, .012, INSET, segs=16)                      # tube cap
    p.box((0, -.631, .12), (.09, .03, .1), SLATE, .006)                      # front barrel block
    p.box((0, -.631, .175), (.02, .02, .02), ORANGE, .003)                   # bead sight
    p.cyl((0, -.657, .111), .022, .004, INSET, segs=14)                      # bore
    p.box((0, -.2885, .04), (.112, .225, .11), RIB, .006)                   # pump core (grooves)
    for k in range(6):
        p.box((0, -.194 - k * .038, .04), (.124, .026, .122), ORANGE, .005)  # pump ribs
    out += p.finish(col, (0, -.657, .111), scale=1.3)

    p = Part('W_railgun')  # railgun: ceramic body, twin rails, glowing coil strip
    p.box((0, .14, 0), (.12, .22, .14), DARK, .03)
    p.box((0, -.20, .05), (.20, .58, .18), WHITE, .05)
    for x in (-.06, .06):
        p.box((x, -.76, .05), (.045, .66, .10), DARK, .015)
    p.box((0, -.76, .05), (.05, .62, .035), G['railgun'], .006)
    for y in (-.52, -.72, -.92):
        p.box((0, y, .05), (.2, .04, .14), A['railgun'], .01)
    out += p.finish(col, (0, -1.10, .05))

    p = Part('W_rocket')  # chunky game rocket launcher (RPG-like), traced from the reference side view, 1 px = 3.7 mm
    # shoulder-fired ('shoulder' stance): the tube rides on the right pauldron, so the optic sits on the tube's
    # left side at visor height instead of on top. -Y ends of a cyl take radius2.
    ORANGE = A['rocket']
    def oct(pos, r, depth, m, r2=None):
        p.cyl(pos, r, depth, m, segs=8, radius2=r2, spin=math.pi / 8, flat=True)  # faceted, flat top and sides
    oct((0, -.102, .124), .105, .87, SLATE)                                  # launch tube
    oct((0, .413, .124), .14, .196, SLATE, r2=.105)                          # rear venturi flare
    oct((0, .512, .124), .1, .006, INSET)                                    # venturi mouth
    oct((0, .314, .124), .109, .022, ORANGE)                                 # rear band
    oct((0, -.50, .124), .109, .022, ORANGE)                                 # front band
    oct((0, -.564, .124), .133, .092, SLATE)                                 # front collar
    oct((0, -.611, .124), .1, .004, INSET)                                   # tube mouth
    # side plate (right) and optic (left)
    p.box((.104, -.20, .13), (.008, .11, .06), ORANGE, .004)
    p.box((.109, -.20, .13), (.004, .08, .008), INSET, .001)
    p.box((-.122, -.146, .124), (.04, .14, .05), INSET, .006)                # optic bracket
    p.box((-.185, -.146, .124), (.09, .266, .13), ORANGE, .01)               # optic body
    p.box((-.185, -.03, .14), (.06, .04, .07), INSET, .004)                  # eyepiece hood
    p.box((-.185, -.008, .14), (.04, .004, .046), GLASS, .001)
    p.box((-.185, -.281, .14), (.05, .004, .05), G['rocket'], .001)         # objective lens
    # rear trigger grip, trigger guard and the forward support grip on silver brackets
    p.box((0, .01, .012), (.07, .14, .03), SILVER, .004)
    p.side([(-.055, .005), (.074, .005), (.088, -.22), (-.02, -.235)], .07, SLATE, bevel=.008)
    for z in (-.08, -.15):
        p.box((.036, .02, z), (.006, .03, .022), ORANGE, .002)
    p.side([(-.055, .005), (-.055, -.012), (-.16, -.012), (-.17, .005), (-.17, -.11), (-.16, -.11),
            (-.16, -.025), (-.06, -.025), (-.06, .005)], .02, SLATE, bevel=.003)
    p.side([(-.085, .0), (-.097, .0), (-.104, -.06), (-.092, -.06)], .012, ORANGE, bevel=0)  # trigger
    p.box((0, -.38, .012), (.07, .13, .03), SILVER, .004)
    p.side([(-.315, .005), (-.444, .005), (-.43, -.21), (-.33, -.21)], .066, SLATE, bevel=.008)
    for z in (-.07, -.14):
        p.box((.034, -.38, z), (.006, .03, .022), ORANGE, .002)
    # the loaded warhead is its own node (Load_rocket, the same mesh as the P_rocket in flight): the game hides it
    # when the rocket leaves and shows it again during the reload; the muzzle marker sits at its origin, so the
    # rocket in flight starts exactly where the loaded one was
    gun = p.finish(col, (0, -.645, .124))
    load = Part('Load_rocket')
    warhead(load)
    ld = load.finish(col)
    ld[0].parent = gun[0]; ld[0].location = (0, -.645, .124)
    out += gun + ld

    p = Part('W_grenade')  # grenade launcher: revolving drum, short fat barrel
    p.box((0, .14, -.01), (.1, .2, .12), DARK, .03)
    p.box((0, -.10, .05), (.13, .30, .14), DARK, .03)
    p.cyl((0, -.18, -.01), .11, .2, WHITE, segs=12)
    for i in range(6):
        a = i * math.tau / 6
        p.cyl((math.cos(a) * .07, -.18, -.01 + math.sin(a) * .07), .025, .205, A['grenade'], segs=8)
    p.cyl((0, -.48, .06), .065, .34, METAL, segs=16)
    p.cyl((0, -.64, .06), .078, .05, A['grenade'], segs=16)
    out += p.finish(col, (0, -.68, .06))

    p = Part('W_plasma')  # plasma caster: rounded body, glowing cell, emitter prongs
    p.box((0, .12, 0), (.11, .2, .13), DARK, .03)
    p.box((0, -.25, .06), (.17, .56, .20), WHITE, .08)
    p.box((.09, -.22, .07), (.02, .3, .09), G['plasma'], .008)
    p.box((-.09, -.22, .07), (.02, .3, .09), G['plasma'], .008)
    for x in (-.055, .055):
        p.box((x, -.60, .06), (.035, .18, .05), DARK, .012)
    p.sphere((0, -.64, .06), .045, G['plasma'])
    out += p.finish(col, (0, -.66, .06))

    # ---------------------------------------------------------------- signature weapons ("The Six" sheet)
    p = Part('W_minigun')  # Magnus: heavy gatling, cream receiver, blue feed box, spinning barrel cluster
    p.box((0, -.14, .05), (.30, .48, .28), WHITE, .07)
    p.box((0, -.14, .20), (.24, .30, .04), A['minigun'], .015)
    p.box((.24, -.06, -.01), (.18, .30, .28), A['minigun'], .05)
    p.box((.24, -.06, .14), (.12, .2, .04), DARK, .015)
    p.box((-.05, .14, .0), (.12, .16, .18), DARK, .04)
    p.box((0, -.30, .24), (.08, .20, .07), DARK, .02)
    p.cyl((0, -.42, .06), .12, .08, DARK, segs=18)
    gun = p.finish(col, (0, -1.38, .06))
    spin = Part('Spin_minigun')
    spin.cyl((0, 0, 0), .095, .10, METAL, segs=18)
    for a in range(6):
        t = a * math.tau / 6
        spin.cyl((math.cos(t) * .068, -.40, math.sin(t) * .068), .03, .80, DARK, segs=10)
    spin.cyl((0, -.18, 0), .125, .06, A['minigun'], segs=18)
    spin.cyl((0, -.76, 0), .125, .07, A['minigun'], segs=18)
    spin.cyl((0, -.40, 0), .045, .76, METAL, segs=10)
    sp = spin.finish(col)
    sp[0].parent = gun[0]; sp[0].location = (0, -.50, .06)
    out += gun + sp

    p = Part('W_sword')  # Albert: plasma katana. Gentle curve (sori) toward the spine, edge on the convex (-X) side,
    # long two-hand tsuka behind the grip origin (right hand at the tsuba, left hand at the pommel)
    R, ARC, BASE = 3.0, .5, .07       # arc radius, sweep (rad) -> ~1.5 m blade; blade starts just past the tsuba
    def edge(t, off):
        th = ARC * t
        sx, sy = R - R * math.cos(th), -(BASE + R * math.sin(th))
        nx, ny = -math.cos(th), -math.sin(th)
        return (sx - nx * off, sy - ny * off)
    def blade_outline(w0, w1, tip_len):
        n = 18
        spine = [edge(i / n, 0.0) for i in range(n + 1)]
        cut = [edge(i / n, -(w0 + (w1 - w0) * (i / n) ** 1.2)) for i in range(n + 1)]
        th = ARC
        tip = (R - R * math.cos(th) + math.sin(th) * tip_len, -(BASE + R * math.sin(th)) - math.cos(th) * tip_len)
        kissaki = edge(1.0, -(w1 * .55))
        return spine + [tip, (kissaki[0] - math.sin(th) * tip_len * .2, kissaki[1] - math.cos(th) * tip_len * .2)] + list(reversed(cut))
    core = mat('wpn_plasma_core', srgb('fff0c8'), 0, .2, 3.5)
    plasma = mat('wpn_plasma_blade', srgb('ff5a0a'), 0, .3, 2.2)
    aura = mat('wpn_plasma_aura', srgb('ff3200'), 0, .3, 2.5)
    aura.node_tree.nodes.get('Principled BSDF').inputs['Alpha'].default_value = .28
    if hasattr(aura, 'surface_render_method'):
        aura.surface_render_method = 'BLENDED'
    p.prism(blade_outline(.19, .11, .2), .06, aura)        # wide plasma aura
    p.prism(blade_outline(.13, .075, .16), .03, plasma)     # plasma blade
    p.prism(blade_outline(.04, .02, .1), .034, core)        # white-hot shinogi line along the spine
    # habaki, round tsuba, wrapped tsuka and kashira (pommel)
    p.box((0, -.04, 0), (.05, .06, .045), A['sword'], .01)
    p.cyl((0, -.005, 0), .1, .025, METAL, axis='Y', segs=20)
    p.cyl((0, -.005, 0), .085, .03, DARK, axis='Y', segs=20)
    p.cyl((0, .17, 0), .034, .33, DARK, axis='Y', segs=12)
    for k in range(6):
        p.box((0, .04 + k * .05, 0), (.075, .018, .075), A['sword'], .006)
    p.cyl((0, .345, 0), .04, .04, METAL, axis='Y', segs=12)
    th = ARC
    tip = (R - R * math.cos(th) + math.sin(th) * .2, -(BASE + R * math.sin(th)) - math.cos(th) * .2, 0)
    out += p.finish(col, tip)  # muzzle = blade tip (swing trail); no baked tilt: the pose solver aims the blade

    p = Part('W_pistol')  # Theo: cream sidearm with amber panels and a glowing cell
    p.box((0, -.15, .07), (.12, .30, .13), WHITE, .035)
    p.box((0, -.17, .155), (.11, .34, .06), WHITE, .02)
    for x in (-.062, .062):
        p.box((x, -.14, .08), (.012, .16, .06), A['pistol'], .004)
    p.box((0, -.02, -.06), (.09, .11, .19), DARK, .025)
    p.cyl((0, -.35, .13), .028, .06, DARK, segs=10)
    p.box((0, -.06, .19), (.04, .06, .02), G['pistol'], .004)
    out += p.finish(col, (0, -.39, .13), scale=1.5)  # sized for the chunky gloves

    p = Part('W_railrifle')  # Iris: long ceramic rail rifle with a teal energy channel
    p.box((0, .17, 0), (.12, .28, .15), WHITE, .04)
    p.box((0, -.22, .05), (.15, .52, .18), WHITE, .05)
    p.box((0, -.22, .145), (.10, .34, .02), A['railrifle'], .006)
    p.box((0, -.06, -.10), (.08, .10, .16), DARK, .02)
    p.box((0, -.92, .06), (.10, .92, .12), DARK, .02)
    p.box((0, -.92, .125), (.05, .86, .02), G['railrifle'], .005)
    for x in (-.052, .052):
        p.box((x, -.92, .06), (.008, .80, .05), G['railrifle'], .003)
    for y in (-.55, -1.25):
        p.box((0, y, .06), (.13, .05, .15), A['railrifle'], .012)
    out += p.finish(col, (0, -1.40, .06))

    p = Part('W_gauntlet')  # Seren: open armoured caster hand on the right fist, palm emitter and a floating holo panel
    # origin = grip point inside the fist. The glove's knuckle face is +Z, the palm faces -X and the fingers run
    # forward (-Y); the cast stance rolls the hand palm up (hold up = +X), so the panel floats on the -X side.
    holo = mat('wpn_holo', srgb('b06cff'), 0, .3, 3.0)
    holo.node_tree.nodes.get('Principled BSDF').inputs['Alpha'].default_value = .38
    if hasattr(holo, 'surface_render_method'):
        holo.surface_render_method = 'BLENDED'
    for c, m in caster_hand(1):
        if c[0] == 'box':
            p.box(c[1], c[2], {'dark': DARK, 'white': WHITE, 'accent': A['gauntlet'], 'glow': G['gauntlet']}[m], c[3])
        else:
            p.cyl(c[1], c[2], c[3], {'dark': DARK, 'accent': A['gauntlet'], 'glow': G['gauntlet']}[m], axis='X', segs=20)
    # holo panel hovering just off the palm, tilted toward the target, with a bright frame and scan lines
    tilt = Matrix.Rotation(-.30, 3, 'X')
    turn = Matrix.Rotation(-math.pi / 2, 3, 'Y')  # panel built palm-up (+Z), turned onto the palm side (-X)
    def hb(pos, size, m):
        v = turn @ (tilt @ Vector(pos) + Vector((0, -.08, .36)))
        p.box(v, (size[2], size[1], size[0]), m, .002)
    hb((0, 0, 0), (.30, .012, .36), holo)
    for z in (-.18, .18):
        hb((0, 0, z), (.32, .016, .014), G['gauntlet'])
    for x in (-.155, .155):
        hb((x, 0, 0), (.014, .016, .36), G['gauntlet'])
    for z in (-.08, -.02, .04, .10):
        hb((-.03, 0, z), (.18, .016, .008), G['gauntlet'])
    out += p.finish(col, (-.12, -.30, 0))  # bolts leave the palm, under the panel

    p = Part('W_sniper')  # Nadia: chunky game bolt-action sniper, traced from the reference side view, 1 px = 3.84 mm
    # scaled 1.3x so it reads from the top-down camera; built so the 'sniper' stance anchors land after scaling:
    # scope centre .238 -> 0.31 m over the grip (at the visor), stock end .258 -> .335 (the shoulder), magazine kept
    # behind the left glove under the receiver front (-.30, -.07)
    ORANGE = A['sniper']
    def oct(pos, r, depth, m):
        p.cyl(pos, r, depth, m, segs=8, spin=math.pi / 8, flat=True)
    # skeleton stock: butt plate, top and bottom bars, front strut, orange cheek pad
    p.box((0, .248, .02), (.075, .02, .23), INSET, .005)
    p.box((0, .16, .058), (.066, .17, .038), SLATE, .006)
    p.box((0, .16, -.038), (.066, .17, .038), SLATE, .006)
    p.box((0, .085, .01), (.066, .03, .14), SLATE, .006)
    p.box((0, .165, .11), (.07, .14, .066), ORANGE, .008)
    p.box((0, -.154, .077), (.08, .384, .154), SLATE, .008)                  # receiver
    p.box((0, -.154, .162), (.05, .37, .016), INSET, .004)                   # top rail
    p.box((.041, -.21, .072), (.006, .154, .022), SILVER, .003)              # bolt slot (right)
    p.box((.042, -.13, .042), (.008, .03, .02), ORANGE, .003)
    p.box((-.042, -.20, .05), (.008, .06, .02), ORANGE, .003)                # safety (left)
    p.cyl((.07, -.058, .045), .012, .06, SILVER, axis='X', segs=10)          # bolt handle
    p.sphere((.105, -.058, .045), .022, INSET)
    p.side([(-.058, .005), (.06, .005), (.1, -.134), (-.0, -.134)], .07, SLATE, bevel=.008)  # raked grip
    p.side([(-.03, .005), (-.03, -.045), (-.115, -.045), (-.115, .005), (-.105, .005), (-.105, -.035), (-.04, -.035), (-.04, .005)], .02, SLATE, bevel=.003)
    p.side([(-.065, .0), (-.077, .0), (-.083, -.035), (-.071, -.035)], .012, ORANGE, bevel=0)  # trigger
    p.box((0, -.155, -.055), (.06, .09, .11), ORANGE, .006)                  # box magazine
    p.box((0, -.155, -.115), (.066, .098, .016), INSET, .004)
    p.box((0, -.528, .086), (.07, .364, .096), SLATE, .008)                  # fore-end
    for y in (-.46, -.52, -.58):
        for x in (-.036, .036):
            p.box((x, y, .09), (.006, .036, .012), ORANGE, .002)             # orange dashes
    p.cyl((0, -.725, .121), .046, .04, SLATE, segs=14)                       # barrel collar at the fore-end
    p.cyl((0, -.975, .121), .034, .50, SILVER, segs=16)                      # heavy barrel
    p.box((0, -1.245, .121), (.084, .07, .076), SLATE, .008)                 # muzzle brake
    for y in (-1.228, -1.258):
        for x in (-.043, .043):
            p.box((x, y, .121), (.006, .012, .046), INSET, .002)             # brake ports
    p.cyl((0, -1.281, .121), .018, .004, INSET, segs=12)                     # bore
    # scope on two tall rings: eyepiece, turret tube, big objective, orange rings and caps
    p.box((0, -.17, .174), (.06, .17, .012), SLATE, .004)                   # mount base on the rail
    for y in (-.11, -.23):
        p.box((0, y, .184), (.064, .036, .024), INSET, .004)                 # ring towers
        p.box((0, y, .196), (.08, .036, .016), SLATE, .004)                  # ring clamps
    oct((0, -.033, .238), .056, .126, SLATE)
    oct((0, -.006, .238), .059, .022, ORANGE)
    oct((0, -.183, .238), .044, .176, SLATE)
    p.box((0, -.185, .298), (.046, .056, .036), ORANGE, .004)                 # elevation turret
    p.box((.054, -.185, .238), (.026, .046, .042), INSET, .004)               # windage turret
    oct((0, -.385, .238), .064, .23, SLATE)
    oct((0, -.475, .238), .068, .026, ORANGE)
    p.cyl((0, -.501, .238), .052, .004, G['sniper'], segs=16)                 # objective lens
    p.cyl((0, .031, .238), .042, .004, GLASS, segs=16)                        # ocular lens
    # deployed bipod under the fore-end: hinge, two legs with orange sleeves, feet
    p.box((0, -.632, .03), (.05, .04, .03), INSET, .004)
    for x in (-.03, .03):
        p.box((x, -.632, -.07), (.016, .02, .19), INSET, .004)
        p.box((x, -.632, -.07), (.022, .026, .04), ORANGE, .004)
        p.box((x, -.632, -.17), (.026, .03, .016), INSET, .004)
    out += p.finish(col, (0, -1.283, .121), scale=1.3)

    p = Part('P_rocket')  # rocket in flight: the same warhead as the launcher's Load_rocket
    warhead(p)
    out += p.finish(col)

    p = Part('P_grenade')  # grenade projectile: dark shell with a bright band
    p.box((0, 0, 0), (.16, .2, .16), DARK, .06)
    p.box((0, 0, 0), (.165, .05, .165), A['grenade'], .02)
    p.box((0, -.1, 0), (.05, .02, .05), G['grenade'], .005)
    out += p.finish(col)
    return out


def build():
    host = bpy.context.scene
    old = bpy.data.scenes.get('WeaponKit')
    if old:
        for o in list(old.objects):
            bpy.data.objects.remove(o)
        bpy.data.scenes.remove(old)
    for c in [c for c in bpy.data.collections if c.name.startswith('WeaponKit')]:
        for o in list(c.objects):
            bpy.data.objects.remove(o)
        bpy.data.collections.remove(c)
    col = bpy.data.collections.new('WeaponKit')
    host.collection.children.link(col)
    objs = guns(col)
    # spread the kit out for viewing in Blender; exported transforms are reset first
    for sc in bpy.data.scenes:
        for vl in sc.view_layers:
            for o in sc.objects:
                try:
                    o.select_set(False, view_layer=vl)
                except RuntimeError:
                    pass
    for o in objs:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', use_selection=True,
                              export_apply=True, export_materials='EXPORT')
    roots = [o for o in objs if o.parent is None]
    for i, o in enumerate(roots):
        o.location.x = 3 + i * .5
    bpy.data.libraries.write(os.path.join(HERE, 'weapons.blend'), {col}, fake_user=True, compress=True)
    if not bpy.app.background:
        sc = bpy.data.scenes.new('WeaponKit')
        sc.collection.children.link(col)
        host.collection.children.unlink(col)
    print('WEAPONS_OK', len(roots))


build()
