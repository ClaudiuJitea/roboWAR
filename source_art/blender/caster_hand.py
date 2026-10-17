"""Seren's armoured open hand, shared by build_weapons.py (W_gauntlet) and build_fighters.py (left glove)."""


def caster_hand(side):
    """Seren's armoured open hand, shared by W_gauntlet (side 1, right hand) and her left glove in build_fighters.py
    (side -1, mirrored). Hand frame: origin = grip point, fingers forward (-Y), palm toward -X*side, knuckles +Z.
    Returns (('box', pos, size, bevel) | ('cyl', pos, radius, depth), material key) pairs."""
    s = side
    out = [(('box', (.004 * s, .10, -.05), (.29, .085, .33), .03), 'accent'),         # slim bracer over the wrist
           (('box', (.004 * s, .10, -.05), (.295, .02, .335), .006), 'glow'),         # glowing bracer band
           (('box', (.135 * s, -.02, -.02), (.035, .22, .25), .014), 'white'),        # back-of-hand plate
           (('box', (.155 * s, -.02, -.02), (.008, .14, .04), .003), 'glow'),         # plate strip
           (('cyl', (-.152 * s, -.03, -.02), .075, .014), 'glow'),                    # palm emitter ring
           (('cyl', (-.158 * s, -.03, -.02), .048, .014), 'dark')]
    # four fingers stacked from the thumb side (+Z) down, each a knuckle, a straight segment and a tip curled to the palm
    for z, length in ((.085, .15), (.028, .165), (-.03, .155), (-.087, .125)):
        y0 = -.135
        out.append((('box', (.06 * s, y0 - .01, z), (.05, .05, .052), .016), 'accent'))  # knuckle cap
        out.append((('box', (-.005 * s, y0 - length * .32, z), (.09, length * .64, .05), .018), 'dark'))
        out.append((('box', (-.03 * s, y0 - length * .78, z), (.075, length * .36, .046), .017), 'dark'))
        out.append((('box', (-.068 * s, y0 - length * .9, z), (.012, length * .14, .03), .004), 'glow'))  # fingertip pad
    # thumb from the palm side of the knuckles, angled forward and up
    out.append((('box', (-.06 * s, -.07, .13), (.07, .10, .06), .02), 'dark'))
    out.append((('box', (-.075 * s, -.15, .155), (.06, .09, .05), .018), 'dark'))
    return out
