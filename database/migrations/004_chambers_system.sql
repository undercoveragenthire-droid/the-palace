-- ============================================================================
-- MIGRATION 004: CHAMBERS SYSTEM
-- Purpose: Create protected institutional spaces and access control
-- ============================================================================

-- ============================================================================
-- TABLE: chambers
-- Purpose: Represents protected institutional spaces
-- ============================================================================

CREATE TABLE chambers (
  chamber_id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  purpose TEXT NOT NULL,
  
  -- Access requirements
  required_standing TEXT REFERENCES standing_definitions(standing_name),  -- NULL = no standing requirement
  required_office TEXT REFERENCES offices(office_id),  -- NULL = no office requirement
  
  is_public BOOLEAN DEFAULT FALSE,  -- Public chambers visible to all
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE chambers IS 'Protected institutional spaces for specific Standing or Office levels';
COMMENT ON COLUMN chambers.chamber_id IS 'Unique identifier (e.g., Members Chamber, Council Chamber)';
COMMENT ON COLUMN chambers.required_standing IS 'Minimum Standing to access (NULL = open)';
COMMENT ON COLUMN chambers.required_office IS 'Specific Office required (NULL = no office requirement)';

-- ============================================================================
-- TABLE: member_chambers
-- Purpose: Explicit grants of chamber access beyond automatic access
-- ============================================================================

CREATE TABLE member_chambers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  palace_id TEXT NOT NULL REFERENCES royal_identities(palace_id) ON DELETE CASCADE,
  chamber_id TEXT NOT NULL REFERENCES chambers(chamber_id),
  
  access_granted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  granted_by TEXT,  -- palace_id of authority
  
  grant_reason TEXT,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  UNIQUE(palace_id, chamber_id)
);

COMMENT ON TABLE member_chambers IS 'Explicit chamber access grants (beyond automatic Standing-based access)';

CREATE INDEX idx_member_chambers_palace ON member_chambers(palace_id);
CREATE INDEX idx_member_chambers_chamber ON member_chambers(chamber_id);

-- ============================================================================
-- TABLE: chamber_access_log
-- Purpose: Institutional memory of chamber access grants
-- ============================================================================

CREATE TABLE chamber_access_log (
  log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  palace_id TEXT NOT NULL REFERENCES royal_identities(palace_id) ON DELETE CASCADE,
  chamber_id TEXT NOT NULL,
  
  action TEXT NOT NULL CHECK (action IN ('granted', 'denied', 'revoked')),
  action_reason TEXT,
  
  attempted_by TEXT,  -- palace_id of requester (for denied/revoked)
  action_by TEXT,  -- palace_id of authority (for granted/revoked)
  
  action_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE chamber_access_log IS 'Complete audit trail of chamber access attempts and changes';

CREATE INDEX idx_chamber_access_palace ON chamber_access_log(palace_id);
CREATE INDEX idx_chamber_access_chamber ON chamber_access_log(chamber_id);
CREATE INDEX idx_chamber_access_date ON chamber_access_log(action_at);

-- ============================================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================================

ALTER TABLE chambers ENABLE ROW LEVEL SECURITY;
ALTER TABLE member_chambers ENABLE ROW LEVEL SECURITY;
ALTER TABLE chamber_access_log ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- RLS POLICIES: chambers
-- ============================================================================

-- Anyone authenticated can view chamber definitions
CREATE POLICY chambers_view
ON chambers FOR SELECT
USING (TRUE);

-- ============================================================================
-- RLS POLICIES: member_chambers
-- ============================================================================

-- Members can view their granted chamber access
CREATE POLICY member_chambers_own
ON member_chambers FOR SELECT
USING (
  palace_id IN (
    SELECT palace_id FROM royal_identities WHERE person_id = auth.uid()
  )
);

-- Authority can view all chamber access
CREATE POLICY member_chambers_authority_view
ON member_chambers FOR SELECT
USING (auth.jwt() ->> 'role' = 'service_role');

-- Authority can grant chamber access
CREATE POLICY member_chambers_authority_insert
ON member_chambers FOR INSERT
USING (auth.jwt() ->> 'role' = 'service_role');

-- Authority can revoke chamber access
CREATE POLICY member_chambers_authority_delete
ON member_chambers FOR DELETE
USING (auth.jwt() ->> 'role' = 'service_role');

-- ============================================================================
-- RLS POLICIES: chamber_access_log
-- ============================================================================

-- Members can view their own access log
CREATE POLICY chamber_access_log_own
ON chamber_access_log FOR SELECT
USING (
  palace_id IN (
    SELECT palace_id FROM royal_identities WHERE person_id = auth.uid()
  )
);

-- Authority can view all logs
CREATE POLICY chamber_access_log_authority
ON chamber_access_log FOR SELECT
USING (auth.jwt() ->> 'role' = 'service_role');

-- ============================================================================
-- TRIGGER: Prevent self-chamber access grant
-- CRITICAL: No member can grant themselves chamber access
-- ============================================================================

CREATE OR REPLACE FUNCTION prevent_self_chamber_access()
RETURNS TRIGGER AS $$
BEGIN
  -- If the person being granted access is the same as who granted it, deny
  IF NEW.palace_id = NEW.granted_by THEN
    RAISE EXCEPTION 'Members cannot grant themselves chamber access';
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER chamber_prevent_self_access
BEFORE INSERT ON member_chambers
FOR EACH ROW
EXECUTE FUNCTION prevent_self_chamber_access();

-- ============================================================================
-- TRIGGER: Log chamber access changes
-- ============================================================================

CREATE OR REPLACE FUNCTION log_chamber_access_change()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO chamber_access_log (palace_id, chamber_id, action, action_reason, action_by, action_at)
    VALUES (NEW.palace_id, NEW.chamber_id, 'granted', NEW.grant_reason, NEW.granted_by, NOW());
  ELSIF TG_OP = 'DELETE' THEN
    INSERT INTO chamber_access_log (palace_id, chamber_id, action, action_reason, action_at)
    VALUES (OLD.palace_id, OLD.chamber_id, 'revoked', 'Access revoked', NOW());
  END IF;
  
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER chamber_log_access_change
AFTER INSERT OR DELETE ON member_chambers
FOR EACH ROW
EXECUTE FUNCTION log_chamber_access_change();

-- ============================================================================
-- FUNCTION: Check Chamber Access
-- Purpose: Determine if a member can access a chamber
-- Returns: BOOLEAN (true if can access, false otherwise)
-- ============================================================================

CREATE OR REPLACE FUNCTION can_access_chamber(
  p_palace_id TEXT,
  p_chamber_id TEXT
)
RETURNS BOOLEAN AS $$
DECLARE
  v_required_standing TEXT;
  v_required_office TEXT;
  v_member_standing TEXT;
  v_member_access_level INT;
  v_required_access_level INT;
  v_has_office BOOLEAN;
  v_is_public BOOLEAN;
BEGIN
  -- Get chamber requirements
  SELECT required_standing, required_office, is_public 
  INTO v_required_standing, v_required_office, v_is_public
  FROM chambers WHERE chamber_id = p_chamber_id;
  
  IF v_is_public THEN
    RETURN TRUE;
  END IF;
  
  -- Get member's current standing
  SELECT current_standing INTO v_member_standing FROM memberships WHERE palace_id = p_palace_id;
  
  -- If chamber requires standing
  IF v_required_standing IS NOT NULL THEN
    -- Get access levels
    SELECT access_level INTO v_member_access_level 
    FROM standing_definitions WHERE standing_name = v_member_standing;
    
    SELECT access_level INTO v_required_access_level 
    FROM standing_definitions WHERE standing_name = v_required_standing;
    
    -- Check if member meets standing requirement
    IF v_member_access_level < v_required_access_level THEN
      RETURN FALSE;
    END IF;
  END IF;
  
  -- If chamber requires specific office
  IF v_required_office IS NOT NULL THEN
    SELECT EXISTS(
      SELECT 1 FROM member_offices 
      WHERE palace_id = p_palace_id AND office_id = v_required_office
    ) INTO v_has_office;
    
    IF NOT v_has_office THEN
      RETURN FALSE;
    END IF;
  END IF;
  
  -- Check for explicit access grant
  IF EXISTS(SELECT 1 FROM member_chambers WHERE palace_id = p_palace_id AND chamber_id = p_chamber_id) THEN
    RETURN TRUE;
  END IF;
  
  -- If we got here, member has access based on Standing/Office requirements
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- FUNCTION: Get Accessible Chambers
-- Purpose: Get all chambers a member can access
-- Returns: TABLE of chamber_id values
-- ============================================================================

CREATE OR REPLACE FUNCTION get_accessible_chambers(p_palace_id TEXT)
RETURNS TABLE(chamber_id TEXT, name TEXT, access_type TEXT) AS $$
BEGIN
  RETURN QUERY
  SELECT c.chamber_id, c.name, 'standing_based' as access_type
  FROM chambers c
  LEFT JOIN standing_definitions sd ON c.required_standing = sd.standing_name
  WHERE 
    c.is_public = TRUE
    OR c.required_standing IS NULL
    OR (
      c.required_standing IS NOT NULL 
      AND EXISTS(
        SELECT 1 FROM memberships m
        LEFT JOIN standing_definitions ms ON m.current_standing = ms.standing_name
        WHERE m.palace_id = p_palace_id
        AND ms.access_level >= sd.access_level
      )
    )
  
  UNION
  
  SELECT c.chamber_id, c.name, 'explicit_grant' as access_type
  FROM chambers c
  WHERE EXISTS(
    SELECT 1 FROM member_chambers mc
    WHERE mc.palace_id = p_palace_id AND mc.chamber_id = c.chamber_id
  );
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- INITIALIZATION DATA
-- ============================================================================

INSERT INTO chambers (chamber_id, name, description, purpose, required_standing, is_public) VALUES
  ('Public Gate', 'The Palace Gate', 'Public entry point', 'Visitors discover The Palace', NULL, TRUE),
  ('Members Chamber', 'Members Chamber', 'General institutional space', 'Member participation and announcements', 'Member', FALSE),
  ('Circle Chamber', 'Circle Chamber', 'Higher recognition space', 'Extended institutional participation', 'Circle', FALSE),
  ('Council Chamber', 'Council Chamber', 'Advisory discussions', 'Council-level advice and decisions', 'Council', FALSE);

INSERT INTO chambers (chamber_id, name, description, purpose, required_office) VALUES
  ('Treasury Chamber', 'Treasury Chamber', 'Financial operations', 'Manage member contributions', 'Treasury Office'),
  ('Admissions Chamber', 'Admissions Chamber', 'Admission processing', 'Review and approve new members', 'Admissions Office'),
  ('Authority Chamber', 'Authority Chamber', 'Institutional governance', 'Administrative and governance functions', 'Authority Office');

COMMENT ON SCHEMA public IS 'Updated: Chambers system implemented';