// GET /appcast.xml — the Sparkle update feed the app checks, built from the release in latest.json.

import { latestRelease, methodNotAllowed, unavailable } from './_shared/releases.js';

const MINIMUM_SYSTEM_VERSION = '14.0';

function xml(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}

export async function onRequest({ request, env }) {
  if (request.method !== 'GET' && request.method !== 'HEAD') return methodNotAllowed();

  const release = await latestRelease(env);
  // Sparkle only installs updates with a valid signature, so an unsigned release isn't offered.
  if (release === null || release.edSignature === null || release.size === null || release.build === null) {
    return unavailable();
  }

  const origin = new URL(request.url).origin;
  const pubDate = new Date(release.publishedAt ?? Date.now()).toUTCString();
  const body = `<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Press59</title>
    <link>${xml(origin)}/</link>
    <item>
      <title>Press59 ${xml(release.version)}</title>
      <pubDate>${xml(pubDate)}</pubDate>
      <sparkle:version>${xml(release.build)}</sparkle:version>
      <sparkle:shortVersionString>${xml(release.version)}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>${MINIMUM_SYSTEM_VERSION}</sparkle:minimumSystemVersion>
      <enclosure url="${xml(origin)}/download/${xml(encodeURIComponent(release.filename))}" length="${release.size}" type="application/octet-stream" sparkle:edSignature="${xml(release.edSignature)}"/>
    </item>
  </channel>
</rss>
`;

  return new Response(request.method === 'HEAD' ? null : body, {
    headers: {
      'cache-control': 'public, max-age=300',
      'content-type': 'application/rss+xml; charset=utf-8',
      'x-content-type-options': 'nosniff',
    },
  });
}
