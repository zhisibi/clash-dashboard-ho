#!/usr/bin/env python3
"""WCAG contrast audit for the palette in entry/src/main/ets/common/Theme.ets.

Parses Palette defaults, darkPalette() overrides and the ACCENTS presets, replicates
applyAccent() + Store.palette() glass/wallpaper translucency, and checks every
text/icon token against every surface it is drawn on (opaque and translucent cards
composited over the page background or the glass backdrop gradient).

Thresholds: body text >= 4.5, titles/icons/large >= 3.0.
Translucent cards are checked at the default glass opacity (0.55); a lower opacity chosen by the user
over a custom wallpaper is outside what a token check can guarantee.
Exit code 1 if anything fails.  Usage: python3 scripts/check-contrast.py [-v]
"""
import re, sys, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
THEME = os.path.join(ROOT, 'entry/src/main/ets/common/Theme.ets')
src = open(THEME, encoding='utf-8').read()
VERBOSE = '-v' in sys.argv


def rgb(h):
    h = h.lstrip('#')
    if len(h) == 8:
        h = h[2:]
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def hexs(c):
    return '#' + ''.join('%02X' % max(0, min(255, round(v))) for v in c)


def lum(c):
    def ch(v):
        v /= 255
        return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
    r, g, b = (ch(v) for v in rgb(c) if True) if isinstance(c, str) else (ch(v) for v in c)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def cr(a, b):
    la, lb = lum(a), lum(b)
    if la < lb:
        la, lb = lb, la
    return (la + 0.05) / (lb + 0.05)


def over(fg, alpha, bg):
    f, b = rgb(fg), rgb(bg)
    return hexs(tuple(b[i] + (f[i] - b[i]) * alpha for i in range(3)))


def mix(a, b, t):
    return over(b, t, a)


# ---- parse Theme.ets ----
pal_block = re.search(r'export class Palette \{(.*?)\n\}', src, re.S).group(1)
LIGHT = dict(re.findall(r"(\w+): string = '(#[0-9A-Fa-f]{6,8})'", pal_block))
dark_block = re.search(r'export function darkPalette\(\).*?\{(.*?)\n\}', src, re.S).group(1)
DARK = dict(LIGHT)
DARK.update(dict(re.findall(r"p\.(\w+) = '(#[0-9A-Fa-f]{6})'", dark_block)))
H = r"'(#[0-9A-Fa-f]{6})'"
TONE = r"new AccentTone\(%s, %s, %s, %s\)" % (H, H, H, H)
ACC = re.findall(r"new AccentDef\('(\w+)', '(\w+)', %s, %s,\s*%s, %s\)" % (H, H, TONE, TONE), src)
assert len(ACC) == 7, 'expected 7 accent presets, parsed %d' % len(ACC)


def build(dark, a):
    """Mirror of Theme.applyAccent()."""
    p = dict(DARK if dark else LIGHT)
    key, _, light, darkc = a[:4]
    ui, text, fill, on = a[8:12] if dark else a[4:8]
    p.update(accentFill=darkc if dark else light, accent=text, accentUi=ui, primary=fill, onPrimary=on, onAccent=on)
    p['accentSoftA'] = 0.20 if dark else 0.11
    p['down'] = ui
    p['up'] = mix(ui, '#FFFFFF', 0.45) if dark else mix(ui, p['text'], 0.45)
    p['downText'] = text
    p['upText'] = mix(text, '#FFFFFF', 0.45) if dark else mix(text, p['text'], 0.45)
    return p


fails = []
worst = {}


def check(mode, acc, what, fg, bg, need):
    v = cr(fg, bg)
    k = (mode, what)
    if k not in worst or v < worst[k][0]:
        worst[k] = (v, acc, fg, bg)
    if v < need:
        fails.append('%-5s %-6s %-48s %s on %s = %.2f (< %.1f)' % (mode, acc, what, fg, bg, v, need))


GLASS_ALPHA = 0.55  # Store.glassAlpha default; chips get +0.15 (Store.palette)
for dark in (False, True):
    mode = 'dark' if dark else 'light'
    for a in ACC:
        p = build(dark, a)
        key = a[0]
        page = p['bg']
        deco = p['accentFill']
        # glass backdrop (Index.glassBackdrop): mid stop mixes bg with the accent, plus an accent radial glow
        if dark:
            mid = mix('#111316', deco, 0.18)
            glow = over(deco, 0.38, mid)
        else:
            mid = mix('#F4F4F6', deco, 0.16)
            glow = over(deco, 0.30, mid)
        backdrops = {'page': page, 'glass-mid': mid, 'glass-glow': glow}
        base = '#1C1F24' if dark else '#FFFFFF'
        surfaces = {'page bg': page, 'card': p['card'], 'chip': p['chip'], 'sheet': p['sheet']}
        for bname, b in backdrops.items():
            surfaces['glass card/%s' % bname] = over(p['card'], GLASS_ALPHA, b)
            surfaces['glass chip/%s' % bname] = over(p['chip'], GLASS_ALPHA + 0.15, b)
            surfaces['bar/%s' % bname] = over(base, 0.66, b)              # Glass.ets bottom bar minimum tint
            surfaces['header/%s' % bname] = over(base, 0.55 if dark else 0.58, b)  # glass header minimum tint
            surfaces['glass sheet/%s' % bname] = over(p['sheet'], 0.88, b)  # 1.2.3: sheets >= 0.88 over the blur
        # 1.2.3: overlay pages (legal docs, consent) over a wallpaper: page color at OVERLAY_SCRIM (0.92) over the
        # blurred wallpaper; checked against the extremes, pure white and pure black
        for wname, w in (('white', '#FFFFFF'), ('black', '#000000')):
            surfaces['overlay scrim/%s wallpaper' % wname] = over(page, 0.92, w)
        for sname, s in surfaces.items():
            check(mode, key, 'text on ' + sname, p['text'], s, 4.5)
            check(mode, key, 'subtle (secondary/label/placeholder) on ' + sname, p['subtle'], s, 4.5)
            check(mode, key, 'accent text on ' + sname, p['accent'], s, 4.5)
            check(mode, key, 'accentUi icon/control on ' + sname, p['accentUi'], s, 3.0)
            for t in ('bad', 'good', 'warn', 'info', 'upText', 'downText'):
                check(mode, key, t + ' text on ' + sname, p[t], s, 4.5)
            for t in ('up', 'down'):
                check(mode, key, t + ' icon on ' + sname, p[t], s, 3.0)
        # nav: selected = accentUi icon + accent label on an accentSoft pill over the bar
        for bname, b in backdrops.items():
            bar = over(base, 0.66, b)
            pill = over(p['accentUi'], p['accentSoftA'], bar)
            check(mode, key, 'nav selected label (accent) on pill/' + bname, p['accent'], pill, 4.5)
            check(mode, key, 'nav selected icon (accentUi) on pill/' + bname, p['accentUi'], pill, 3.0)
        for sname, s in (('card', p['card']), ('glass card/glow', over(p['card'], GLASS_ALPHA, glow))):
            pill = over(p['accentUi'], p['accentSoftA'], s)
            check(mode, key, 'accent tag text on accentSoft/' + sname, p['accent'], pill, 4.5)
        # buttons / segmented tabs / round icon buttons
        check(mode, key, 'onPrimary on primary (button, segtab)', p['onPrimary'], p['primary'], 4.5)
        check(mode, key, 'text on chip button', p['text'], p['chip'], 4.5)
        check(mode, key, 'subtle on segtab track (chip)', p['subtle'], p['chip'], 4.5)
        # error banner (Index): bad text on tinted pill at 0.94 over the page
        banner = over('#3A1F22' if dark else '#FDECEC', 0.94, page)
        check(mode, key, 'bad text on error banner', p['bad'], banner, 4.5)
        check(mode, key, 'text on error banner', p['text'], banner, 4.5)

if VERBOSE or fails:
    print('Worst case per (mode, pair):')
    for (mode, what), (v, acc, fg, bg) in sorted(worst.items(), key=lambda x: x[1][0]):
        if VERBOSE or v < 4.5:
            print('  %-5s %-58s %5.2f  (%s %s on %s)' % (mode, what, v, acc, fg, bg))
print('%d failures' % len(fails))
for f in fails[:400] if VERBOSE else []:
    print('  ' + f)
sys.exit(1 if fails else 0)
