// ============================================
// Slash Command & Interaction Store (Zustand)
// ============================================
import { create } from 'zustand';

// ---- Types ----

export type CommandType = 1 | 2 | 3; // chatInput, user, message
export type CommandOptionType = 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11;
export type InteractionType = 1 | 2 | 3 | 4 | 5; // ping, appCommand, component, autocomplete, modalSubmit
export type ButtonStyle = 1 | 2 | 3 | 4 | 5; // primary, secondary, success, danger, link

export interface CommandOptionChoice {
  name: string;
  value: string | number;
}

export interface CommandOption {
  type: CommandOptionType;
  name: string;
  description: string;
  required?: boolean;
  choices?: CommandOptionChoice[];
  options?: CommandOption[]; // for subcommands
  channel_types?: number[];
  min_value?: number;
  max_value?: number;
  min_length?: number;
  max_length?: number;
  autocomplete?: boolean;
}

export interface ApplicationCommand {
  id: string;
  application_id: string;
  guild_id?: string | null;
  name: string;
  description: string;
  options: CommandOption[];
  default_member_perms?: string | null;
  dm_permission: boolean;
  type: CommandType;
  nsfw: boolean;
  version: number;
  created_at: string;
}

export interface ButtonComponent {
  type: 2;
  style: ButtonStyle;
  label?: string;
  emoji?: { id?: string; name: string; animated?: boolean };
  custom_id?: string;
  url?: string;
  disabled?: boolean;
}

export interface SelectOption {
  label: string;
  value: string;
  description?: string;
  emoji?: { id?: string; name: string; animated?: boolean };
  default?: boolean;
}

export interface SelectMenuComponent {
  type: 3 | 5 | 6 | 7 | 8;
  custom_id: string;
  options?: SelectOption[];
  placeholder?: string;
  min_values?: number;
  max_values?: number;
  disabled?: boolean;
}

export type MessageComponent = ButtonComponent | SelectMenuComponent;

export interface ActionRow {
  type: 1;
  components: MessageComponent[];
}

export interface InteractionData {
  id?: string;
  name?: string;
  type?: CommandType;
  options?: { name: string; type: CommandOptionType; value: any }[];
  custom_id?: string;
  component_type?: number;
  values?: string[];
}

export interface Interaction {
  id: string;
  application_id: string;
  type: InteractionType;
  guild_id?: string;
  channel_id?: string;
  user_id: string;
  token: string;
  data?: InteractionData;
  version: number;
  created_at: string;
  responded: boolean;
}

export interface InteractionResponse {
  type: number; // 4=message, 5=deferred, 6=deferred_update, 7=update_message
  data?: {
    content?: string;
    embeds?: any[];
    components?: ActionRow[];
    flags?: number; // 64 = ephemeral
  };
}

// ---- Store ----

interface InteractionStore {
  // Commands
  commands: ApplicationCommand[];
  filteredCommands: ApplicationCommand[];
  selectedCommand: ApplicationCommand | null;
  commandParams: Record<string, any>;
  isPaletteOpen: boolean;
  searchQuery: string;
  isLoading: boolean;

  // Autocomplete
  autocompleteSuggestions: CommandOptionChoice[];
  activeAutocompleteName: string | null;

  // Component interactions
  pendingInteraction: Interaction | null;

  // Actions
  setCommands: (commands: ApplicationCommand[]) => void;
  openPalette: () => void;
  closePalette: () => void;
  setSearchQuery: (query: string) => void;
  selectCommand: (command: ApplicationCommand | null) => void;
  setParam: (name: string, value: any) => void;
  clearParams: () => void;
  setAutocompleteSuggestions: (name: string, suggestions: CommandOptionChoice[]) => void;
  clearAutocomplete: () => void;
  setPendingInteraction: (interaction: Interaction | null) => void;
  setLoading: (loading: boolean) => void;
  reset: () => void;
}

export const useInteractionStore = create<InteractionStore>((set, get) => ({
  commands: [],
  filteredCommands: [],
  selectedCommand: null,
  commandParams: {},
  isPaletteOpen: false,
  searchQuery: '',
  isLoading: false,
  autocompleteSuggestions: [],
  activeAutocompleteName: null,
  pendingInteraction: null,

  setCommands: (commands) => set({ commands, filteredCommands: commands }),

  openPalette: () => set({ isPaletteOpen: true, searchQuery: '', selectedCommand: null, commandParams: {} }),

  closePalette: () => set({
    isPaletteOpen: false,
    searchQuery: '',
    selectedCommand: null,
    commandParams: {},
    autocompleteSuggestions: [],
    activeAutocompleteName: null,
  }),

  setSearchQuery: (query) => {
    const { commands } = get();
    const q = query.toLowerCase().replace(/^\//, '');
    const filtered = q
      ? commands.filter((c) => c.name.includes(q) || c.description.toLowerCase().includes(q))
      : commands;
    set({ searchQuery: query, filteredCommands: filtered });
  },

  selectCommand: (command) => set({ selectedCommand: command, commandParams: {}, searchQuery: '' }),

  setParam: (name, value) =>
    set((state) => ({ commandParams: { ...state.commandParams, [name]: value } })),

  clearParams: () => set({ commandParams: {} }),

  setAutocompleteSuggestions: (name, suggestions) =>
    set({ activeAutocompleteName: name, autocompleteSuggestions: suggestions }),

  clearAutocomplete: () => set({ autocompleteSuggestions: [], activeAutocompleteName: null }),

  setPendingInteraction: (interaction) => set({ pendingInteraction: interaction }),

  setLoading: (loading) => set({ isLoading: loading }),

  reset: () =>
    set({
      commands: [],
      filteredCommands: [],
      selectedCommand: null,
      commandParams: {},
      isPaletteOpen: false,
      searchQuery: '',
      isLoading: false,
      autocompleteSuggestions: [],
      activeAutocompleteName: null,
      pendingInteraction: null,
    }),
}));
