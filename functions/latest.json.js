// GET /latest.json — the current release's public details, shown under the homepage download buttons.
// The app's updater uses /appcast.xml instead.

import { latestRelease, methodNotAllowed, unavailable } from './_shared/releases.js';

export async function onRequest({ request, env }) {
  if (request.method !== 'GET' && request.method !== 'HEAD') return methodNotAllowed();

  const release = await latestRelease(env);
  if (release === null) return unavailable();

  const { version, build, filename, size, sha256, publishedAt } = release;
  return Response.json(
    { version, build, filename, size, sha256, publishedAt, url: '/download' },
    {
      headers: {
        'access-control-allow-origin': '*',
        'cache-control': 'public, max-age=300',
        'x-content-type-options': 'nosniff',
      },
    },
  );
}
