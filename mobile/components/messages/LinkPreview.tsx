/**
 * LinkPreview Component
 *
 * Renders rich embeds and link previews within messages.
 * Extracts metadata from URLs and displays title, description, image.
 * Requirements: Feature 13 (Embeds & Link Previews)
 */
import React, { memo, useMemo } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Image,
  Pressable,
  Linking,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { spacing, borderRadius, typography, type ThemeColors } from '../../constants/Colors';
import { useTheme } from '../../hooks/useTheme';

interface Embed {
  title?: string;
  description?: string;
  url?: string;
  color?: string;
  image?: string;
  thumbnail?: string;
  footer?: string;
  timestamp?: string;
  author?: { name: string; url?: string; icon_url?: string };
  fields?: { name: string; value: string; inline?: boolean }[];
}

interface LinkPreviewProps {
  embeds?: Embed[];
  /** Raw message content — extracts URLs if no embeds provided */
  content?: string;
}

const URL_REGEX = /https?:\/\/[^\s<]+/gi;

export const LinkPreview = memo(function LinkPreview({ embeds, content }: LinkPreviewProps) {
  const { themeColors } = useTheme();

  // Extract URLs from content if no embeds
  const urls = useMemo(() => {
    if (embeds && embeds.length > 0) return [];
    if (!content) return [];
    return content.match(URL_REGEX) ?? [];
  }, [content, embeds]);

  if ((!embeds || embeds.length === 0) && urls.length === 0) return null;

  return (
    <View style={styles.container}>
      {/* Render rich embeds */}
      {(embeds ?? []).map((embed, i) => (
        <EmbedCard key={i} embed={embed} themeColors={themeColors} />
      ))}

      {/* Render URL previews (simplified — in production, would fetch OG metadata) */}
      {urls.map((url, i) => (
        <URLCard key={i} url={url} themeColors={themeColors} />
      ))}
    </View>
  );
});

function EmbedCard({ embed, themeColors }: { embed: Embed; themeColors: ThemeColors }) {
  const accentColor = embed.color || themeColors.accentPrimary;

  return (
    <Pressable
      style={[styles.embedCard, { backgroundColor: themeColors.bgTertiary, borderLeftColor: accentColor }]}
      onPress={() => embed.url && Linking.openURL(embed.url)}
    >
      {/* Author */}
      {embed.author && (
        <View style={styles.embedAuthor}>
          {embed.author.icon_url && (
            <Image source={{ uri: embed.author.icon_url }} style={styles.authorIcon} />
          )}
          <Text style={[styles.authorName, { color: themeColors.textPrimary }]}>
            {embed.author.name}
          </Text>
        </View>
      )}

      {/* Title */}
      {embed.title && (
        <Text style={[styles.embedTitle, { color: themeColors.accentSecondary }]} numberOfLines={2}>
          {embed.title}
        </Text>
      )}

      {/* Description */}
      {embed.description && (
        <Text style={[styles.embedDesc, { color: themeColors.textSecondary }]} numberOfLines={4}>
          {embed.description}
        </Text>
      )}

      {/* Fields */}
      {embed.fields && embed.fields.length > 0 && (
        <View style={styles.fieldsContainer}>
          {embed.fields.map((field, fi) => (
            <View key={fi} style={[styles.field, field.inline && styles.fieldInline]}>
              <Text style={[styles.fieldName, { color: themeColors.textPrimary }]}>
                {field.name}
              </Text>
              <Text style={[styles.fieldValue, { color: themeColors.textSecondary }]}>
                {field.value}
              </Text>
            </View>
          ))}
        </View>
      )}

      {/* Image */}
      {embed.image && (
        <Image
          source={{ uri: embed.image }}
          style={styles.embedImage}
          resizeMode="cover"
        />
      )}

      {/* Thumbnail */}
      {embed.thumbnail && !embed.image && (
        <Image
          source={{ uri: embed.thumbnail }}
          style={styles.embedThumbnail}
          resizeMode="cover"
        />
      )}

      {/* Footer */}
      {(embed.footer || embed.timestamp) && (
        <View style={styles.embedFooter}>
          {embed.footer && (
            <Text style={[styles.footerText, { color: themeColors.textMuted }]}>
              {embed.footer}
            </Text>
          )}
          {embed.timestamp && (
            <Text style={[styles.footerText, { color: themeColors.textMuted }]}>
              {new Date(embed.timestamp).toLocaleDateString()}
            </Text>
          )}
        </View>
      )}
    </Pressable>
  );
}

function URLCard({ url, themeColors }: { url: string; themeColors: ThemeColors }) {
  // Extract domain for display
  let domain = '';
  try {
    domain = new URL(url).hostname.replace('www.', '');
  } catch {
    domain = url;
  }

  return (
    <Pressable
      style={[styles.urlCard, { backgroundColor: themeColors.bgTertiary }]}
      onPress={() => Linking.openURL(url)}
    >
      <Ionicons name="link-outline" size={16} color={themeColors.accentSecondary} />
      <View style={styles.urlInfo}>
        <Text style={[styles.urlDomain, { color: themeColors.textMuted }]} numberOfLines={1}>
          {domain}
        </Text>
        <Text style={[styles.urlText, { color: themeColors.accentSecondary }]} numberOfLines={1}>
          {url}
        </Text>
      </View>
      <Ionicons name="open-outline" size={14} color={themeColors.textMuted} />
    </Pressable>
  );
}

const styles = StyleSheet.create({
  container: { marginTop: spacing.xs, gap: spacing.xs },
  embedCard: {
    borderLeftWidth: 4,
    borderRadius: borderRadius.sm,
    padding: spacing.md,
    maxWidth: 400,
  },
  embedAuthor: { flexDirection: 'row', alignItems: 'center', gap: spacing.xs, marginBottom: spacing.xs },
  authorIcon: { width: 20, height: 20, borderRadius: 10 },
  authorName: { ...typography.caption, fontFamily: 'gg-sans-semibold' },
  embedTitle: { ...typography.bodySmall, fontFamily: 'gg-sans-semibold', marginBottom: spacing.xs },
  embedDesc: { ...typography.bodySmall, marginBottom: spacing.sm },
  fieldsContainer: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm, marginBottom: spacing.sm },
  field: { minWidth: '100%' },
  fieldInline: { minWidth: '30%', maxWidth: '48%' },
  fieldName: { ...typography.caption, fontFamily: 'gg-sans-semibold' },
  fieldValue: { ...typography.caption },
  embedImage: { width: '100%', height: 150, borderRadius: borderRadius.sm, marginTop: spacing.xs },
  embedThumbnail: { width: 60, height: 60, borderRadius: borderRadius.sm, position: 'absolute', top: spacing.md, right: spacing.md },
  embedFooter: { flexDirection: 'row', gap: spacing.sm, marginTop: spacing.xs },
  footerText: { ...typography.micro },
  urlCard: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: spacing.sm,
    borderRadius: borderRadius.sm,
    gap: spacing.sm,
  },
  urlInfo: { flex: 1 },
  urlDomain: { ...typography.micro },
  urlText: { ...typography.caption },
});
