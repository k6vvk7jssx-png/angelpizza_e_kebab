import { supabase } from '../src/lib/supabaseClient';

describe('Supabase Client', () => {
  it('initializes with the correct URL', () => {
    expect(supabase).toBeDefined();
    expect(supabase.supabaseUrl).toBe('https://cavxvkwixbxbdvaasxpa.supabase.co');
  });
});
