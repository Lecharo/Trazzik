-- ==============================================================================
-- Trazzik — Script de Migración Inicial PostgreSQL + RLS (Supabase)
-- Arquitectura Paramétrica de Diseño, Remodelación y Cuantificación de Obra
-- ==============================================================================

-- 0. Extensiones
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Perfiles de usuario vinculados al sistema de autenticación de Supabase
DROP TYPE IF EXISTS public.user_type CASCADE;
CREATE TYPE public.user_type AS ENUM (
    'architect',
    'engineer',
    'contractor',
    'client',
    'admin'
);

CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    full_name TEXT,
    user_type public.user_type DEFAULT 'architect' NOT NULL,
    phone TEXT,
    company TEXT,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc', NOW()) NOT NULL
);

ALTER TABLE public.profiles 
    ADD COLUMN IF NOT EXISTS user_type public.user_type DEFAULT 'architect' NOT NULL;

-- Trigger para sincronizar auth.users con public.profiles automáticamente
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER 
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    detected_user_type public.user_type;
    raw_type TEXT;
BEGIN
    raw_type := LOWER(COALESCE(NEW.raw_user_meta_data->>'user_type', 'architect'));
    
    IF raw_type IN ('architect', 'engineer', 'contractor', 'client', 'admin') THEN
        detected_user_type := raw_type::public.user_type;
    ELSE
        detected_user_type := 'architect'::public.user_type;
    END IF;

    INSERT INTO public.profiles (id, email, full_name, user_type)
    VALUES (
        NEW.id,
        COALESCE(NEW.email, ''),
        NEW.raw_user_meta_data->>'full_name',
        detected_user_type
    )
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        full_name = COALESCE(EXCLUDED.full_name, profiles.full_name),
        user_type = COALESCE(EXCLUDED.user_type, profiles.user_type);

    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    INSERT INTO public.profiles (id, email, full_name, user_type)
    VALUES (
        NEW.id,
        COALESCE(NEW.email, ''),
        NEW.raw_user_meta_data->>'full_name',
        'architect'::public.user_type
    )
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 2. Proyectos
CREATE TABLE IF NOT EXISTS public.projects (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    description TEXT,
    owner_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    country TEXT,
    state_province TEXT,
    city TEXT,
    address TEXT,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc', NOW()) NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT TIMEZONE('utc', NOW()) NOT NULL
);

ALTER TABLE public.projects 
    ADD COLUMN IF NOT EXISTS country TEXT,
    ADD COLUMN IF NOT EXISTS state_province TEXT,
    ADD COLUMN IF NOT EXISTS city TEXT,
    ADD COLUMN IF NOT EXISTS address TEXT;

-- 3. Membresía y Roles de Proyecto
DROP TABLE IF EXISTS public.project_members CASCADE;
DROP TYPE IF EXISTS public.project_role CASCADE;
CREATE TYPE public.project_role AS ENUM ('owner', 'editor', 'viewer');

CREATE TABLE public.project_members (
    project_id UUID NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    role public.project_role NOT NULL DEFAULT 'editor',
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc', NOW()) NOT NULL,
    PRIMARY KEY (project_id, user_id)
);

ALTER TABLE public.project_members 
    ADD COLUMN IF NOT EXISTS role public.project_role NOT NULL DEFAULT 'editor';

-- 4. Lotes
CREATE TABLE IF NOT EXISTS public.lots (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID NOT NULL UNIQUE REFERENCES public.projects(id) ON DELETE CASCADE,
    boundary_polygon JSONB NOT NULL,
    orientation_degrees DOUBLE PRECISION DEFAULT 0.0 NOT NULL
);

-- 5. Zonas de Reglamentación y Zonificación del Lote
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'zoning_type') THEN
        CREATE TYPE public.zoning_type AS ENUM (
            'nonBuildable',
            'buildableUnoccupied',
            'futureReserved',
            'occupied',
            'exterior',
            'other'
        );
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.zoning_zones (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    lot_id UUID NOT NULL REFERENCES public.lots(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    type public.zoning_type NOT NULL,
    boundary JSONB NOT NULL
);

ALTER TABLE public.zoning_zones 
    ADD COLUMN IF NOT EXISTS type public.zoning_type NOT NULL DEFAULT 'buildableUnoccupied';

-- 6. Edificaciones
CREATE TABLE IF NOT EXISTS public.buildings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    lot_id UUID NOT NULL REFERENCES public.lots(id) ON DELETE CASCADE ON UPDATE CASCADE,
    name TEXT NOT NULL DEFAULT 'Edificación Principal',
    floors_count INT DEFAULT 1 NOT NULL,
    order_index INT DEFAULT 1 NOT NULL
);

ALTER TABLE public.buildings
    ADD COLUMN IF NOT EXISTS floors_count INT DEFAULT 1;

-- 7. Pisos / Niveles
CREATE TABLE IF NOT EXISTS public.floors (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    building_id UUID NOT NULL REFERENCES public.buildings(id) ON DELETE CASCADE ON UPDATE CASCADE,
    floor_number INT NOT NULL,
    name TEXT NOT NULL,
    level_meters DOUBLE PRECISION DEFAULT 0.0 NOT NULL,
    height_meters DOUBLE PRECISION DEFAULT 2.60 NOT NULL,
    boundary JSONB NOT NULL,
    max_allowed_area DOUBLE PRECISION NOT NULL,
    UNIQUE(building_id, floor_number)
);

-- 8. Estados de Elemento Constructivo
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'element_status') THEN
        CREATE TYPE public.element_status AS ENUM (
            'existing',
            'preserved',
            'toDemolish',
            'toModify',
            'isNew',
            'future',
            'reference'
        );
    END IF;
END $$;

-- 9. Módulos (Espacios funcionales)
CREATE TABLE IF NOT EXISTS public.modules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    floor_id UUID NOT NULL REFERENCES public.floors(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    module_type TEXT NOT NULL,
    geometry JSONB NOT NULL,
    status public.element_status NOT NULL DEFAULT 'isNew',
    sub_modules JSONB DEFAULT '[]'::jsonb NOT NULL,
    created_at TIMESTAMPTZ DEFAULT TIMEZONE('utc', NOW()) NOT NULL
);

ALTER TABLE public.modules 
    ADD COLUMN IF NOT EXISTS status public.element_status NOT NULL DEFAULT 'isNew';

-- 10. Muros Independientes (Walls)
CREATE TABLE IF NOT EXISTS public.walls (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    floor_id UUID NOT NULL REFERENCES public.floors(id) ON DELETE CASCADE,
    start_point JSONB NOT NULL,
    end_point JSONB NOT NULL,
    thickness DOUBLE PRECISION DEFAULT 0.15 NOT NULL,
    height DOUBLE PRECISION DEFAULT 2.60 NOT NULL,
    status public.element_status NOT NULL DEFAULT 'isNew'
);

ALTER TABLE public.walls 
    ADD COLUMN IF NOT EXISTS status public.element_status NOT NULL DEFAULT 'isNew';

-- 11. Relaciones de Reemplazo (Demolición / Construcción / Ampliación)
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'replacement_type') THEN
        CREATE TYPE public.replacement_type AS ENUM (
            'replace',
            'expand',
            'modify',
            'remove',
            'relocate'
        );
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.replacement_relationships (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    floor_id UUID NOT NULL REFERENCES public.floors(id) ON DELETE CASCADE,
    existing_element_id UUID NOT NULL,
    proposed_element_id UUID NOT NULL,
    relationship_type public.replacement_type NOT NULL,
    overlap_area DOUBLE PRECISION NOT NULL,
    expanded_area DOUBLE PRECISION DEFAULT 0.0 NOT NULL,
    notes TEXT
);

ALTER TABLE public.replacement_relationships 
    ADD COLUMN IF NOT EXISTS relationship_type public.replacement_type NOT NULL DEFAULT 'replace';

-- ==============================================================================
-- FUNCIONES DE RESOLUCIÓN DE AUTORIZACIÓN (SECURITY DEFINER / STABLE)
-- ==============================================================================

-- Verifica si el usuario actual tiene acceso de lectura al proyecto (owner, editor o viewer)
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

-- Verifica si el usuario actual tiene acceso de edición al proyecto (owner o editor)
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

-- Resuelve el project_id a partir de un lot_id
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

-- Resuelve el project_id a partir de un building_id
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

-- Resuelve el project_id a partir de un floor_id
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

-- Validador directo de edición de piso
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

-- Validador directo de visualización de piso
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

-- ==============================================================================
-- POLÍTICAS DE SEGURIDAD RLS (Row Level Security)
-- ==============================================================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.project_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.zoning_zones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.buildings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.floors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.modules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.walls ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.replacement_relationships ENABLE ROW LEVEL SECURITY;

-- Limpieza preventiva de políticas
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can view authorized projects" ON public.projects;
DROP POLICY IF EXISTS "Users can create projects" ON public.projects;
DROP POLICY IF EXISTS "Owners and editors can update projects" ON public.projects;
DROP POLICY IF EXISTS "Only owners can delete projects" ON public.projects;
DROP POLICY IF EXISTS "Users can view project members" ON public.project_members;
DROP POLICY IF EXISTS "Project owners can manage members" ON public.project_members;
DROP POLICY IF EXISTS "Users can view lots" ON public.lots;
DROP POLICY IF EXISTS "Editors can modify lots" ON public.lots;
DROP POLICY IF EXISTS "Users can view zoning zones" ON public.zoning_zones;
DROP POLICY IF EXISTS "Editors can modify zoning zones" ON public.zoning_zones;
DROP POLICY IF EXISTS "Users can view buildings" ON public.buildings;
DROP POLICY IF EXISTS "Editors can modify buildings" ON public.buildings;
DROP POLICY IF EXISTS "Users can view floors" ON public.floors;
DROP POLICY IF EXISTS "Editors can modify floors" ON public.floors;
DROP POLICY IF EXISTS "Users can view modules" ON public.modules;
DROP POLICY IF EXISTS "Editors can modify modules" ON public.modules;
DROP POLICY IF EXISTS "Users can view walls" ON public.walls;
DROP POLICY IF EXISTS "Editors can modify walls" ON public.walls;
DROP POLICY IF EXISTS "Users can view replacements" ON public.replacement_relationships;
DROP POLICY IF EXISTS "Editors can modify replacements" ON public.replacement_relationships;

-- 1. Profiles
CREATE POLICY "Users can view own profile"
    ON public.profiles FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
    ON public.profiles FOR UPDATE
    USING (auth.uid() = id);

-- 2. Projects
CREATE POLICY "Users can view authorized projects"
    ON public.projects FOR SELECT
    USING (owner_id = auth.uid() OR public.has_project_access(id));

CREATE POLICY "Users can create projects"
    ON public.projects FOR INSERT
    WITH CHECK (owner_id = auth.uid());

CREATE POLICY "Owners and editors can update projects"
    ON public.projects FOR UPDATE
    USING (owner_id = auth.uid() OR public.has_project_edit_access(id))
    WITH CHECK (owner_id = auth.uid() OR public.has_project_edit_access(id));

CREATE POLICY "Only owners can delete projects"
    ON public.projects FOR DELETE
    USING (owner_id = auth.uid());

-- 2.1 Project Members
CREATE POLICY "Users can view project members"
    ON public.project_members FOR SELECT
    USING (user_id = auth.uid() OR public.has_project_access(project_id));

CREATE POLICY "Project owners can manage members"
    ON public.project_members FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.projects p
            WHERE p.id = project_members.project_id AND p.owner_id = auth.uid()
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.projects p
            WHERE p.id = project_members.project_id AND p.owner_id = auth.uid()
        )
    );

-- 3. Lots
CREATE POLICY "Users can view lots"
    ON public.lots FOR SELECT
    USING (public.has_project_access(project_id));

CREATE POLICY "Editors can modify lots"
    ON public.lots FOR ALL
    USING (public.has_project_edit_access(project_id))
    WITH CHECK (public.has_project_edit_access(project_id));

-- 4. Zoning Zones
CREATE POLICY "Users can view zoning zones"
    ON public.zoning_zones FOR SELECT
    USING (public.has_project_access(public.get_project_id_for_lot(lot_id)));

CREATE POLICY "Editors can modify zoning zones"
    ON public.zoning_zones FOR ALL
    USING (public.has_project_edit_access(public.get_project_id_for_lot(lot_id)))
    WITH CHECK (public.has_project_edit_access(public.get_project_id_for_lot(lot_id)));

-- 5. Buildings
CREATE POLICY "Users can view buildings"
    ON public.buildings FOR SELECT
    USING (public.has_project_access(public.get_project_id_for_lot(lot_id)));

CREATE POLICY "Editors can modify buildings"
    ON public.buildings FOR ALL
    USING (public.has_project_edit_access(public.get_project_id_for_lot(lot_id)))
    WITH CHECK (public.has_project_edit_access(public.get_project_id_for_lot(lot_id)));

-- 6. Floors
CREATE POLICY "Users can view floors"
    ON public.floors FOR SELECT
    USING (public.has_project_access(public.get_project_id_for_building(building_id)));

CREATE POLICY "Editors can modify floors"
    ON public.floors FOR ALL
    USING (public.has_project_edit_access(public.get_project_id_for_building(building_id)))
    WITH CHECK (public.has_project_edit_access(public.get_project_id_for_building(building_id)));

-- 7. Modules
CREATE POLICY "Users can view modules"
    ON public.modules FOR SELECT
    USING (public.can_view_floor(floor_id));

CREATE POLICY "Editors can modify modules"
    ON public.modules FOR ALL
    USING (public.can_edit_floor(floor_id))
    WITH CHECK (public.can_edit_floor(floor_id));

-- 8. Walls
CREATE POLICY "Users can view walls"
    ON public.walls FOR SELECT
    USING (public.can_view_floor(floor_id));

CREATE POLICY "Editors can modify walls"
    ON public.walls FOR ALL
    USING (public.can_edit_floor(floor_id))
    WITH CHECK (public.can_edit_floor(floor_id));

-- 9. Replacement Relationships
CREATE POLICY "Users can view replacements"
    ON public.replacement_relationships FOR SELECT
    USING (public.can_view_floor(floor_id));

CREATE POLICY "Editors can modify replacements"
    ON public.replacement_relationships FOR ALL
    USING (public.can_edit_floor(floor_id))
    WITH CHECK (public.can_edit_floor(floor_id));
