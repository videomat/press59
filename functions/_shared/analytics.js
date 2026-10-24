// Private download analytics: one row per download in the D1 database bound as DB.
// There is no public read endpoint; read the numbers with ./scripts/stats.

const HOMEPAGE_HOSTS = new Set(['press59.win', 'www.press59.win', 'press59.pages.dev', 'localhost', '127.0.0.1']);
const BOT_USER_AGENT = /bot|crawler|spider|slurp|preview|facebookexternalhit|headlesschrome|lighthouse|curl|wget|python|go-http-client|httpie|postman|powershell/i;
const BROWSER_USER_AGENT = /chrome|chromium|firefox|safari|edg|opr\//i;

function source(request) {
  // The app's updater downloads /download/<filename>, the URL in /appcast.xml.
  if (new URL(request.url).pathname.startsWith('/download/')) return { source: 'update', referrerHost: null };
  const referrer = request.headers.get('referer');
  if (!referrer) return { source: 'direct', referrerHost: null };
  try {
    const host = new URL(referrer).hostname;
    const ownHost = new URL(request.url).hostname;
    if (host === ownHost || HOMEPAGE_HOSTS.has(host) || host.endsWith('.press59.pages.dev')) {
      return { source: 'homepage', referrerHost: null };
    }
    return { source: 'external', referrerHost: host };
  } catch {
    return { source: 'direct', referrerHost: null };
  }
}

// The ?ref= on /download: a tag put on shared links (press59.win/?ref=reddit) or the site
// that sent a visitor to the homepage, which main.js adds to its download links.
const CHANNEL = /^[a-z0-9][a-z0-9._-]{0,63}$/;

function channel(request) {
  const ref = new URL(request.url).searchParams.get('ref')?.toLowerCase().replace(/^www\./, '');
  return ref && CHANNEL.test(ref) ? ref : null;
}

function client(request) {
  const userAgent = request.headers.get('user-agent') ?? '';
  if (request.cf?.botManagement?.verifiedBot) return 'bot';
  if (!userAgent || BOT_USER_AGENT.test(userAgent)) return 'bot';
  // A click in a browser sends these navigation headers; scripts and prefetchers usually don't.
  const navigated = request.headers.get('sec-fetch-mode') === 'navigate'
    || request.headers.get('sec-fetch-user') === '?1';
  return BROWSER_USER_AGENT.test(userAgent) && navigated ? 'human' : 'unknown';
}

export async function recordDownload(env, request, release) {
  if (!env.DB) return;
  const { source: from, referrerHost } = source(request);
  try {
    await env.DB
      .prepare('INSERT INTO downloads (downloaded_at, version, country, source, referrer_host, channel, client) VALUES (?, ?, ?, ?, ?, ?, ?)')
      .bind(new Date().toISOString(), release.version, request.cf?.country ?? null, from, referrerHost, channel(request), client(request))
      .run();
  } catch (error) {
    // Analytics must never break a download.
    console.error('Recording the download failed', error);
  }
}
