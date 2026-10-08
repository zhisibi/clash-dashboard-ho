#!/usr/bin/env python3
"""由 docs/privacy.md、docs/agreement.md 生成 entry/src/main/ets/common/Legal.ets（应用内展示的正文）。"""
import json, os
root = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')


def lines(p):
    ls = open(os.path.join(root, p), encoding='utf-8').read().split('\n')
    while ls and ls[-1] == '':
        ls.pop()
    return ls


out = ['/** 隐私政策与用户协议正文：由 scripts/gen-legal.py 从 docs/privacy.md、docs/agreement.md 生成，请勿手改 */', '',
       "export const LEGAL_DEVELOPER: string = 'zhisibi';",
       "export const LEGAL_CONTACT: string = 'https://github.com/zhisibi';",
       '/** 隐私政策版本：正文有实质变更时递增，用户需要重新同意 */',
       'export const PRIVACY_VERSION: number = 1;', '']
for name, p in [('PRIVACY_LINES', 'docs/privacy.md'), ('AGREEMENT_LINES', 'docs/agreement.md')]:
    out.append('export const %s: string[] = [' % name)
    out.append(',\n'.join('  ' + json.dumps(l, ensure_ascii=False) for l in lines(p)))
    out.append('];')
    out.append('')
open(os.path.join(root, 'entry/src/main/ets/common/Legal.ets'), 'w', encoding='utf-8').write('\n'.join(out))
