import { createClient, type SupabaseClient } from "@supabase/supabase-js";

const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

/** Supabase dikonfigurasi hanya bila kedua variabel lingkungan tersedia.
 *  Bila belum, dashboard tetap tampil memakai data contoh bawaan. */
export const supabaseAktif = Boolean(url && anonKey);

let klien: SupabaseClient | null = null;

export function getSupabase(): SupabaseClient | null {
  if (!supabaseAktif) return null;
  if (!klien) {
    klien = createClient(url as string, anonKey as string, {
      auth: { persistSession: false },
    });
  }
  return klien;
}
