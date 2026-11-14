// GET /download — streams the DMG that latest.json points to, straight from R2.
// GET /download/<filename> (functions/download/[filename].js) does the same for the app's updater.

import { recordDownload } from './_shared/analytics.js';
import { latestRelease, methodNotAllowed, unavailable } from './_shared/releases.js';

export function onRequest(context) {
  return serveRelease(context);
}

// A release's DMG as scripts/package names it, e.g. Press59-0.3.0.dmg.
const RELEASE_FILENAME = /^Press59-([0-9A-Za-z][0-9A-Za-z.-]*)\.dmg$/;

function notFound() {
  return new Response('Not found', { status: 404, headers: { 'cache-control': 'no-store' } });
}

// An earlier release, which stays in R2 under its own name. An app that was offered it as an
// update, or read a cached /appcast.xml, may still ask for it after a newer one is published.
function earlierRelease(filename) {
  const version = RELEASE_FILENAME.exec(filename)?.[1];
  return version ? { version, key: `releases/${filename}`, filename } : null;
}

// Streams the current release. With `filename`, that file and no other, so an update signed for
// one version is never served another version's DMG.
export async function serveRelease({ request, env, waitUntil }, filename = null) {
  if (request.method !== 'GET' && request.method !== 'HEAD') return methodNotAllowed();

  let release = await latestRelease(env);
  if (filename !== null && filename !== release?.filename) {
    release = earlierRelease(filename);
    if (release === null) return notFound();
  }
  if (release === null) return unavailable();

  const object = request.method === 'HEAD'
    ? await env.RELEASES.head(release.key)
    : await env.RELEASES.get(release.key, { onlyIf: request.headers, range: request.headers });
  if (object === null) return filename === null ? unavailable() : notFound();

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

  // Count whole-file downloads only; resumed or partial (range) requests are the same download.
  headers.set('content-length', String(object.size));
  waitUntil(recordDownload(env, request, release));
  return new Response(object.body, { status: 200, headers });
}
