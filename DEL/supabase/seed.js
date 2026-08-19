/**
 * Database Seed Script
 * 
 * Populates the Supabase database with sample data for development and testing.
 * Includes sample users, servers, channels, roles, and messages.
 * 
 * Usage: node supabase/seed.js
 */

import { createClient } from '@supabase/supabase-js';
import * as dotenv from 'dotenv';
import { randomUUID } from 'crypto';

// Load environment variables
dotenv.config();

const supabaseUrl = process.env.VITE_SUPABASE_URL || process.env.REACT_APP_SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.VITE_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseKey) {
    console.error('Error: Required environment variables are missing.');
    console.log('Please ensure VITE_SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are set in your .env file.');
    process.exit(1);
}

// Ensure we're not running in production
if (process.env.NODE_ENV === 'production') {
    console.error('⛔ FATAL: Cannot run seed script in production environment.');
    process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey, {
    auth: { autoRefreshToken: false, persistSession: false }
});

const MOCK_USERS = [
    { id: randomUUID(), username: 'gamer_dude', discriminator: '1337', email: 'gamer@example.com', avatar: 'https://api.dicebear.com/7.x/avataaars/svg?seed=gamer' },
    { id: randomUUID(), username: 'coding_ninja', discriminator: '4040', email: 'ninja@example.com', avatar: 'https://api.dicebear.com/7.x/avataaars/svg?seed=ninja' },
    { id: randomUUID(), username: 'pixel_art', discriminator: '1024', email: 'pixel@example.com', avatar: 'https://api.dicebear.com/7.x/avataaars/svg?seed=pixel' },
    { id: randomUUID(), username: 'synthwave', discriminator: '1984', email: 'synth@example.com', avatar: 'https://api.dicebear.com/7.x/avataaars/svg?seed=synth' },
    { id: randomUUID(), username: 'cool_beans', discriminator: '9999', email: 'beans@example.com', avatar: 'https://api.dicebear.com/7.x/avataaars/svg?seed=beans' },
];

const MOCK_SERVERS = [
    { id: randomUUID(), name: 'Global Gaming Hub', description: 'The official server for gamers worldwide.', icon: null },
    { id: randomUUID(), name: 'DevChat Connect', description: 'A place for developers to chat and share ideas.', icon: null },
];

async function seedDatabase() {
    console.log('🌱 Starting database seed...');

    try {
        // Note: This script assumes you are using the service_role key to bypass RLS, OR
        // that the anon key has sufficient permission via RLS policies (unlikely for inserts).
        // Because we need complete control over insertion (including explicit IDs for profiles), 
        // the service_role is highly recommended.

        console.log('[1/5] Creating profiles...');
        // We insert straight into profiles. 
        // Auth users (auth.users) are technically required for full login capabilities,
        // so this mock data can only be used to populate the UI, not actually log in as them.
        for (const u of MOCK_USERS) {
            await supabase.from('profiles').insert({
                id: u.id,
                username: u.username,
                discriminator: u.discriminator,
                email: u.email,
                avatar: u.avatar,
                status: 'online',
                updated_at: new Date().toISOString()
            }).select();
        }

        console.log('[2/5] Creating servers and roles...');
        for (let i = 0; i < MOCK_SERVERS.length; i++) {
            const server = MOCK_SERVERS[i];
            const owner = MOCK_USERS[i]; // Make the first user owner of first server, second user owner of second, etc.

            const { data: serverData, error: serverError } = await supabase.from('servers').insert({
                id: server.id,
                name: server.name,
                description: server.description,
                owner_id: owner.id,
            }).select().single();

            if (serverError) console.error('Server Insert Error:', serverError.message);

            // Create some default roles
            await supabase.from('roles').insert([
                { server_id: server.id, name: '@everyone', permissions: 104320577, position: 0 },
                { server_id: server.id, name: 'Admin', permissions: 8, position: 1, color: '#ff0000', hoist: true },
            ]);
        }

        console.log('[3/5] Adding members to servers...');
        for (const server of MOCK_SERVERS) {
            for (const user of MOCK_USERS) {
                // Add everyone to every server with 80% probability
                if (Math.random() > 0.2) {
                    await supabase.from('server_members').insert({
                        server_id: server.id,
                        user_id: user.id,
                        joined_at: new Date().toISOString()
                    });
                }
            }
        }

        console.log('[4/5] Creating channels...');
        for (const server of MOCK_SERVERS) {
            // Create a category
            const { data: catData } = await supabase.from('channels').insert({
                server_id: server.id,
                name: 'Text Channels',
                type: 'category',
                position: 0
            }).select().single();

            // Create text channels under category
            if (catData) {
                await supabase.from('channels').insert([
                    { server_id: server.id, name: 'general', type: 'text', parent_id: catData.id, position: 0 },
                    { server_id: server.id, name: 'announcements', type: 'text', parent_id: catData.id, position: 1 },
                    { server_id: server.id, name: 'off-topic', type: 'text', parent_id: catData.id, position: 2 }
                ]);

                // Let's create a voice category too
                const { data: voiceCatData } = await supabase.from('channels').insert({
                    server_id: server.id,
                    name: 'Voice Channels',
                    type: 'category',
                    position: 1
                }).select().single();

                if (voiceCatData) {
                    await supabase.from('channels').insert([
                        { server_id: server.id, name: 'General', type: 'voice', parent_id: voiceCatData.id, position: 0 },
                        { server_id: server.id, name: 'Gaming', type: 'voice', parent_id: voiceCatData.id, position: 1 }
                    ]);
                }
            }
        }

        console.log('[5/5] Creating friendships...');
        // Create some friendships
        const user1 = MOCK_USERS[0];
        const user2 = MOCK_USERS[1];
        const user3 = MOCK_USERS[2];

        await supabase.from('friends').insert([
            { user_id: user1.id, friend_id: user2.id, status: 'accepted' },
            { user_id: user2.id, friend_id: user1.id, status: 'accepted' },

            { user_id: user1.id, friend_id: user3.id, status: 'pending' },
        ]);

        console.log('\n✅ Database seeded successfully!');
        console.log('Use one of the real users created via auth UI to test interactions.');
    } catch (error) {
        console.error('\n❌ Error during seeding:', error);
    } finally {
        process.exit(0);
    }
}

seedDatabase();
