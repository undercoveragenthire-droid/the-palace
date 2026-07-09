# The Palace — A Digital Institution

> "I am not simply using a platform. I belong to The Palace."

---

## What Is The Palace?

The Palace is not a website, app, or SaaS product. It is a **private digital institution** where membership is meaningful, standards are maintained, and belonging is earned.

Think of it like a university, professional society, or exclusive club — but in a digital environment.

**The difference:**
- ❌ Netflix sells movies. You don't "belong" to Netflix.
- ❌ Slack sells productivity tools. You don't "belong" to Slack.
- ✅ **The Palace offers belonging to an institution with standards, governance, and recognition.**

---

## Core Philosophy

### Identity Over Anonymity
Every member enters with a **Royal Identity** — a recognized institutional name. Not an anonymous account. Not a username. A place in an institution.

### Standing Over Status
A member's position within The Palace is **earned through trust and responsibility**, not purchased through payment alone. Standing reflects institutional recognition, not software features.

### Belonging Over Subscription
Members **belong to an institution**. They don't subscribe to a service. Language matters:
- ❌ "Your subscription expires"
- ✅ "Your Standing requires renewal"

### Quality Over Growth
The Palace prioritizes exclusivity and institutional standards over unlimited expansion. Growth is welcome, but never at the expense of institutional integrity.

### Authority Through Responsibility
No person holds power without accountability. Authority exists to protect the institution, not benefit the holder.

---

## Institutional Structure

### Royal Identity
When a person is admitted, they receive a **Royal Identity** — a permanent institutional name in the format `PALACE-XXXXXX`. This identity remains even if their Standing changes.

### Standing Levels
Each member has a recognized position within The Palace:

| Standing | Description | Access Level |
|----------|-------------|--------------|
| **Visitor** | External viewing only | 0 |
| **Member** | Foundation membership with Royal Identity | 1 |
| **Circle** | Higher recognition and broader access | 2 |
| **Council** | Advisory institutional participation | 3 |
| **Authority** | Highest institutional responsibility and governance | 4 |

### Offices
Members may hold institutional **Offices** — responsibilities that carry specific authority:

- **Royal Member Office** — Standard membership role
- **Council Office** — Advisory body participation
- **Admissions Office** — Control institutional entry
- **Treasury Office** — Manage financial sustainability
- **Butler Office** — Operational administration
- **Authority Office** — Highest institutional responsibility

**Critical:** A member does not *become* an office. They are *assigned to* an office. This prevents power from being self-granted.

### Chambers
**Chambers** are protected institutional spaces, each with specific access requirements:

- **Members Chamber** — General institutional space for Members and above
- **Circle Chamber** — Extended institutional participation for Circle and above
- **Council Chamber** — Advisory discussions for Council and above
- **Authority Chamber** — Institutional governance (Authority only)
- **Treasury Chamber** — Financial operations (Treasury Office)
- **Admissions Chamber** — Entry processing (Admissions Office)

### Permissions
**Permissions** are technical capabilities (not visible to members). They are derived from:
- **Standing** — What the member's position allows
- **Office** — What their responsibilities grant

Members never see "permissions." They see Standing and Offices.

---

## How It Works

### The Admission Path
```
Visitor
  ↓ (submits admission request)
  ↓
Pending Review
  ↓ (Authority approves)
  ↓
Royal Identity Created (PALACE-XXXXXX)
  ↓
Member Standing Granted
  ↓
Access to Throne (personal domain)
  ↓
Can enter authorized Chambers
```

### Standing Changes
Standing changes require **Authority approval**. A member cannot increase their own Standing:

```
Current Member
  ↓ (requests advancement via announcement)
  ↓
Authority Reviews
  ↓ (approves based on institutional merit)
  ↓
Standing Changed
  ↓
New access & responsibilities granted
```

### Payment Is Separate
Payment for membership is **isolated** from authority systems:

```
Payment Processing
  └─ Records transaction in Treasury
       ↓
       ↓ (separate decision)
       ↓
Authority Review
  └─ Approves or denies Standing change
```

**Payment does NOT automatically grant authority.**

---

## Technical Architecture

### Database Schema
The Palace uses PostgreSQL with Supabase, organized by institutional concepts:

- **persons** — Initial contact with visitors
- **royal_identities** — Admitted members (permanent institutional identity)
- **memberships** — Active Standing and renewal status
- **standing_definitions** — Institutional Standing levels
- **offices** — Institutional responsibilities
- **member_offices** — Office assignments
- **chambers** — Protected institutional spaces
- **member_chambers** — Chamber access grants
- **permissions** — Technical capabilities (hidden layer)
- **standing_permissions** — Standing → Permissions mapping
- **office_permissions** — Office → Permissions mapping
- Audit logs for institutional memory

### Row-Level Security (RLS)
Every table has RLS policies that enforce Standing and Office requirements. **Security is in the database**, not the application.

### Service Layer
Reusable institutional logic in `lib/services/`:
- `member.service.js` — Member operations
- `standing.service.js` — Standing management
- `chamber.service.js` — Chamber access
- `admission.service.js` — Entry process

### Engine Layer
Institutional rules in `lib/engine/`:
- `permissions.engine.js` — Access control
- `membership.engine.js` — Standing integrity
- `security.engine.js` — Protection rules

---

## File Structure

```
the-palace/
├── CHARTER.md                        ← Governing document (locked)
├── DEVELOPMENT_RULES.md              ← Rules preventing drift
├── DATABASE_SCHEMA.md                ← Data model
├── TECHNICAL_ARCHITECTURE.md         ← System design
│
├── database/migrations/              ← Numbered schema changes
│   ├── 001_initial_schema.sql
│   ├── 002_standing_system.sql
│   ├── 003_offices_system.sql
│   ├── 004_chambers_system.sql
│   └── 005_permissions_system.sql
│
├── app/                              ← User-facing spaces
│   ├── gate/                         (Admission entrance)
│   ├── throne/                       (Member personal domain)
│   ├── chambers/                     (Protected spaces)
│   ├── butler/                       (Administration)
│   └── api/                          (Institutional APIs)
│
└── lib/                              ← Reusable logic
    ├── services/                     (Member, Standing, Chamber, Admission)
    └── engine/                       (Permissions, Membership, Security)
```

---

## Key Rules

### 1. The Charter Test
> Every feature must be traceable to one sentence in CHARTER.md.
> If it's not authorized by the Charter, it doesn't belong.

### 2. The Institutional Purpose Test
> Before creating any database table or API: "What institutional concept does this represent?"
> If the answer is "a feature needs this," redesign it.

### 3. The Member Experience Test
> Does this make members feel like they belong to an institution?
> YES = Ship it. NO = Redesign it.

### 4. Self-Assignment Prevention
> No person, process, or system may grant itself authority.
> Enforced by triggers and RLS policies.

### 5. Audit Everything
> Every important action is logged in institutional audit trails.
> The institution can always answer: What happened? When? Who did it? Why?

---

## Development Workflow

1. **Check CHARTER.md** — Does your feature have Charter authorization?
2. **Read DATABASE_SCHEMA.md** — What institutional concept are you implementing?
3. **Create a migration** — Add it to `database/migrations/` with a number
4. **Write RLS policies** — Enforce access control in the database
5. **Implement services** — Reusable institutional logic
6. **Write tests** — Verify institutional rules work correctly
7. **Submit with institutional context** — Explain what concept this represents

---

## Standing & Authority

### Who Can Change Standing?
Only **Authority members** with the `Authority Office` can change Standing.

### Who Can Assign Offices?
Only **Authority members** with the `Authority Office` can assign offices.

### Who Can Grant Chamber Access?
Only **Authority members** with the `Authority Office` can grant explicit chamber access.

### Can Authority Change Their Own Standing?
**No.** This is enforced by triggers. Self-assignment is impossible.

---

## Next Steps

The Palace is ready for implementation:

- [ ] Deploy Supabase instance
- [ ] Run all migrations (001-005)
- [ ] Build the Gate (admission system)
- [ ] Implement the Throne (member domain)
- [ ] Create Chambers (protected spaces)
- [ ] Build Butler's Office (administration)
- [ ] Launch Treasury (financial operations)

Each system must follow the Charter and implement institutional concepts, not just features.

---

## Documentation

- **CHARTER.md** — Governing principles (locked)
- **DEVELOPMENT_RULES.md** — Rules that prevent drift
- **DATABASE_SCHEMA.md** — Data relationships
- **TECHNICAL_ARCHITECTURE.md** — System design
- **database/migrations/** — Schema evolution

---

## The Vision

> The Palace exists to establish the world's most respected private digital institution, where membership represents identity, trust, recognition, and belonging rather than simple access to software.

Every line of code should serve this vision.

---

*The Palace is locked. It is governed by Charter. It operates by institutional principles, not feature logic.*

*Welcome to The Palace.*
