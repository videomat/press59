// GET /download — streams the DMG that latest.json points to, straight from R2.

import { latestRelease, methodNotAllowed, unavailable } from './_shared/releases.js';

export async function onRequest({ request, env }) {
  if (request.method !== 'GET' && request.method !== 'HEAD') return methodNotAllowed();

  const release = await latestRelease(env);
  if (release === null) return unavailable();

  const object = request.method === 'HEAD'
    ? await env.RELEASES.head(release.key)
    : await env.RELEASES.get(release.key, { onlyIf: request.headers, range: request.headers });
  if (object === null) return unavailable();

  const headers = new Headers();
  object.writeHttpMetadata(headers);
  headers.set('accept-ranges', 'bytes');
  headers.set('cache-control', 'private, no-store');
  headers.set('content-disposition', `attachment; filename*=UTF-8''${encodeURIComponent(release.filename)}`);
  headers.set('etag', object.httpEtag);
  headers.set('x-content-type-options', 'nosniff');

  if (request.method === 'HEAD') {
    headers.set('content-length', String(object.size));
    return new Response(null, { status: 200, headers });
  }

  // A conditional request whose precondition failed returns metadata without a body.
  if (!('body' in object)) return new Response(null, { status: 412, headers });

  if (request.headers.has('range') && object.range) {
    const { offset, length } = object.range;
    headers.set('content-range', `bytes ${offset}-${offset + length - 1}/${object.size}`);
    headers.set('content-length', String(length));
    return new Response(object.body, { status: 206, headers });
  }

  headers.set('content-length', String(object.size));
  return new Response(object.body, { status: 200, headers });
}
