-- ==============================================================================
-- Trazzik — Migration 0005: 3D/2D Finishes, Fee Proposals, Client Share Links,
-- Foreign Key Indexes, and RLS / Security Hardening
-- ==============================================================================

-- 1. Enrich public.profiles with phone and company
ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS phone TEXT,
    ADD COLUMN IF NOT EXISTS company TEXT;

-- 2. Add first-class finish columns to public.modules and backfill from geometry JSONB
ALTER TABLE public.modules
    ADD COLUMN IF NOT EXISTS floor_material_id TEXT,
    ADD COLUMN IF NOT EXISTS wall_finish_id TEXT;

UPDATE public.modules
SET
    floor_material_id = COALESCE(floor_material_id, geometry->>'floor_material_id'),
    wall_finish_id = COALESCE(wall_finish_id, geometry->>'wall_finish_id')
WHERE (geometry ? 'floor_material_id') OR (geometry ? 'wall_finish_id');

-- 3. Add fee_proposal_config JSONB to public.projects for cloud-synced architect quotes
ALTER TABLE public.projects
    ADD COLUMN IF NOT EXISTS fee_proposal_config JSONB;

-- 4. Create public.project_share_links for 60-day interactive client 3D/2D links
CREATE TABLE IF NOT EXISTS public.project_share_links (
    id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
    project_id UUID NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
    token TEXT NOT NULL UNIQUE,
    created_by UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    allow_finish_selection BOOLEAN NOT NULL DEFAULT true,
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (TIMEZONE('utc', NOW()) + INTERVAL '60 days'),
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW())
);

ALTER TABLE public.project_share_links ENABLE ROW LEVEL SECURITY;

-- 5. Create covering indexes on all foreign keys (eliminating unindexed_foreign_keys lint)
CREATE INDEX IF NOT EXISTS idx_projects_owner_id ON public.projects(owner_id);
CREATE INDEX IF NOT EXISTS idx_project_members_user_id ON public.project_members(user_id);
CREATE INDEX IF NOT EXISTS idx_zoning_zones_lot_id ON public.zoning_zones(lot_id);
CREATE INDEX IF NOT EXISTS idx_buildings_lot_id ON public.buildings(lot_id);
CREATE INDEX IF NOT EXISTS idx_floors_building_id ON public.floors(building_id);
CREATE INDEX IF NOT EXISTS idx_modules_floor_id ON public.modules(floor_id);
CREATE INDEX IF NOT EXISTS idx_walls_floor_id ON public.walls(floor_id);
CREATE INDEX IF NOT EXISTS idx_replacement_relationships_floor_id ON public.replacement_relationships(floor_id);
CREATE INDEX IF NOT EXISTS idx_project_share_links_project_id ON public.project_share_links(project_id);
CREATE INDEX IF NOT EXISTS idx_project_share_links_created_by ON public.project_share_links(created_by);

-- 6. Harden all SECURITY DEFINER helper functions with explicit SET search_path = public
CREATE OR REPLACE FUNCTION public.has_project_access(proj_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    current_uid UUID := (SELECT auth.uid());
BEGIN
    IF proj_id IS NULL OR current_uid IS NULL THEN
        RETURN FALSE;
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.projects p
        WHERE p.id = proj_id AND p.owner_id = current_uid
    ) THEN
        RETURN TRUE;
    END IF;

    RETURN EXISTS (
        SELECT 1 FROM public.project_members pm
        WHERE pm.project_id = proj_id
          AND pm.user_id = current_uid
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.has_project_access(proj_id UUID, required_roles public.project_role[])
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    current_uid UUID := (SELECT auth.uid());
BEGIN
    IF proj_id IS NULL OR current_uid IS NULL THEN
        RETURN FALSE;
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.projects p
        WHERE p.id = proj_id AND p.owner_id = current_uid
    ) THEN
        RETURN TRUE;
    END IF;

    RETURN EXISTS (
        SELECT 1 FROM public.project_members pm
        WHERE pm.project_id = proj_id
          AND pm.user_id = current_uid
          AND pm.role = ANY(required_roles)
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.has_project_edit_access(proj_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    current_uid UUID := (SELECT auth.uid());
BEGIN
    IF proj_id IS NULL OR current_uid IS NULL THEN
        RETURN FALSE;
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.projects p
        WHERE p.id = proj_id AND p.owner_id = current_uid
    ) THEN
        RETURN TRUE;
    END IF;

    RETURN EXISTS (
        SELECT 1 FROM public.project_members pm
        WHERE pm.project_id = proj_id
          AND pm.user_id = current_uid
          AND pm.role IN ('owner', 'editor')
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_project_id_for_lot(target_lot_id UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    found_project_id UUID;
BEGIN
    IF target_lot_id IS NULL THEN
        RETURN NULL;
    END IF;

    SELECT project_id INTO found_project_id
    FROM public.lots
    WHERE id = target_lot_id;

    RETURN found_project_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_project_id_for_building(target_building_id UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    found_project_id UUID;
BEGIN
    IF target_building_id IS NULL THEN
        RETURN NULL;
    END IF;

    SELECT l.project_id INTO found_project_id
    FROM public.buildings b
    JOIN public.lots l ON l.id = b.lot_id
    WHERE b.id = target_building_id;

    RETURN found_project_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_project_id_for_floor(target_floor_id UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    found_project_id UUID;
BEGIN
    IF target_floor_id IS NULL THEN
        RETURN NULL;
    END IF;

    SELECT l.project_id INTO found_project_id
    FROM public.floors f
    JOIN public.buildings b ON b.id = f.building_id
    JOIN public.lots l ON l.id = b.lot_id
    WHERE f.id = target_floor_id;

    RETURN found_project_id;
END;
$$;

-- Revoke anonymous execution on internal RLS & trigger functions
REVOKE EXECUTE ON FUNCTION public.can_edit_floor(UUID) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.can_view_floor(UUID) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.get_project_id_for_building(UUID) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.get_project_id_for_floor(UUID) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.get_project_id_for_lot(UUID) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.has_project_access(UUID) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.has_project_access(UUID, public.project_role[]) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.has_project_edit_access(UUID) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.can_edit_floor(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.can_view_floor(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_project_id_for_building(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_project_id_for_floor(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_project_id_for_lot(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.has_project_access(UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.has_project_access(UUID, public.project_role[]) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.has_project_edit_access(UUID) TO authenticated, service_role;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public' AND p.proname = 'rls_auto_enable'
    ) THEN
        EXECUTE 'REVOKE EXECUTE ON FUNCTION public.rls_auto_enable() FROM PUBLIC, anon, authenticated';
    END IF;
END $$;

-- 7. Rebuild RLS policies to use (SELECT auth.uid()) and non-overlapping action policies
-- 7.1 Profiles
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;

CREATE POLICY "Users can view own profile"
    ON public.profiles FOR SELECT TO authenticated
    USING ((SELECT auth.uid()) = id);

CREATE POLICY "Users can update own profile"
    ON public.profiles FOR UPDATE TO authenticated
    USING ((SELECT auth.uid()) = id)
    WITH CHECK ((SELECT auth.uid()) = id);

-- 7.2 Projects
DROP POLICY IF EXISTS "Users can view authorized projects" ON public.projects;
DROP POLICY IF EXISTS "Users can create projects" ON public.projects;
DROP POLICY IF EXISTS "Owners and editors can update projects" ON public.projects;
DROP POLICY IF EXISTS "Only owners can delete projects" ON public.projects;

CREATE POLICY "Users can view authorized projects"
    ON public.projects FOR SELECT TO authenticated
    USING (owner_id = (SELECT auth.uid()) OR public.has_project_access(id));

CREATE POLICY "Users can create projects"
    ON public.projects FOR INSERT TO authenticated
    WITH CHECK (owner_id = (SELECT auth.uid()));

CREATE POLICY "Owners and editors can update projects"
    ON public.projects FOR UPDATE TO authenticated
    USING (owner_id = (SELECT auth.uid()) OR public.has_project_edit_access(id))
    WITH CHECK (owner_id = (SELECT auth.uid()) OR public.has_project_edit_access(id));

CREATE POLICY "Only owners can delete projects"
    ON public.projects FOR DELETE TO authenticated
    USING (owner_id = (SELECT auth.uid()));

-- 7.3 Project Members (separate SELECT from INSERT/UPDATE/DELETE to avoid multiple_permissive_policies)
DROP POLICY IF EXISTS "Users can view project members" ON public.project_members;
DROP POLICY IF EXISTS "Project owners can manage members" ON public.project_members;
DROP POLICY IF EXISTS "Project owners can insert members" ON public.project_members;
DROP POLICY IF EXISTS "Project owners can update members" ON public.project_members;
DROP POLICY IF EXISTS "Project owners can delete members" ON public.project_members;

CREATE POLICY "Users can view project members"
    ON public.project_members FOR SELECT TO authenticated
    USING (user_id = (SELECT auth.uid()) OR public.has_project_access(project_id));

CREATE POLICY "Project owners can insert members"
    ON public.project_members FOR INSERT TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.projects p
            WHERE p.id = project_members.project_id AND p.owner_id = (SELECT auth.uid())
        )
    );

CREATE POLICY "Project owners can update members"
    ON public.project_members FOR UPDATE TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.projects p
            WHERE p.id = project_members.project_id AND p.owner_id = (SELECT auth.uid())
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.projects p
            WHERE p.id = project_members.project_id AND p.owner_id = (SELECT auth.uid())
        )
    );

CREATE POLICY "Project owners can delete members"
    ON public.project_members FOR DELETE TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.projects p
            WHERE p.id = project_members.project_id AND p.owner_id = (SELECT auth.uid())
        )
    );

-- 7.4 Lots
DROP POLICY IF EXISTS "Users can view lots" ON public.lots;
DROP POLICY IF EXISTS "Editors can modify lots" ON public.lots;
DROP POLICY IF EXISTS "Editors can insert lots" ON public.lots;
DROP POLICY IF EXISTS "Editors can update lots" ON public.lots;
DROP POLICY IF EXISTS "Editors can delete lots" ON public.lots;

CREATE POLICY "Users can view lots"
    ON public.lots FOR SELECT TO authenticated
    USING (public.has_project_access(project_id));

CREATE POLICY "Editors can insert lots"
    ON public.lots FOR INSERT TO authenticated
    WITH CHECK (public.has_project_edit_access(project_id));

CREATE POLICY "Editors can update lots"
    ON public.lots FOR UPDATE TO authenticated
    USING (public.has_project_edit_access(project_id))
    WITH CHECK (public.has_project_edit_access(project_id));

CREATE POLICY "Editors can delete lots"
    ON public.lots FOR DELETE TO authenticated
    USING (public.has_project_edit_access(project_id));

-- 7.5 Zoning Zones
DROP POLICY IF EXISTS "Users can view zoning zones" ON public.zoning_zones;
DROP POLICY IF EXISTS "Editors can modify zoning zones" ON public.zoning_zones;
DROP POLICY IF EXISTS "Editors can insert zoning zones" ON public.zoning_zones;
DROP POLICY IF EXISTS "Editors can update zoning zones" ON public.zoning_zones;
DROP POLICY IF EXISTS "Editors can delete zoning zones" ON public.zoning_zones;

CREATE POLICY "Users can view zoning zones"
    ON public.zoning_zones FOR SELECT TO authenticated
    USING (public.has_project_access(public.get_project_id_for_lot(lot_id)));

CREATE POLICY "Editors can insert zoning zones"
    ON public.zoning_zones FOR INSERT TO authenticated
    WITH CHECK (public.has_project_edit_access(public.get_project_id_for_lot(lot_id)));

CREATE POLICY "Editors can update zoning zones"
    ON public.zoning_zones FOR UPDATE TO authenticated
    USING (public.has_project_edit_access(public.get_project_id_for_lot(lot_id)))
    WITH CHECK (public.has_project_edit_access(public.get_project_id_for_lot(lot_id)));

CREATE POLICY "Editors can delete zoning zones"
    ON public.zoning_zones FOR DELETE TO authenticated
    USING (public.has_project_edit_access(public.get_project_id_for_lot(lot_id)));

-- 7.6 Buildings
DROP POLICY IF EXISTS "Users can view buildings" ON public.buildings;
DROP POLICY IF EXISTS "Editors can modify buildings" ON public.buildings;
DROP POLICY IF EXISTS "Editors can insert buildings" ON public.buildings;
DROP POLICY IF EXISTS "Editors can update buildings" ON public.buildings;
DROP POLICY IF EXISTS "Editors can delete buildings" ON public.buildings;

CREATE POLICY "Users can view buildings"
    ON public.buildings FOR SELECT TO authenticated
    USING (public.has_project_access(public.get_project_id_for_lot(lot_id)));

CREATE POLICY "Editors can insert buildings"
    ON public.buildings FOR INSERT TO authenticated
    WITH CHECK (public.has_project_edit_access(public.get_project_id_for_lot(lot_id)));

CREATE POLICY "Editors can update buildings"
    ON public.buildings FOR UPDATE TO authenticated
    USING (public.has_project_edit_access(public.get_project_id_for_lot(lot_id)))
    WITH CHECK (public.has_project_edit_access(public.get_project_id_for_lot(lot_id)));

CREATE POLICY "Editors can delete buildings"
    ON public.buildings FOR DELETE TO authenticated
    USING (public.has_project_edit_access(public.get_project_id_for_lot(lot_id)));

-- 7.7 Floors
DROP POLICY IF EXISTS "Users can view floors" ON public.floors;
DROP POLICY IF EXISTS "Editors can modify floors" ON public.floors;
DROP POLICY IF EXISTS "Editors can insert floors" ON public.floors;
DROP POLICY IF EXISTS "Editors can update floors" ON public.floors;
DROP POLICY IF EXISTS "Editors can delete floors" ON public.floors;

CREATE POLICY "Users can view floors"
    ON public.floors FOR SELECT TO authenticated
    USING (public.has_project_access(public.get_project_id_for_building(building_id)));

CREATE POLICY "Editors can insert floors"
    ON public.floors FOR INSERT TO authenticated
    WITH CHECK (public.has_project_edit_access(public.get_project_id_for_building(building_id)));

CREATE POLICY "Editors can update floors"
    ON public.floors FOR UPDATE TO authenticated
    USING (public.has_project_edit_access(public.get_project_id_for_building(building_id)))
    WITH CHECK (public.has_project_edit_access(public.get_project_id_for_building(building_id)));

CREATE POLICY "Editors can delete floors"
    ON public.floors FOR DELETE TO authenticated
    USING (public.has_project_edit_access(public.get_project_id_for_building(building_id)));

-- 7.8 Modules
DROP POLICY IF EXISTS "Users can view modules" ON public.modules;
DROP POLICY IF EXISTS "Editors can modify modules" ON public.modules;
DROP POLICY IF EXISTS "Editors can insert modules" ON public.modules;
DROP POLICY IF EXISTS "Editors can update modules" ON public.modules;
DROP POLICY IF EXISTS "Editors can delete modules" ON public.modules;

CREATE POLICY "Users can view modules"
    ON public.modules FOR SELECT TO authenticated
    USING (public.can_view_floor(floor_id));

CREATE POLICY "Editors can insert modules"
    ON public.modules FOR INSERT TO authenticated
    WITH CHECK (public.can_edit_floor(floor_id));

CREATE POLICY "Editors can update modules"
    ON public.modules FOR UPDATE TO authenticated
    USING (public.can_edit_floor(floor_id))
    WITH CHECK (public.can_edit_floor(floor_id));

CREATE POLICY "Editors can delete modules"
    ON public.modules FOR DELETE TO authenticated
    USING (public.can_edit_floor(floor_id));

-- 7.9 Walls
DROP POLICY IF EXISTS "Users can view walls" ON public.walls;
DROP POLICY IF EXISTS "Editors can modify walls" ON public.walls;
DROP POLICY IF EXISTS "Editors can insert walls" ON public.walls;
DROP POLICY IF EXISTS "Editors can update walls" ON public.walls;
DROP POLICY IF EXISTS "Editors can delete walls" ON public.walls;

CREATE POLICY "Users can view walls"
    ON public.walls FOR SELECT TO authenticated
    USING (public.can_view_floor(floor_id));

CREATE POLICY "Editors can insert walls"
    ON public.walls FOR INSERT TO authenticated
    WITH CHECK (public.can_edit_floor(floor_id));

CREATE POLICY "Editors can update walls"
    ON public.walls FOR UPDATE TO authenticated
    USING (public.can_edit_floor(floor_id))
    WITH CHECK (public.can_edit_floor(floor_id));

CREATE POLICY "Editors can delete walls"
    ON public.walls FOR DELETE TO authenticated
    USING (public.can_edit_floor(floor_id));

-- 7.10 Replacement Relationships
DROP POLICY IF EXISTS "Users can view replacements" ON public.replacement_relationships;
DROP POLICY IF EXISTS "Editors can modify replacements" ON public.replacement_relationships;
DROP POLICY IF EXISTS "Editors can insert replacements" ON public.replacement_relationships;
DROP POLICY IF EXISTS "Editors can update replacements" ON public.replacement_relationships;
DROP POLICY IF EXISTS "Editors can delete replacements" ON public.replacement_relationships;

CREATE POLICY "Users can view replacements"
    ON public.replacement_relationships FOR SELECT TO authenticated
    USING (public.can_view_floor(floor_id));

CREATE POLICY "Editors can insert replacements"
    ON public.replacement_relationships FOR INSERT TO authenticated
    WITH CHECK (public.can_edit_floor(floor_id));

CREATE POLICY "Editors can update replacements"
    ON public.replacement_relationships FOR UPDATE TO authenticated
    USING (public.can_edit_floor(floor_id))
    WITH CHECK (public.can_edit_floor(floor_id));

CREATE POLICY "Editors can delete replacements"
    ON public.replacement_relationships FOR DELETE TO authenticated
    USING (public.can_edit_floor(floor_id));

-- 7.11 Project Share Links
DROP POLICY IF EXISTS "Users can view project share links" ON public.project_share_links;
DROP POLICY IF EXISTS "Editors can insert project share links" ON public.project_share_links;
DROP POLICY IF EXISTS "Editors can update project share links" ON public.project_share_links;
DROP POLICY IF EXISTS "Editors can delete project share links" ON public.project_share_links;

CREATE POLICY "Users can view project share links"
    ON public.project_share_links FOR SELECT TO authenticated
    USING (public.has_project_access(project_id));

CREATE POLICY "Editors can insert project share links"
    ON public.project_share_links FOR INSERT TO authenticated
    WITH CHECK (
        created_by = (SELECT auth.uid())
        AND public.has_project_edit_access(project_id)
    );

CREATE POLICY "Editors can update project share links"
    ON public.project_share_links FOR UPDATE TO authenticated
    USING (public.has_project_edit_access(project_id))
    WITH CHECK (public.has_project_edit_access(project_id));

CREATE POLICY "Editors can delete project share links"
    ON public.project_share_links FOR DELETE TO authenticated
    USING (public.has_project_edit_access(project_id));
