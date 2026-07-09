# The Palace — Database Schema

This document defines the institutional data model. Every table represents a real concept from the Charter, not just a feature requirement.

---

## CORE ENTITY RELATIONSHIP

```
PERSON
    │
    ├─ ROYAL_IDENTITY (institutional recognition)
    │
    ├─ MEMBERSHIP (active relationship)
    │   └─ STANDING (Member, Circle, Council, Authority)
    │
    ├─ MEMBER_OFFICES (institutional responsibilities)
    │   └─ OFFICES (defined roles)
    │
    ├─ MEMBER_CHAMBERS (access to protected spaces)
    │   └─ CHAMBERS (institutional spaces)
    │
    └─ PERMISSIONS (technical capabilities derived from Standing + Office)
```

---

## TABLES

### 1. PERSONS
**Purpose:** Represents individuals before membership.

```sql
CREATE TABLE persons (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  status TEXT DEFAULT 'unverified'  -- unverified, verified, banned
);
```

**RLS Policy:** Users can only read/update their own record.

---

### 2. ROYAL_IDENTITIES
**Purpose:** The institutional identity — permanent even if Standing changes.

```sql
CREATE TABLE royal_identities (
  palace_id TEXT PRIMARY KEY,  -- e.g., PALACE-000001
  person_id UUID NOT NULL REFERENCES persons(id),
  created_at TIMESTAMP DEFAULT NOW(),
  identity_status TEXT DEFAULT 'active',  -- active, suspended, restored
  
  UNIQUE(person_id)
);
```

**RLS Policy:** Members can read their own identity. Authority can read any identity.

---

### 3. MEMBERSHIPS
**Purpose:** Manages the active relationship between person and The Palace.

```sql
CREATE TABLE memberships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  palace_id TEXT NOT NULL REFERENCES royal_identities(palace_id),
  
  current_standing TEXT NOT NULL,  -- Member, Circle, Council, Authority
  standing_status TEXT NOT NULL,  -- Active, Renewal Required, Suspended, Restored
  
  admission_date TIMESTAMP NOT NULL,
  last_renewal_date TIMESTAMP,
  next_renewal_date TIMESTAMP,
  
  updated_at TIMESTAMP DEFAULT NOW(),
  
  UNIQUE(palace_id)
);
```

**RLS Policy:** Members can read their own. Authority can read all.

---

### 4. STANDING_DEFINITIONS
**Purpose:** Defines what each Standing level represents.

```sql
CREATE TABLE standing_definitions (
  standing_name TEXT PRIMARY KEY,  -- Member, Circle, Council, Authority
  description TEXT NOT NULL,
  requirements TEXT,  -- JSON describing requirements
  access_level INT NOT NULL,  -- 1-4
  created_at TIMESTAMP DEFAULT NOW()
);
```

**RLS Policy:** Anyone authenticated can read.

---

### 5. OFFICES
**Purpose:** Defines institutional responsibilities.

```sql
CREATE TABLE offices (
  office_id TEXT PRIMARY KEY,  -- e.g., Council Office, Treasury Office
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  purpose TEXT NOT NULL,
  minimum_standing TEXT NOT NULL,  -- Minimum Standing required
  
  created_at TIMESTAMP DEFAULT NOW()
);
```

**RLS Policy:** Anyone authenticated can read.

---

### 6. MEMBER_OFFICES
**Purpose:** Links which member holds which office.

**CRITICAL:** A member does not become an office. They are assigned to one.

```sql
CREATE TABLE member_offices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  palace_id TEXT NOT NULL REFERENCES royal_identities(palace_id),
  office_id TEXT NOT NULL REFERENCES offices(office_id),
  
  assigned_at TIMESTAMP DEFAULT NOW(),
  assigned_by TEXT,  -- palace_id of who assigned it
  
  UNIQUE(palace_id, office_id)
);
```

**RLS Policy:**
- Members can only read their own offices
- Authority can read/write all offices
- **Members CANNOT assign themselves offices**

---

### 7. CHAMBERS
**Purpose:** Protected institutional spaces.

```sql
CREATE TABLE chambers (
  chamber_id TEXT PRIMARY KEY,  -- e.g., Members Chamber, Council Chamber
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  purpose TEXT NOT NULL,
  
  required_standing TEXT,  -- Minimum Standing (can be NULL for unrestricted)
  required_office TEXT,    -- Specific Office (can be NULL)
  
  is_public BOOLEAN DEFAULT FALSE,
  
  created_at TIMESTAMP DEFAULT NOW()
);
```

**RLS Policy:** Public chambers visible to all. Protected chambers only to those with Standing.

---

### 8. MEMBER_CHAMBERS
**Purpose:** Explicit grants of Chamber access.

```sql
CREATE TABLE member_chambers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  palace_id TEXT NOT NULL REFERENCES royal_identities(palace_id),
  chamber_id TEXT NOT NULL REFERENCES chambers(chamber_id),
  
  access_granted_at TIMESTAMP DEFAULT NOW(),
  granted_by TEXT,  -- palace_id of who granted it
  
  UNIQUE(palace_id, chamber_id)
);
```

**RLS Policy:**
- Members can only read their own chamber access
- Authority can read/write all
- **Members CANNOT grant themselves access**

---

### 9. PERMISSIONS
**Purpose:** Technical capabilities (not visible to members, behind the scenes).

```sql
CREATE TABLE permissions (
  permission_id TEXT PRIMARY KEY,  -- e.g., view_announcements, approve_members
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  
  created_at TIMESTAMP DEFAULT NOW()
);
```

**RLS Policy:** Authority only.

---

### 10. STANDING_PERMISSIONS
**Purpose:** Maps Standing levels to permissions.

```sql
CREATE TABLE standing_permissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  standing_name TEXT NOT NULL REFERENCES standing_definitions(standing_name),
  permission_id TEXT NOT NULL REFERENCES permissions(permission_id),
  
  UNIQUE(standing_name, permission_id)
);
```

**RLS Policy:** Authority only (determines access control).

---

### 11. OFFICE_PERMISSIONS
**Purpose:** Maps specific Offices to permissions (Office authority).

```sql
CREATE TABLE office_permissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  office_id TEXT NOT NULL REFERENCES offices(office_id),
  permission_id TEXT NOT NULL REFERENCES permissions(permission_id),
  
  UNIQUE(office_id, permission_id)
);
```

**RLS Policy:** Authority only.

---

### 12. ANNOUNCEMENTS
**Purpose:** Official Palace communication (not social posts).

```sql
CREATE TABLE announcements (
  announcement_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  
  issued_by TEXT NOT NULL,  -- palace_id of issuing Office
  issued_at TIMESTAMP DEFAULT NOW(),
  
  visibility TEXT DEFAULT 'members',  -- members, council, authority
  
  created_at TIMESTAMP DEFAULT NOW()
);
```

**RLS Policy:** Based on Standing — members see member announcements, etc.

---

### 13. TREASURY_RECORDS
**Purpose:** Financial contributions and sustainability records.

```sql
CREATE TABLE treasury_records (
  transaction_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  palace_id TEXT NOT NULL REFERENCES royal_identities(palace_id),
  
  amount DECIMAL NOT NULL,
  currency TEXT DEFAULT 'USD',
  
  contribution_type TEXT NOT NULL,  -- membership, upgrade, etc.
  standing_level TEXT,  -- What Standing is being supported
  
  status TEXT NOT NULL,  -- pending, confirmed, failed
  reference TEXT,  -- External payment reference
  
  recorded_at TIMESTAMP DEFAULT NOW()
);
```

**RLS Policy:**
- Members can only read their own transactions
- Treasury can read all
- **Cannot be modified publicly**

---

### 14. AUDIT_LOG
**Purpose:** Institutional memory — every important action is recorded.

```sql
CREATE TABLE audit_log (
  log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  action_type TEXT NOT NULL,  -- standing_changed, office_assigned, etc.
  affected_palace_id TEXT,  -- Who it affected
  performed_by TEXT,  -- palace_id of who did it (or system)
  
  details JSONB,  -- What happened (old value → new value)
  
  reason TEXT,  -- Why (approval, request, etc.)
  
  action_at TIMESTAMP DEFAULT NOW()
);
```

**RLS Policy:** Authority only (cannot be modified).

---

## CRITICAL SECURITY RULES

### 1. No Self-Assignment
```sql
-- Trigger prevents member from assigning themselves Office
CREATE TRIGGER prevent_self_office_assignment
BEFORE INSERT ON member_offices
FOR EACH ROW
EXECUTE FUNCTION check_not_self_assignment();
```

### 2. No Self-Standing Increase
```sql
-- Trigger prevents member from increasing their own Standing
CREATE TRIGGER prevent_self_standing_increase
BEFORE UPDATE ON memberships
FOR EACH ROW
EXECUTE FUNCTION check_standing_authority();
```

### 3. Payment Separation
```sql
-- Payment system records contribution but CANNOT directly modify Standing
-- A separate approval process must change Standing after payment
-- This prevents: Payment → Automatic Authority Granted
```

### 4. Standing-Based Access
```sql
-- All Chamber access is verified through:
-- Member's Standing + Member's Offices = Allowed Chambers
-- Not just "Is the button visible?"
```

---

## INITIALIZATION DATA

After migrations run, initialize:

### Standing Definitions
```sql
INSERT INTO standing_definitions VALUES
  ('Visitor', 'Limited external access', NULL, 0),
  ('Member', 'Foundation membership', NULL, 1),
  ('Circle', 'Higher recognition', NULL, 2),
  ('Council', 'Advisory participation', NULL, 3),
  ('Authority', 'Institutional responsibility', NULL, 4);
```

### Offices
```sql
INSERT INTO offices VALUES
  ('Royal Member Office', 'Royal Member Office', 'Standard member role', 'Represent membership', 'Member'),
  ('Council Office', 'Council Office', 'Advisory body', 'Provide institutional guidance', 'Council'),
  ('Treasury Office', 'Treasury Office', 'Financial operations', 'Manage contributions', 'Authority'),
  ('Admissions Office', 'Admissions Office', 'Membership control', 'Approve new members', 'Authority'),
  ('Butler Office', 'Butler Office', 'Administration', 'Maintain operations', 'Authority'),
  ('Authority Office', 'Authority Office', 'Governance', 'Protect standards', 'Authority');
```

### Chambers
```sql
INSERT INTO chambers VALUES
  ('Members Chamber', 'Members Chamber', 'General institutional space', 'Member participation', 'Member', NULL, FALSE),
  ('Council Chamber', 'Council Chamber', 'Advisory discussions', 'Council decisions', 'Council', NULL, FALSE),
  ('Authority Chamber', 'Authority Chamber', 'Administrative functions', 'Institutional management', 'Authority', NULL, FALSE),
  ('Treasury Chamber', 'Treasury Chamber', 'Financial operations', 'Treasury management', 'Authority', NULL, FALSE);
```

---

## NEXT MIGRATION PLAN

1. ✅ Initial schema (persons, identities, memberships)
2. ✅ Standing system (definitions, membership relationships)
3. ✅ Offices (definitions, member offices)
4. ✅ Chambers (definitions, access control)
5. ✅ Permissions (definitions, Standing → Permission mapping)
6. ✅ Announcements (official communication)
7. ✅ Treasury (contribution tracking)
8. ✅ Audit logging (institutional memory)

---

*This schema is the digital representation of The Palace as an institution.*
*Every table represents an institutional concept, not a feature.*
*Every change must maintain institutional integrity.*
