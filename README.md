# ASMCP skills

Agent skills for ASMCP, the MCP server for B&R Automation Studio 6. ASMCP reads this repository as a **skill
source**: in Automation Studio, Tools > ASMCP Server..., tab **Skills**, add

```
https://github.com/jooansk/asmcp-skills
```

and the skills below appear in the list. Tick the ones you want and press **Install / Update**: ASMCP copies them into
the agents' skills folders (Claude Code `.claude\skills`, Codex / GitHub Copilot `.agents\skills`), for you or for the
open project, and serves each one as an `as_guide` topic too.

> This repository is a test of the skill source mechanism. Its skills are samples.

## Layout

```
asmcp-skills.json           optional: the skill groups of this repository
skills/<name>/SKILL.md      one folder per skill (the open Agent Skills format)
skills/<name>/...           further files the skill points to
```

## A skill

```markdown
---
name: conveyor-station              # = the folder name: lower case, digits, hyphens
description: What it is for ... Use when ...   # at most 1024 characters; agents see it all the time
metadata:
  group: conveyors                  # a group of asmcp-skills.json, or a built-in one (core, motion, hmi ...)
  version: "1.0.0"
  min-asmcp: "1.44.0"               # optional: the oldest ASMCP it works with
  requires-tools: "add_station, add_device"   # optional: ASMCP tools the text uses
---
# Title

The text the agent reads.
```

ASMCP installs a skill as `asmcp-<name>` (it writes that name into the installed SKILL.md and a line saying where the
skill comes from). A name that a built-in ASMCP guide already has is not installed: the built-in one wins. Names
starting with `asmcp-` are ASMCP's own.

## Rules for contributions

- One pull request per skill or change; somebody else reviews it. A skill's text steers agents that write PLC code
  and transfer it to controllers.
- Name only ASMCP tools that exist in the `min-asmcp` version, and list them in `requires-tools`.
- Write what the agent must do and why, not B&R's Help pages copied: link or name the Help page instead.
