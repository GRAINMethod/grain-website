import { createClient, type SupabaseClient } from "@supabase/supabase-js";

// The publishable key is safe in client code: every table is behind row level security,
// and anything sensitive goes through database functions that check who is calling.
export const SUPABASE_URL =
  process.env.NEXT_PUBLIC_SUPABASE_URL ?? "https://emmgtxumhaqfbcjzddpa.supabase.co";
export const SUPABASE_KEY =
  process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ?? "sb_publishable_f6-MchoNCazpEvscPeaGzA_xdBiIhrJ";

/** Server-side client. Pass the caller's access token to act as that signed-in user. */
export function serverClient(accessToken?: string | null): SupabaseClient {
  return createClient(SUPABASE_URL, SUPABASE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: accessToken ? { headers: { Authorization: `Bearer ${accessToken}` } } : undefined,
  });
}

let browser: SupabaseClient | null = null;
/** Browser client for /login and /hq. Keeps the session in this browser and refreshes it. */
export function browserClient(): SupabaseClient {
  if (!browser) {
    browser = createClient(SUPABASE_URL, SUPABASE_KEY, {
      auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true, storageKey: "grain-auth" },
    });
  }
  return browser;
}
