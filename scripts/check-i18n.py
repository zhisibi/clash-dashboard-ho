#!/usr/bin/env python3
"""Checks the in-app string tables (1.2.0):
  1. StringsZh.ets and StringsEn.ets have the same keys;
  2. every literal t('key') used in .ets exists;
  3. no CJK characters in .ets outside the Chinese tables (StringsZh.ets, LegalZh.ets).
Exit code 1 on any problem."""
import os, re, sys
root = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
ets = os.path.join(root, 'entry/src/main/ets')
CJK = re.compile('[\u3000-\u303f\u3400-\u9fff\uff00-\uffef]')
ALLOW = {'common/i18n/StringsZh.ets', 'common/i18n/LegalZh.ets'}


def keys(name):
    s = open(os.path.join(ets, 'common/i18n', name), encoding='utf-8').read()
    return set(re.findall(r'^\s+"([A-Za-z0-9_]+)":', s, re.M))


zh, en = keys('StringsZh.ets'), keys('StringsEn.ets')
bad = 0
for k in sorted(zh ^ en):
    print('key only in one table:', k)
    bad += 1
cjk = 0
for d, _, fs in os.walk(ets):
    for f in fs:
        if not f.endswith('.ets'):
            continue
        p = os.path.join(d, f)
        rel = os.path.relpath(p, ets).replace(os.sep, '/')
        src = open(p, encoding='utf-8').read()
        for k in re.findall(r"\bt\('([A-Za-z0-9_]+)'\s*[,)]", src):
            if k not in zh:
                print('missing key %s in %s' % (k, rel))
                bad += 1
        if rel in ALLOW:
            continue
        for i, line in enumerate(src.split('\n')):
            if CJK.search(line):
                print('CJK in %s:%d: %s' % (rel, i + 1, line.strip()[:100]))
                cjk += 1
print('keys: zh=%d en=%d, problems=%d, CJK lines outside Chinese tables=%d' % (len(zh), len(en), bad, cjk))
sys.exit(1 if bad or cjk else 0)
