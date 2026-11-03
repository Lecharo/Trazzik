-- ==============================================================================
-- Trazzik — Corrección definitiva de RLS para modules, walls y replacement_relationships
-- ==============================================================================

-- 1. Funciones de verificación de membresía y acceso (PL/pgSQL SECURITY DEFINER)
CREATE OR REPLACE FUNCTION public.has_project_access(proj_id UUID)
RETURNS BOOLEAN 
LANGUAGE plpgsql 
SECURITY DEFINER 
SET search_path = public
AS $$
BEGIN
    IF proj_id IS NULL THEN
        RETURN FALSE;
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.projects p
        WHERE p.id = proj_id AND p.owner_id = auth.uid()
    ) THEN
        RETURN TRUE;
    END IF;

    RETURN EXISTS (
        SELECT 1 FROM public.project_members pm
        WHERE pm.project_id = proj_id
          AND pm.user_id = auth.uid()
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.has_project_edit_access(proj_id UUID)
RETURNS BOOLEAN 
LANGUAGE plpgsql 
SECURITY DEFINER 
SET search_path = public
AS $$
BEGIN
    IF proj_id IS NULL THEN
        RETURN FALSE;
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.projects p
        WHERE p.id = proj_id AND p.owner_id = auth.uid()
    ) THEN
        RETURN TRUE;
    END IF;

    RETURN EXISTS (
        SELECT 1 FROM public.project_members pm
        WHERE pm.project_id = proj_id
          AND pm.user_id = auth.uid()
          AND pm.role IN ('owner', 'editor')
    );
END;
$$;

-- 2. Funciones de resolución de jerarquía sin recursión de RLS (PL/pgSQL SECURITY DEFINER)
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

-- 3. Funciones directas de validación de permisos para Pisos y sus Elementos
CREATE OR REPLACE FUNCTION public.can_edit_floor(target_floor_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    proj_id UUID;
BEGIN
    IF target_floor_id IS NULL THEN
        RETURN FALSE;
    END IF;

    proj_id := public.get_project_id_for_floor(target_floor_id);

    IF proj_id IS NULL THEN
        RETURN FALSE;
    END IF;

    RETURN public.has_project_edit_access(proj_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.can_view_floor(target_floor_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    proj_id UUID;
BEGIN
    IF target_floor_id IS NULL THEN
        RETURN FALSE;
    END IF;

    proj_id := public.get_project_id_for_floor(target_floor_id);

    IF proj_id IS NULL THEN
        RETURN FALSE;
    END IF;

    RETURN public.has_project_access(proj_id);
END;
$$;

-- 4. Re-crear Políticas RLS para modules, walls y replacement_relationships
DROP POLICY IF EXISTS "Users can view modules" ON public.modules;
DROP POLICY IF EXISTS "Editors can modify modules" ON public.modules;

CREATE POLICY "Users can view modules"
    ON public.modules FOR SELECT
    USING (public.can_view_floor(floor_id));

CREATE POLICY "Editors can modify modules"
    ON public.modules FOR ALL
    USING (public.can_edit_floor(floor_id))
    WITH CHECK (public.can_edit_floor(floor_id));

DROP POLICY IF EXISTS "Users can view walls" ON public.walls;
DROP POLICY IF EXISTS "Editors can modify walls" ON public.walls;

CREATE POLICY "Users can view walls"
    ON public.walls FOR SELECT
    USING (public.can_view_floor(floor_id));

CREATE POLICY "Editors can modify walls"
    ON public.walls FOR ALL
    USING (public.can_edit_floor(floor_id))
    WITH CHECK (public.can_edit_floor(floor_id));

DROP POLICY IF EXISTS "Users can view replacements" ON public.replacement_relationships;
DROP POLICY IF EXISTS "Editors can modify replacements" ON public.replacement_relationships;

CREATE POLICY "Users can view replacements"
    ON public.replacement_relationships FOR SELECT
    USING (public.can_view_floor(floor_id));

CREATE POLICY "Editors can modify replacements"
    ON public.replacement_relationships FOR ALL
    USING (public.can_edit_floor(floor_id))
    WITH CHECK (public.can_edit_floor(floor_id));
