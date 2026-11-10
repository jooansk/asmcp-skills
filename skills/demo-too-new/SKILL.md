---
name: demo-too-new
description: Test skill that needs a future ASMCP version. ASMCP must list it as not installable. Use never; it exists to test the min-asmcp check of skill sources.
metadata:
  group: tests
  version: "0.1.0"
  min-asmcp: "9.0.0"
---
# A skill for a future ASMCP

ASMCP 1.44 must show this skill as "needs ASMCP 9.0.0" and refuse to install it.
