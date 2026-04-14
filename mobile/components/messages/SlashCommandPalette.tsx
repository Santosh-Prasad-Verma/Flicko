// ============================================
// Slash Command Palette — Full UI
// ============================================
import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  View,
  Text,
  TextInput,
  FlatList,
  TouchableOpacity,
  StyleSheet,
  Keyboard,
  ActivityIndicator,
  KeyboardAvoidingView,
  Platform,
} from 'react-native';
import Animated, {
  FadeIn,
  FadeOut,
  SlideInDown,
  SlideOutDown,
  useAnimatedStyle,
  useSharedValue,
  withSpring,
} from 'react-native-reanimated';
import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '@/hooks/useTheme';
import { spacing, borderRadius, typography } from '../../constants/Colors';
import { SPRING_SNAPPY } from '../../constants/Animations';
import {
  useInteractionStore,
  ApplicationCommand,
  CommandOption,
  CommandOptionType,
} from '@stores/interactionStore';
import {
  fetchGuildCommands,
  submitCommandInteraction,
  fetchAutocompleteSuggestions,
  COMMAND_ICONS,
} from '@services/commandService';
import * as botService from '@shared/services/botService';

interface SlashCommandPaletteProps {
  serverId: string;
  channelId: string;
  onInteractionResponse?: (response: any) => void;
}

const OPTION_TYPE_LABELS: Record<number, string> = {
  3: 'Text',
  4: 'Number',
  5: 'True/False',
  6: 'User',
  7: 'Channel',
  8: 'Role',
  9: 'Mentionable',
  10: 'Number',
  11: 'Attachment',
};

export function SlashCommandPalette({ serverId, channelId, onInteractionResponse }: SlashCommandPaletteProps) {
  const { themeColors } = useTheme();
  const {
    commands,
    filteredCommands,
    selectedCommand,
    commandParams,
    isPaletteOpen,
    searchQuery,
    isLoading,
    autocompleteSuggestions,
    activeAutocompleteName,
    setCommands,
    openPalette: _open,
    closePalette,
    setSearchQuery,
    selectCommand,
    setParam,
    clearParams,
    setAutocompleteSuggestions,
    clearAutocomplete,
    setLoading,
  } = useInteractionStore();

  const searchInputRef = useRef<TextInput>(null);
  const [activeParamIndex, setActiveParamIndex] = useState(0);

  // Load commands on mount
  useEffect(() => {
    if (isPaletteOpen && commands.length === 0) {
      loadCommands();
    }
  }, [isPaletteOpen]);

  const loadCommands = useCallback(async () => {
    setLoading(true);
    try {
      // Load from both sources: Supabase commands + Go backend bot commands
      const [supabaseCmds, botDefs] = await Promise.all([
        fetchGuildCommands(serverId).catch(() => [] as ApplicationCommand[]),
        botService.fetchServerCommands(serverId).catch(() => []),
      ]);

      // Convert bot command definitions to ApplicationCommand format
      const botCmds: ApplicationCommand[] = botDefs.map((def: any) => ({
        id: `bot-${def.name}`,
        application_id: 'bot-system',
        guild_id: serverId,
        name: def.name,
        description: def.description,
        options: (def.options ?? []).map((o: any) => ({
          type: o.type,
          name: o.name,
          description: o.description,
          required: o.required ?? false,
          choices: o.choices,
          options: o.options,
        })),
        default_member_perms: null,
        dm_permission: false,
        type: 1 as const,
        nsfw: false,
        version: 1,
        created_at: new Date().toISOString(),
      }));

      // Merge, dedup by name (bot commands take priority)
      const botNames = new Set(botCmds.map((c) => c.name));
      const merged = [
        ...botCmds,
        ...supabaseCmds.filter((c) => !botNames.has(c.name)),
      ];

      setCommands(merged);
    } catch (err) {
      console.warn('Failed to load commands:', err);
    } finally {
      setLoading(false);
    }
  }, [serverId]);

  // Focus search input when palette opens
  useEffect(() => {
    if (isPaletteOpen) {
      setTimeout(() => searchInputRef.current?.focus(), 100);
    }
  }, [isPaletteOpen]);

  // Submit command
  const handleSubmit = useCallback(async () => {
    if (!selectedCommand) return;
    const requiredParams = (selectedCommand.options ?? []).filter((o: CommandOption) => o.required);
    const missingParams = requiredParams.filter((p: CommandOption) => !commandParams[p.name]);
    if (missingParams.length > 0) {
      // Focus first missing param
      const idx = selectedCommand.options.findIndex((o: CommandOption) => o.name === missingParams[0].name);
      setActiveParamIndex(idx);
      return;
    }

    setLoading(true);
    try {
      let response: any;

      if (selectedCommand.application_id === 'bot-system') {
        // Route through Go backend command router
        const result = await botService.invokeCommand(
          selectedCommand.name,
          serverId,
          channelId,
          commandParams
        );
        response = {
          type: 4, // channelMessageWithSource
          data: {
            content: result.response?.content ?? '',
            embeds: result.response?.embed ? [result.response.embed] : [],
            flags: result.response?.ephemeral ? 64 : 0,
            components: result.response?.components ?? [],
          },
        };
      } else {
        // Use existing Supabase-based command execution
        response = await submitCommandInteraction(
          serverId,
          channelId,
          selectedCommand.id,
          selectedCommand.name,
          commandParams
        );
      }

      onInteractionResponse?.(response);
      closePalette();
    } catch (err) {
      console.warn('Failed to submit command:', err);
    } finally {
      setLoading(false);
    }
  }, [selectedCommand, commandParams, serverId, channelId]);

  if (!isPaletteOpen) return null;

  return (
    <Animated.View
      entering={SlideInDown.duration(250).springify()}
      exiting={SlideOutDown.duration(200)}
      style={[styles.container, { backgroundColor: themeColors.bgSecondary }]}
    >
      {/* Header */}
      <View style={[styles.header, { borderBottomColor: themeColors.border }]}>
        <Text style={[styles.headerTitle, { color: themeColors.textPrimary }]}>
          {selectedCommand ? `/${selectedCommand.name}` : 'Commands'}
        </Text>
        <TouchableOpacity onPress={closePalette} hitSlop={{ top: 12, bottom: 12, left: 12, right: 12 }}>
          <Ionicons name="close" size={22} color={themeColors.textSecondary} />
        </TouchableOpacity>
      </View>

      {selectedCommand ? (
        <ParameterForm
          command={selectedCommand}
          params={commandParams}
          activeParamIndex={activeParamIndex}
          setActiveParamIndex={setActiveParamIndex}
          onParamChange={setParam}
          onSubmit={handleSubmit}
          onBack={() => { selectCommand(null); clearParams(); }}
          isLoading={isLoading}
          autocompleteSuggestions={autocompleteSuggestions}
          activeAutocompleteName={activeAutocompleteName}
          onAutocomplete={async (name, value) => {
            const suggestions = await fetchAutocompleteSuggestions(selectedCommand.name, name, value);
            setAutocompleteSuggestions(name, suggestions);
          }}
          onClearAutocomplete={clearAutocomplete}
          themeColors={themeColors}
        />
      ) : (
        <>
          {/* Search */}
          <View style={[styles.searchRow, { backgroundColor: themeColors.bgPrimary }]}>
            <Ionicons name="search" size={18} color={themeColors.textSecondary} />
            <TextInput
              ref={searchInputRef}
              style={[styles.searchInput, { color: themeColors.textPrimary }]}
              placeholder="Search commands..."
              placeholderTextColor={themeColors.textSecondary}
              value={searchQuery}
              onChangeText={(text) => setSearchQuery(text)}
              autoCorrect={false}
              autoCapitalize="none"
            />
            {searchQuery.length > 0 && (
              <TouchableOpacity onPress={() => setSearchQuery('')}>
                <Ionicons name="close-circle" size={18} color={themeColors.textSecondary} />
              </TouchableOpacity>
            )}
          </View>

          {/* Command List */}
          {isLoading ? (
            <View style={styles.loadingContainer}>
              <ActivityIndicator color={themeColors.accentPrimary} />
            </View>
          ) : (
            <FlatList
              data={filteredCommands}
              keyExtractor={(item) => item.id}
              renderItem={({ item }) => (
                <CommandRow command={item} onSelect={selectCommand} themeColors={themeColors} />
              )}
              style={styles.commandList}
              keyboardShouldPersistTaps="handled"
              ListEmptyComponent={
                <Text style={[styles.emptyText, { color: themeColors.textSecondary }]}>
                  No commands found
                </Text>
              }
            />
          )}
        </>
      )}
    </Animated.View>
  );
}

// ---- Command Row ----

function CommandRow({
  command,
  onSelect,
  themeColors,
}: {
  command: ApplicationCommand;
  onSelect: (cmd: ApplicationCommand) => void;
  themeColors: any;
}) {
  const icon = COMMAND_ICONS[command.name] ?? '⚡';
  const paramHint = (command.options ?? [])
    .filter((o) => o.type >= 3) // skip subcommands
    .map((o) => (o.required ? `<${o.name}>` : `[${o.name}]`))
    .join(' ');

  return (
    <TouchableOpacity
      style={[styles.commandRow, { borderBottomColor: themeColors.border }]}
      onPress={() => onSelect(command)}
      activeOpacity={0.7}
    >
      <Text style={styles.commandIcon}>{icon}</Text>
      <View style={styles.commandInfo}>
        <View style={styles.commandNameRow}>
          <Text style={[styles.commandName, { color: themeColors.text }]}>/{command.name}</Text>
          {paramHint ? (
            <Text style={[styles.commandParams, { color: themeColors.textSecondary }]}> {paramHint}</Text>
          ) : null}
        </View>
        <Text style={[styles.commandDesc, { color: themeColors.textSecondary }]} numberOfLines={1}>
          {command.description}
        </Text>
      </View>
      <Ionicons name="chevron-forward" size={16} color={themeColors.textSecondary} />
    </TouchableOpacity>
  );
}

// ---- Parameter Form ----

function ParameterForm({
  command,
  params,
  activeParamIndex,
  setActiveParamIndex,
  onParamChange,
  onSubmit,
  onBack,
  isLoading,
  autocompleteSuggestions,
  activeAutocompleteName,
  onAutocomplete,
  onClearAutocomplete,
  themeColors,
}: {
  command: ApplicationCommand;
  params: Record<string, any>;
  activeParamIndex: number;
  setActiveParamIndex: (i: number) => void;
  onParamChange: (name: string, value: any) => void;
  onSubmit: () => void;
  onBack: () => void;
  isLoading: boolean;
  autocompleteSuggestions: any[];
  activeAutocompleteName: string | null;
  onAutocomplete: (name: string, value: string) => void;
  onClearAutocomplete: () => void;
  themeColors: any;
}) {
  const options = (command.options ?? []).filter((o) => o.type >= 3);
  const allRequiredFilled = options
    .filter((o) => o.required)
    .every((o) => params[o.name] !== undefined && params[o.name] !== '');

  return (
    <View style={styles.paramForm}>
      {/* Back to command list */}
      <TouchableOpacity style={styles.backButton} onPress={onBack}>
        <Ionicons name="arrow-back" size={18} color={themeColors.primary} />
        <Text style={[styles.backText, { color: themeColors.primary }]}>Back</Text>
      </TouchableOpacity>

      {/* Parameters */}
      <FlatList
        data={options}
        keyExtractor={(item) => item.name}
        renderItem={({ item, index }) => (
          <ParameterInput
            option={item}
            value={params[item.name]}
            isActive={activeParamIndex === index}
            onFocus={() => setActiveParamIndex(index)}
            onChange={(value) => {
              onParamChange(item.name, value);
              if (item.autocomplete) {
                onAutocomplete(item.name, value);
              }
            }}
            themeColors={themeColors}
            suggestions={activeAutocompleteName === item.name ? autocompleteSuggestions : []}
            onSelectSuggestion={(value) => {
              onParamChange(item.name, value);
              onClearAutocomplete();
            }}
          />
        )}
        style={styles.paramList}
        keyboardShouldPersistTaps="handled"
      />

      {/* Submit */}
      <TouchableOpacity
        style={[
          styles.submitButton,
          { backgroundColor: allRequiredFilled ? themeColors.primary : themeColors.border },
        ]}
        onPress={onSubmit}
        disabled={!allRequiredFilled || isLoading}
      >
        {isLoading ? (
          <ActivityIndicator color="#fff" size="small" />
        ) : (
          <Text style={styles.submitText}>Execute Command</Text>
        )}
      </TouchableOpacity>
    </View>
  );
}

// ---- Parameter Input ----

function ParameterInput({
  option,
  value,
  isActive,
  onFocus,
  onChange,
  themeColors,
  suggestions,
  onSelectSuggestion,
}: {
  option: CommandOption;
  value: any;
  isActive: boolean;
  onFocus: () => void;
  onChange: (value: any) => void;
  themeColors: any;
  suggestions: any[];
  onSelectSuggestion: (value: any) => void;
}) {
  // Boolean toggle
  if (option.type === 5) {
    return (
      <TouchableOpacity
        style={[styles.paramRow, isActive && { borderColor: themeColors.primary }]}
        onPress={() => onChange(!value)}
      >
        <View style={styles.paramHeader}>
          <Text style={[styles.paramName, { color: themeColors.text }]}>
            {option.name}
            {option.required && <Text style={{ color: themeColors.danger }}> *</Text>}
          </Text>
          <Text style={[styles.paramType, { color: themeColors.textSecondary }]}>
            {OPTION_TYPE_LABELS[option.type]}
          </Text>
        </View>
        <View style={[styles.boolToggle, value && { backgroundColor: themeColors.primary }]}>
          <Text style={{ color: value ? '#fff' : themeColors.textSecondary }}>
            {value ? 'True' : 'False'}
          </Text>
        </View>
      </TouchableOpacity>
    );
  }

  // Choices dropdown
  if (option.choices && option.choices.length > 0) {
    return (
      <View style={[styles.paramRow, isActive && { borderColor: themeColors.primary }]}>
        <View style={styles.paramHeader}>
          <Text style={[styles.paramName, { color: themeColors.text }]}>
            {option.name}
            {option.required && <Text style={{ color: themeColors.danger }}> *</Text>}
          </Text>
        </View>
        <View style={styles.choicesWrap}>
          {option.choices.map((choice) => (
            <TouchableOpacity
              key={String(choice.value)}
              style={[
                styles.choiceChip,
                {
                  backgroundColor:
                    value === choice.value ? themeColors.primary : themeColors.background,
                  borderColor: value === choice.value ? themeColors.primary : themeColors.border,
                },
              ]}
              onPress={() => onChange(choice.value)}
            >
              <Text
                style={{
                  color: value === choice.value ? '#fff' : themeColors.text,
                  fontSize: 13,
                }}
              >
                {choice.name}
              </Text>
            </TouchableOpacity>
          ))}
        </View>
      </View>
    );
  }

  // Text / Number input
  return (
    <View style={[styles.paramRow, isActive && { borderColor: themeColors.primary }]}>
      <View style={styles.paramHeader}>
        <Text style={[styles.paramName, { color: themeColors.text }]}>
          {option.name}
          {option.required && <Text style={{ color: themeColors.danger }}> *</Text>}
        </Text>
        <Text style={[styles.paramType, { color: themeColors.textSecondary }]}>
          {OPTION_TYPE_LABELS[option.type] ?? 'Text'}
        </Text>
      </View>
      <Text style={[styles.paramDesc, { color: themeColors.textSecondary }]} numberOfLines={1}>
        {option.description}
      </Text>
      <TextInput
        style={[styles.paramInput, { color: themeColors.text, borderColor: themeColors.border }]}
        value={value !== undefined ? String(value) : ''}
        onChangeText={(text) => {
          onChange(option.type === 4 || option.type === 10 ? Number(text) || text : text);
        }}
        onFocus={onFocus}
        placeholder={option.description}
        placeholderTextColor={themeColors.textSecondary}
        keyboardType={option.type === 4 || option.type === 10 ? 'numeric' : 'default'}
        autoCorrect={false}
      />
      {/* Autocomplete suggestions */}
      {suggestions.length > 0 && (
        <View style={[styles.suggestionsBox, { backgroundColor: themeColors.background, borderColor: themeColors.border }]}>
          {suggestions.map((s, i) => (
            <TouchableOpacity
              key={i}
              style={[styles.suggestionRow, { borderBottomColor: themeColors.border }]}
              onPress={() => onSelectSuggestion(s.value)}
            >
              <Text style={[styles.suggestionText, { color: themeColors.text }]}>{s.name}</Text>
            </TouchableOpacity>
          ))}
        </View>
      )}
    </View>
  );
}

// ---- Styles ----

const styles = StyleSheet.create({
  container: {
    maxHeight: 400,
    borderTopLeftRadius: borderRadius.lg,
    borderTopRightRadius: borderRadius.lg,
    overflow: 'hidden',
    elevation: 8,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: -2 },
    shadowOpacity: 0.25,
    shadowRadius: 8,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    borderBottomWidth: 1,
  },
  headerTitle: {
    fontSize: 16,
    fontFamily: 'gg-sans-semibold',
  },
  searchRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.xs,
    margin: spacing.sm,
    borderRadius: borderRadius.md,
    gap: spacing.xs,
  },
  searchInput: {
    flex: 1,
    fontSize: 14,
    paddingVertical: spacing.xs,
  },
  commandList: {
    maxHeight: 300,
  },
  commandRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    borderBottomWidth: StyleSheet.hairlineWidth,
    gap: spacing.sm,
  },
  commandIcon: {
    fontSize: 20,
    width: 28,
    textAlign: 'center',
  },
  commandInfo: {
    flex: 1,
  },
  commandNameRow: {
    flexDirection: 'row',
    alignItems: 'baseline',
  },
  commandName: {
    fontSize: 14,
    fontFamily: 'gg-sans-semibold',
  },
  commandParams: {
    fontSize: 12,
    fontStyle: 'italic',
  },
  commandDesc: {
    fontSize: 12,
    marginTop: 2,
  },
  loadingContainer: {
    padding: spacing.xl,
    alignItems: 'center',
  },
  emptyText: {
    textAlign: 'center',
    padding: spacing.xl,
    fontSize: 14,
  },
  paramForm: {
    maxHeight: 340,
  },
  backButton: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.xs,
    gap: 4,
  },
  backText: {
    fontSize: 14,
    fontFamily: 'gg-sans-medium',
  },
  paramList: {
    maxHeight: 240,
  },
  paramRow: {
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    borderLeftWidth: 3,
    borderColor: 'transparent',
    marginBottom: spacing.xs,
  },
  paramHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  paramName: {
    fontSize: 14,
    fontFamily: 'gg-sans-semibold',
  },
  paramType: {
    fontSize: 12,
  },
  paramDesc: {
    fontSize: 12,
    marginTop: 2,
    marginBottom: spacing.xs,
  },
  paramInput: {
    borderWidth: 1,
    borderRadius: borderRadius.sm,
    paddingHorizontal: spacing.sm,
    paddingVertical: spacing.xs,
    fontSize: 14,
  },
  boolToggle: {
    alignSelf: 'flex-start',
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.xs,
    borderRadius: borderRadius.full,
    marginTop: spacing.xs,
  },
  choicesWrap: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: spacing.xs,
    marginTop: spacing.xs,
  },
  choiceChip: {
    paddingHorizontal: spacing.sm,
    paddingVertical: spacing.xs,
    borderRadius: borderRadius.full,
    borderWidth: 1,
  },
  submitButton: {
    marginHorizontal: spacing.md,
    marginVertical: spacing.sm,
    paddingVertical: spacing.sm,
    borderRadius: borderRadius.md,
    alignItems: 'center',
  },
  submitText: {
    color: '#fff',
    fontSize: 14,
    fontFamily: 'gg-sans-semibold',
  },
  suggestionsBox: {
    marginTop: spacing.xs,
    borderWidth: 1,
    borderRadius: borderRadius.sm,
    overflow: 'hidden',
  },
  suggestionRow: {
    paddingHorizontal: spacing.sm,
    paddingVertical: spacing.xs,
    borderBottomWidth: StyleSheet.hairlineWidth,
  },
  suggestionText: {
    fontSize: 14,
  },
});
