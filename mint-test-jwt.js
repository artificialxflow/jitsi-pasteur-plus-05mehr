#!/usr/bin/env node
/**
 * Smoke test: mint HS256 JWT for meet.pasteur-plus.com (same contract as Pasteur Plus API).
 *
 * Usage (PowerShell):
 *   $env:JITSI_APP_SECRET="..."; node mint-test-jwt.js
 *
 * Usage (bash):
 *   JITSI_APP_SECRET=... node mint-test-jwt.js
 *
 * Optional:
 *   ROOM=visite-123 DISPLAY_NAME='پزشک تست' MODERATOR=true
 */
const crypto = require('crypto');

const secret = process.env.JITSI_APP_SECRET || process.env.JWT_APP_SECRET;
const appId = process.env.JITSI_APP_ID || process.env.JWT_APP_ID || 'pasteur_plus';
const domain = process.env.JITSI_DOMAIN || 'meet.pasteur-plus.com';
// Room id in URL (keep ASCII for stable links); shown title is derived from this.
const room = process.env.ROOM || 'pasteur-visite';
const moderator = process.env.MODERATOR !== 'false';
const exp = Math.floor(Date.now() / 1000) + Number(process.env.TTL_SEC || 3600);
const displayName = process.env.DISPLAY_NAME || 'کاربر پاستور پلاس';

if (!secret) {
  console.error('Set JITSI_APP_SECRET (or JWT_APP_SECRET) in the environment.');
  process.exit(1);
}

const header = Buffer.from(JSON.stringify({ alg: 'HS256', typ: 'JWT' })).toString('base64url');
const payload = Buffer.from(
  JSON.stringify({
    iss: appId,
    aud: appId,
    sub: process.env.SUB || 'pasteur-user',
    room,
    moderator,
    exp,
    context: {
      user: { name: displayName },
    },
  }),
).toString('base64url');
const sig = crypto.createHmac('sha256', secret).update(`${header}.${payload}`).digest('base64url');
const jwt = `${header}.${payload}.${sig}`;

const base = `https://${domain.replace(/^https?:\/\//, '')}`;
console.log(jwt);
console.error(`\nOpen in browser:\n${base}/${room}?jwt=${jwt}\n`);
console.error(`Display name: ${displayName} | room: ${room} | moderator: ${moderator}\n`);
