/**
 * Settings Layout
 *
 * Stack navigator for all settings sub-screens.
 * Each screen gets a back button and consistent header styling.
 */
import { Stack } from 'expo-router';
import { useTheme } from '../../hooks/useTheme';

export default function SettingsLayout() {
  const { themeColors } = useTheme();

  return (
    <Stack
      screenOptions={{
        headerShown: false,
        contentStyle: { backgroundColor: themeColors.bgPrimary },
        animation: 'slide_from_right',
      }}
    />
  );
}
