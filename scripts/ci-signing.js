#!/usr/bin/env node
/*
 * CI 用：把签名文件写成 hvigor 能直接使用的 signingConfigs（等价于 DevEco Studio 里手动填写 Signing Configs）。
 * hvigor 要求 build-profile.json5 中的密码是用 "material" 目录里的密钥加密过的十六进制串，
 * 这里在签名目录下随机生成一套 material 并加密密码，然后把 signingConfig 写进 build-profile.json5。
 *
 * 用法：node scripts/ci-signing.js <签名目录>
 *   目录内需要：key.p12、app.cer、app.p7b
 *   环境变量：HAP_KEY_ALIAS、HAP_KEY_PASSWORD、HAP_STORE_PASSWORD
 * 只在 CI 的临时工作区里运行；不要提交被修改后的 build-profile.json5。
 */
'use strict';
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const COMPONENT = Buffer.from(new Int8Array([49, 243 - 256, 9, 115, 214 - 256, 175 - 256, 91, 184 - 256,
  211 - 256, 190 - 256, 177 - 256, 88, 101, 131 - 256, 192 - 256, 119]).buffer);

function gcmEncrypt(key, plain) {
  const iv = crypto.randomBytes(12);
  const c = crypto.createCipheriv('aes-128-gcm', key, iv);
  const body = Buffer.concat([c.update(plain), c.final(), c.getAuthTag()]);
  const len = Buffer.alloc(4);
  len.writeUInt32BE(body.length, 0);
  return Buffer.concat([len, iv, body]);
}

function xorAll(parts) {
  const out = Buffer.alloc(16);
  for (const p of parts) {
    for (let i = 0; i < 16; i++) {
      out[i] ^= p[i];
    }
  }
  return out;
}

function writeOne(dir, bytes) {
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(path.join(dir, crypto.randomBytes(8).toString('hex')), bytes);
}

function main() {
  const dir = path.resolve(process.argv[2] || '');
  const alias = (process.env.HAP_KEY_ALIAS || '').trim();
  const keyPwd = (process.env.HAP_KEY_PASSWORD || '').trim();
  const storePwd = (process.env.HAP_STORE_PASSWORD || '').trim();
  for (const f of ['key.p12', 'app.cer', 'app.p7b']) {
    if (!fs.existsSync(path.join(dir, f))) {
      throw new Error('missing ' + f);
    }
  }
  if (!alias || !keyPwd || !storePwd) {
    throw new Error('missing HAP_KEY_ALIAS / HAP_KEY_PASSWORD / HAP_STORE_PASSWORD');
  }
  const mat = path.join(dir, 'material');
  fs.rmSync(mat, { recursive: true, force: true });
  const fds = [crypto.randomBytes(16), crypto.randomBytes(16), crypto.randomBytes(16)];
  fds.forEach((b, i) => writeOne(path.join(mat, 'fd', String(i)), b));
  const salt = crypto.randomBytes(16);
  writeOne(path.join(mat, 'ac'), salt);
  // 与 hvigor DecipherUtil.getRootKey 一致：xor 结果按 utf-8 转字符串后做 PBKDF2
  const rootKey = crypto.pbkdf2Sync(xorAll([...fds, COMPONENT]).toString(), salt, 10000, 16, 'sha256');
  const workKey = crypto.randomBytes(16);
  writeOne(path.join(mat, 'ce'), gcmEncrypt(rootKey, workKey));
  const enc = (s) => gcmEncrypt(workKey, Buffer.from(s, 'utf-8')).toString('hex');

  const profilePath = path.resolve(__dirname, '..', 'build-profile.json5');
  // build-profile.json5 本身是严格 JSON（无注释），可以直接解析
  const cfg = JSON.parse(fs.readFileSync(profilePath, 'utf-8'));
  cfg.app.signingConfigs = [{
    name: 'release',
    type: 'HarmonyOS',
    material: {
      storeFile: path.join(dir, 'key.p12'),
      storePassword: enc(storePwd),
      keyAlias: alias,
      keyPassword: enc(keyPwd),
      signAlg: 'SHA256withECDSA',
      profile: path.join(dir, 'app.p7b'),
      certpath: path.join(dir, 'app.cer')
    }
  }];
  for (const p of cfg.app.products) {
    p.signingConfig = 'release';
  }
  fs.writeFileSync(profilePath, JSON.stringify(cfg, null, 2) + '\n');
  console.log('signingConfig "release" written to build-profile.json5');
}

main();
