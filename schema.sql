-- ============================================================
-- STAMPBIT - Database Schema
-- Supabase SQL Script
-- Otimizado para performance (Regiao: Sao Paulo)
-- ============================================================

-- 1. ENUM: Rarity
CREATE TYPE stamp_rarity AS ENUM ('Comum', 'Raro', 'Epico', 'Lendario');

-- 2. TABLE: stamps (Catalogo de selos)
CREATE TABLE IF NOT EXISTS stamps (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name          TEXT NOT NULL,
  description   TEXT,
  rarity        stamp_rarity NOT NULL DEFAULT 'Comum',
  image_url     TEXT,
  serial_prefix TEXT NOT NULL,
  total_supply  INTEGER NOT NULL DEFAULT 0,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. TABLE: inventory (One-to-many: usuario -> selos)
CREATE TABLE IF NOT EXISTS inventory (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL,
  stamp_id      UUID NOT NULL REFERENCES stamps(id) ON DELETE CASCADE,
  serial_number INTEGER NOT NULL,
  hash_validation TEXT NOT NULL UNIQUE,
  forged_at     TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT fk_user
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
  CONSTRAINT fk_stamp
    FOREIGN KEY (stamp_id) REFERENCES stamps(id) ON DELETE CASCADE
);

-- 4. INDEX: Performance em queries por usuario
CREATE INDEX IF NOT EXISTS idx_inventory_user_id ON inventory(user_id);
CREATE INDEX IF NOT EXISTS idx_inventory_stamp_id ON inventory(stamp_id);
CREATE INDEX IF NOT EXISTS idx_inventory_hash ON inventory(hash_validation);

-- 5. FUNCTION: Gerar hash unico de validacao
CREATE OR REPLACE FUNCTION generate_stamp_hash()
RETURNS TRIGGER AS $$
BEGIN
  NEW.hash_validation := encode(
    sha256(
      (NEW.user_id::text || NEW.stamp_id::text || NEW.serial_number::text || now()::text)::bytea
    ),
    'hex'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. TRIGGER: Auto-gerar hash antes de inserir
DROP TRIGGER IF EXISTS trg_generate_stamp_hash ON inventory;
CREATE TRIGGER trg_generate_stamp_hash
  BEFORE INSERT ON inventory
  FOR EACH ROW
  EXECUTE FUNCTION generate_stamp_hash();

-- 7. RLS: Seguranca linha a linha
ALTER TABLE stamps ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory ENABLE ROW LEVEL SECURITY;

-- 8. POLICIES
-- Stamps: todos podem ler
CREATE POLICY "Stamps leitura publica"
  ON stamps FOR SELECT
  USING (true);

-- Inventory: usuario ve apenas seus proprios selos
CREATE POLICY "Inventory leitura propria"
  ON inventory FOR SELECT
  USING (auth.uid() = user_id);

-- Inventory: usuario pode inserir apenas para si
CREATE POLICY "Inventory insercao propria"
  ON inventory FOR INSERT
  WITH CHECK (auth.uid() = user_id);
