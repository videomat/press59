// Reads the release manifest that scripts/release uploads to R2 (bound as RELEASES).

const MANIFEST_KEY = 'latest.json';

function isNonEmptyString(value) {
  return typeof value === 'string' && value.trim().length > 0;
}

export async function latestRelease(env) {
  const manifest = await env.RELEASES.get(MANIFEST_KEY);
  if (manifest === null) return null;

  let release;
  try {
    release = await manifest.json();
  } catch {
    return null;
  }

  if (
    !isNonEmptyString(release?.version)
    || !isNonEmptyString(release?.key)
    || !isNonEmptyString(release?.filename)
    || release.filename.includes('/')
    || release.filename.includes('\\')
  ) {
    return null;
  }

  return {
    version: release.version.trim(),
    build: release.build ?? null,
    key: release.key.trim(),
    filename: release.filename.trim(),
    size: Number.isFinite(release.size) ? release.size : null,
    sha256: release.sha256 ?? null,
    publishedAt: release.publishedAt ?? null,
  };
}

export function unavailable() {
  return new Response('Press59 is not available for download yet.', {
    status: 503,
    headers: {
      'cache-control': 'no-store',
      'content-type': 'text/plain; charset=utf-8',
      'retry-after': '300',
    },
  });
}

export function methodNotAllowed() {
  return new Response('Method not allowed', { status: 405, headers: { allow: 'GET, HEAD' } });
}
