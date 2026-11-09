-- ==============================================================================
-- Trazzik — Migration 0006: Secure RPCs for 60-Day Interactive Client Share Links
-- ==============================================================================

-- 1. Fetch shared project, lot, building, and floors by valid 60-day token
CREATE OR REPLACE FUNCTION public.get_shared_project_by_token(p_token TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_link RECORD;
    v_project JSONB;
    v_lot JSONB;
    v_building JSONB;
    v_floors JSONB;
BEGIN
    IF p_token IS NULL OR length(trim(p_token)) < 8 THEN
        RETURN NULL;
    END IF;

    SELECT id, project_id, allow_finish_selection, expires_at
    INTO v_link
    FROM public.project_share_links
    WHERE token = trim(p_token)
      AND expires_at > TIMEZONE('utc', NOW())
    LIMIT 1;

    IF v_link IS NULL THEN
        RETURN NULL;
    END IF;

    SELECT to_jsonb(p) INTO v_project
    FROM public.projects p
    WHERE p.id = v_link.project_id;

    IF v_project IS NULL THEN
        RETURN NULL;
    END IF;

    SELECT jsonb_build_object(
        'id', l.id,
        'project_id', l.project_id,
        'boundary_polygon', l.boundary_polygon,
        'orientation_degrees', l.orientation_degrees,
        'zoning_zones', COALESCE(
            (
                SELECT jsonb_agg(to_jsonb(z))
                FROM public.zoning_zones z
                WHERE z.lot_id = l.id
            ),
            '[]'::jsonb
        )
    )
    INTO v_lot
    FROM public.lots l
    WHERE l.project_id = v_link.project_id
    LIMIT 1;

    IF v_lot IS NOT NULL THEN
        SELECT to_jsonb(b) INTO v_building
        FROM public.buildings b
        WHERE b.lot_id = (v_lot->>'id')::uuid
        ORDER BY b.order_index ASC
        LIMIT 1;
    END IF;

    IF v_building IS NOT NULL THEN
        SELECT COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'id', f.id,
                    'building_id', f.building_id,
                    'floor_number', f.floor_number,
                    'name', f.name,
                    'level_meters', f.level_meters,
                    'height_meters', f.height_meters,
                    'boundary', f.boundary,
                    'max_allowed_area', f.max_allowed_area,
                    'modules', COALESCE(
                        (
                            SELECT jsonb_agg(to_jsonb(m))
                            FROM public.modules m
                            WHERE m.floor_id = f.id
                        ),
                        '[]'::jsonb
                    ),
                    'walls', COALESCE(
                        (
                            SELECT jsonb_agg(to_jsonb(w))
                            FROM public.walls w
                            WHERE w.floor_id = f.id
                        ),
                        '[]'::jsonb
                    ),
                    'replacement_relationships', COALESCE(
                        (
                            SELECT jsonb_agg(to_jsonb(r))
                            FROM public.replacement_relationships r
                            WHERE r.floor_id = f.id
                        ),
                        '[]'::jsonb
                    )
                )
                ORDER BY f.floor_number ASC
            ),
            '[]'::jsonb
        )
        INTO v_floors
        FROM public.floors f
        WHERE f.building_id = (v_building->>'id')::uuid;
    ELSE
        v_floors := '[]'::jsonb;
    END IF;

    RETURN jsonb_build_object(
        'project', v_project,
        'allow_finish_selection', v_link.allow_finish_selection,
        'expires_at', v_link.expires_at,
        'lot', v_lot,
        'building', v_building,
        'floors', v_floors
    );
END;
$$;

-- 2. Allow client with valid interactive share token to update room finishes only on that project
CREATE OR REPLACE FUNCTION public.update_shared_module_finishes(
    p_token TEXT,
    p_module_id UUID,
    p_floor_material_id TEXT DEFAULT NULL,
    p_wall_finish_id TEXT DEFAULT NULL,
    p_clear_finishes BOOLEAN DEFAULT FALSE
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_project_id UUID;
    v_module_project_id UUID;
BEGIN
    IF p_token IS NULL OR p_module_id IS NULL THEN
        RETURN FALSE;
    END IF;

    SELECT project_id INTO v_project_id
    FROM public.project_share_links
    WHERE token = trim(p_token)
      AND allow_finish_selection = TRUE
      AND expires_at > TIMEZONE('utc', NOW())
    LIMIT 1;

    IF v_project_id IS NULL THEN
        RETURN FALSE;
    END IF;

    SELECT l.project_id INTO v_module_project_id
    FROM public.modules m
    JOIN public.floors f ON f.id = m.floor_id
    JOIN public.buildings b ON b.id = f.building_id
    JOIN public.lots l ON l.id = b.lot_id
    WHERE m.id = p_module_id;

    IF v_module_project_id IS NULL OR v_module_project_id <> v_project_id THEN
        RETURN FALSE;
    END IF;

    IF p_clear_finishes THEN
        UPDATE public.modules
        SET
            floor_material_id = NULL,
            wall_finish_id = NULL,
            geometry = (geometry - 'floor_material_id') - 'wall_finish_id'
        WHERE id = p_module_id;
    ELSE
        UPDATE public.modules
        SET
            floor_material_id = COALESCE(p_floor_material_id, floor_material_id),
            wall_finish_id = COALESCE(p_wall_finish_id, wall_finish_id),
            geometry = jsonb_strip_nulls(
                geometry || jsonb_build_object(
                    'floor_material_id', COALESCE(p_floor_material_id, floor_material_id),
                    'wall_finish_id', COALESCE(p_wall_finish_id, wall_finish_id)
                )
            )
        WHERE id = p_module_id;
    END IF;

    RETURN TRUE;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_shared_project_by_token(TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.update_shared_module_finishes(TEXT, UUID, TEXT, TEXT, BOOLEAN) TO anon, authenticated, service_role;
