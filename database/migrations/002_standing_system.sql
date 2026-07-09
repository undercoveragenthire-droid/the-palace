-- ============================================================================
-- MIGRATION 002: STANDING SYSTEM
-- Purpose: Create Standing definitions and membership relationships
-- ============================================================================

-- ============================================================================
-- TABLE: standing_definitions
-- Purpose: Defines what each Standing level means institutionally
-- ============================================================================

CREATE TABLE standing_definitions (
  standing_name TEXT PRIMARY KEY,
  description TEXT NOT NULL,
  access_level INT NOT NULL CHECK (access_level >= 0 AND access_level <= 4),
  requirements JSONB,  -- Can contain admission criteria, permissions, etc.
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  COMMENT ON TABLE standing_definitions IS 'Institutional Standing levels: Visitor, Member, Circle, Council, Authority';
  COMMENT ON COLUMN standing_definitions.access_level IS '0=Visitor, 1=Member, 2=Circle, 3=Council, 4=Authority';
);

-- ============================================================================
-- TABLE: memberships
-- Purpose: Manages the active relationship between member and The Palace
-- ============================================================================

CREATE TABLE memberships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  palace_id TEXT NOT NULL UNIQUE REFERENCES royal_identities(palace_id) ON DELETE CASCADE,
  
  current_standing TEXT NOT NULL REFERENCES standing_definitions(standing_name),
  standing_status TEXT DEFAULT 'active' CHECK (standing_status IN ('active', 'renewal_required', 'suspended', 'restored')),
  
  admission_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  last_renewal_date TIMESTAMP WITH TIME ZONE,
  next_renewal_date TIMESTAMP WITH TIME ZONE,
  
  standing_changed_at TIMESTAMP WITH TIME ZONE,
  standing_changed_by TEXT,  -- palace_id of authority
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  COMMENT ON TABLE memberships IS 'Active membership relationship - defines Standing and renewal status';
  COMMENT ON COLUMN memberships.current_standing IS 'Current institutional Standing';
  COMMENT ON COLUMN memberships.standing_status IS 'active (normal), renewal_required (payment due), suspended, restored (after suspension)';
  COMMENT ON COLUMN memberships.standing_changed_by IS 'Palace ID of the Authority member who made the change';
);

CREATE INDEX idx_memberships_palace ON memberships(palace_id);
CREATE INDEX idx_memberships_standing ON memberships(current_standing);
CREATE INDEX idx_memberships_status ON memberships(standing_status);

-- ============================================================================
-- TABLE: standing_changes_log
-- Purpose: Institutional memory of Standing changes
-- ============================================================================

CREATE TABLE standing_changes_log (
  log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  palace_id TEXT NOT NULL REFERENCES royal_identities(palace_id) ON DELETE CASCADE,
  
  previous_standing TEXT NOT NULL,
  new_standing TEXT NOT NULL,
  
  changed_by TEXT,  -- palace_id of authority
  reason TEXT NOT NULL,
  
  changed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  COMMENT ON TABLE standing_changes_log IS 'Audit log for all Standing changes';
);

CREATE INDEX idx_standing_changes_palace ON standing_changes_log(palace_id);
CREATE INDEX idx_standing_changes_date ON standing_changes_log(changed_at);

-- ============================================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================================

ALTER TABLE standing_definitions ENABLE ROW LEVEL SECURITY;
ALTER TABLE memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE standing_changes_log ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- RLS POLICIES: standing_definitions
-- ============================================================================

-- Anyone authenticated can view Standing definitions
CREATE POLICY standing_definitions_view
ON standing_definitions FOR SELECT
USING (TRUE);

-- ============================================================================
-- RLS POLICIES: memberships
-- ============================================================================

-- Members can view their own membership
CREATE POLICY memberships_own
ON memberships FOR SELECT
USING (
  palace_id IN (
    SELECT palace_id FROM royal_identities WHERE person_id = auth.uid()
  )
);

-- Authority can view all memberships
CREATE POLICY memberships_authority_view
ON memberships FOR SELECT
USING (auth.jwt() ->> 'role' = 'service_role');

-- Authority can update memberships (Standing changes)
CREATE POLICY memberships_authority_update
ON memberships FOR UPDATE
USING (auth.jwt() ->> 'role' = 'service_role');

-- ============================================================================
-- RLS POLICIES: standing_changes_log
-- ============================================================================

-- Members can view their own changes
CREATE POLICY standing_changes_own
ON standing_changes_log FOR SELECT
USING (
  palace_id IN (
    SELECT palace_id FROM royal_identities WHERE person_id = auth.uid()
  )
);

-- Authority can view all
CREATE POLICY standing_changes_authority
ON standing_changes_log FOR SELECT
USING (auth.jwt() ->> 'role' = 'service_role');

-- Authority can insert (done via function)
CREATE POLICY standing_changes_authority_insert
ON standing_changes_log FOR INSERT
USING (auth.jwt() ->> 'role' = 'service_role');

-- ============================================================================
-- TRIGGER: Log Standing changes
-- Purpose: Every Standing change is recorded in the audit log
-- ============================================================================

CREATE OR REPLACE FUNCTION log_standing_change()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.current_standing IS DISTINCT FROM OLD.current_standing THEN
    INSERT INTO standing_changes_log (palace_id, previous_standing, new_standing, changed_by, reason, changed_at)
    VALUES (
      NEW.palace_id,
      OLD.current_standing,
      NEW.current_standing,
      NEW.standing_changed_by,
      'Standing change via membership update',
      NOW()
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER membership_log_standing_change
AFTER UPDATE ON memberships
FOR EACH ROW
EXECUTE FUNCTION log_standing_change();

-- ============================================================================
-- TRIGGER: Update timestamp on membership change
-- ============================================================================

CREATE OR REPLACE FUNCTION update_membership_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER membership_update_timestamp
BEFORE UPDATE ON memberships
FOR EACH ROW
EXECUTE FUNCTION update_membership_timestamp();

-- ============================================================================
-- FUNCTION: Grant Standing (Authority only)
-- Purpose: Safely change member Standing with audit trail
-- ============================================================================

CREATE OR REPLACE FUNCTION grant_standing(
  p_palace_id TEXT,
  p_new_standing TEXT,
  p_authority_palace_id TEXT,
  p_reason TEXT
)
RETURNS BOOLEAN AS $$
DECLARE
  v_current_standing TEXT;
  v_exists BOOLEAN;
BEGIN
  -- Verify target member exists
  SELECT TRUE INTO v_exists FROM royal_identities WHERE palace_id = p_palace_id;
  IF NOT v_exists THEN
    RAISE EXCEPTION 'Palace ID not found: %', p_palace_id;
  END IF;
  
  -- Verify new Standing exists
  v_exists := EXISTS(SELECT 1 FROM standing_definitions WHERE standing_name = p_new_standing);
  IF NOT v_exists THEN
    RAISE EXCEPTION 'Standing not found: %', p_new_standing;
  END IF;
  
  -- Get current Standing
  SELECT current_standing INTO v_current_standing FROM memberships WHERE palace_id = p_palace_id;
  
  -- Prevent self-assignment (authority cannot change their own Standing)
  IF p_palace_id = p_authority_palace_id THEN
    RAISE EXCEPTION 'Authority members cannot change their own Standing';
  END IF;
  
  -- Update membership
  UPDATE memberships
  SET 
    current_standing = p_new_standing,
    standing_changed_at = NOW(),
    standing_changed_by = p_authority_palace_id
  WHERE palace_id = p_palace_id;
  
  -- Log the change (trigger will handle this)
  
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- INITIALIZATION DATA
-- ============================================================================

INSERT INTO standing_definitions (standing_name, description, access_level, requirements) VALUES
  ('Visitor', 'Limited external access - browsing only', 0, '{"can_view_public": true}'),
  ('Member', 'Foundation membership with Royal Identity', 1, '{"can_access_throne": true, "can_view_announcements": true}'),
  ('Circle', 'Higher recognition and broader access', 2, '{"can_access_chambers": true, "can_participate": true}'),
  ('Council', 'Advisory institutional participation', 3, '{"can_access_council_chamber": true, "can_vote_advisory": true}'),
  ('Authority', 'Highest institutional responsibility and governance', 4, '{"can_administer": true, "can_grant_standing": true, "can_manage_chambers": true}');

COMMENT ON SCHEMA public IS 'Updated: Standing system implemented';
