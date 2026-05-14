// STAMPBIT - Database Module
// Supabase Client - Vanilla JS

const STAMPBIT_DB = (() => {
  let client = null;
  let ready = false;

  function getConfig() {
    const url = window.STAMPBIT_ENV?.SUPABASE_URL;
    const key = window.STAMPBIT_ENV?.SUPABASE_ANON_KEY;
    if (!url || !key) {
      console.error('[STAMPBIT] Variaveis de ambiente nao encontradas. Verifique .env');
      return null;
    }
    return { url, key };
  }

  async function init() {
    const config = getConfig();
    if (!config) return { ready: false };

    try {
      const { createClient } = await import('https://esm.sh/@supabase/supabase-js@2');
      client = createClient(config.url, config.key, {
        auth: { persistSession: true, autoRefreshToken: true },
        global: { headers: { 'x-application-name': 'STAMPBIT' } }
      });

      const { data, error } = await client.from('stamps').select('id').limit(1);
      if (error) throw error;

      ready = true;
      console.log('%c> STAMPBIT_SYSTEM_READY // DATABASE: SUPABASE_ONLINE', 'color: #4cc9f0; font-family: monospace; font-size: 12px;');
      return { ready: true, client };
    } catch (err) {
      console.error('[STAMPBIT] Falha na conexao Supabase:', err.message);
      return { ready: false, error: err.message };
    }
  }

  function getClient() { return client; }
  function isReady() { return ready; }

  return { init, getClient, isReady };
})();

export default STAMPBIT_DB;
