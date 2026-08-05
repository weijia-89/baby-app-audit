# CI Troubleshooting

Quick fixes when CI goes red.

## If unit tests fail

Check that `jsonschema` is installed before the test step runs.

```bash
pip install jsonschema==4.26.0
bash tests/test-decode-traffic.sh
```

Tests 12 and 13 require it for strict-mode schema validation. A missing install fails with `jsonschema module required for strict mode validation`.

## If smoke tests fail

The smoke test greps `localonly/candidates.md` for the app slug. It normalizes hyphens to spaces (`baby-connect` -> `baby connect`) before matching.

- Check the app slug in `test.yml` matches an entry in `candidates.md`.
- If the app name contains a hyphen, verify both the hyphenated and spaced forms are present where the test looks.
- Command to debug locally:

```bash
APP_NORMALIZED="$(echo 'your-app' | tr '-' ' ')"
grep -qi "your-app" localonly/candidates.md || grep -qi "$APP_NORMALIZED" localonly/candidates.md
```

## If merge conflicts

`main` may have reverted changes that conflict with your branch.

- Prefer strict mode over lenient mode where both exist.
- External config files (`results/schema.json`, `localonly/skeletons/*.json`) are the source of truth when in doubt.
- Resolve conflicts in favor of the more specific, more tested version.

## If YAML parsing fails

Quote step names containing colons. GitHub Actions YAML parses unquoted strings with colons as mappings.

```yaml
# Bad
- name: Install: jsonschema

# Good
- name: "Install: jsonschema"
```
