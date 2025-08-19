-- Seed sample content (stub)
INSERT INTO content.items(title, body, content_type)
VALUES ('Welcome', 'Sample content body', 'article')
ON CONFLICT DO NOTHING;
