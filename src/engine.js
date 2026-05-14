// STAMPBIT - Forge Engine
// Logica de forja e validacao de selos

const STAMPBIT_ENGINE = (() => {
  function generateSerial(prefix, number, total) {
    const padded = String(number).padStart(3, '0');
    return `${prefix}-${padded}/${total}`;
  }

  async function forgeStamp(stampId) {
    const db = STAMPBIT_DB.getClient();
    const user = STAMPBIT_AUTH.getUser();
    if (!db) return { error: 'Database offline' };
    if (!user) return { error: 'Usuario nao autenticado' };

    try {
      const { data: stamp, error: stampErr } = await db
        .from('stamps')
        .select('*')
        .eq('id', stampId)
        .single();
      if (stampErr) throw stampErr;

      const { count, error: countErr } = await db
        .from('inventory')
        .select('*', { count: 'exact', head: true })
        .eq('stamp_id', stampId);
      if (countErr) throw countErr;

      const nextSerial = (count || 0) + 1;
      if (nextSerial > stamp.total_supply) {
        return { error: 'Supply esgotado deste selo' };
      }

      const { data: forged, error: forgeErr } = await db
        .from('inventory')
        .insert({
          user_id: user.id,
          stamp_id: stampId,
          serial_number: nextSerial
        })
        .select()
        .single();
      if (forgeErr) throw forgeErr;

      console.log(
        `%c> STAMPBIT_FORGED // ${stamp.name} // ${generateSerial(stamp.serial_prefix, nextSerial, stamp.total_supply)} // HASH: ${forged.hash_validation?.slice(0, 16)}...`,
        'color: #9d4edd; font-family: monospace;'
      );

      return {
        success: true,
        stamp: forged,
        serial: generateSerial(stamp.serial_prefix, nextSerial, stamp.total_supply),
        hash: forged.hash_validation
      };
    } catch (err) {
      console.error('[STAMPBIT] Erro na forja:', err.message);
      return { error: err.message };
    }
  }

  async function getUserStamps() {
    const db = STAMPBIT_DB.getClient();
    const user = STAMPBIT_AUTH.getUser();
    if (!db || !user) return [];

    const { data, error } = await db
      .from('inventory')
      .select('*, stamps(*)')
      .eq('user_id', user.id)
      .order('forged_at', { ascending: false });

    if (error) {
      console.error('[STAMPBIT] Erro ao buscar inventario:', error.message);
      return [];
    }
    return data || [];
  }

  function validateHash(hash) {
    return /^[a-f0-9]{64}$/.test(hash);
  }

  return { forgeStamp, getUserStamps, generateSerial, validateHash };
})();

export default STAMPBIT_ENGINE;
