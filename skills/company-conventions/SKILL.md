---
name: company-conventions
description: "Template, not rules: how a company makes its own conventions skill for ASMCP agents (versions, project structure, naming beyond the B&R guidelines, standard hardware, libraries, machine control, HMI style, documentation and delivery, responsibilities, customer standards), kept in a private skill source, with a skeleton to fill in with the user. Use only when the user wants to create or fill in their company's or a customer's conventions skill; the skeleton's placeholders are not rules."
metadata:
  group: company
  version: "0.1.0"
  min-asmcp: "1.44.0"
---
# Company conventions: a template

ASMCP's guides say how B&R technology works; the project's `ASMCP.md` holds one project's conventions (as_guide
'project'). Between them sit the company's own rules: the versions it has approved, its standard hardware and
libraries, its HMI style, what every delivery contains, who decides what. This skill helps the user write them down
once, as a skill every agent in the company reads.

## Making the company's skill

1. **Keep it private.** Copy [TEMPLATE.md](TEMPLATE.md) into a new folder `<company>-conventions/SKILL.md` in a
   private skill source: a folder on the team's share (Tools > ASMCP Server..., Skills, Sources: its path), or a
   private repository once ASMCP reads those. Never a public repository: version approvals, hardware lists,
   customer names and responsibilities are company information.
2. **Name and description:** `name:` = the folder's name (lower case, digits, hyphens; not starting with `asmcp-`).
   The description decides when agents read it, so it names the company and ends with "Use at the start of every
   task in a <Company> project."
3. **Fill it in with the user, section by section.** Propose facts from a reference project the user names
   (`runtime_versions`, `hardware`, `list_objects`, `list_libraries`, its ASMCP.md through as_guide 'project') and let
   the user confirm or correct each. Delete a section that does not apply; leave no placeholder behind.
4. **A reason for each rule**, in a few words: agents follow a reason better and see when a rule does not fit.
5. **Only what differs:** what ASMCP's guides already say (the B&R guidelines, OMC, DevLib, documentation) needs no
   copy; write only the company's additions and deviations, with the guide's name.
6. **Version** (`metadata.version`): raise it at every change; the team gets it with Install / Update.

Precedence, as the template states it: the project's ASMCP.md, then the company skill, then the B&R Coding
Guidelines and ASMCP's guides - where they differ. A customer's standard that applies to all of that customer's
projects is best a skill of its own (`<customer>-standard`) in the same private source.
