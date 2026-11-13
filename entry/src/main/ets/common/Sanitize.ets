/**
 * Redaction pass for crash-log text before it is written to disk (1.4.19). Pure logic, no imports;
 * Node-tested in scripts/test-logic.mjs.
 *
 * CrashLog.write assembles a fixed header (time / app version / device / OS / error kind) plus the raw
 * errorManager detail. That detail is an exception message + stack trace and could in principle carry a
 * backend request URL, an IP address or a credential, so the whole text goes through sanitizeCrashText
 * before FileUtil.writeText. The rules replace values only — line structure, class / method names and
 * three-part version numbers stay readable (the IPv4 rule needs four numeric segments, so "1.4.19"
 * and timestamps are never hit).
 */

/**
 * Applies the redaction rules in order: full URLs first (so an IP inside a URL leaves no residue),
 * then credential forms, then bare IP addresses.
 */
export function sanitizeCrashText(text: string): string {
  let out = text;
  // 1. URLs (scheme + everything up to whitespace / quote / closing bracket)
  out = out.replace(/https?:\/\/[^\s"'\)\]]+/g, '<url>');
  // 2. Bearer tokens first, so "Authorization: Bearer x" leaves nothing behind for rule 3 to miss
  out = out.replace(/Bearer\s+\S+/gi, 'Bearer ***');
  // 3. Authorization header / assignment values
  out = out.replace(/(Authorization\s*[:=]\s*)\S+/gi, '$1***');
  // 4. Credential-looking query parameters in whatever URL fragments remain
  out = out.replace(/([?&](secret|token|key|password|auth)=)[^&\s]+/gi, '$1***');
  // 5. Bracketed IPv6 (only when the bracket content holds a colon), with optional port
  out = out.replace(/\[[^\]]*:[^\]]*\](:\d+)?/g, '***');
  // 6. Bare IPv4 with optional port
  out = out.replace(/\b\d{1,3}(\.\d{1,3}){3}(:\d{1,5})?\b/g, '***');
  return out;
}
