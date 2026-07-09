# THE PALACE CHARTER

## Status: LOCKED — Governing Document

This document is the highest law of The Palace. Every feature, every database change, every design decision, and every line of code must be traceable to this Charter.

**The Golden Rule:**
> Every future development decision must be traceable back to one sentence in this Charter. If a proposed feature has no Charter basis, it must be rejected or redesigned.

---

## FOUNDATIONAL PRINCIPLE

**The Palace is a private digital institution where membership is meaningful, standards are maintained, and recognition is earned rather than assumed.**

- ❌ NOT a social network
- ❌ NOT a SaaS dashboard
- ❌ NOT a typical membership platform
- ✅ A digital institution with governance, standing, and responsibility

---

## CORE COMMITMENTS

### 1. Identity Over Anonymity
Members enter as **recognized individuals** with a **Royal Identity**, not anonymous accounts.

### 2. Standing Over Status
A member's position within The Palace is earned through trust and responsibility, not purchased through payment alone.

### 3. Belonging Over Subscription
Members **belong to an institution**, they do not **purchase software features**.

### 4. Quality Over Growth
The Palace prioritizes exclusivity and standards over unlimited expansion.

### 5. Authority Through Responsibility
No person receives power without accountability. Authority exists to protect the institution, not to benefit the holder.

---

## INSTITUTIONAL STRUCTURE

```
THE PALACE
    ├─ Royal Identity (Who the member is)
    ├─ Royal Standing (Their recognized position)
    ├─ Offices (Their responsibilities)
    ├─ Chambers (Protected institutional spaces)
    ├─ Permissions (Technical capabilities)
    └─ Authority (Institutional governance)
```

### Standing Categories
- **Visitor**: Limited external access
- **Member**: Foundation membership with Royal Identity
- **Circle**: Higher recognition
- **Council**: Advisory institutional participation
- **Authority**: Highest institutional responsibility

---

## TECHNOLOGY PHILOSOPHY

Technology serves the institution. The institution is never limited by technology.

**Before creating any database table or API endpoint:**
Ask: *"What institutional concept does this represent?"*

If the answer is *"A feature needs this,"* then it doesn't belong.

---

## CRITICAL GUARDRAILS

### Payment ≠ Authority
```
WRONG: Payment → Authority Granted
RIGHT: Membership → Trust → Recognition → Authority
```

### Membership ≠ Subscription
Language matters:
- ❌ "Your subscription expires"  →  ✅ "Your Standing requires renewal"
- ❌ "Upgrade your plan"  →  ✅ "Request advancement of your Standing"
- ❌ "Feature unlocked"  →  ✅ "Access has been granted"

### Self-Assignment Prevention
> No person, process, or system may grant itself authority.

Members cannot:
- Increase their own Standing
- Assign themselves Offices
- Grant themselves Chamber access

---

## NEXT STEPS

This Charter is locked. Future development must:

1. ✅ Implement exactly what the Charter authorizes
2. ✅ Create database migrations that represent institutional concepts
3. ✅ Establish Supabase RLS policies that enforce Standing and Office boundaries
4. ✅ Design interfaces that make members feel institutional, not like customers
5. ✅ Document every feature in relation to the Charter

---

*Version: Foundation Edition*
*Status: LOCKED — No modifications without institutional review*
