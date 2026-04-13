// ============================================
// Slash Command & Interaction Service
// ============================================
import { supabase } from '../../mobile/services/supabase';
import {
  ApplicationCommand,
  CommandOptionChoice,
  InteractionResponse,
  ActionRow,
} from '../stores/interactionStore';

// ---- Fetch Commands ----

export async function fetchGuildCommands(guildId: string): Promise<ApplicationCommand[]> {
  const { data, error } = await supabase
    .from('application_commands')
    .select('*')
    .or(`guild_id.is.null,guild_id.eq.${guildId}`)
    .order('name', { ascending: true });

  if (error) throw error;
  return (data ?? []).map(mapCommand);
}

export async function fetchGlobalCommands(): Promise<ApplicationCommand[]> {
  const { data, error } = await supabase
    .from('application_commands')
    .select('*')
    .is('guild_id', null)
    .order('name', { ascending: true });

  if (error) throw error;
  return (data ?? []).map(mapCommand);
}

// ---- Submit Interaction ----

export async function submitCommandInteraction(
  guildId: string,
  channelId: string,
  commandId: string,
  commandName: string,
  params: Record<string, any>
): Promise<InteractionResponse> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error('Not authenticated');

  // Build options array from params
  const options = Object.entries(params)
    .filter(([, v]) => v !== undefined && v !== '')
    .map(([name, value]) => ({ name, value, type: typeof value === 'number' ? 4 : 3 }));

  // Create interaction record
  const { data: interaction, error: intError } = await supabase
    .from('interactions')
    .insert({
      type: 2, // applicationCommand
      guild_id: guildId,
      channel_id: channelId,
      user_id: user.id,
      data: { id: commandId, name: commandName, type: 1, options },
    })
    .select()
    .single();

  if (intError) throw intError;

  // Execute the command handler (local simulation for dev/testing)
  const response = await executeCommandHandler(commandName, params, {
    guildId,
    channelId,
    userId: user.id,
    interactionId: interaction.id,
  });

  // Mark interaction as responded
  await supabase
    .from('interactions')
    .update({ responded: true })
    .eq('id', interaction.id);

  return response;
}

// ---- Component Interaction ----

export async function submitComponentInteraction(
  guildId: string,
  channelId: string,
  customId: string,
  componentType: number,
  values?: string[]
): Promise<InteractionResponse> {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error('Not authenticated');

  const { data: interaction, error } = await supabase
    .from('interactions')
    .insert({
      type: 3, // messageComponent
      guild_id: guildId,
      channel_id: channelId,
      user_id: user.id,
      data: { custom_id: customId, component_type: componentType, values },
    })
    .select()
    .single();

  if (error) throw error;

  // For dev: return a simple acknowledgement
  return {
    type: 6, // deferred update
    data: { content: `Component interaction: ${customId}` },
  };
}

// ---- Autocomplete ----

export async function fetchAutocompleteSuggestions(
  commandName: string,
  optionName: string,
  currentValue: string
): Promise<CommandOptionChoice[]> {
  // For dev/testing: generate mock suggestions
  const mockSuggestions: Record<string, CommandOptionChoice[]> = {
    query: [
      { name: `"${currentValue}" in messages`, value: currentValue },
      { name: `"${currentValue}" exact match`, value: `"${currentValue}"` },
    ],
    time: [
      { name: '10 minutes', value: '10m' },
      { name: '30 minutes', value: '30m' },
      { name: '1 hour', value: '1h' },
      { name: '1 day', value: '1d' },
      { name: '1 week', value: '1w' },
    ],
    duration: [
      { name: '10 minutes', value: '10m' },
      { name: '1 hour', value: '1h' },
      { name: '1 day', value: '1d' },
    ],
  };

  return mockSuggestions[optionName] ?? [
    { name: currentValue || 'Type to search...', value: currentValue || '' },
  ];
}

// ---- Local Command Handlers (Dev/Testing) ----

interface CommandContext {
  guildId: string;
  channelId: string;
  userId: string;
  interactionId: string;
}

async function executeCommandHandler(
  name: string,
  params: Record<string, any>,
  ctx: CommandContext
): Promise<InteractionResponse> {
  switch (name) {
    case 'poll':
      return handlePoll(params, ctx);
    case '8ball':
      return handleEightBall(params);
    case 'coinflip':
      return handleCoinflip();
    case 'serverinfo':
      return handleServerInfo(ctx);
    case 'userinfo':
      return handleUserInfo(params, ctx);
    case 'avatar':
      return handleAvatar(params, ctx);
    case 'remind':
      return handleRemind(params);
    case 'ban':
    case 'kick':
    case 'mute':
      return handleModeration(name, params);
    case 'clear':
      return handleClear(params);
    case 'search':
      return { type: 4, data: { content: `🔍 Searching for: "${params.query}"...`, flags: 64 } };
    case 'play':
      return { type: 4, data: { content: `🎵 Now playing: ${params.query}` } };
    default:
      return { type: 4, data: { content: `⚙️ Command /${name} executed.`, flags: 64 } };
  }
}

function handlePoll(params: Record<string, any>, _ctx: CommandContext): InteractionResponse {
  const options = [params.option1, params.option2, params.option3, params.option4].filter(Boolean);
  const buttons: ActionRow = {
    type: 1,
    components: options.map((opt, i) => ({
      type: 2 as const,
      style: 1 as const, // primary
      label: `${opt} (0)`,
      custom_id: `poll_vote_${i}`,
      emoji: { name: ['🅰️', '🅱️', '🅲', '🅳'][i] },
    })),
  };

  return {
    type: 4,
    data: {
      content: `📊 **${params.question}**\n\nVote by clicking a button below:`,
      components: [buttons],
    },
  };
}

function handleEightBall(params: Record<string, any>): InteractionResponse {
  const responses = [
    '🎱 It is certain.', '🎱 Without a doubt.', '🎱 Yes, definitely.',
    '🎱 Reply hazy, try again.', '🎱 Ask again later.', '🎱 Better not tell you now.',
    '🎱 Don\'t count on it.', '🎱 My reply is no.', '🎱 Outlook not so good.',
    '🎱 Very doubtful.', '🎱 Signs point to yes.', '🎱 Most likely.',
  ];
  const answer = responses[Math.floor(Math.random() * responses.length)];
  return { type: 4, data: { content: `**Q:** ${params.question}\n${answer}` } };
}

function handleCoinflip(): InteractionResponse {
  const result = Math.random() > 0.5 ? '🪙 **Heads!**' : '🪙 **Tails!**';
  return { type: 4, data: { content: result } };
}

async function handleServerInfo(ctx: CommandContext): Promise<InteractionResponse> {
  const { data: server } = await supabase
    .from('servers')
    .select('name, created_at')
    .eq('id', ctx.guildId)
    .single();

  const { count: memberCount } = await supabase
    .from('server_members')
    .select('*', { count: 'exact', head: true })
    .eq('server_id', ctx.guildId);

  return {
    type: 4,
    data: {
      content: [
        `📋 **Server Info**`,
        `**Name:** ${server?.name ?? 'Unknown'}`,
        `**Members:** ${memberCount ?? 0}`,
        `**Created:** ${server?.created_at ? new Date(server.created_at).toLocaleDateString() : 'Unknown'}`,
      ].join('\n'),
      flags: 64, // ephemeral
    },
  };
}

async function handleUserInfo(
  params: Record<string, any>,
  ctx: CommandContext
): Promise<InteractionResponse> {
  const userId = params.user || ctx.userId;
  const { data: profile } = await supabase
    .from('profiles')
    .select('display_name, username, created_at')
    .eq('id', userId)
    .single();

  return {
    type: 4,
    data: {
      content: [
        `👤 **User Info**`,
        `**Name:** ${profile?.display_name ?? profile?.username ?? 'Unknown'}`,
        `**Username:** ${profile?.username ?? 'Unknown'}`,
        `**Joined:** ${profile?.created_at ? new Date(profile.created_at).toLocaleDateString() : 'Unknown'}`,
      ].join('\n'),
      flags: 64,
    },
  };
}

async function handleAvatar(params: Record<string, any>, ctx: CommandContext): Promise<InteractionResponse> {
  const userId = params.user || ctx.userId;
  const { data: profile } = await supabase
    .from('profiles')
    .select('avatar_url, display_name, username')
    .eq('id', userId)
    .single();

  return {
    type: 4,
    data: {
      content: `🖼️ **${profile?.display_name ?? profile?.username ?? 'User'}'s Avatar**\n${profile?.avatar_url ?? 'No avatar set'}`,
      flags: 64,
    },
  };
}

function handleRemind(params: Record<string, any>): InteractionResponse {
  return {
    type: 4,
    data: {
      content: `⏰ Reminder set for **${params.time}**: ${params.message}`,
      flags: 64,
    },
  };
}

function handleModeration(action: string, params: Record<string, any>): InteractionResponse {
  const emoji = action === 'ban' ? '🔨' : action === 'kick' ? '👢' : '🔇';
  const past = action === 'ban' ? 'banned' : action === 'kick' ? 'kicked' : 'muted';
  return {
    type: 4,
    data: {
      content: `${emoji} User has been **${past}**.${params.reason ? ` Reason: ${params.reason}` : ''}`,
    },
  };
}

function handleClear(params: Record<string, any>): InteractionResponse {
  return {
    type: 4,
    data: {
      content: `🗑️ Cleared **${params.amount}** messages.`,
      flags: 64,
    },
  };
}

// ---- Helpers ----

function mapCommand(row: any): ApplicationCommand {
  return {
    id: row.id,
    application_id: row.application_id,
    guild_id: row.guild_id,
    name: row.name,
    description: row.description,
    options: Array.isArray(row.options) ? row.options : JSON.parse(row.options || '[]'),
    default_member_perms: row.default_member_perms,
    dm_permission: row.dm_permission ?? true,
    type: row.type ?? 1,
    nsfw: row.nsfw ?? false,
    version: row.version ?? 1,
    created_at: row.created_at,
  };
}

// Command icon mapping
export const COMMAND_ICONS: Record<string, string> = {
  poll: '📊',
  ban: '🔨',
  kick: '👢',
  mute: '🔇',
  play: '🎵',
  search: '🔍',
  clear: '🗑️',
  serverinfo: '📋',
  userinfo: '👤',
  remind: '⏰',
  '8ball': '🎱',
  coinflip: '🪙',
  avatar: '🖼️',
};
