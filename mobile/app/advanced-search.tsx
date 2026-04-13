/**
 * Advanced Message Search Route
 *
 * Full-screen advanced search with filter chips, replacing the
 * messages tab of the basic search screen when accessed directly.
 */
import React from 'react';
import { View, StyleSheet } from 'react-native';
import { Stack, useLocalSearchParams } from 'expo-router';
import { useTheme } from '../hooks/useTheme';
import { AdvancedMessageSearch } from '../components/messages/AdvancedMessageSearch';

export default function AdvancedSearchScreen() {
  const { themeColors } = useTheme();
  const { serverId, channelId } = useLocalSearchParams<{
    serverId?: string;
    channelId?: string;
  }>();

  return (
    <>
      <Stack.Screen
        options={{
          headerShown: true,
          headerStyle: { backgroundColor: themeColors.bgPrimary },
          headerTintColor: themeColors.textPrimary,
          headerTitle: 'Search Messages',
          animation: 'fade_from_bottom',
        }}
      />
      <View style={[styles.container, { backgroundColor: themeColors.bgPrimary }]}>
        <AdvancedMessageSearch
          serverId={serverId}
          channelId={channelId}
        />
      </View>
    </>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
});
