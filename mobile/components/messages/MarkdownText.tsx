/**
 * Markdown Renderer Component
 *
 * Renders Discord-style markdown: bold, italic, strikethrough, code,
 * code blocks, spoilers, blockquotes, headers, links, and custom emoji.
 * Requirements: Feature 27 (Markdown / Rich Text Formatting)
 */
import React, { memo, useState, useMemo } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Pressable,
  Linking,
} from 'react-native';
import { colors, spacing, borderRadius, typography } from '../../constants/Colors';
import type { ThemeColors } from '../../constants/Colors';
import { useTheme } from '@/hooks/useTheme';

interface MarkdownTextProps {
  content: string;
  color?: string;
  /** Base font size for body text (appearance setting); default 15 */
  fontSize?: number;
}

interface MarkdownNode {
  type: 'text' | 'bold' | 'italic' | 'strikethrough' | 'code' | 'codeBlock' | 'spoiler' | 'blockquote' | 'heading' | 'link' | 'lineBreak' | 'mention';
  content?: string;
  children?: MarkdownNode[];
  level?: number;     // heading level 1-3
  url?: string;       // link url
  language?: string;  // code block language
  mentionType?: 'everyone' | 'here' | 'user' | 'role'; // mention type
}

/**
 * Simple recursive-descent Markdown parser for chat messages.
 * Handles common Discord-style formatting.
 */
function parseMarkdown(text: string): MarkdownNode[] {
  const nodes: MarkdownNode[] = [];
  let remaining = text;

  while (remaining.length > 0) {
    // Code block ```
    const codeBlockMatch = remaining.match(/^```(\w*)\n?([\s\S]*?)```/);
    if (codeBlockMatch) {
      nodes.push({ type: 'codeBlock', language: codeBlockMatch[1], content: codeBlockMatch[2] });
      remaining = remaining.slice(codeBlockMatch[0].length);
      continue;
    }

    // Heading # ## ###
    const headingMatch = remaining.match(/^(#{1,3})\s+(.+?)$/m);
    if (headingMatch && remaining.indexOf(headingMatch[0]) === 0) {
      nodes.push({ type: 'heading', level: headingMatch[1].length, content: headingMatch[2] });
      remaining = remaining.slice(headingMatch[0].length);
      continue;
    }

    // Blockquote >
    const quoteMatch = remaining.match(/^>\s+(.+?)$/m);
    if (quoteMatch && remaining.indexOf(quoteMatch[0]) === 0) {
      nodes.push({ type: 'blockquote', content: quoteMatch[1] });
      remaining = remaining.slice(quoteMatch[0].length);
      continue;
    }

    // Inline patterns
    // Spoiler ||text||
    const spoilerMatch = remaining.match(/^\|\|(.+?)\|\|/);
    if (spoilerMatch) {
      nodes.push({ type: 'spoiler', content: spoilerMatch[1] });
      remaining = remaining.slice(spoilerMatch[0].length);
      continue;
    }

    // Bold **text**
    const boldMatch = remaining.match(/^\*\*(.+?)\*\*/);
    if (boldMatch) {
      nodes.push({ type: 'bold', content: boldMatch[1] });
      remaining = remaining.slice(boldMatch[0].length);
      continue;
    }

    // Italic *text* or _text_
    const italicMatch = remaining.match(/^[*_](.+?)[*_]/);
    if (italicMatch) {
      nodes.push({ type: 'italic', content: italicMatch[1] });
      remaining = remaining.slice(italicMatch[0].length);
      continue;
    }

    // Strikethrough ~~text~~
    const strikeMatch = remaining.match(/^~~(.+?)~~/);
    if (strikeMatch) {
      nodes.push({ type: 'strikethrough', content: strikeMatch[1] });
      remaining = remaining.slice(strikeMatch[0].length);
      continue;
    }

    // Inline code `text`
    const codeMatch = remaining.match(/^`([^`]+)`/);
    if (codeMatch) {
      nodes.push({ type: 'code', content: codeMatch[1] });
      remaining = remaining.slice(codeMatch[0].length);
      continue;
    }

    // Link [text](url)
    const linkMatch = remaining.match(/^\[([^\]]+)\]\(([^)]+)\)/);
    if (linkMatch) {
      nodes.push({ type: 'link', content: linkMatch[1], url: linkMatch[2] });
      remaining = remaining.slice(linkMatch[0].length);
      continue;
    }

    // Auto-link URLs
    const urlMatch = remaining.match(/^(https?:\/\/[^\s<]+)/);
    if (urlMatch) {
      nodes.push({ type: 'link', content: urlMatch[1], url: urlMatch[1] });
      remaining = remaining.slice(urlMatch[0].length);
      continue;
    }

    // @everyone and @here mentions (Feature 5)
    const mentionMatch = remaining.match(/^@(everyone|here)\b/);
    if (mentionMatch) {
      nodes.push({ type: 'mention', content: `@${mentionMatch[1]}`, mentionType: mentionMatch[1] as 'everyone' | 'here' });
      remaining = remaining.slice(mentionMatch[0].length);
      continue;
    }

    // Line break
    if (remaining[0] === '\n') {
      nodes.push({ type: 'lineBreak' });
      remaining = remaining.slice(1);
      continue;
    }

    // Plain text — consume until next special char
    const nextSpecial = remaining.slice(1).search(/[*_~`|\[#>\n@]|https?:/);
    const end = nextSpecial === -1 ? remaining.length : nextSpecial + 1;
    nodes.push({ type: 'text', content: remaining.slice(0, end) });
    remaining = remaining.slice(end);
  }

  return nodes;
}

const SpoilerText = memo(({ content, themeColors }: { content: string; themeColors: ThemeColors }) => {
  const [revealed, setRevealed] = useState(false);
  return (
    <Pressable onPress={() => setRevealed((v) => !v)}>
      <Text
        style={[
          styles.spoiler,
          {
            backgroundColor: revealed ? themeColors.bgTertiary : themeColors.textMuted,
            color: revealed ? themeColors.textPrimary : 'transparent',
          },
        ]}
      >
        {content}
      </Text>
    </Pressable>
  );
});

export const MarkdownText = memo(function MarkdownText({ content, color, fontSize = 15 }: MarkdownTextProps) {
  const { themeColors: c } = useTheme();
  const textColor = color || c.textPrimary;
  const baseText = { fontSize, lineHeight: Math.round(fontSize * 1.35) };

  const nodes = useMemo(() => parseMarkdown(content), [content]);

  const renderNode = (node: MarkdownNode, index: number): React.ReactNode => {
    switch (node.type) {
      case 'text':
        return <Text key={index} style={[{ color: textColor }, baseText]}>{node.content}</Text>;

      case 'bold':
        return <Text key={index} style={[styles.bold, baseText, { color: textColor }]}>{node.content}</Text>;

      case 'italic':
        return <Text key={index} style={[styles.italic, baseText, { color: textColor }]}>{node.content}</Text>;

      case 'strikethrough':
        return <Text key={index} style={[styles.strikethrough, baseText, { color: textColor }]}>{node.content}</Text>;

      case 'code':
        return (
          <Text key={index} style={[styles.inlineCode, { backgroundColor: c.bgTertiary, color: c.accentSecondary, fontSize: Math.max(12, fontSize - 2) }]}>
            {node.content}
          </Text>
        );

      case 'codeBlock':
        return (
          <View key={index} style={[styles.codeBlock, { backgroundColor: c.bgTertiary }]}>
            {node.language ? (
              <Text style={[styles.codeBlockLang, { color: c.textMuted }]}>{node.language}</Text>
            ) : null}
            <Text style={[styles.codeBlockText, { color: c.textPrimary, fontSize: Math.max(12, fontSize - 2), lineHeight: Math.round((fontSize - 2) * 1.4) }]}>{node.content}</Text>
          </View>
        );

      case 'spoiler':
        return <SpoilerText key={index} content={node.content!} themeColors={c} />;

      case 'blockquote':
        return (
          <View key={index} style={[styles.blockquote, { borderLeftColor: c.textMuted }]}>
            <Text style={[styles.blockquoteText, baseText, { color: c.textSecondary }]}>{node.content}</Text>
          </View>
        );

      case 'heading':
        const headingStyle = node.level === 1 ? typography.headingL : node.level === 2 ? typography.headingM : typography.headingS;
        return <Text key={index} style={[headingStyle, { color: textColor, marginVertical: spacing.xs }]}>{node.content}</Text>;

      case 'link':
        return (
          <Text
            key={index}
            style={[styles.link, { color: c.accentSecondary }]}
            onPress={() => node.url && Linking.openURL(node.url)}
          >
            {node.content}
          </Text>
        );

      case 'mention':
        return (
          <Text
            key={index}
            style={[styles.mention, { backgroundColor: c.accentPrimary + '30', color: c.accentPrimary }]}
          >
            {node.content}
          </Text>
        );

      case 'lineBreak':
        return <Text key={index}>{'\n'}</Text>;

      default:
        return <Text key={index} style={[{ color: textColor }, baseText]}>{node.content}</Text>;
    }
  };

  return (
    <Text style={[styles.container, baseText]}>
      {nodes.map((node, i) => renderNode(node, i))}
    </Text>
  );
});

const styles = StyleSheet.create({
  container: { flexWrap: 'wrap', fontSize: 15 },
  bold: { fontFamily: 'gg-sans-bold' },
  italic: { fontStyle: 'italic' },
  strikethrough: { textDecorationLine: 'line-through' },
  inlineCode: {
    fontFamily: 'monospace',
    fontSize: 13,
    paddingHorizontal: 4,
    paddingVertical: 1,
    borderRadius: 3,
    overflow: 'hidden',
  },
  codeBlock: {
    borderRadius: borderRadius.sm,
    padding: spacing.md,
    marginVertical: spacing.xs,
  },
  codeBlockLang: {
    ...typography.micro,
    marginBottom: spacing.xs,
  },
  codeBlockText: {
    fontFamily: 'monospace',
    fontSize: 13,
    lineHeight: 18,
  },
  spoiler: {
    borderRadius: 3,
    paddingHorizontal: 2,
    overflow: 'hidden',
  },
  blockquote: {
    borderLeftWidth: 3,
    paddingLeft: spacing.md,
    marginVertical: spacing.xs,
  },
  blockquoteText: {
    ...typography.bodySmall,
    fontStyle: 'italic',
  },
  link: {
    textDecorationLine: 'underline',
  },
  mention: {
    borderRadius: 3,
    paddingHorizontal: 2,
    fontFamily: 'gg-sans-medium',
    overflow: 'hidden',
  },
});
