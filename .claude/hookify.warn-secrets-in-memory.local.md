---
name: warn-secrets-in-memory
enabled: true
event: file
action: warn
conditions:
  - field: file_path
    operator: regex_match
    pattern: memory[/\\].*\.md$
  - field: new_text
    operator: regex_match
    pattern: (ntn_[a-zA-Z0-9]+|Banking#|app_password|smtp.*password|jdyn\s+bntb)
---

**Secret detected in memory file!**

You are writing credentials or tokens to a Claude memory file. These persist across sessions and could be exposed.

**Redact or remove:**
- Notion tokens (`ntn_...`)
- PocketBase passwords
- SMTP/email credentials
- API keys
