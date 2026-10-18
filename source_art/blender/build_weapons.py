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
    'minigun': 'f2a01e', 'sword': 'ff7a1a', 'pistol': 'f2a01e', 'railrifle': '18c8c8',
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

    def prism(self, outline, thickness, material, smooth=True):
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
        self._commit(t, material, Matrix.Identity(4), smooth=smooth)

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

    p = Part('W_grenade')  # revolver-drum grenade launcher traced from the reference side view at 2.3 mm per pixel,
    # scaled 1.3x (pixel x 318 / y 132 = grip origin, top of the pistol grip); the vertical foregrip lands on the
    # 'launcher' stance's left glove (support -.55), ahead of the drum so the drum stays in view
    ORANGE = A['rifle']
    def P(x, y):
        return ((x - 318) * .0023, (132 - y) * .0023)
    def S(pts, w, m, x=0.0, bevel=.004):
        p.side([P(*q) for q in pts], w, m, x=x, bevel=bevel)
    def B(x0, y0, x1, y1, w, m, x=0.0, bevel=.004):
        (ya, za), (yb, zb) = P(x0, y0), P(x1, y1)
        p.box((x, (ya + yb) / 2, (za + zb) / 2), (w, abs(ya - yb), abs(za - zb)), m, bevel)
    def C(x0, x1, y, r, m, segs=12, flat=True):  # cylinder along the barrel axis, from pixel x0 to x1, radius in px
        (ya, z), (yb, _) = P(x0, y), P(x1, y)
        p.cyl((0, (ya + yb) / 2, z), r * .0023, abs(ya - yb), m, segs=segs, spin=math.pi / segs, flat=flat)
    # barrel: silver tube, dark clamp with the foregrip, green glowing muzzle ring
    C(74, 200, 92, 17, SILVER, segs=16, flat=False)
    C(56, 76, 92, 21, G['grenade'], segs=12)
    C(54, 57, 92, 14, INSET, segs=12)
    B(124, 68, 156, 118, .1, SLATE, bevel=.006)
    B(128, 64, 152, 70, .07, INSET)
    S([(122, 116), (148, 116), (146, 186), (124, 186)], .05, INSET, bevel=.006)          # vertical foregrip
    for k in range(3):
        B(124, 134 + k * 16, 146, 140 + k * 16, .054, SLATE, bevel=.001)                # grip ribs
    B(184, 70, 202, 114, .1, SLATE, bevel=.005)                                         # rear barrel collar
    # revolving drum: faceted slate cylinder with orange end bands, six chambers on its face, orange cradle under it
    C(196, 270, 129, 49, SLATE, segs=12)
    for x0 in (198, 258):
        C(x0, x0 + 10, 129, 50.5, ORANGE, segs=12)
    for i in range(6):
        a = i * math.tau / 6 + math.pi / 6
        y, z = P(195, 129 + math.sin(a) * 30)
        p.cyl((math.cos(a) * 30 * .0023, y, z), .022, .008, INSET, segs=10)
    C(193, 197, 129, 10, INSET, segs=8)                                                 # axle
    S([(192, 150), (198, 150), (198, 172), (266, 172), (266, 150), (272, 150), (272, 180), (192, 180)], .06, ORANGE, bevel=.003)
    # receiver: stepped top with a hazard stripe and a red-dot sight, lower rear block with orange vents
    S([(182, 66), (196, 56), (330, 56), (340, 66), (340, 92), (182, 92)], .085, SLATE, bevel=.006)
    for k in range(6):
        B(206 + k * 9, 56, 213 + k * 9, 63, .088, ORANGE if k % 2 == 0 else INSET, bevel=.001)
    B(258, 38, 288, 54, .06, INSET, bevel=.004)                                         # red-dot sight
    B(256, 40, 259, 52, .045, GLASS, bevel=.001)
    B(264, 52, 284, 57, .04, SLATE, bevel=.002)
    S([(268, 90), (346, 90), (346, 128), (336, 134), (268, 134)], .075, SLATE, bevel=.006)
    for k in range(3):
        B(288 + k * 11, 100, 295 + k * 11, 108, .078, ORANGE, bevel=.001)               # vents
    B(276, 112, 330, 118, .078, INSET, bevel=.001)
    # trigger guard, orange trigger, raked orange pistol grip with a dark panel
    S([(282, 132), (312, 132), (312, 150), (286, 150), (286, 146), (308, 146), (308, 136), (282, 136)], .02, SLATE, bevel=.002)
    S([(294, 133), (300, 133), (298, 144), (293, 142)], .012, ORANGE, bevel=0)
    S([(312, 132), (344, 132), (350, 152), (344, 188), (322, 188), (318, 160)], .055, ORANGE, bevel=.006)
    S([(322, 140), (338, 140), (340, 158), (334, 178), (326, 178), (324, 158)], .058, INSET, bevel=.003)
    # skeleton stock: top bar with an orange cheek riser, diagonal strut, dark buttplate with an orange stripe
    S([(344, 88), (420, 88), (420, 102), (344, 102)], .045, SLATE, bevel=.004)
    S([(364, 82), (412, 82), (412, 96), (364, 96)], .052, ORANGE, bevel=.004)
    S([(346, 122), (346, 134), (420, 112), (420, 100)], .04, SLATE, bevel=.004)
    S([(418, 80), (434, 80), (434, 144), (418, 142)], .06, INSET, bevel=.006)
    S([(418, 86), (424, 86), (424, 136), (418, 136)], .062, ORANGE, bevel=.002)
    out += p.finish(col, (0, *P(54, 92)), scale=1.3)

    p = Part('W_plasma')  # plasma caster traced from the reference side view at 3.2 mm per pixel (pixel x 335 / y 135 =
    # grip origin, top of the pistol grip); the 'gun' stance's left glove (support -.25) lands on the lower fore-end
    # just ahead of the magazine, under the glowing cell window
    ORANGE = A['rifle']
    SHELL = mat('wpn_plasma_shell', srgb('8a9099'), .45, .4)
    def P(x, y):
        return ((x - 335) * .0032, (135 - y) * .0032)
    def S(pts, w, m, x=0.0, bevel=.004):
        p.side([P(*q) for q in pts], w, m, x=x, bevel=bevel)
    def B(x0, y0, x1, y1, w, m, x=0.0, bevel=.004):
        (ya, za), (yb, zb) = P(x0, y0), P(x1, y1)
        p.box((x, (ya + yb) / 2, (za + zb) / 2), (w, abs(ya - yb), abs(za - zb)), m, bevel)
    # twin emitter prongs: dark sleeves, grey barrels, glowing tips
    for y0 in (84, 111):
        B(104, y0, 138, y0 + 14, .036, SHELL, bevel=.004)
        B(96, y0 + 1, 106, y0 + 13, .03, G['plasma'], bevel=.003)
        B(126, y0 - 2, 142, y0 + 16, .044, INSET, bevel=.003)
    # light shell over the front half with the plasma cell window, dark lower body with a slotted rail
    S([(136, 74), (150, 66), (388, 66), (388, 120), (136, 120)], .086, SHELL, bevel=.008)
    S([(176, 86), (262, 86), (272, 96), (272, 110), (262, 120), (176, 120), (166, 110), (166, 96)], .09, INSET, bevel=.004)
    S([(180, 90), (258, 90), (266, 98), (266, 108), (258, 116), (180, 116), (172, 108), (172, 98)], .094, G['plasma'], bevel=.002)
    for x in (196, 222, 246):
        B(x, 89, x + 6, 117, .097, A['plasma'], bevel=.001)                            # cell bars
    S([(136, 118), (388, 118), (388, 150), (156, 150), (136, 138)], .08, SLATE, bevel=.006)
    B(152, 128, 262, 146, .083, INSET, bevel=.002)
    for k in range(5):
        B(158 + k * 21, 132, 170 + k * 21, 142, .085, SLATE, bevel=.001)               # rail slots
    # receiver: dark upper with hazard stripe and sight, orange tabs and vents
    S([(266, 66), (276, 56), (388, 56), (392, 66), (392, 150), (266, 150)], .09, SLATE, bevel=.008)
    for k in range(5):
        B(234 + k * 9, 64, 241 + k * 9, 70, .09, ORANGE if k % 2 == 0 else INSET, bevel=.001)
    B(300, 56, 390, 66, .092, SHELL, bevel=.003)                                        # light top band
    B(274, 38, 300, 56, .05, INSET, bevel=.004)                                         # sight
    B(272, 42, 275, 52, .04, GLASS, bevel=.001)
    B(280, 52, 296, 58, .04, SLATE, bevel=.002)
    B(290, 96, 330, 120, .094, INSET, bevel=.002)                                       # side panel
    for k in range(3):
        B(296 + k * 10, 100, 302 + k * 10, 106, .096, ORANGE, bevel=.001)
    B(338, 76, 378, 82, .094, ORANGE, bevel=.001)
    B(272, 126, 286, 134, .094, ORANGE, bevel=.001)
    # grey magazine, trigger guard, orange trigger and raked orange pistol grip
    B(226, 150, 280, 176, .066, SHELL, bevel=.005)
    B(226, 170, 280, 176, .07, INSET, bevel=.002)
    S([(290, 150), (322, 150), (322, 166), (294, 166), (294, 162), (318, 162), (318, 154), (290, 154)], .02, SLATE, bevel=.002)
    S([(304, 151), (310, 151), (308, 161), (303, 159)], .012, ORANGE, bevel=0)
    S([(322, 135), (350, 135), (362, 152), (360, 188), (338, 192), (334, 160)], .055, ORANGE, bevel=.006)
    S([(338, 146), (352, 146), (356, 160), (352, 182), (342, 182), (340, 160)], .058, INSET, bevel=.003)
    # skeleton stock: dark frame, orange top block, dark buttplate
    S([(390, 84), (434, 84), (434, 100), (390, 100)], .045, SLATE, bevel=.004)
    S([(390, 82), (420, 82), (420, 104), (390, 104)], .052, ORANGE, bevel=.004)
    S([(392, 128), (392, 140), (436, 114), (436, 102)], .04, SLATE, bevel=.004)
    S([(432, 80), (448, 80), (448, 134), (432, 132)], .06, INSET, bevel=.006)
    out += p.finish(col, (0, *P(96, 105)))

    # ---------------------------------------------------------------- signature weapons ("The Six" sheet)
    p = Part('W_minigun')  # Bastion: chunky belt-fed machine gun, traced from the reference side view, 1 px = 4 mm
    # scaled 1.3x for Bastion; hip carry ('heavy' stance) with the left glove on the carry handle, which lands at
    # build_fighters.MG_HANDLE (0, -.221, .39) after scaling
    ORANGE = A['minigun']
    # stock: slanted body, orange cheek block and butt plate
    p.side([(.12, .22), (.40, .22), (.40, -.02), (.12, .08)], .09, SLATE, bevel=.008)
    p.box((0, .30, .205), (.094, .12, .05), ORANGE, .006)
    p.box((0, .41, .09), (.1, .024, .28), ORANGE, .006)
    p.box((0, -.11, .155), (.12, .46, .19), SLATE, .01)                      # receiver
    p.box((0, -.11, .255), (.1, .42, .014), INSET, .004)                     # feed cover seam
    p.box((0, .03, .275), (.05, .05, .04), SLATE, .005)                      # rear sight block
    p.box((.062, .02, .16), (.008, .03, .03), ORANGE, .003)
    p.box((-.062, -.05, .12), (.008, .08, .022), SILVER, .003)               # charging slot (left)
    # carry handle: orange grip bar on two posts
    for y in (-.08, -.26):
        p.box((0, y, .27), (.03, .03, .05), INSET, .004)
    p.box((0, -.17, .30), (.04, .22, .03), ORANGE, .006)
    # belt feeding from the box into the right side of the receiver, rounds in orange and silver
    p.box((.064, -.21, .16), (.01, .1, .06), INSET, .003)                    # feed tray
    for k in range(6):
        z = .12 - k * .022
        p.box((.07, -.21, z), (.014, .07, .012), ORANGE if k % 2 == 0 else SILVER, .002)
    p.box((0, -.22, -.08), (.12, .17, .24), ORANGE, .01)                     # ammo box
    p.box((0, -.22, .045), (.124, .174, .018), RIB, .004)                    # lid
    p.box((.063, -.22, -.08), (.004, .1, .12), RIB, .002)                    # side panel
    # lower: trigger guard, orange trigger, raked grip
    p.side([(-.02, .06), (-.02, .0), (-.08, .0), (-.08, .06), (-.07, .06), (-.07, .01), (-.03, .01), (-.03, .06)], .02, SLATE, bevel=.003)
    p.side([(-.045, .06), (-.055, .06), (-.06, .02), (-.05, .02)], .012, ORANGE, bevel=0)
    p.side([(-.06, .065), (.06, .065), (.10, -.13), (-.0, -.14)], .085, SLATE, bevel=.01)
    # handguard with two rows of orange vents, underside rail
    p.box((0, -.54, .165), (.1, .40, .13), SLATE, .008)
    for row in (.19, .145):
        for k in range(5):
            for x in (-.051, .051):
                p.box((x, -.40 - k * .065, row), (.006, .04, .014), ORANGE, .002)
    p.box((0, -.52, .085), (.07, .26, .04), INSET, .004)
    for k in range(6):
        p.box((0, -.42 - k * .04, .06), (.072, .02, .02), INSET, .002)       # rail teeth
    # barrel, gas tube, front sight, bipod folded down
    p.cyl((0, -.90, .17), .03, .38, SILVER, segs=16)
    p.cyl((0, -1.09, .17), .018, .004, INSET, segs=12)                       # bore
    p.cyl((0, -.80, .10), .016, .26, SILVER, segs=12)                        # gas tube
    p.box((0, -1.03, .235), (.02, .02, .07), INSET, .004)                    # front sight post
    p.box((0, -.82, .10), (.05, .04, .04), INSET, .004)                      # bipod hinge
    for x in (-.03, .03):
        p.box((x, -.82, -.04), (.016, .02, .26), INSET, .004)
        p.box((x, -.82, -.18), (.03, .03, .014), INSET, .004)
    out += p.finish(col, (0, -1.09, .17), scale=1.3)

    p = Part('W_sword')  # Ronin: plasma katana from the reference sheet. Dark faceted blade with a glowing orange
    # cutting edge on the convex (-X) side, gentle curve (sori) toward the spine, gold habaki with a glowing gem, tall
    # dark tsuba, square two-hand tsuka with diagonal gold wraps behind the grip origin and a gold kashira
    R, ARC, BASE = 3.0, .46, .215     # arc radius, sweep (rad) -> ~1.4 m blade; blade starts just past the tsuba
    N = 9                             # straight chunks along the curve: the reference's stepped, blocky look
    def edge(t, off):
        th = ARC * t
        sx, sy = R - R * math.cos(th), -(BASE + R * math.sin(th))
        nx, ny = -math.cos(th), -math.sin(th)
        return (sx - nx * off, sy - ny * off)
    def width(t):                     # dark body: slim at the habaki, a touch wider before the point
        return .07 + .016 * t
    def band(o0, o1, tip=False):
        """Outline of the strip between spine offsets o0(t) and o1(t); tip=True closes it round a raked kissaki."""
        a = [edge(i / N, -o0(i / N)) for i in range(N + 1)]
        b = [edge(i / N, -o1(i / N)) for i in range(N + 1)]
        if tip:  # kissaki: the edge sweeps up to meet the spine
            th = ARC
            fx, fy = math.sin(th), -math.cos(th)
            a[-1] = (a[-1][0] + fx * .05, a[-1][1] + fy * .05)
            return a + [(b[-1][0] + fx * .11, b[-1][1] + fy * .11)] + list(reversed(b))
        return a + list(reversed(b))
    GOLD = mat('wpn_katana_gold', srgb('c99a2e'), .8, .35)
    BODY = mat('wpn_katana_steel', srgb('545c66'), .5, .38)
    glow = mat('wpn_plasma_blade', srgb('ff5a0a'), 0, .3, 4.0)
    halo = mat('wpn_plasma_aura', srgb('ff3c00'), 0, .3, .5)   # faint plasma haze: keeps the blade readable from the top-down camera
    halo.node_tree.nodes.get('Principled BSDF').inputs['Alpha'].default_value = .07
    if hasattr(halo, 'surface_render_method'):
        halo.surface_render_method = 'BLENDED'
    p.prism(band(lambda t: 0, lambda t: width(t), tip=True), .03, BODY, smooth=False)   # blade body
    p.prism(band(lambda t: .004, lambda t: .022), .04, INSET, smooth=False)             # raised spine ridge
    p.prism(band(lambda t: width(t) - .002, lambda t: width(t) + .03), .026, glow, smooth=False)  # plasma edge
    p.prism(band(lambda t: -.02, lambda t: width(t) + .055, tip=True), .07, halo, smooth=False)
    th = ARC
    tip = edge(1.0, -(width(1.0) + .03))
    tip = (tip[0] + math.sin(th) * .13, tip[1] - math.cos(th) * .13, 0)
    tip_glow = [edge(1.0, -(width(1.0) - .002)), (tip[0], tip[1]),
                (tip[0] - math.sin(th) * .025 + math.cos(th) * .02, tip[1] + math.cos(th) * .025 + math.sin(th) * .02),
                edge(1.0, -(width(1.0) + .03))]
    p.prism(tip_glow, .02, glow, smooth=False)                                          # glowing point
    # gold habaki with the glowing gem on the spine side, then the tall dark tsuba and gold fuchi, set just ahead of the
    # big glove (~.29 m deep) so they stay visible; the right fist holds the tsuka right behind the tsuba
    p.box((.005, -.21, 0), (.085, .05, .046), GOLD, .006)
    p.box((.035, -.21, 0), (.03, .03, .052), INSET, .003)
    p.box((.04, -.21, 0), (.018, .02, .058), glow, .002)
    p.box((-.005, -.17, 0), (.15, .03, .1), DARK, .008)
    p.box((-.005, -.17, 0), (.17, .018, .085), METAL, .006)
    for x in (-.06, .05):
        p.box((x, -.17, 0), (.012, .034, .104), INSET, .002)
    p.box((0, -.137, 0), (.072, .034, .066), GOLD, .006)
    # square tsuka with diagonal gold wraps on every face, gold kashira
    p.box((0, .135, 0), (.058, .52, .052), DARK, .008)
    for k in range(7):
        y = -.09 + k * .072
        for ax in ('X', 'Z'):
            t = bmesh.new()
            bmesh.ops.create_cube(t, size=1.0)
            sz = (.062, .011, .056) if ax == 'Z' else (.061, .011, .057)
            bmesh.ops.scale(t, vec=sz, verts=t.verts)
            p._commit(t, GOLD, Matrix.Translation((0, y, 0)) @ Matrix.Rotation(.45 if ax == 'Z' else -.45, 4, ax), smooth=False)
    p.box((0, .41, 0), (.07, .04, .064), GOLD, .008)
    p.box((0, .432, 0), (.05, .008, .046), INSET, .003)
    out += p.finish(col, tip)  # muzzle = blade tip (swing trail); no baked tilt: the pose solver aims the blade

    p = Part('W_pistol')  # Marshal: chunky game hand cannon (revolver), traced from the reference side view at 1.9 mm
    # per pixel, scaled 1.16x; grip top = the fist, the 'pistol' stance's left glove wraps the right fist
    ORANGE = A['pistol']
    p.side([(-.0475, .0095), (.038, .019), (.057, -.038), (.1045, -.1805), (.0095, -.1995), (-.0095, -.1235),
            (-.0475, -.038)], .058, ORANGE, bevel=.008)                     # raked orange grip
    p.side([(.0, -.03), (.04, -.04), (.075, -.15), (.025, -.165), (.008, -.11)], .064, INSET, bevel=.004)  # grip panel
    for z in (-.07, -.13):
        p.box((.033, .03 + (z + .07) * -.35, z), (.006, .012, .012), ORANGE, .002)  # panel screws
    p.box((0, -.13, .045), (.07, .2, .12), SLATE, .008)                     # frame
    p.side([(.019, .072), (.038, .057), (.0, .019), (-.0285, .019), (-.0285, .0475)], .03, INSET, bevel=.004)  # hammer
    p.box((0, -.057, .106), (.024, .036, .016), INSET, .003)                # rear sight
    # cylinder bulging out of the frame window, with flutes and orange chamber marks
    p.cyl((0, -.119, .014), .052, .124, SILVER, segs=12, spin=math.pi / 12, flat=True)
    for k in range(6):
        a = k * math.tau / 6
        p.box((math.cos(a) * .05, -.119, .014 + math.sin(a) * .05), (.008, .11, .008), INSET, .001)
    for z in (.03, .0):
        p.box((.054, -.10, z), (.004, .014, .012), ORANGE, .001)
    p.box((.037, -.204, .014), (.006, .024, .02), ORANGE, .002)             # frame accents
    p.box((.037, -.204, -.03), (.006, .02, .012), ORANGE, .002)
    # trigger guard and orange trigger
    p.side([(-.0475, -.015), (-.0475, -.099), (-.1425, -.099), (-.1425, -.015), (-.1325, -.015), (-.1325, -.089),
            (-.0575, -.089), (-.0575, -.015)], .02, SLATE, bevel=.003)
    p.side([(-.08, -.015), (-.092, -.015), (-.098, -.07), (-.086, -.07)], .012, ORANGE, bevel=0)
    # heavy barrel slab with a dark top rib and front sight, under-lug with orange dashes, ejector rod and rail
    p.box((0, -.39, .043), (.064, .323, .066), SILVER, .008)
    p.box((0, -.39, .084), (.05, .323, .022), INSET, .004)
    p.box((0, -.527, .1), (.018, .028, .022), INSET, .003)
    p.box((0, -.375, -.014), (.058, .294, .048), SLATE, .006)
    for y, ln in ((-.365, .07), (-.50, .03)):
        for x in (-.03, .03):
            p.box((x, y, -.014), (.004, ln, .01), ORANGE, .001)
    p.cyl((0, -.38, -.052), .014, .285, SILVER, segs=12)
    p.box((0, -.347, -.07), (.05, .16, .016), INSET, .003)
    for k in range(5):
        p.box((0, -.28 - k * .033, -.082), (.052, .016, .014), INSET, .002)
    p.cyl((0, -.552, .043), .02, .004, INSET, segs=12)                      # bore
    out += p.finish(col, (0, -.553, .043), scale=1.16)  # a hand cannon for the chunky gloves

    # Nova's rail rifle and the shared railgun every operative carries are the same model
    for rail_id in ('railrifle', 'railgun'):
        p = Part('W_' + rail_id)  # Nova: twin-rail energy rifle traced from the reference side view at 4.4 mm per pixel, scaled 1.15x
        # (pixel x 160 / y 125 = grip origin, top of the pistol grip); the skeleton stock is compressed to .34 m so it clears
        # the hip hold, and the orange magazine sits under the 'rail' stance's left glove (support -.34), a magwell grip
        ORANGE = A['rifle']
        CYAN = G['railrifle']
        def P(x, y):  # reference pixel -> (weapon y, z); the stock (x < 140) is squeezed toward the receiver
            if x < 140:
                x = 140 - (140 - x) * .62
            return (-(x - 160) * .0044, (125 - y) * .0044)
        def S(pts, w, m, x=0.0, bevel=.004):
            p.side([P(*q) for q in pts], w, m, x=x, bevel=bevel)
        def B(x0, y0, x1, y1, w, m, x=0.0, bevel=.004):  # box from a pixel rectangle
            (ya, za), (yb, zb) = P(x0, y0), P(x1, y1)
            p.box((x, (ya + yb) / 2, (za + zb) / 2), (w, abs(ya - yb), abs(za - zb)), m, bevel)
        # receiver: blocky slab with a stepped front, dark inset panel and vents
        S([(140, 80), (288, 80), (300, 90), (300, 112), (286, 125), (150, 125), (140, 114)], .075, SLATE, bevel=.006)
        B(150, 76, 280, 82, .05, INSET)                                         # top rail
        B(196, 88, 250, 108, .079, INSET, bevel=.002)                           # side panel
        for k in range(3):
            B(205 + k * 14, 93, 213 + k * 14, 103, .081, SLATE, bevel=.001)     # vents
        B(258, 96, 284, 104, .079, ORANGE, bevel=.002)                          # accent strip
        # scope: dark tube with orange rings, big objective box, two mounts
        p.cyl((0, P(205, 55)[0], P(205, 55)[1]), .04, abs(P(168, 0)[0] - P(240, 0)[0]), INSET, segs=12, spin=math.pi / 12, flat=True)
        B(232, 38, 254, 72, .095, SLATE, bevel=.006)                            # objective housing
        B(254, 44, 257, 66, .06, GLASS, bevel=.001)                             # lens
        B(162, 42, 176, 68, .085, SLATE, bevel=.005)                            # eyepiece
        for x in (180, 222):
            B(x, 40, x + 9, 70, .09, ORANGE, bevel=.003)                        # rings
        for x in (182, 226):
            B(x, 68, x + 8, 78, .03, INSET, bevel=.002)                         # mounts
        # twin rails: dark caps over glowing cyan cores, a cyan arc between them, orange clamp rings
        for sx in (-.032, .032):
            B(284, 80, 463, 88, .026, SLATE, x=sx)
            B(286, 88, 461, 104, .022, CYAN, x=sx, bevel=.001)
            B(284, 104, 463, 112, .026, SLATE, x=sx)
            B(455, 78, 465, 114, .03, INSET, x=sx, bevel=.003)                  # rail tips
        B(300, 92, 452, 100, .03, CYAN, bevel=.001)                             # field between the rails
        for x in (346, 370, 424, 436):
            B(x, 72, x + 9, 120, .1, ORANGE, bevel=.003)
        for x in (348, 426):
            B(x + 11, 76, x + 20, 116, .094, INSET, bevel=.002)
        # under-rail with teeth below the barrel housing
        B(282, 112, 342, 126, .06, INSET)
        for k in range(5):
            B(286 + k * 11, 126, 293 + k * 11, 134, .05, SLATE, bevel=.001)
        # orange magazine with a dark side window and a glowing cyan base
        B(204, 125, 246, 166, .07, ORANGE, bevel=.006)
        B(212, 132, 238, 158, .074, INSET, bevel=.002)
        B(202, 166, 248, 178, .074, CYAN, bevel=.003)
        B(200, 176, 250, 181, .078, SLATE, bevel=.002)
        # raked pistol grip (dark, orange back strap), trigger guard and trigger
        S([(148, 125), (170, 125), (164, 150), (156, 172), (134, 170), (140, 150)], .055, INSET, bevel=.006)
        S([(134, 170), (156, 172), (154, 178), (130, 176)], .057, ORANGE, bevel=.003)
        S([(170, 125), (200, 125), (200, 130), (176, 140), (164, 140), (166, 132)], .02, SLATE, bevel=.002)
        S([(178, 126), (184, 126), (182, 136), (177, 134)], .012, ORANGE, bevel=0)
        # skeleton stock: top bar with an orange cheek riser, diagonal strut, lower bar and a tall buttplate
        S([(60, 84), (140, 84), (140, 102), (60, 102)], .045, SLATE, bevel=.004)
        S([(68, 80), (122, 80), (122, 94), (68, 94)], .052, ORANGE, bevel=.004)
        S([(140, 104), (140, 116), (90, 142), (78, 134)], .04, SLATE, bevel=.004)
        S([(62, 128), (100, 128), (100, 140), (62, 140)], .04, SLATE, bevel=.004)
        S([(45, 78), (62, 78), (62, 152), (45, 150)], .06, INSET, bevel=.006)
        S([(55, 82), (62, 82), (62, 146), (55, 146)], .062, ORANGE, bevel=.002)
        out += p.finish(col, (0, P(465, 96)[0], P(465, 96)[1]), scale=1.15)

    p = Part('W_gauntlet')  # Hex: arc gauntlet (caster_hand.py) on the right fist, palm emitter and a floating holo panel
    # origin = grip point inside the fist. The glove's knuckle face is +Z, the palm faces -X and the fingers run
    # forward (-Y); the cast stance rolls the hand palm up (hold up = +X), so the panel floats on the -X side.
    holo = mat('wpn_holo', srgb('b06cff'), 0, .3, 3.0)
    holo.node_tree.nodes.get('Principled BSDF').inputs['Alpha'].default_value = .38
    if hasattr(holo, 'surface_render_method'):
        holo.surface_render_method = 'BLENDED'
    HAND = {'slate': SLATE, 'inset': INSET, 'orange': A['rifle'], 'glow': G['gauntlet']}
    for c, m in caster_hand(1):
        if c[0] == 'box':
            p.box(c[1], c[2], HAND[m], c[3])
        else:
            p.cyl(c[1], c[2], c[3], HAND[m], axis='X', segs=20)
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

    p = Part('W_sniper')  # Kestrel: chunky game bolt-action sniper, traced from the reference side view, 1 px = 3.84 mm
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
