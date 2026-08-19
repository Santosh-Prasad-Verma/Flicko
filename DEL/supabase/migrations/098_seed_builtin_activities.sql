-- Seed built-in voice-channel activities with stable UUIDs (used by mobile fallback + sessions FK)
INSERT INTO public.activities (
  id, name, description, icon_url, category, max_participants, is_premium, embed_url, developer, avg_duration, enabled
) VALUES
  (
    'a0000000-0000-4000-8000-000000000001'::uuid,
    'Watch Together',
    'Browse Wikipedia together in the voice channel.',
    'https://cdn-icons-png.flaticon.com/512/1384/1384060.png',
    'watch_together',
    25,
    false,
    'https://en.m.wikipedia.org/wiki/Main_Page',
    'Flicko',
    '~30 min',
    true
  ),
  (
    'a0000000-0000-4000-8000-000000000002'::uuid,
    'Sketch & Guess',
    'Simple drawing prompts you can share on screen (opens a lightweight page).',
    'https://cdn-icons-png.flaticon.com/512/1828/1828817.png',
    'games',
    10,
    false,
    'https://en.m.wikipedia.org/wiki/Pictionary',
    'Flicko Games',
    '~20 min',
    true
  ),
  (
    'a0000000-0000-4000-8000-000000000003'::uuid,
    'Community Hangout',
    'A relaxed premium-style lounge label (still free — opens a readable page).',
    'https://cdn-icons-png.flaticon.com/512/105/105220.png',
    'premium',
    15,
    false,
    'https://en.m.wikipedia.org/wiki/Online_chat',
    'Flicko',
    '~1 hr',
    true
  )
ON CONFLICT (id) DO NOTHING;
