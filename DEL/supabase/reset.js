/**
 * Database Reset Script
 * 
 * Clears all data from the Supabase database.
 * WARNING: This is a destructive operation and should only be used in development.
 * 
 * Usage: node supabase/reset.js
 */

import { createClient } from '@supabase/supabase-js';
import * as dotenv from 'dotenv';
import readline from 'readline';

// Load environment variables
dotenv.config();

const supabaseUrl = process.env.VITE_SUPABASE_URL || process.env.REACT_APP_SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.VITE_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseKey) {
    console.error('Error: Required environment variables are missing.');
    console.log('Please ensure VITE_SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are set in your .env file.');
    process.exit(1);
}

// Create a client with the service role key to bypass RLS and delete data
const supabase = createClient(supabaseUrl, supabaseKey, {
    auth: {
        autoRefreshToken: false,
        persistSession: false
    }
});

const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
});

const confirmReset = () => {
    return new Promise((resolve) => {
        rl.question('\n⚠️  WARNING ⚠️\n\nThis will DELETE ALL DATA from your connected Supabase project.\nAre you absolutely sure you want to proceed? (yes/no): ', (answer) => {
            resolve(answer.toLowerCase() === 'yes' || answer.toLowerCase() === 'y');
        });
    });
};

async function resetDatabase() {
    const confirmed = await confirmReset();

    if (!confirmed) {
        console.log('Reset cancelled.');
        process.exit(0);
    }

    console.log('\n🗑️  Starting database reset...');

    try {
        // Note: Due to foreign key constraints, we delete in a specific order
        // Because we set ON DELETE CASCADE on almost everything, deleting top-level entities
        // like servers and users will clean up most of the dependent tables.

        // We can't easily delete Auth users via the standard client without the admin API
        console.log('[1/4] Deleting servers... (cascades to channels, members, roles, bans, emojis, invites)');
        const { error: serversError } = await supabase
            .from('servers')
            .delete()
            .neq('id', '00000000-0000-0000-0000-000000000000'); // Delete everything

        if (serversError) throw new Error(`Servers deletion failed: ${serversError.message}`);

        console.log('[2/4] Deleting friendships & direct messages...');
        await supabase.from('friends').delete().neq('user_id', '00000000-0000-0000-0000-000000000000');
        await supabase.from('direct_messages').delete().neq('id', '00000000-0000-0000-0000-000000000000');

        console.log('[3/4] Deleting messages & reactions...');
        await supabase.from('messages').delete().neq('id', '00000000-0000-0000-0000-000000000000');
        // Reactions should cascade, but just in case
        await supabase.from('reactions').delete().neq('message_id', '00000000-0000-0000-0000-000000000000');

        console.log('[4/4] Deleting profiles... (Note: Auth users must be deleted manually from the dashboard or admin API)');
        const { error: profilesError } = await supabase
            .from('profiles')
            .delete()
            .neq('id', '00000000-0000-0000-0000-000000000000');

        if (profilesError) throw new Error(`Profiles deletion failed: ${profilesError.message}`);

        // Storage is generally harder to clear from the client without knowing all paths
        console.log('Note: Storage bucket contents were not deleted.');

        console.log('\n✅ Database reset completed successfully!');
    } catch (error) {
        console.error('\n❌ Error during reset:', error);
    } finally {
        process.exit(0);
    }
}

// Ensure the script only runs if explicitly called
if (process.argv[1].includes('reset.js')) {
    // Check if we're in production
    if (process.env.NODE_ENV === 'production') {
        console.error('⛔ FATAL: Cannot run reset script in production environment.');
        process.exit(1);
    }

    resetDatabase();
}
