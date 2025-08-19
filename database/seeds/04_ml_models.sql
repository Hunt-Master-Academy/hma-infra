-- Seed ML model registry (stub)
INSERT INTO ml.model_registry(name, version, artifact_url)
VALUES ('demo-model', '1.0.0', 's3://models/demo-model-1.0.0.pkl')
ON CONFLICT DO NOTHING;
