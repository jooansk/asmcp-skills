---
name: demo-hello
description: Test skill from the ASMCP skill repository github.com/jooansk/asmcp-skills. Use when the user asks to test or check the ASMCP skill repository, skill sources or skills installed from GitHub.
metadata:
  group: tests
  version: "0.1.0"
---
# Skill repository test

This skill comes from a skill source, not from ASMCP itself. When the user asks to test the skill sources:

1. Call `as_status`. Report its `skillSources` line (the sources and their state) and the part of `agentSkills` that
   names the skills from skill sources.
2. Call `as_guide` with topic `list`. `demo-hello` must be named under "Installed from skill sources".
3. Call `as_guide` with topic `demo-hello`: the same text as this skill must come back.
4. Tell the user the version of this skill (the line under the front matter of the installed SKILL.md names the
   source and its commit).
