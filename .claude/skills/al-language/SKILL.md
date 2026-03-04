---
name: al-language
description: Use when writing, reviewing, or modifying AL code for Microsoft Dynamics 365 Business Central. Covers syntax, object types, data types, patterns, and best practices.
---

# AL Language Skill

Skill for AL (Application Language) programming in Microsoft Dynamics 365 Business Central.

## When to use

- Writing or reviewing AL code
- Developing Business Central Extensions
- Creating/extending Tables, Pages, Codeunits, Reports
- Implementing BC-specific logic

## References

- `references/syntax.md` - AL Syntax Basics
- `references/objects.md` - Table, Page, Codeunit, Report Objects
- `references/datatypes.md` - Data Types and Methods
- `references/patterns.md` - Best Practices and Code Patterns
- `references/index.db` - SQLite index of all AL objects (generated)

## Object Index (SQLite)

A SQLite database indexes all AL objects across configured source repos.

### Setup

1. Edit `sources.conf` to list repo paths (one per line)
2. Run `scripts/build-index.sh` to generate `references/index.db`

### Searching

```bash
# By name
scripts/bc-find.sh "Sales Header"

# By type + name
scripts/bc-find.sh --type table "Sales"

# By object ID
scripts/bc-find.sh --id 36

# By source repo
scripts/bc-find.sh --repo BusinessCentralApps "Post"

# Direct SQL
sqlite3 references/index.db "SELECT * FROM objects WHERE name LIKE '%Sales%' AND type='table';"
```

### Schema

```sql
objects(id, type, object_id, name, filepath, source_repo, line)
```

### Adding Sources

Edit `sources.conf` to add new repos (e.g. custom modules, dependencies), then re-run `build-index.sh`.

## Key Concepts

### Object Types
- **Table / TableExtension** - Data structure
- **Page / PageExtension** - UI/Forms
- **Codeunit** - Business logic (like classes)
- **Report / ReportExtension** - Reports
- **XMLport** - Data import/export
- **Query** - Data queries
- **Enum / EnumExtension** - Enumerations

### Extension Development
BC development is done through Extensions (Apps) that extend the base system without modifying it.

### Object ID Ranges
- 1-49,999: Microsoft Base App
- 50,000-99,999: Per-tenant Extensions (PTEs)
- 100,000+: AppSource Apps

## Quick Reference

```al
// Declare variables
var
    myInt: Integer;
    myText: Text[100];
    myRec: Record Customer;

// Assignment
myInt := 42;
myText := 'Hello';

// Condition
if myInt > 10 then
    Message('Large')
else
    Message('Small');

// Loop
for i := 1 to 10 do
    Total += i;

// Record operations
if Customer.Get('10000') then
    Message(Customer.Name);

Customer.SetRange("Country/Region Code", 'DE');
if Customer.FindSet() then
    repeat
        // Process each customer
    until Customer.Next() = 0;
```

## Source Repos

Configured in `sources.conf`. Default repos:

| Repo | Content | Use |
|------|---------|-----|
| **BusinessCentralApps** | Base Application Source | Look up core BC logic |
| **BCApps** | System Application, Dev Tools | System functions |
| **ALAppExtensions** | First-Party Apps, Localizations | Extension patterns |
| **BCTech** | Samples, Performance tips | Examples |
| **AL-Go** | GitHub Actions for BC CI/CD | DevOps Engine |

Add custom repos (own modules, dependencies) by editing `sources.conf`.

### AL-Go Workflow

1. New project: Use `AL-Go-PTE` or `AL-Go-AppSource` as GitHub template
2. Repo includes ready-made workflows (CI/CD, Deploy, Release)
3. `AL-Go` repo contains the Actions used by the workflows

## Docs

- [AL Programming](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/devenv-programming-in-al)
- [AL Reference](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/devenv-reference-overview)
- [AL-Go Workshop](https://aka.ms/algoworkshop)
