-- Where the visitor came from before downloading: a ?ref= tag (e.g. reddit) or, for downloads
-- from the homepage, the site that sent them there (e.g. news.ycombinator.com).
ALTER TABLE downloads ADD COLUMN channel TEXT;
