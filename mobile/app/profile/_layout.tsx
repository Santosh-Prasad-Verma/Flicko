import { Stack } from 'expo-router';
import { useTheme } from '../../hooks/useTheme';

export default function ProfileLayout() {
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
