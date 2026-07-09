-- ============================================================================
-- MIGRATION 003: OFFICES SYSTEM
-- Purpose: Define institutional responsibilities and office structure
-- ============================================================================

-- ============================================================================
-- TABLE: offices
-- Purpose: Defines institutional offices (responsibilities, not permissions)
-- ============================================================================

CREATE TABLE offices (
  office_id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  purpose TEXT NOT NULL,
  minimum_standing TEXT NOT NULL REFERENCES standing_definitions(standing_name),
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  COMMENT ON TABLE offices IS 'Institutional Offices - represent responsibilities, not personal positions';
  COMMENT ON COLUMN offices.office_id IS 'Unique identifier for the office (e.g., Council Office, Treasury Office)';
  COMMENT ON COLUMN offices.minimum_standing IS 'Minimum Standing required to hold this office';
);

-- ============================================================================
-- TABLE: member_offices
-- Purpose: Associates members with the offices they hold
-- CRITICAL: A member does not become an office. They are assigned to one.
-- ============================================================================

CREATE TABLE member_offices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  palace_id TEXT NOT NULL REFERENCES royal_identities(palace_id) ON DELETE CASCADE,
  office_id TEXT NOT NULL REFERENCES offices(office_id),
  
  assigned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  assigned_by TEXT,  -- palace_id of authority
  
  assignment_reason TEXT,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  UNIQUE(palace_id, office_id),
  
  COMMENT ON TABLE member_offices IS 'Explicit assignment of members to offices';
  COMMENT ON COLUMN member_offices.assigned_by IS 'Palace ID of the Authority member who made the assignment';
);

CREATE INDEX idx_member_offices_palace ON member_offices(palace_id);
CREATE INDEX idx_member_offices_office ON member_offices(office_id);

-- ============================================================================
-- TABLE: office_assignments_log
-- Purpose: Institutional memory of office assignments
-- ============================================================================

CREATE TABLE office_assignments_log (
  log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  palace_id TEXT NOT NULL REFERENCES royal_identities(palace_id) ON DELETE CASCADE,
  office_id TEXT NOT NULL,
  
  action TEXT NOT NULL CHECK (action IN ('assigned', 'removed')),
  assigned_by TEXT,  -- palace_id of authority
  reason TEXT,
  
  action_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  COMMENT ON TABLE office_assignments_log IS 'Complete audit trail of office assignments and removals';
);

CREATE INDEX idx_office_assignments_palace ON office_assignments_log(palace_id);
CREATE INDEX idx_office_assignments_office ON office_assignments_log(office_id);
CREATE INDEX idx_office_assignments_date ON office_assignments_log(action_at);

-- ============================================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================================

ALTER TABLE offices ENABLE ROW LEVEL SECURITY;
ALTER TABLE member_offices ENABLE ROW LEVEL SECURITY;
ALTER TABLE office_assignments_log ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- RLS POLICIES: offices
-- ============================================================================

-- Anyone authenticated can view office definitions
CREATE POLICY offices_view
ON offices FOR SELECT
USING (TRUE);

-- ============================================================================
-- RLS POLICIES: member_offices
-- ============================================================================

-- Members can view their own offices
CREATE POLICY member_offices_own
ON member_offices FOR SELECT
USING (
  palace_id IN (
    SELECT palace_id FROM royal_identities WHERE person_id = auth.uid()
  )
);

-- Authority can view all office assignments
CREATE POLICY member_offices_authority_view
ON member_offices FOR SELECT
USING (auth.jwt() ->> 'role' = 'service_role');

-- Authority can assign offices
CREATE POLICY member_offices_authority_insert
ON member_offices FOR INSERT
USING (auth.jwt() ->> 'role' = 'service_role');

-- Authority can remove offices
CREATE POLICY member_offices_authority_delete
ON member_offices FOR DELETE
USING (auth.jwt() ->> 'role' = 'service_role');

-- ============================================================================
-- RLS POLICIES: office_assignments_log
-- ============================================================================

-- Members can view their own assignment history
CREATE POLICY office_assignments_own
ON office_assignments_log FOR SELECT
USING (
  palace_id IN (
    SELECT palace_id FROM royal_identities WHERE person_id = auth.uid()
  )
);

-- Authority can view all
CREATE POLICY office_assignments_authority
ON office_assignments_log FOR SELECT
USING (auth.jwt() ->> 'role' = 'service_role');

-- Authority can insert logs
CREATE POLICY office_assignments_authority_insert
ON office_assignments_log FOR INSERT
USING (auth.jwt() ->> 'role' = 'service_role');

-- ============================================================================
-- TRIGGER: Prevent self-assignment of offices
-- CRITICAL: No member can assign themselves an office
-- ============================================================================

CREATE OR REPLACE FUNCTION prevent_self_office_assignment()
RETURNS TRIGGER AS $$
DECLARE
  v_assigned_by_palace TEXT;
BEGIN
  -- Get the palace_id of who is trying to assign
  SELECT assigned_by INTO v_assigned_by_palace FROM member_offices WHERE id = NEW.id;
  
  -- If the person being assigned the office is the same as who assigned it, deny
  IF NEW.palace_id = v_assigned_by_palace THEN
    RAISE EXCEPTION 'Members cannot assign themselves offices';
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER office_prevent_self_assignment
BEFORE INSERT ON member_offices
FOR EACH ROW
EXECUTE FUNCTION prevent_self_office_assignment();

-- ============================================================================
-- TRIGGER: Log office assignment
-- ============================================================================

CREATE OR REPLACE FUNCTION log_office_assignment()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO office_assignments_log (palace_id, office_id, action, assigned_by, reason, action_at)
    VALUES (NEW.palace_id, NEW.office_id, 'assigned', NEW.assigned_by, NEW.assignment_reason, NOW());
  ELSIF TG_OP = 'DELETE' THEN
    INSERT INTO office_assignments_log (palace_id, office_id, action, assigned_by, reason, action_at)
    VALUES (OLD.palace_id, OLD.office_id, 'removed', NULL, 'Office removed', NOW());
  END IF;
  
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER office_log_assignment
AFTER INSERT OR DELETE ON member_offices
FOR EACH ROW
EXECUTE FUNCTION log_office_assignment();

-- ============================================================================
-- FUNCTION: Assign Office (Authority only)
-- Purpose: Safely assign an office to a member with audit trail
-- ============================================================================

CREATE OR REPLACE FUNCTION assign_office(
  p_palace_id TEXT,
  p_office_id TEXT,
  p_authority_palace_id TEXT,
  p_reason TEXT
)
RETURNS BOOLEAN AS $$
DECLARE
  v_exists BOOLEAN;
  v_min_standing TEXT;
  v_member_standing TEXT;
BEGIN
  -- Verify target member exists
  SELECT TRUE INTO v_exists FROM royal_identities WHERE palace_id = p_palace_id;
  IF NOT v_exists THEN
    RAISE EXCEPTION 'Palace ID not found: %', p_palace_id;
  END IF;
  
  -- Verify office exists and get minimum standing
  SELECT minimum_standing INTO v_min_standing FROM offices WHERE office_id = p_office_id;
  IF v_min_standing IS NULL THEN
    RAISE EXCEPTION 'Office not found: %', p_office_id;
  END IF;
  
  -- Verify member has minimum standing for this office
  SELECT current_standing INTO v_member_standing FROM memberships WHERE palace_id = p_palace_id;
  IF NOT EXISTS(
    SELECT 1 FROM standing_definitions a, standing_definitions b 
    WHERE a.standing_name = v_member_standing 
    AND b.standing_name = v_min_standing
    AND a.access_level >= b.access_level
  ) THEN
    RAISE EXCEPTION 'Member does not have minimum standing (%) for this office', v_min_standing;
  END IF;
  
  -- Prevent self-assignment
  IF p_palace_id = p_authority_palace_id THEN
    RAISE EXCEPTION 'Authority members cannot assign themselves offices';
  END IF;
  
  -- Assign the office
  INSERT INTO member_offices (palace_id, office_id, assigned_by, assignment_reason)
  VALUES (p_palace_id, p_office_id, p_authority_palace_id, p_reason)
  ON CONFLICT (palace_id, office_id) DO NOTHING;
  
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- INITIALIZATION DATA
-- ============================================================================

INSERT INTO offices (office_id, name, description, purpose, minimum_standing) VALUES
  ('Royal Member Office', 'Royal Member Office', 'Standard membership role', 'Represent ordinary institutional membership', 'Member'),
  ('Council Office', 'Council Office', 'Advisory institutional body', 'Provide recommendations and guidance', 'Council'),
  ('Admissions Office', 'Admissions Office', 'Control entry into The Palace', 'Review and approve membership applications', 'Authority'),
  ('Treasury Office', 'Treasury Office', 'Financial operations', 'Manage member contributions and sustainability', 'Authority'),
  ('Butler Office', 'Butler Office', 'Operational administration', 'Maintain daily institutional operations', 'Authority'),
  ('Authority Office', 'Authority Office', 'Highest institutional responsibility', 'Protect institutional standards and governance', 'Authority');

COMMENT ON SCHEMA public IS 'Updated: Offices system implemented';
