// STAMPBIT - Auth Module
// Autenticacao via Supabase

const STAMPBIT_AUTH = (() => {
  let currentUser = null;

  async function signIn(email, password) {
    const db = STAMPBIT_DB.getClient();
    if (!db) return { error: 'Database not initialized' };

    const { data, error } = await db.auth.signInWithPassword({ email, password });
    if (!error) currentUser = data.user;
    return { user: data?.user, error };
  }

  async function signUp(email, password) {
    const db = STAMPBIT_DB.getClient();
    if (!db) return { error: 'Database not initialized' };

    const { data, error } = await db.auth.signUp({
      email,
      password,
      options: { data: { app: 'STAMPBIT' } }
    });
    return { user: data?.user, error };
  }

  async function signOut() {
    const db = STAMPBIT_DB.getClient();
    if (!db) return;
    await db.auth.signOut();
    currentUser = null;
  }

  async function getSession() {
    const db = STAMPBIT_DB.getClient();
    if (!db) return null;
    const { data } = await db.auth.getSession();
    currentUser = data?.session?.user ?? null;
    return currentUser;
  }

  function getUser() { return currentUser; }

  function onAuthChange(callback) {
    const db = STAMPBIT_DB.getClient();
    if (!db) return;
    db.auth.onAuthStateChange((event, session) => {
      currentUser = session?.user ?? null;
      callback(event, currentUser);
    });
  }

  return { signIn, signUp, signOut, getSession, getUser, onAuthChange };
})();

export default STAMPBIT_AUTH;
