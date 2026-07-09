# The Palace — Technical Architecture

This document defines how the technology implements the institutional principles from the Charter.

---

## ARCHITECTURE PHILOSOPHY

**Technology exists to serve the institution. The institution is never compromised by technology.**

Before building any system, ask:
> "What institutional concept does this implement?"

If the answer is only "we need this for a feature," **STOP and redesign.**

---

## CORE TECHNOLOGY STACK

### Application Layer
- **Framework:** Next.js 16+ (App Router)
- **Language:** TypeScript
- **Purpose:** User-facing institutional spaces

### Database Layer
- **Platform:** Supabase (PostgreSQL + RLS)
- **Purpose:** Institutional data preservation and access control
- **Security:** Row-Level Security policies enforce Standing-based access

### Authentication
- **Method:** Supabase Auth or similar
- **Identity:** Links Person → Royal Identity
- **Session:** Maintains authenticated user context

---

## APPLICATION STRUCTURE

```
app/
├── gate/                     (Institutional entrance)
│   ├── page.tsx             (The Gate welcome)
│   └── admit/               (Admission request process)
│
├── throne/                  (Member personal domain)
│   ├── page.tsx             (Royal Throne display)
│   ├── identity/            (Royal Identity view)
│   └── standing/            (Current Standing)
│
├── chambers/                (Protected institutional spaces)
│   ├── members/             (Member Chamber)
│   ├── council/             (Council Chamber)
│   ├── treasury/            (Treasury Chamber)
│   └── authority/           (Authority Chamber)
│
├── butler/                  (Administrative operations)
│   ├── admissions/          (Admission processing)
│   ├── members/             (Member management)
│   └── standing/            (Standing management)
│
└── api/                     (Institutional APIs)
    ├── auth/               (Authentication)
    ├── standing/           (Standing management — Authority only)
    ├── chambers/           (Chamber access)
    ├── announcements/      (Official communication)
    └── treasury/           (Financial processing)
```

---

## SERVICE LAYER

Located in `lib/services/`, these provide reusable institutional logic.

### member.service.ts
**Purpose:** Manages member-related operations

```typescript
// Get member's Royal Identity
async getMemberIdentity(userId: string): Promise<RoyalIdentity>

// Get member's current Standing
async getMemberStanding(palace_id: string): Promise<Standing>

// Get member's assigned Offices
async getMemberOffices(palace_id: string): Promise<Office[]>

// Get member's authorized Chambers
async getAuthorizedChambers(palace_id: string): Promise<Chamber[]>
```

### standing.service.ts
**Purpose:** Manages Standing relationships

```typescript
// Authority only — NEVER callable by members
async changeStanding(palace_id: string, newStanding: string, reason: string): Promise<void>

// Get Standing definition
async getStandingDefinition(standing: string): Promise<StandingDefinition>

// Get all permissions for a Standing level
async getStandingPermissions(standing: string): Promise<Permission[]>
```

### chamber.service.ts
**Purpose:** Controls access to protected spaces

```typescript
// Check if member can access chamber
async canAccessChamber(palace_id: string, chamber_id: string): Promise<boolean>

// Get list of accessible chambers
async getAccessibleChambers(palace_id: string): Promise<Chamber[]>

// Authority only — grant chamber access
async grantChamberAccess(palace_id: string, chamber_id: string, reason: string): Promise<void>
```

### admission.service.ts
**Purpose:** Manages the entry process

```typescript
// Public — start admission request
async submitAdmissionRequest(email: string, name: string): Promise<AdmissionRequest>

// Authority only — approve admission
async approveAdmission(request_id: string, approvedBy: string): Promise<RoyalIdentity>

// Authority only — deny admission
async denyAdmission(request_id: string, reason: string): Promise<void>
```

---

## ENGINE LAYER

Located in `lib/engine/`, these contain institutional rules that determine access and capability.

### permissions.engine.ts
**Purpose:** Authorization engine that determines what members can do

```typescript
// Core function: Check if member has permission
async hasPermission(palace_id: string, permission: string): Promise<boolean>
  // Checks: Standing → Permissions + Office → Permissions

// Get all effective permissions
async getEffectivePermissions(palace_id: string): Promise<Permission[]>
  // Combines Standing permissions + Office permissions

// Check multiple permissions
async hasAllPermissions(palace_id: string, required: string[]): Promise<boolean>
```

**Rule:** This engine is consulted on EVERY protected action. No shortcuts.

### membership.engine.ts
**Purpose:** Validates membership status and Standing integrity

```typescript
// Is membership still active?
async isMembershipActive(palace_id: string): Promise<boolean>

// Get renewal status
async getRenewalStatus(palace_id: string): Promise<RenewalStatus>

// Check Standing requirements
async validateStanding(palace_id: string): Promise<StandingValidation>
```

### security.engine.ts
**Purpose:** Protects against unauthorized access and manipulation

```typescript
// Prevent self-assignment of Standing
async preventSelfStandingChange(palace_id: string, newStanding: string): Promise<void>

// Prevent self-assignment of Offices
async preventSelfOfficeAssignment(palace_id: string, office_id: string): Promise<void>

// Prevent self-granting of Chamber access
async preventSelfChamberAccess(palace_id: string, chamber_id: string): Promise<void>

// Validate authority of person making changes
async validateAuthority(executing_palace_id: string, action: string): Promise<boolean>
```

---

## API DESIGN PRINCIPLE

**Every API endpoint must pass institutional validation, not just technical validation.**

### ❌ Bad Pattern
```typescript
// API endpoint that directly modifies
POST /api/standing/change
  palace_id: "PALACE-001"
  newStanding: "Council"
  // Assumes caller has authority
```

### ✅ Correct Pattern
```typescript
// API validates authority at every step
POST /api/standing/change
{
  palace_id: "PALACE-001",
  newStanding: "Council"
}

// Server implementation:
1. Verify authenticated user
2. Get their Royal Identity
3. Check their Standing (must be Authority)
4. Check their Offices (must have appropriate Office)
5. Validate permission (must have 'change_standing' permission)
6. ONLY THEN apply the change
7. Create audit log entry
8. Return success
```

---

## DATABASE LAYER PROTECTION

### Supabase RLS Policies

**Rule:** Never use "visible" as security. Always use RLS policies.

Every sensitive table requires policies:

```sql
-- Example: member_offices table
CREATE POLICY "members_view_own_offices"
ON member_offices FOR SELECT
USING (palace_id = current_user_palace_id());

CREATE POLICY "authority_manages_offices"
ON member_offices FOR INSERT
USING (current_user_has_permission('assign_office'));

-- Prevent members from inserting their own offices
CREATE POLICY "prevent_self_office_assignment"
ON member_offices FOR INSERT
WITH CHECK (palace_id != current_user_palace_id());
```

**Critical:** If a feature only works by removing RLS policies, the feature is WRONG. Redesign it.

---

## AUTHENTICATION FLOW

```
Visitor
  ↓
Gate Page (public)
  ↓
Submit Admission Request
  ↓
Identity Verification (Supabase Auth)
  ↓
Pending Review
  ↓
Authority Approves (Butler's Office)
  ↓
Royal Identity Created
  ↓
Standing Granted
  ↓
Access to Throne
  ↓
Can Enter Authorized Chambers
```

---

## STANDING-BASED ACCESS CONTROL

**Every access decision follows this chain:**

```
Request arrives
  ↓
Is user authenticated? NO → 401
  ↓
Get user's Royal Identity
  ↓
Get user's current Standing
  ↓
Get user's assigned Offices
  ↓
Get user's permissions (Standing + Offices)
  ↓
Does permission allow this action? NO → 403
  ↓
Grant access / Execute action
  ↓
Create audit log entry
```

---

## PAYMENT ISOLATION

**Critical:** Payment systems are ISOLATED from authority systems.

```
Payment Processing
  ├─ Process payment
  ├─ Record in treasury_records
  └─ Generate approval request (NOT automatic)
       ↓
       ↓ (Separate process)
       ↓
Authority Review
  ├─ Verify member identity
  ├─ Verify payment
  └─ THEN change Standing (if appropriate)
```

**Payment CANNOT directly trigger:**
- Standing changes
- Office assignments
- Chamber access

---

## AUDIT LOGGING

Every action that changes institutional state is logged:

```typescript
interface AuditLogEntry {
  log_id: UUID;
  action_type: 'standing_changed' | 'office_assigned' | 'chamber_access_granted' | ...;
  affected_palace_id: string;    // Who was affected
  performed_by: string;           // Who did it (palace_id or "system")
  details: {
    before: any;
    after: any;
    reason: string;
  };
  action_at: Timestamp;
}
```

The institution can always answer:
- What happened?
- When?
- Who did it?
- Why?

---

## DEPLOYMENT STRATEGY

### Development
- Local Supabase instance
- Full RLS policies enabled
- Migrations applied

### Production
- Supabase managed instance
- RLS policies enforced
- Encrypted backups
- Audit logging enabled

**Rule:** Production and development must have identical RLS policies and database structure. Only data differs.

---

## TESTING STRATEGY

### Engine Tests
Test institutional logic with different Standing levels:

```typescript
describe('Permissions Engine', () => {
  test('Member cannot access Authority Chamber', async () => {
    const result = await permissions.hasPermission(memberPalaceId, 'access_authority_chamber');
    expect(result).toBe(false);
  });

  test('Council member can access Council Chamber', async () => {
    const result = await permissions.hasPermission(councilPalaceId, 'access_council_chamber');
    expect(result).toBe(true);
  });
});
```

### Security Tests
Test that vulnerabilities are prevented:

```typescript
describe('Security Rules', () => {
  test('Member cannot self-assign Authority Office', async () => {
    const result = await security.preventSelfOfficeAssignment(
      memberPalaceId,
      'Authority Office'
    );
    expect(result).toThrow();
  });
});
```

### API Tests
Test APIs enforce institutional rules:

```typescript
describe('Standing API', () => {
  test('Member cannot change own Standing', async () => {
    const response = await client.post('/api/standing/change', {
      palace_id: memberPalaceId,
      newStanding: 'Council'
    });
    expect(response.status).toBe(403); // Forbidden
  });

  test('Authority can change member Standing', async () => {
    const response = await client.post('/api/standing/change', {
      palace_id: memberPalaceId,
      newStanding: 'Council'
    });
    expect(response.status).toBe(200); // OK
  });
});
```

---

## MONITORING

Track these institutional metrics:

- Active Standing counts (Members, Council, Authority)
- Admission request pipeline
- Access control denials (potential attacks)
- API response times
- Database query performance
- Audit log growth

**Do NOT track:**
- Engagement metrics
- Session duration
- Click counts
- Page views

The Palace doesn't optimize for engagement. It preserves institutional integrity.

---

*This architecture is the implementation of the Charter.*
*Every system must serve institutional purpose.*
*Technology serves The Palace, not the reverse.*
