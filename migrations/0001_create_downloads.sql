-- One row per download served by /download. No IP addresses or user agents are stored.
CREATE TABLE downloads (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  downloaded_at TEXT NOT NULL,       -- UTC, ISO 8601
  version TEXT NOT NULL,
  country TEXT,                      -- Two-letter code from Cloudflare, when known
  source TEXT NOT NULL,              -- homepage | direct | external
  referrer_host TEXT,                -- Only for external sources, e.g. news.ycombinator.com
  client TEXT NOT NULL               -- human | bot | unknown
);

CREATE INDEX downloads_downloaded_at ON downloads (downloaded_at);
