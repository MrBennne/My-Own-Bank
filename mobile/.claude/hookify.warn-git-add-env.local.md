---
name: warn-git-add-env
enabled: true
event: bash
action: warn
pattern: git\s+add\s+.*\.(env|pocketbase)
---

**Sensitive file in git add!**

You are staging a `.env` or `.pocketbase` file. These files typically contain credentials and should NOT be committed.

**Check:**
- Is the file in `.gitignore`?
- Does it contain passwords, tokens, or API keys?
- Should you be using a `.env.example` template instead?
