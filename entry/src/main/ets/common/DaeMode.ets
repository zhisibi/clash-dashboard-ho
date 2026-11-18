/**
 * dae/honk config text surgery for the outbound-mode catch-all rule —
 * the same mechanism doona uses: a marked rule near the top of the
 * routing block (after any leading must rules) forces ALL traffic to
 * one outbound; removing the line returns routing to the authored
 * rules ("auto"). The marker comment identifies the line as managed,
 * so a hand-edited condition or spacing still reads back and is still
 * removed cleanly. Two markers are recognised: doona's and ours.
 */

export class DaeModeWrite {
  ok: boolean = false;
  text: string = '';
  error: string = '';
}

const MARKS: string[] = ['# doona: outbound mode', '# mimipanel: outbound mode'];
const OUR_MARK: string = '# mimipanel: outbound mode';

class BlockRange {
  start: number = 0; // first index inside the braces
  end: number = 0; // index of the closing brace
}

function isWordChar(c: string): boolean {
  return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
    (c >= '0' && c <= '9') || c === '_' || c === '-';
}

/**
 * Find the top-level `routing { ... }` block body. The scan is aware of
 * quoted strings and # comments so braces inside them never count.
 */
function routingBlock(text: string): BlockRange | null {
  const n = text.length;
  let depth = 0;
  let state = 0; // 0 code, 1 single-quote, 2 double-quote, 3 comment
  let i = 0;
  while (i < n) {
    const c = text.charAt(i);
    if (state === 3) {
      if (c === '\n') {
        state = 0;
      }
      i++;
      continue;
    }
    if (state === 1 || state === 2) {
      if (c === '\\') {
        i += 2;
        continue;
      }
      if ((state === 1 && c === "'") || (state === 2 && c === '"')) {
        state = 0;
      }
      i++;
      continue;
    }
    if (c === '#') {
      state = 3;
      i++;
      continue;
    }
    if (c === "'") {
      state = 1;
      i++;
      continue;
    }
    if (c === '"') {
      state = 2;
      i++;
      continue;
    }
    if (c === '{') {
      depth++;
      i++;
      continue;
    }
    if (c === '}') {
      depth--;
      i++;
      continue;
    }
    if (depth === 0 && c === 'r' && text.startsWith('routing', i) &&
      (i === 0 || !isWordChar(text.charAt(i - 1))) &&
      (i + 7 >= n || !isWordChar(text.charAt(i + 7)))) {
      // the next meaningful token must be the opening brace
      let j = i + 7;
      let open = -1;
      while (j < n) {
        const cj = text.charAt(j);
        if (cj === '#') {
          while (j < n && text.charAt(j) !== '\n') {
            j++;
          }
          continue;
        }
        if (cj === ' ' || cj === '\t' || cj === '\r' || cj === '\n') {
          j++;
          continue;
        }
        if (cj === '{') {
          open = j;
        }
        break;
      }
      if (open >= 0) {
        // find the matching close brace
        let d = 1;
        let st = 0;
        let k = open + 1;
        while (k < n) {
          const ck = text.charAt(k);
          if (st === 3) {
            if (ck === '\n') {
              st = 0;
            }
            k++;
            continue;
          }
          if (st === 1 || st === 2) {
            if (ck === '\\') {
              k += 2;
              continue;
            }
            if ((st === 1 && ck === "'") || (st === 2 && ck === '"')) {
              st = 0;
            }
            k++;
            continue;
          }
          if (ck === '#') {
            st = 3;
          } else if (ck === "'") {
            st = 1;
          } else if (ck === '"') {
            st = 2;
          } else if (ck === '{') {
            d++;
          } else if (ck === '}') {
            d--;
            if (d === 0) {
              const r = new BlockRange();
              r.start = open + 1;
              r.end = k;
              return r;
            }
          }
          k++;
        }
        return null; // unbalanced
      }
      i += 7;
      continue;
    }
    i++;
  }
  return null;
}

class LineRec {
  start: number = 0; // absolute offset of the line start
  end: number = 0; // offset just past the trailing newline (or text end)
  depthStart: number = 1; // brace depth at line start, routing body = 1
  parenDelta: number = 0;
  hasArrow: boolean = false;
  marked: boolean = false;
  blank: boolean = true;
  text: string = '';
}

/** Split [start, end) of text into line records with scan metadata. */
function scanLines(text: string, start: number, end: number): LineRec[] {
  const out: LineRec[] = [];
  let depth = 1;
  let i = start;
  while (i < end) {
    let j = text.indexOf('\n', i);
    if (j < 0 || j >= end) {
      j = end;
    }
    const lineEnd = j < end ? j + 1 : end;
    const raw = text.substring(i, j);
    const rec = new LineRec();
    rec.start = i;
    rec.end = lineEnd;
    rec.text = raw;
    rec.depthStart = depth;
    // per-line scan: strings/comments do not span lines in practice
    let state = 0;
    let paren = 0;
    let arrow = false;
    let hasCode = false;
    for (let p = 0; p < raw.length; p++) {
      const c = raw.charAt(p);
      if (state === 3) {
        break;
      }
      if (state === 1 || state === 2) {
        if (c === '\\') {
          p++;
          continue;
        }
        if ((state === 1 && c === "'") || (state === 2 && c === '"')) {
          state = 0;
        }
        continue;
      }
      if (c === '#') {
        state = 3;
        break;
      }
      if (c === "'") {
        state = 1;
        hasCode = true;
        continue;
      }
      if (c === '"') {
        state = 2;
        hasCode = true;
        continue;
      }
      if (c === '(') {
        paren++;
      } else if (c === ')') {
        paren--;
      } else if (c === '{') {
        depth++;
      } else if (c === '}') {
        depth--;
      } else if (c === '-' && p + 1 < raw.length && raw.charAt(p + 1) === '>') {
        arrow = true;
      }
      if (c !== ' ' && c !== '\t' && c !== '\r') {
        hasCode = true;
      }
    }
    rec.parenDelta = paren;
    rec.hasArrow = arrow;
    rec.blank = !hasCode;
    for (const m of MARKS) {
      if (raw.indexOf(m) >= 0) {
        rec.marked = true;
      }
    }
    out.push(rec);
    i = lineEnd;
  }
  return out;
}

function markIndex(line: string): number {
  let best = -1;
  for (const m of MARKS) {
    const idx = line.indexOf(m);
    if (idx >= 0 && (best < 0 || idx < best)) {
      best = idx;
    }
  }
  return best;
}

/** Target of the marked catch-all rule ('' = none / auto, 'direct' allowed). */
export function readModeTarget(text: string): string {
  const block = routingBlock(text);
  if (block === null) {
    return '';
  }
  const lines = scanLines(text, block.start, block.end);
  for (const rec of lines) {
    if (!rec.marked) {
      continue;
    }
    const mi = markIndex(rec.text);
    const seg = mi >= 0 ? rec.text.substring(0, mi) : rec.text;
    const arrow = seg.lastIndexOf('->');
    if (arrow < 0) {
      continue;
    }
    let target = seg.substring(arrow + 2).trim();
    const paren = target.indexOf('(');
    if (paren >= 0) {
      target = target.substring(0, paren).trim();
    }
    if (target.startsWith("'") && target.endsWith("'") && target.length >= 2) {
      target = target.substring(1, target.length - 1);
    }
    if (target !== '') {
      return target;
    }
  }
  return '';
}

/**
 * Return the config with the catch-all set to `target` (a group name),
 * or removed when target is ''. Mirrors doona's placement: after the
 * leading run of must rules, before ordinary rules; refuses when must
 * rules are interleaved with ordinary ones.
 */
export function writeModeTarget(text: string, target: string): DaeModeWrite {
  const res = new DaeModeWrite();
  const block = routingBlock(text);
  if (block === null) {
    res.error = 'no routing block in config';
    return res;
  }
  // 1) drop existing marked lines inside the routing block
  const lines = scanLines(text, block.start, block.end);
  let rebuilt = text.substring(0, block.start);
  for (const rec of lines) {
    if (!rec.marked) {
      rebuilt += text.substring(rec.start, rec.end);
    }
  }
  rebuilt += text.substring(block.end);
  if (target === '') {
    res.ok = true;
    res.text = rebuilt;
    return res;
  }
  // 2) locate the block again in the rebuilt text and chunk its rules
  const b2 = routingBlock(rebuilt);
  if (b2 === null) {
    res.error = 'no routing block in config';
    return res;
  }
  const recs = scanLines(rebuilt, b2.start, b2.end);
  // chunk: a statement starts at a depth-1 non-blank line and continues
  // while parentheses are unbalanced or following lines sit deeper
  class Chunk {
    end: number = 0;
    isRule: boolean = false;
    isMust: boolean = false;
  }
  const chunks: Chunk[] = [];
  let indent = '';
  let idx = 0;
  while (idx < recs.length) {
    const first = recs[idx];
    if (first.blank || first.depthStart !== 1) {
      idx++;
      continue;
    }
    if (indent === '') {
      const m = /^[ \t]+/.exec(first.text);
      indent = m !== null ? m[0] : '';
    }
    let paren = 0;
    let chunkText = '';
    let end = first.end;
    let j = idx;
    while (j < recs.length) {
      const r = recs[j];
      paren += r.parenDelta;
      chunkText += r.text + '\n';
      end = r.end;
      j++;
      if (paren <= 0) {
        // continue only when the next line is deeper (continuation)
        if (j < recs.length && recs[j].depthStart > 1 && !recs[j].blank) {
          continue;
        }
        break;
      }
    }
    const ch = new Chunk();
    ch.end = end;
    const arrow = chunkText.lastIndexOf('->');
    ch.isRule = arrow >= 0;
    if (ch.isRule) {
      const after = chunkText.substring(arrow + 2);
      ch.isMust = /^\s*\S+\s*\(\s*must\b/.test(after);
    }
    chunks.push(ch);
    idx = j;
  }
  if (indent === '') {
    indent = '    ';
  }
  // 3) insertion point: after the leading must-rule run
  let insertPos = b2.start;
  if (insertPos < rebuilt.length && rebuilt.charAt(insertPos) === '\n') {
    insertPos++;
  }
  let seenOrdinary = false;
  for (const ch of chunks) {
    if (!ch.isRule) {
      continue;
    }
    if (ch.isMust) {
      if (seenOrdinary) {
        res.error = 'must rules are interleaved with ordinary rules; refusing to insert the catch-all';
        return res;
      }
      insertPos = ch.end;
    } else {
      seenOrdinary = true;
    }
  }
  const line = indent + 'l4proto(tcp, udp) -> ' + target + ' ' + OUR_MARK + '\n';
  const prefix = insertPos > 0 && rebuilt.charAt(insertPos - 1) !== '\n' ? '\n' : '';
  res.ok = true;
  res.text = rebuilt.substring(0, insertPos) + prefix + line + rebuilt.substring(insertPos);
  return res;
}
