---
name: block-hardcoded-credentials
enabled: true
event: file
action: block
conditions:
  - field: new_text
    operator: regex_match
    pattern: (password|secret_key|app_password|token)\s*[:=]\s*['"][^'"]{8,}['"]
  - field: file_path
    operator: not_contains
    pattern: .local.md
---

**Hardcoded credential detected!**

You are writing what appears to be a hardcoded password, token, or secret key directly into source code.

**Why this is blocked:**
- Credentials in source code get committed to git history
- Even if removed later, they remain in git history forever
- This project has had credential leaks before (config.yaml)

**Instead:**
- Use environment variables or `.env` files (which are gitignored)
- Reference `config.yaml` values at runtime
- Use PocketBase auth tokens from secure storage
