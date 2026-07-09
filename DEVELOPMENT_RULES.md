# The Palace — Development Rules

These rules exist to prevent future development from slowly transforming The Palace into an ordinary platform.

---

## BEFORE ANY CODE CHANGES

### 1. The Charter Test
Every proposed feature must pass:

```
Q: Which section of the CHARTER.md authorizes this feature?
A: [Must have a specific Charter reference]

If answer is "none," the feature is REJECTED or must be redesigned.
```

### 2. The Institutional Purpose Test
Before creating any database table, API, or page:

```
Q: What institutional concept does this represent?
A: [Must define the institutional relationship]

If answer is "it's needed for a feature," STOP and redesign.
```

### 3. The Member Experience Test
Before shipping any user-facing change:

```
Q: Does this make members feel like they belong to an institution?
A: YES = Ship it
   NO = Redesign it
```

---

## FILE ORGANIZATION

```
the-palace/
├── docs/
│   ├── CHARTER.md                    (Governing document)
│   ├── TECHNICAL_ARCHITECTURE.md     (System design)
│   └── DATABASE_SCHEMA.md            (Data relationships)
│
├── app/                              (User-facing institutional spaces)
│   ├── gate/                         (Admission entrance)
│   ├── throne/                       (Member personal domain)
│   ├── chambers/                     (Protected institutional spaces)
│   ├── butler/                       (Administrative operations)
│   └── treasury/                     (Financial systems)
│
├── lib/                              (Reusable institutional logic)
│   ├── services/
│   │   ├── member.service.js
│   │   ├── standing.service.js
│   │   ├── chamber.service.js
│   │   └── admission.service.js
│   │
│   └── engine/                       (Institutional rules)
│       ├── membership.js             (Standing logic)
│       ├── permissions.js            (Access control)
│       ├── admission.js              (Entry process)
│       └── security.js               (Protection rules)
│
├── database/
│   ├── migrations/                   (Numbered schema changes)
│   │   ├── 001_initial.sql
│   │   ├── 002_members.sql
│   │   └── ...
│   └── schema.sql                    (Current state)
│
└── tests/
    ├── engine/                       (Test institutional logic)
    └── security/                     (Test access control)
```

---

## DATABASE RULES

### Creating Tables

Before writing SQL:

1. **Read existing tables** — Can this concept extend an existing table?
2. **Document the institution concept** — What does this represent?
3. **Write the migration** — Use numbered migrations (001_, 002_, etc.)
4. **Add RLS policies** — Define who can access what
5. **Test with different Standing levels** — Verify access control works

### Never:
- ❌ Manually modify production tables without migrations
- ❌ Create duplicate tables that represent the same concept
- ❌ Delete columns/relationships without analyzing impact
- ❌ Bypass RLS policies to make features work faster

### Migration Naming
```
database/migrations/
├── 001_initial_schema.sql           (Create base tables)
├── 002_members_and_identity.sql     (Member records)
├── 003_standing_system.sql          (Standing relationships)
├── 004_offices_and_authority.sql    (Office structure)
├── 005_chambers_and_access.sql      (Chamber protection)
├── 006_permissions_engine.sql       (Access control)
└── 007_treasury_and_audit.sql       (Financial + history)
```

---

## GIT COMMIT STANDARDS

Every commit must have institutional purpose:

### ✅ Good Commits
```
git commit -m "INSTITUTION: Create Standing system with Council and Authority levels"
git commit -m "SECURITY: Implement RLS policies for Chamber access control"
git commit -m "EXPERIENCE: Royal Throne display member's Standing and available Chambers"
```

### ❌ Bad Commits
```
git commit -m "fix stuff"
git commit -m "add feature"
git commit -m "update code"
```

---

## CODE REVIEW CHECKLIST

Before merging any PR:

- [ ] Does it serve an institutional purpose defined in CHARTER.md?
- [ ] Are database changes in numbered migrations?
- [ ] Do RLS policies prevent unauthorized access?
- [ ] Will this make members feel like customers or like they belong to an institution?
- [ ] Is institutional history preserved (audit logs, etc.)?
- [ ] Are there no self-assignment vulnerabilities?

---

## AI DEVELOPER RULES

If AI is used to develop features:

**Before coding:**
- Read CHARTER.md completely
- Read TECHNICAL_ARCHITECTURE.md
- Explain what institutional concept is being implemented
- Identify all files affected
- Assess security implications

**After coding:**
- Explain what was built
- Show migrations created
- Demonstrate RLS policies
- Provide test scenarios
- Explain Charter alignment

**Never:**
- ❌ Rewrite working systems without explicit approval
- ❌ Bypass security for convenience
- ❌ Create duplicate implementations
- ❌ Use software terminology instead of institutional language
- ❌ Make features work by removing security checks

---

## TECHNICAL DEBT TRACKING

Track violations and fixes:

```
DEBT: [Description]
SEVERITY: Low/Medium/High
CHARTER_IMPACT: [How it violates the Charter]
FIX_PLAN: [How to resolve it]
STATUS: Open/In Progress/Fixed
```

---

## WHEN IN DOUBT

If unclear whether something is allowed:

1. Read CHARTER.md
2. Check DEVELOPMENT_RULES.md
3. Ask: "Does this make The Palace feel more like an institution?"

If still unclear: **Default to NO.** It's easier to add features later than to remove them.

---

*Last Updated: 2026-07-09*
*This document is locked. Changes require institutional review.*
