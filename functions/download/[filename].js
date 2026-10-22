// GET /download/<filename> — the current release's DMG under its own name, for the app's updater.

import { serveRelease } from '../download.js';

export function onRequest(context) {
  return serveRelease(context, context.params.filename);
}
