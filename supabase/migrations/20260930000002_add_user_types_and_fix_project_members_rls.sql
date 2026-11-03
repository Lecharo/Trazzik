-- ==============================================================================
-- Trazzik — Corrección de RLS para project_members y enriquecimiento de profiles
-- ==============================================================================

-- 1. Tipo de usuario / perfil profesional en profiles (según punto 35 de requerimientos)
DROP TYPE IF EXISTS public.user_type CASCADE;
CREATE TYPE public.user_type AS ENUM (
    'architect',
    'engineer',
    'contractor',
    'client',
    'admin'
);

ALTER TABLE public.profiles 
    ADD COLUMN IF NOT EXISTS user_type public.user_type DEFAULT 'architect' NOT NULL,
    ADD COLUMN IF NOT EXISTS phone TEXT,
    ADD COLUMN IF NOT EXISTS company TEXT;

-- 2. Actualización del trigger para persistir user_type desde los metadatos de registro
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, email, full_name, user_type)
    VALUES (
        NEW.id,
        NEW.email,
        NEW.raw_user_meta_data->>'full_name',
        COALESCE(
            NULLIF(NEW.raw_user_meta_data->>'user_type', '')::public.user_type,
            'architect'::public.user_type
        )
    )
    ON CONFLICT (id) DO UPDATE SET
        full_name = COALESCE(EXCLUDED.full_name, profiles.full_name),
        user_type = COALESCE(EXCLUDED.user_type, profiles.user_type);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Políticas de seguridad RLS faltantes para project_members
ALTER TABLE public.project_members ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view project members" ON public.project_members;
DROP POLICY IF EXISTS "Project owners can manage members" ON public.project_members;

-- Lectura: Ver miembros de los proyectos en los que participás o sos dueño
CREATE POLICY "Users can view project members"
    ON public.project_members FOR SELECT
    USING (user_id = auth.uid() OR public.has_project_access(project_id));

-- Gestión total para el creador/dueño del proyecto (permite agregarse como owner y sumar colaboradores)
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
