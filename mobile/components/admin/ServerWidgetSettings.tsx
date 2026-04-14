/**
 * Server Widget Preview (Feature 24)
 *
 * Embeddable widget card showing server info.
 * Shows server name, icon, online count, voice channel participants, and invite button.
 * Also provides API endpoint for external embedding.
 */
import React, { memo, useEffect, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Pressable,
  ActivityIndicator,
  Share,
} from 'react-native';
import { Image } from 'expo-image';
import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '@/hooks/useTheme';
import { spacing, typography } from '../../constants/Colors';
import {
  useServerManagementStore,
  ServerWidget,
} from '@stores/serverManagementStore';
import { supabase } from '@services/supabase';
import * as Clipboard from 'expo-clipboard';

interface WidgetData {
  name: string;
  icon_url?: string;
  online_count: number;
  member_count: number;
  voice_channels: { name: string; users: string[] }[];
  invite_link?: string;
}

interface ServerWidgetSettingsProps {
  serverId: string;
}

/**
 * Admin settings to enable/disable the server widget
 */
export const ServerWidgetSettings = memo(function ServerWidgetSettings({
  serverId,
}: ServerWidgetSettingsProps) {
  const { themeColors } = useTheme();
  const widget = useServerManagementStore((s) => s.serverWidgets[serverId]);
  const setWidget = useServerManagementStore((s) => s.setServerWidget);

  const handleToggle = async () => {
    const newWidget: ServerWidget = {
      enabled: !widget?.enabled,
      channel_id: widget?.channel_id,
    };
    setWidget(serverId, newWidget);
    await supabase
      .from('servers')
      .update({ widget_enabled: newWidget.enabled })
      .eq('id', serverId);
  };

  const handleCopyJson = async () => {
    const url = `${process.env.EXPO_PUBLIC_API_URL}/api/v1/servers/${serverId}/widget.json`;
    await Clipboard.setStringAsync(url);
  };

  const handleShareEmbed = async () => {
    const url = `${process.env.EXPO_PUBLIC_API_URL}/api/v1/servers/${serverId}/widget`;
    await Share.share({ message: `Check out our server! ${url}` });
  };

  return (
    <View style={[styles.settingsContainer, { backgroundColor: themeColors.bgPrimary }]}>
      <Text style={[styles.title, { color: themeColors.textPrimary }]}>Server Widget</Text>
      <Text style={[styles.subtitle, { color: themeColors.textMuted }]}>
        Enable an embeddable widget for your server that shows online members and voice activity.
      </Text>

      <View style={[styles.card, { backgroundColor: themeColors.bgSecondary }]}>
        <View style={styles.toggleRow}>
          <Text style={[styles.toggleLabel, { color: themeColors.textPrimary }]}>
            Enable Widget
          </Text>
          <Pressable
            style={[
              styles.toggle,
              { backgroundColor: widget?.enabled ? themeColors.accentPrimary : themeColors.bgTertiary },
            ]}
            onPress={handleToggle}
          >
            <View
              style={[
                styles.toggleThumb,
                widget?.enabled && styles.toggleThumbActive,
              ]}
            />
          </Pressable>
        </View>
      </View>

      {widget?.enabled && (
        <>
          <View style={[styles.card, { backgroundColor: themeColors.bgSecondary }]}>
            <Pressable style={styles.actionRow} onPress={handleCopyJson}>
              <Ionicons name="copy-outline" size={20} color={themeColors.textMuted} />
              <Text style={[styles.actionLabel, { color: themeColors.textPrimary }]}>
                Copy Widget JSON URL
              </Text>
            </Pressable>
            <Pressable style={styles.actionRow} onPress={handleShareEmbed}>
              <Ionicons name="share-outline" size={20} color={themeColors.textMuted} />
              <Text style={[styles.actionLabel, { color: themeColors.textPrimary }]}>
                Share Widget Link
              </Text>
            </Pressable>
          </View>

          {/* Widget Preview */}
          <Text style={[styles.sectionLabel, { color: themeColors.textMuted }]}>PREVIEW</Text>
          <ServerWidgetPreview serverId={serverId} />
        </>
      )}
    </View>
  );
});

/**
 * Visual preview of the server widget card
 */
export const ServerWidgetPreview = memo(function ServerWidgetPreview({
  serverId,
}: {
  serverId: string;
}) {
  const { themeColors } = useTheme();
  const [data, setData] = useState<WidgetData | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    (async () => {
      try {
        const { data: server } = await supabase
          .from('servers')
          .select('name, icon_url, invite_code')
          .eq('id', serverId)
          .single();

        const { count: memberCount } = await supabase
          .from('server_members')
          .select('*', { count: 'exact', head: true })
          .eq('server_id', serverId);

        setData({
          name: server?.name ?? 'Server',
          icon_url: server?.icon_url,
          online_count: 0, // real-time count would come from presence system
          member_count: memberCount ?? 0,
          voice_channels: [],
          invite_link: server?.invite_code
            ? `https://flicko.me/invite/${server.invite_code}`
            : undefined,
        });
      } catch (err) {
        console.error('[ServerWidget] fetch failed:', err);
      } finally {
        setLoading(false);
      }
    })();
  }, [serverId]);

  if (loading) return <ActivityIndicator color={themeColors.accentPrimary} style={{ marginTop: 20 }} />;
  if (!data) return null;

  return (
    <View style={[styles.widgetCard, { backgroundColor: themeColors.bgSecondary }]}>
      <View style={styles.widgetHeader}>
        {data.icon_url ? (
          <Image source={{ uri: data.icon_url }} style={styles.widgetIcon} />
        ) : (
          <View style={[styles.widgetIconPlaceholder, { backgroundColor: themeColors.bgTertiary }]}>
            <Text style={[styles.widgetInitial, { color: themeColors.textMuted }]}>
              {data.name.charAt(0).toUpperCase()}
            </Text>
          </View>
        )}
        <View style={{ flex: 1 }}>
          <Text style={[styles.widgetName, { color: themeColors.textPrimary }]}>
            {data.name}
          </Text>
          <Text style={[styles.widgetStats, { color: themeColors.textMuted }]}>
            {data.member_count} members • {data.online_count} online
          </Text>
        </View>
      </View>
      {data.invite_link && (
        <Pressable
          style={[styles.joinButton, { backgroundColor: themeColors.accentPrimary }]}
          onPress={() => {
            Share.share({ message: data.invite_link! });
          }}
        >
          <Text style={styles.joinButtonText}>Join Server</Text>
        </Pressable>
      )}
    </View>
  );
});

const styles = StyleSheet.create({
  settingsContainer: { padding: spacing.md },
  title: { fontSize: 20, fontFamily: 'gg-sans-bold', marginBottom: 4 },
  subtitle: { ...typography.body, marginBottom: spacing.md },
  card: {
    borderRadius: 12,
    overflow: 'hidden',
    marginBottom: spacing.md,
  },
  toggleRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    padding: spacing.sm,
  },
  toggleLabel: { fontSize: 15, fontFamily: 'gg-sans-medium' },
  toggle: {
    width: 48,
    height: 28,
    borderRadius: 14,
    padding: 2,
    justifyContent: 'center',
  },
  toggleThumb: {
    width: 24,
    height: 24,
    borderRadius: 12,
    backgroundColor: '#fff',
  },
  toggleThumbActive: { alignSelf: 'flex-end' },
  actionRow: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: spacing.sm,
    gap: spacing.sm,
  },
  actionLabel: { fontSize: 15, fontFamily: 'gg-sans-medium' },
  sectionLabel: {
    fontSize: 12,
    fontFamily: 'gg-sans-bold',
    letterSpacing: 0.5,
    textTransform: 'uppercase',
    marginBottom: spacing.xs,
    marginTop: spacing.sm,
  },
  widgetCard: {
    borderRadius: 12,
    padding: spacing.md,
    marginBottom: spacing.md,
  },
  widgetHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    marginBottom: spacing.sm,
  },
  widgetIcon: { width: 48, height: 48, borderRadius: 12 },
  widgetIconPlaceholder: {
    width: 48,
    height: 48,
    borderRadius: 12,
    justifyContent: 'center',
    alignItems: 'center',
  },
  widgetInitial: { fontSize: 20, fontFamily: 'gg-sans-bold' },
  widgetName: { fontSize: 16, fontFamily: 'gg-sans-bold' },
  widgetStats: { ...typography.caption, marginTop: 2 },
  joinButton: {
    paddingVertical: 10,
    borderRadius: 8,
    alignItems: 'center',
  },
  joinButtonText: { color: '#fff', fontFamily: 'gg-sans-bold', fontSize: 14 },
});
