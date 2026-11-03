-- ==============================================================================
-- Trazzik — Migración: Agregar soporte para imagen de portada en proyectos
-- ==============================================================================

ALTER TABLE public.projects 
    ADD COLUMN IF NOT EXISTS image_url TEXT;
