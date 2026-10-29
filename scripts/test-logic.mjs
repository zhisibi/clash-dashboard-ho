// Unit tests for the pure ArkTS logic (common/MotionLogic.ets, common/ReviewLogic.ets) under Node's type stripping.
// Usage: node scripts/test-logic.mjs        (Node >= 22.18; copies the .ets files to a temp dir as .ts)
import fs from 'fs';
import os from 'os';
import path from 'path';
import { pathToFileURL } from 'url';

const root = path.join(path.dirname(new URL(import.meta.url).pathname), '..');
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'mimipanel-logic-'));
for (const f of ['MotionLogic', 'ReviewLogic']) {
  fs.copyFileSync(path.join(root, 'entry/src/main/ets/common', f + '.ets'), path.join(tmp, f + '.ts'));
}
const mot = await import(pathToFileURL(path.join(tmp, 'MotionLogic.ts')).href);
const rev = await import(pathToFileURL(path.join(tmp, 'ReviewLogic.ts')).href);
let failed = 0, passed = 0;
const eq = (name, got, want) => {
  const ok = JSON.stringify(got) === JSON.stringify(want);
  ok ? passed++ : failed++;
  console.log((ok ? 'ok   ' : 'FAIL ') + name + (ok ? '' : `\n     got  ${JSON.stringify(got)}\n     want ${JSON.stringify(want)}`));
};

// ---- motion
eq('parseScale empty', mot.parseScale(''), 1);
eq('parseScale zero', mot.parseScale('0'), 0);
eq('parseScale half', mot.parseScale('0.5'), 0.5);
eq('parseScale junk', mot.parseScale('x'), 1);
eq('parseScale null', mot.parseScale(null), 1);
eq('motionOn user off', mot.motionOn(false, '1', '1'), false);
eq('motionOn scale 0', mot.motionOn(true, '0', '1'), false);
eq('motionOn ok', mot.motionOn(true, '1', '0.5'), true);
eq('motionMs off', mot.motionMs(300, false), 0);
eq('motionMs on', mot.motionMs(300, true), 300);
eq('list anim small', mot.animateListChange(10, 11, true), true);
eq('list anim big jump', mot.animateListChange(10, 20, true), false);
eq('list anim long list', mot.animateListChange(500, 501, true), false);
eq('list anim off', mot.animateListChange(10, 11, false), false);

// ---- review
const DAY = 24 * 60 * 60 * 1000;
const T0 = 1700000000000;
const fresh = () => new rev.ReviewData();
eq('fresh blocked by age/launches/successes', rev.reviewBlockers(fresh(), T0, false), ['age', 'launches', 'successes']);
eq('busy blocks', rev.reviewBlockers(fresh(), T0, true).includes('busy'), true);

const d = fresh();
eq('first launch flagged', rev.reviewRecordLaunch(d, T0), true);
eq('second launch not first', rev.reviewRecordLaunch(d, T0), false);
for (let i = 0; i < 3; i++) rev.reviewRecordLaunch(d, T0);
for (let i = 0; i < 3; i++) rev.reviewRecordSuccess(d);
eq('not yet: age', rev.reviewShouldShow(d, T0 + 2 * DAY, false), false);
eq('eligible at 3 days', rev.reviewShouldShow(d, T0 + 3 * DAY, false), true);
eq('busy still blocks when eligible', rev.reviewShouldShow(d, T0 + 3 * DAY, true), false);

rev.reviewRecordShown(d, T0 + 3 * DAY);
eq('interval blocks re-show', rev.reviewBlockers(d, T0 + 30 * DAY, false), ['interval']);
eq('later snoozes', (() => { const x = fresh(); Object.assign(x, d); rev.reviewChooseLater(x, T0 + 3 * DAY); return x.snoozeUntil; })(), T0 + 63 * DAY);
eq('interval passes at 90d', rev.reviewShouldShow(d, T0 + 93 * DAY, false), true);
rev.reviewRecordShown(d, T0 + 93 * DAY);
rev.reviewRecordShown(d, T0 + 183 * DAY);
eq('max shows blocks', rev.reviewBlockers(d, T0 + 400 * DAY, false), ['max-shows']);

const r = fresh(); Object.assign(r, d); rev.reviewChooseRate(r);
eq('rated blocks forever', rev.reviewBlockers(r, T0 + 999 * DAY, false).includes('life-done'), true);
const n = fresh(); rev.reviewChooseNever(n);
eq('never blocks forever', rev.reviewBlockers(n, T0 + 999 * DAY, false).includes('life-never'), true);

console.log(`\n${passed} passed, ${failed} failed`);
process.exit(failed === 0 ? 0 : 1);
