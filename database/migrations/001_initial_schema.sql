-- ============================================================================
-- MIGRATION 001: INITIAL SCHEMA
-- Purpose: Create foundational tables for persons and Royal Identities
-- ============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- TABLE: persons
-- Purpose: Represents individuals before they become members
-- ============================================================================

CREATE TABLE persons (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  status TEXT DEFAULT 'unverified' CHECK (status IN ('unverified', 'verified', 'banned')),
  
  COMMENT ON TABLE persons IS 'Represents individuals at the point of contact with The Palace';
  COMMENT ON COLUMN persons.id IS 'Unique identifier for the person';
  COMMENT ON COLUMN persons.status IS 'unverified (initial), verified (email confirmed), banned (institutional ban)';
);

CREATE INDEX idx_persons_email ON persons(email);
CREATE INDEX idx_persons_status ON persons(status);

-- ============================================================================
-- TABLE: royal_identities
-- Purpose: The institutional identity of admitted members (permanent)
-- ============================================================================

CREATE TABLE royal_identities (
  palace_id TEXT PRIMARY KEY,  -- Format: PALACE-XXXXXX
  person_id UUID NOT NULL UNIQUE REFERENCES persons(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  identity_status TEXT DEFAULT 'active' CHECK (identity_status IN ('active', 'suspended', 'restored')),
  
  COMMENT ON TABLE royal_identities IS 'Permanent institutional identity of admitted members';
  COMMENT ON COLUMN royal_identities.palace_id IS 'Unique Palace identifier (PALACE-XXXXXX) - the institutional name';
  COMMENT ON COLUMN royal_identities.person_id IS 'Link to the person (each person has only one identity)';
  COMMENT ON COLUMN royal_identities.identity_status IS 'active (normal), suspended (institutional action), restored (reinstatement)';
);

CREATE INDEX idx_royal_identities_person ON royal_identities(person_id);
CREATE INDEX idx_royal_identities_status ON royal_identities(identity_status);

-- ============================================================================
-- TABLE: admission_requests
-- Purpose: Track the journey from visitor to member
-- ============================================================================

CREATE TABLE admission_requests (
  request_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  person_id UUID NOT NULL REFERENCES persons(id) ON DELETE CASCADE,
  
  requested_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'denied', 'withdrawn')),
  
  approved_by TEXT,  -- palace_id of authority who approved
  approved_at TIMESTAMP WITH TIME ZONE,
  
  denial_reason TEXT,
  
  COMMENT ON TABLE admission_requests IS 'Represents the admission process from visitor to member';
  COMMENT ON COLUMN admission_requests.status IS 'pending (awaiting review), approved (granted admission), denied (rejected), withdrawn (applicant withdrew)';
);

CREATE INDEX idx_admission_requests_person ON admission_requests(person_id);
CREATE INDEX idx_admission_requests_status ON admission_requests(status);
CREATE INDEX idx_admission_requests_date ON admission_requests(requested_at);

-- ============================================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE persons ENABLE ROW LEVEL SECURITY;
ALTER TABLE royal_identities ENABLE ROW LEVEL SECURITY;
ALTER TABLE admission_requests ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- RLS POLICY: persons table
-- ============================================================================

-- Users can only view/update their own person record
CREATE POLICY persons_own_record
ON persons FOR SELECT
USING (auth.uid()::text = id::text);

CREATE POLICY persons_own_record_update
ON persons FOR UPDATE
USING (auth.uid()::text = id::text);

-- Authority can view all persons (Authority office must be created first)
CREATE POLICY persons_authority_view
ON persons FOR SELECT
USING (auth.jwt() ->> 'role' = 'service_role');

-- ============================================================================
-- RLS POLICY: royal_identities table
-- ============================================================================

-- Members can view their own royal identity
CREATE POLICY royal_identities_own
ON royal_identities FOR SELECT
USING (
  person_id = auth.uid()
);

-- Authority can view all royal identities
CREATE POLICY royal_identities_authority_view
ON royal_identities FOR SELECT
USING (auth.jwt() ->> 'role' = 'service_role');

-- ============================================================================
-- RLS POLICY: admission_requests table
-- ============================================================================

-- Applicants can view their own request
CREATE POLICY admission_requests_own
ON admission_requests FOR SELECT
USING (person_id = auth.uid());

-- Authority can view all requests
CREATE POLICY admission_requests_authority_view
ON admission_requests FOR SELECT
USING (auth.jwt() ->> 'role' = 'service_role');

-- Authority can approve/deny requests
CREATE POLICY admission_requests_authority_update
ON admission_requests FOR UPDATE
USING (auth.jwt() ->> 'role' = 'service_role');

-- ============================================================================
-- HELPER FUNCTION: Generate Palace ID
-- Purpose: Create unique Palace identifiers in format PALACE-XXXXXX
-- ============================================================================

CREATE OR REPLACE FUNCTION generate_palace_id()
RETURNS TEXT AS $$
DECLARE
  new_id TEXT;
  last_number INT;
BEGIN
  -- Get the highest number from existing Palace IDs
  SELECT COALESCE(MAX(CAST(SUBSTRING(palace_id, 8) AS INT)), 0) INTO last_number
  FROM royal_identities
  WHERE palace_id LIKE 'PALACE-%';
  
  -- Create new Palace ID with incremented number
  new_id := 'PALACE-' || LPAD((last_number + 1)::TEXT, 6, '0');
  
  RETURN new_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- TRIGGER: Auto-create Royal Identity on admission approval
-- Purpose: When an admission is approved, create the Royal Identity
-- ============================================================================

CREATE OR REPLACE FUNCTION create_royal_identity_on_approval()
RETURNS TRIGGER AS $$
DECLARE
  new_palace_id TEXT;
BEGIN
  -- Only execute when status changes to 'approved'
  IF NEW.status = 'approved' AND OLD.status != 'approved' THEN
    new_palace_id := generate_palace_id();
    
    INSERT INTO royal_identities (palace_id, person_id)
    VALUES (new_palace_id, NEW.person_id);
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER admission_approval_creates_identity
BEFORE UPDATE ON admission_requests
FOR EACH ROW
EXECUTE FUNCTION create_royal_identity_on_approval();

-- ============================================================================
-- DOCUMENTATION
-- ============================================================================

COMMENT ON SCHEMA public IS 'The Palace institutional database - represents Royal Standing, Membership, and Governance';

-- ============================================================================
-- INITIALIZATION: Add initial Palace ID sequence starter
-- ============================================================================

-- This allows Palace IDs to start at PALACE-000001
-- No data is inserted here; IDs are generated on demand
