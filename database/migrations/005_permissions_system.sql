-- ============================================================================
-- MIGRATION 005: PERMISSIONS SYSTEM
-- Purpose: Create technical permissions layer (not visible to members)
-- ============================================================================

-- ============================================================================
-- TABLE: permissions
-- Purpose: Technical capabilities (hidden from members)
-- ============================================================================

CREATE TABLE permissions (
  permission_id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  category TEXT NOT NULL,  -- viewing, participation, administration
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  COMMENT ON TABLE permissions IS 'Technical permissions (not visible to members - Standing and Offices are the visible layer)';
  COMMENT ON COLUMN permissions.category IS 'viewing (read access), participation (contribute), administration (manage)';
);

-- ============================================================================
-- TABLE: standing_permissions
-- Purpose: Maps Standing levels to permissions
-- ============================================================================

CREATE TABLE standing_permissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  standing_name TEXT NOT NULL REFERENCES standing_definitions(standing_name),
  permission_id TEXT NOT NULL REFERENCES permissions(permission_id),
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  UNIQUE(standing_name, permission_id),
  
  COMMENT ON TABLE standing_permissions IS 'Maps Standing levels to technical permissions';
);

CREATE INDEX idx_standing_permissions_standing ON standing_permissions(standing_name);
CREATE INDEX idx_standing_permissions_permission ON standing_permissions(permission_id);

-- ============================================================================
-- TABLE: office_permissions
-- Purpose: Maps specific Offices to permissions
-- ============================================================================

CREATE TABLE office_permissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  office_id TEXT NOT NULL REFERENCES offices(office_id),
  permission_id TEXT NOT NULL REFERENCES permissions(permission_id),
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  UNIQUE(office_id, permission_id),
  
  COMMENT ON TABLE office_permissions IS 'Maps offices to technical permissions';
);

CREATE INDEX idx_office_permissions_office ON office_permissions(office_id);
CREATE INDEX idx_office_permissions_permission ON office_permissions(permission_id);

-- ============================================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================================

ALTER TABLE permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE standing_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE office_permissions ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- RLS POLICIES: permissions (Authority only)
-- ============================================================================

-- Authority can view permissions
CREATE POLICY permissions_authority_view
ON permissions FOR SELECT
USING (auth.jwt() ->> 'role' = 'service_role');

-- ============================================================================
-- RLS POLICIES: standing_permissions (Authority only)
-- ============================================================================

CREATE POLICY standing_permissions_authority_view
ON standing_permissions FOR SELECT
USING (auth.jwt() ->> 'role' = 'service_role');

CREATE POLICY standing_permissions_authority_insert
ON standing_permissions FOR INSERT
USING (auth.jwt() ->> 'role' = 'service_role');

-- ============================================================================
-- RLS POLICIES: office_permissions (Authority only)
-- ============================================================================

CREATE POLICY office_permissions_authority_view
ON office_permissions FOR SELECT
USING (auth.jwt() ->> 'role' = 'service_role');

CREATE POLICY office_permissions_authority_insert
ON office_permissions FOR INSERT
USING (auth.jwt() ->> 'role' = 'service_role');

-- ============================================================================
-- FUNCTION: Get Effective Permissions
-- Purpose: Get all permissions a member has (from Standing + Offices)
-- Returns: TABLE of permission_id values
-- ============================================================================

CREATE OR REPLACE FUNCTION get_effective_permissions(p_palace_id TEXT)
RETURNS TABLE(permission_id TEXT, permission_name TEXT, source TEXT) AS $$
BEGIN
  -- Get permissions from Standing
  RETURN QUERY
  SELECT sp.permission_id, p.name, 'Standing: ' || m.current_standing as source
  FROM memberships m
  LEFT JOIN standing_permissions sp ON m.current_standing = sp.standing_name
  LEFT JOIN permissions p ON sp.permission_id = p.permission_id
  WHERE m.palace_id = p_palace_id AND sp.permission_id IS NOT NULL
  
  UNION
  
  -- Get permissions from Offices
  SELECT op.permission_id, p.name, 'Office: ' || mo.office_id as source
  FROM member_offices mo
  LEFT JOIN office_permissions op ON mo.office_id = op.office_id
  LEFT JOIN permissions p ON op.permission_id = p.permission_id
  WHERE mo.palace_id = p_palace_id AND op.permission_id IS NOT NULL;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- FUNCTION: Has Permission
-- Purpose: Check if a member has a specific permission
-- Returns: BOOLEAN
-- ============================================================================

CREATE OR REPLACE FUNCTION has_permission(p_palace_id TEXT, p_permission_id TEXT)
RETURNS BOOLEAN AS $$
DECLARE
  v_count INT;
BEGIN
  -- Count matching permissions from this member's Standing or Offices
  SELECT COUNT(*) INTO v_count
  FROM (
    SELECT sp.permission_id
    FROM memberships m
    LEFT JOIN standing_permissions sp ON m.current_standing = sp.standing_name
    WHERE m.palace_id = p_palace_id AND sp.permission_id = p_permission_id
    
    UNION
    
    SELECT op.permission_id
    FROM member_offices mo
    LEFT JOIN office_permissions op ON mo.office_id = op.office_id
    WHERE mo.palace_id = p_palace_id AND op.permission_id = p_permission_id
  ) as effective_permissions;
  
  RETURN v_count > 0;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- INITIALIZATION DATA
-- ============================================================================

-- Viewing permissions
INSERT INTO permissions (permission_id, name, description, category) VALUES
  ('view_announcements', 'View Announcements', 'View official Palace announcements', 'viewing'),
  ('view_member_list', 'View Member List', 'View list of members', 'viewing'),
  ('view_own_identity', 'View Own Identity', 'View own Royal Identity', 'viewing'),
  ('view_standing', 'View Standing', 'View own Standing and Standing history', 'viewing'),
  ('view_council_chamber', 'View Council Chamber', 'Access Council Chamber', 'viewing'),
  ('view_treasury_chamber', 'View Treasury Chamber', 'Access Treasury Chamber (Authority)', 'viewing'),
  ('view_admissions_chamber', 'View Admissions Chamber', 'Access Admissions Chamber (Authority)', 'viewing'),
  ('view_authority_chamber', 'View Authority Chamber', 'Access Authority Chamber (Authority)', 'viewing');

-- Participation permissions
INSERT INTO permissions (permission_id, name, description, category) VALUES
  ('participate_members_chamber', 'Participate in Members Chamber', 'Post in Members Chamber', 'participation'),
  ('participate_council_chamber', 'Participate in Council Chamber', 'Participate in Council discussions', 'participation'),
  ('vote_advisory', 'Vote on Advisory Matters', 'Vote on Council recommendations', 'participation');

-- Administration permissions
INSERT INTO permissions (permission_id, name, description, category) VALUES
  ('manage_admissions', 'Manage Admissions', 'Review and approve/deny admission requests', 'administration'),
  ('grant_standing', 'Grant Standing', 'Change member Standing levels', 'administration'),
  ('assign_offices', 'Assign Offices', 'Assign members to offices', 'administration'),
  ('grant_chamber_access', 'Grant Chamber Access', 'Grant explicit chamber access', 'administration'),
  ('manage_treasury', 'Manage Treasury', 'Manage member contributions and payments', 'administration'),
  ('post_announcements', 'Post Announcements', 'Post official announcements', 'administration'),
  ('manage_members', 'Manage Members', 'Review and manage member records', 'administration'),
  ('configure_standing', 'Configure Standing', 'Define Standing levels and requirements', 'administration'),
  ('configure_offices', 'Configure Offices', 'Define offices and responsibilities', 'administration'),
  ('configure_chambers', 'Configure Chambers', 'Define chambers and access requirements', 'administration'),
  ('access_audit_logs', 'Access Audit Logs', 'View institutional audit logs', 'administration');

-- ============================================================================
-- STANDING → PERMISSION MAPPINGS
-- ============================================================================

-- Visitor permissions
INSERT INTO standing_permissions (standing_name, permission_id) VALUES
  ('Visitor', 'view_announcements');

-- Member permissions
INSERT INTO standing_permissions (standing_name, permission_id) VALUES
  ('Member', 'view_announcements'),
  ('Member', 'view_own_identity'),
  ('Member', 'view_standing'),
  ('Member', 'view_member_list'),
  ('Member', 'participate_members_chamber');

-- Circle permissions
INSERT INTO standing_permissions (standing_name, permission_id) VALUES
  ('Circle', 'view_announcements'),
  ('Circle', 'view_own_identity'),
  ('Circle', 'view_standing'),
  ('Circle', 'view_member_list'),
  ('Circle', 'participate_members_chamber');

-- Council permissions
INSERT INTO standing_permissions (standing_name, permission_id) VALUES
  ('Council', 'view_announcements'),
  ('Council', 'view_own_identity'),
  ('Council', 'view_standing'),
  ('Council', 'view_member_list'),
  ('Council', 'participate_members_chamber'),
  ('Council', 'view_council_chamber'),
  ('Council', 'participate_council_chamber'),
  ('Council', 'vote_advisory');

-- Authority permissions
INSERT INTO standing_permissions (standing_name, permission_id) VALUES
  ('Authority', 'view_announcements'),
  ('Authority', 'view_own_identity'),
  ('Authority', 'view_standing'),
  ('Authority', 'view_member_list'),
  ('Authority', 'participate_members_chamber'),
  ('Authority', 'view_council_chamber'),
  ('Authority', 'participate_council_chamber'),
  ('Authority', 'vote_advisory'),
  ('Authority', 'manage_admissions'),
  ('Authority', 'grant_standing'),
  ('Authority', 'assign_offices'),
  ('Authority', 'grant_chamber_access'),
  ('Authority', 'manage_treasury'),
  ('Authority', 'post_announcements'),
  ('Authority', 'manage_members'),
  ('Authority', 'view_treasury_chamber'),
  ('Authority', 'view_admissions_chamber'),
  ('Authority', 'view_authority_chamber'),
  ('Authority', 'access_audit_logs');

-- ============================================================================
-- OFFICE → PERMISSION MAPPINGS
-- ============================================================================

-- Council Office permissions (beyond those granted by Standing)
INSERT INTO office_permissions (office_id, permission_id) VALUES
  ('Council Office', 'vote_advisory');

-- Admissions Office permissions
INSERT INTO office_permissions (office_id, permission_id) VALUES
  ('Admissions Office', 'manage_admissions'),
  ('Admissions Office', 'view_admissions_chamber');

-- Treasury Office permissions
INSERT INTO office_permissions (office_id, permission_id) VALUES
  ('Treasury Office', 'manage_treasury'),
  ('Treasury Office', 'view_treasury_chamber');

-- Butler Office permissions
INSERT INTO office_permissions (office_id, permission_id) VALUES
  ('Butler Office', 'manage_members'),
  ('Butler Office', 'post_announcements');

-- Authority Office permissions
INSERT INTO office_permissions (office_id, permission_id) VALUES
  ('Authority Office', 'grant_standing'),
  ('Authority Office', 'assign_offices'),
  ('Authority Office', 'grant_chamber_access'),
  ('Authority Office', 'configure_standing'),
  ('Authority Office', 'configure_offices'),
  ('Authority Office', 'configure_chambers'),
  ('Authority Office', 'access_audit_logs'),
  ('Authority Office', 'view_authority_chamber');

COMMENT ON SCHEMA public IS 'Updated: Permissions system implemented';
