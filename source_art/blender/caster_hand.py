"""Hex's armoured open hand, shared by build_weapons.py (W_gauntlet) and build_fighters.py (left glove)."""


def caster_hand(side):
    """Hex's arc gauntlet from the reference sheet, shared by W_gauntlet (side 1, right hand) and her left glove in
    build_fighters.py (side -1, mirrored). Hand frame: origin = grip point, fingers forward (-Y), palm toward -X*side,
    back of the hand +X*side, fingers stacked along Z. Chunky slate bracer with a hazard-striped band and an orange
    top panel, slate hand with glowing studs, orange knuckle plates, segmented slate fingers with glowing tips.
    Returns (('box', pos, size, bevel) | ('cyl', pos, radius, depth), material key) pairs; keys: slate, inset,
    orange, glow."""
    s = side
    out = [(('box', (.01 * s, .17, -.02), (.32, .26, .34), .06), 'slate'),            # armoured forearm shell
           (('box', (.01 * s, .29, -.02), (.29, .03, .31), .02), 'inset'),            # rear cuff
           (('box', (.01 * s, .045, -.02), (.30, .03, .32), .02), 'inset'),           # wrist cuff
           (('box', (.17 * s, .21, -.02), (.014, .1, .17), .005), 'orange'),          # top panel
           (('box', (.175 * s, .21, -.02), (.008, .06, .05), .002), 'inset'),         # panel slot
           (('box', (-.16 * s, .17, .05), (.012, .12, .03), .004), 'glow'),           # palm-side vents
           (('box', (-.16 * s, .17, -.09), (.012, .12, .03), .004), 'glow')]
    # hazard band: orange and dark blocks round the front of the bracer
    for i, z in enumerate((-.15, -.09, -.03, .03, .09)):
        out.append((('box', (.168 * s, .1, z + .03), (.016, .06, .055), .004), 'orange' if i % 2 == 0 else 'inset'))
    for i, x in enumerate((-.12, -.06, 0, .06, .12)):
        out.append((('box', (x * s, .1, .158), (.055, .06, .016), .004), 'inset' if i % 2 == 0 else 'orange'))
    # back of the hand: slate plate with three glowing studs, palm emitter ring
    out += [(('box', (.11 * s, -.035, -.02), (.07, .21, .27), .02), 'slate'),
            (('box', (.06 * s, -.035, -.02), (.06, .19, .25), .02), 'inset')]
    for z in (-.08, -.02, .04):
        out.append((('box', (.15 * s, -.02, z), (.025, .03, .03), .006), 'glow'))
    out += [(('cyl', (-.152 * s, -.03, -.02), .075, .014), 'glow'),
            (('cyl', (-.158 * s, -.03, -.02), .048, .014), 'inset')]
    # four fingers stacked from the thumb side (+Z) down: orange knuckle plate, two slate segments, glowing tip
    for z, length in ((.085, .15), (.028, .165), (-.03, .155), (-.087, .125)):
        y0 = -.135
        out.append((('box', (.075 * s, y0 - .005, z), (.05, .06, .052), .012), 'orange'))     # knuckle plate
        out.append((('box', (.0 * s, y0 - length * .3, z), (.095, length * .6, .052), .014), 'slate'))
        out.append((('box', (-.03 * s, y0 - length * .72, z), (.08, length * .3, .048), .013), 'inset'))
        out.append((('box', (-.04 * s, y0 - length * .95, z), (.07, length * .18, .05), .012), 'glow'))  # glowing tip
    # thumb from the palm side of the knuckles, angled forward and up, glowing tip
    out.append((('box', (-.06 * s, -.07, .13), (.075, .10, .065), .02), 'slate'))
    out.append((('box', (-.075 * s, -.15, .155), (.062, .08, .055), .016), 'inset'))
    out.append((('box', (-.08 * s, -.2, .162), (.055, .03, .05), .01), 'glow'))
    return out
