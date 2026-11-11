---
name: git-for-as
description: "Sample skill: an Automation Studio 6 project in git - what to commit and what to ignore (with a ready .gitignore and .gitattributes), the ASMCP files beside the .apj, commits that build, branches and tags per machine release, closing the project before switching branches, merging .pkg, Cpu.sw and other structure files, Ladder and HMI conflicts, passwords in descriptions, parallel work in worktrees, and the git commands an agent leaves to the user. Use when an AS project is put under version control, or for a commit, branch, merge or release tag in one."
metadata:
  group: engineering
  version: "0.1.0"
  min-asmcp: "1.44.0"
---
# An Automation Studio project in git (sample)

Automation Studio needs nothing special from git: the sources are the `.apj`, `Logical/` and `Physical/`, and the
rest is generated or belongs to one Windows user (as_guide 'files'). This skill is the team's way of working with
it. **Status of this sample (0.1.0):** from as_guide 'files' and 'workflow'; the merge advice is practice, not
measured with every AS version.

## 1. Setting it up

1. The repository's root is the project folder (where the `.apj` is). No repository there or above: suggest
   `git init` to the user (as_guide 'workflow'); don't run it unasked.
2. Copy this skill's `as.gitignore` there as `.gitignore`, and `as.gitattributes` as `.gitattributes` (the agent's
   own file tools; they are not AS objects).
3. Commits carry the user's identity: `git config user.name` / `user.email` in this repository, as the user says.
4. The first commit after a build with 0 errors, so every commit from then on starts from a project that builds.

| Keep in git | Leave out (.gitignore) |
|---|---|
| `<Project>.apj`, `Logical/`, `Physical/` | `Temp/` (build files, the ARsim installation), `Binaries/` (the build's output) |
| `ASMCP.md` (the team's conventions, as_guide 'project') | `*.set`, `*.isopen` beside the .apj (one Windows user's) |
| `ASMCP-work.md` (phase and decisions, as_guide 'workflow') | `Diagnosis/` (each user's watch and trace setups; share them by deleting that line) |
| `ASMCP-prompts.md`, the project's `.claude/skills` / `.agents/skills`, when the team shares them | install packages, RUC files, logbook exports: they go into the release store |
| tools the build calls (e.g. `Tools/PrgMonGen.exe` of the program monitor) | |

## 2. Daily work

- **Commit after each finished step that builds** (0 errors, 0 warnings in your files); the message says what
  changed and why, like the decisions in ASMCP-work.md. A step that does not build yet stays uncommitted or on a
  branch of its own.
- **Branches:** `main` = what runs on the machines; one branch per feature or field change.
- **Close the project in AS before** `git checkout`, `switch`, `pull`, `merge`, `rebase` or `stash`, or at least
  save everything: AS keeps the open project in memory and does not expect its files to change underneath. If AS
  asks to reload, reload. Open it again afterwards and build.
- `Temp/` is ignored, so a branch switch keeps the old build files: after a switch `build rebuild=true` once.
- **Several engineers or agents at once:** one `git worktree` per branch. Each worktree is a project folder of its
  own; AS opens it as a separate project. Two ARsims on one PC need an IP address each (as_guide 'runtime').

## 3. Merging

| Files | How |
|---|---|
| `.st`, `.var`, `.typ`, `.fun` | text merge, then build |
| `Package.pkg`, `IEC.prg`, `*.lby`, `Cpu.sw`, `Config.pkg`, `IoMap.iom` (lists) | keep both sides' entries; one entry changed on both sides: take one and tell the user |
| `Hardware.hw`, `Hardware.hwl`, mapp configurations (`.mpalarmxlist`, `.axis` ...) | take one side and redo the other side's change with the tools (hardware, add_mapp_config ...) |
| Ladder `.ld`, FBD `.fbd` | never by hand: the file holds generated code and a checksum, a text merge breaks the build (1112 / 1113). Take one side (`.gitattributes` makes git keep one), redo the other with write_ladder / write_fbd |
| mapp View `.page`, `.content`, `.binding`, `.eventbinding` | take one side, redo the other with the HMI tools, then check_hmi |

After every merge:
1. Open the project in AS; `list_objects` and `software_configuration`: every object and task of both sides is there.
2. A file that is in a folder but not listed in its `.pkg` / `.prg` / `.lby` is not part of the project, and AS
   deletes it when the object moves (as_guide 'files'): every new file of both sides must be listed.
3. `build rebuild=true`: 0 errors. HMI changed: check_hmi.
4. Report what was merged by hand and what you redid.

## 4. Releases

- Tag the commit that went onto a machine: `<machine>-<version>` (e.g. `boxlid-1.4.0`), the same version as the
  configuration version on the controller (as_guide 'installation').
- The installation package of that build goes into the team's release store, not into git.
- A field change made on the machine (the user's online change) gets a commit and a tag too, so the next release
  starts from what really runs.

## 5. What the agent leaves to the user

- Commits, branches and merges only when the user asks; `push`, force pushes, `reset --hard`, deleting branches and
  rebasing shared branches only on the user's explicit word.
- **Passwords in descriptions:** ASMCP writes every password it sets into that item's description in plain text,
  so the user can change it later. Before a push to a shared or public remote, search the project for them
  (users, OPC UA, certificates) and tell the user.
- Never commit secrets the user gave (tokens, customer passwords); never put them into ASMCP-work.md either.
