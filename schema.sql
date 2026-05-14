-- ============================================================
-- STAMPBIT - Database Schema v3.0 (Ecosystem)
-- ============================================================

-- 0. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 1. ENUMS
DO $$ BEGIN
  CREATE TYPE stamp_rarity AS ENUM ('Comum', 'Raro', 'Epico', 'Lendario');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE trade_status AS ENUM ('pending', 'accepted', 'rejected', 'cancelled');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 2. STAMPS (Catalogo de selos)
CREATE TABLE IF NOT EXISTS stamps (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name          TEXT NOT NULL,
  description   TEXT,
  rarity        stamp_rarity NOT NULL DEFAULT 'Comum',
  emoji         TEXT DEFAULT '🔶',
  image_url     TEXT,
  serial_prefix TEXT NOT NULL,
  total_supply  INTEGER NOT NULL DEFAULT 0,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. INVENTORY (Selos unicos forjados com hash)
CREATE TABLE IF NOT EXISTS inventory (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  stamp_id        UUID NOT NULL REFERENCES stamps(id) ON DELETE CASCADE,
  serial_number   INTEGER NOT NULL,
  hash_validation TEXT NOT NULL UNIQUE,
  forged_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_inventory_user_id ON inventory(user_id);
CREATE INDEX IF NOT EXISTS idx_inventory_stamp_id ON inventory(stamp_id);
CREATE INDEX IF NOT EXISTS idx_inventory_hash ON inventory(hash_validation);

-- 4. ALBUMS (Colecoes tematicas)
CREATE TABLE IF NOT EXISTS albums (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name            TEXT NOT NULL,
  description     TEXT,
  cover_emoji     TEXT DEFAULT '📒',
  theme           TEXT,
  total_slots     INTEGER NOT NULL DEFAULT 0,
  reward_desc     TEXT,
  is_active       BOOLEAN DEFAULT true,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 5. ALBUM_STAMPS (Quais selos vao em cada album + posicao)
CREATE TABLE IF NOT EXISTS album_stamps (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  album_id    UUID NOT NULL REFERENCES albums(id) ON DELETE CASCADE,
  stamp_id    UUID NOT NULL REFERENCES stamps(id) ON DELETE CASCADE,
  slot_number INTEGER NOT NULL,
  UNIQUE(album_id, slot_number),
  UNIQUE(album_id, stamp_id)
);

-- 6. USER_STAMPS (Colecao do usuario com quantidade)
CREATE TABLE IF NOT EXISTS user_stamps (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id             UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  stamp_id            UUID NOT NULL REFERENCES stamps(id) ON DELETE CASCADE,
  quantity            INTEGER NOT NULL DEFAULT 0,
  quantity_duplicate  INTEGER NOT NULL DEFAULT 0,
  first_acquired_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id, stamp_id)
);

-- 7. USER_ALBUMS (Progresso do usuario nos albums)
CREATE TABLE IF NOT EXISTS user_albums (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  album_id    UUID NOT NULL REFERENCES albums(id) ON DELETE CASCADE,
  completed   BOOLEAN DEFAULT false,
  completed_at TIMESTAMPTZ,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id, album_id)
);

-- 8. BOOSTER_PACKS (Tipos de envelope)
CREATE TABLE IF NOT EXISTS booster_packs (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name            TEXT NOT NULL,
  description     TEXT,
  emoji           TEXT DEFAULT '📨',
  price_credits   INTEGER NOT NULL DEFAULT 0,
  stamps_per_pack INTEGER NOT NULL DEFAULT 5,
  is_active       BOOLEAN DEFAULT true,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 9. PACK_RARITY_WEIGHTS (Probabilidade de cada raridade no pack)
CREATE TABLE IF NOT EXISTS pack_rarity_weights (
  id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pack_id UUID NOT NULL REFERENCES booster_packs(id) ON DELETE CASCADE,
  rarity  stamp_rarity NOT NULL,
  weight  INTEGER NOT NULL DEFAULT 1,
  UNIQUE(pack_id, rarity)
);

-- 10. TRADES (Propostas de troca)
CREATE TABLE IF NOT EXISTS trades (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  proposer_id   UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  responder_id  UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status        trade_status NOT NULL DEFAULT 'pending',
  message       TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 11. TRADE_ITEMS (Itens de cada proposta)
CREATE TABLE IF NOT EXISTS trade_items (
  id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  trade_id  UUID NOT NULL REFERENCES trades(id) ON DELETE CASCADE,
  user_id   UUID NOT NULL,
  stamp_id  UUID NOT NULL REFERENCES stamps(id) ON DELETE CASCADE,
  quantity  INTEGER NOT NULL DEFAULT 1,
  direction TEXT NOT NULL CHECK (direction IN ('offering', 'requesting'))
);

-- 12. USER_CREDITS (Saldo de creditos para comprar packs)
CREATE TABLE IF NOT EXISTS user_credits (
  id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id   UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
  balance   INTEGER NOT NULL DEFAULT 100,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ========== TRIGGERS ==========

CREATE OR REPLACE FUNCTION generate_stamp_hash()
RETURNS TRIGGER AS $$
BEGIN
  NEW.hash_validation := encode(
    sha256((NEW.user_id::text || NEW.stamp_id::text || NEW.serial_number::text || now()::text)::bytea),
    'hex'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_generate_stamp_hash ON inventory;
CREATE TRIGGER trg_generate_stamp_hash
  BEFORE INSERT ON inventory
  FOR EACH ROW EXECUTE FUNCTION generate_stamp_hash();

-- Atualizar updated_at automaticamente
CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_stamps_updated ON stamps;
CREATE TRIGGER trg_stamps_updated BEFORE UPDATE ON stamps
  FOR EACH ROW EXECUTE FUNCTION update_timestamp();

DROP TRIGGER IF EXISTS trg_trades_updated ON trades;
CREATE TRIGGER trg_trades_updated BEFORE UPDATE ON trades
  FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- ========== RLS ==========
ALTER TABLE stamps ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE albums ENABLE ROW LEVEL SECURITY;
ALTER TABLE album_stamps ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_stamps ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_albums ENABLE ROW LEVEL SECURITY;
ALTER TABLE booster_packs ENABLE ROW LEVEL SECURITY;
ALTER TABLE pack_rarity_weights ENABLE ROW LEVEL SECURITY;
ALTER TABLE trades ENABLE ROW LEVEL SECURITY;
ALTER TABLE trade_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_credits ENABLE ROW LEVEL SECURITY;

-- Leitura publica
DROP POLICY IF EXISTS "Stamps public read" ON stamps;
CREATE POLICY "Stamps public read" ON stamps FOR SELECT USING (true);

DROP POLICY IF EXISTS "Albums public read" ON albums;
CREATE POLICY "Albums public read" ON albums FOR SELECT USING (true);

DROP POLICY IF EXISTS "AlbumStamps public read" ON album_stamps;
CREATE POLICY "AlbumStamps public read" ON album_stamps FOR SELECT USING (true);

DROP POLICY IF EXISTS "BoosterPacks public read" ON booster_packs;
CREATE POLICY "BoosterPacks public read" ON booster_packs FOR SELECT USING (true);

DROP POLICY IF EXISTS "PackWeights public read" ON pack_rarity_weights;
CREATE POLICY "PackWeights public read" ON pack_rarity_weights FOR SELECT USING (true);

-- Usuario: apenas seus proprios dados
DROP POLICY IF EXISTS "UserStamps own" ON user_stamps;
CREATE POLICY "UserStamps own" ON user_stamps
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "UserAlbums own" ON user_albums;
CREATE POLICY "UserAlbums own" ON user_albums
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Inventory own" ON inventory;
CREATE POLICY "Inventory own" ON inventory
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Credits own" ON user_credits;
CREATE POLICY "Credits own" ON user_credits
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- Trades: envolvidos podem ver
DROP POLICY IF EXISTS "Trades involved" ON trades;
CREATE POLICY "Trades involved" ON trades
  FOR ALL USING (auth.uid() = proposer_id OR auth.uid() = responder_id);

DROP POLICY IF EXISTS "TradeItems involved" ON trade_items;
CREATE POLICY "TradeItems involved" ON trade_items
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM trades t WHERE t.id = trade_items.trade_id AND (t.proposer_id = auth.uid() OR t.responder_id = auth.uid()))
  );
