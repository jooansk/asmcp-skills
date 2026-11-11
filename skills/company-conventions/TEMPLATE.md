---
name: <company>-conventions
description: "<Company>'s rules for every Automation Studio project: approved versions, project structure and names, standard hardware, libraries, machine control, HMI style, deliveries and responsibilities. Use at the start of every task in a <Company> project."
metadata:
  group: <company>
  version: "1.0.0"
  min-asmcp: "1.44.0"
---
# <Company> conventions

Read at the start of every task in a <Company> project. Where rules differ: the project's ASMCP.md (as_guide
'project') wins over this skill, and this skill over the B&R Coding Guidelines and ASMCP's guides.

## 1. Versions
- New projects: Automation Studio <6.x>, Automation Runtime <6.x.y>, mappServices <...>, mappView <...>,
  mappMotion <...>. Why: <tested together / approved by ...>.
- Existing machines keep their versions until the user decides an upgrade (`runtime_versions` shows them).

## 2. Project structure and names
- Packages: <e.g. by machine function, Logical/<Function>/...>; shared code: <...>.
- Configurations: <e.g. `Sim` for ARsim, `<Machine>` for the controller>.
- Hardware: <e.g. `<OrderNumber>_<Function>`>.
- Deviations from the B&R Coding Guidelines (as_guide 'guidelines'), each with the rule number and why:
  - <C006: ...>

## 3. Standard hardware
| Use | Order number | Why / note |
|---|---|---|
| Controller | <...> | <...> |
| I/O | <...> | <...> |
| Drives and motors | <...> | <...> |
| Panel | <...> | <...> |

Other hardware: the agent proposes, the user decides.

## 4. Libraries and own code
- Company libraries every project uses: <name, version, where they come from>.
- Not to be used in new code: <library: why, what instead>.

## 5. Machine control
- Operation modes: <e.g. as_guide 'omc' as it stands / with these additions>.
- Alarms: <numbering per station, severities and the reaction of each>.
- Line and MES interface: <OPC UA namespace, PackML / PackTags, signal list document>.

## 6. HMI
- Style: <theme, colours, logo, fonts, the standard panel's resolution>.
- Standard pages: <overview, manual, alarms, settings, users, ...>.
- Languages: <...>.

## 7. Documentation and delivery
- Every delivery contains: <package CHM, I/O list, operator manual, FAT protocol, ...>.
- File header (as_guide 'guidelines' C204): Copyright <...>, Author <...>.
- Version numbers: <scheme>; shown on the HMI and as the configuration version (as_guide 'installation').

## 8. Responsibilities
- Safety: the safety application, the risk assessment and the validation belong to <role>; agents never change
  safety programs or safety parameters.
- Transfers to machines: <role>; agents test on ARsim only.
- What may leave the company (code, customer data, logbooks): <...>.

## 9. Customers
- <Customer>: their standard is the skill `<customer>-standard`; their specification: <where>.
