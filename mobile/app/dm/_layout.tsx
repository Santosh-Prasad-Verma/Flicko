import { Stack } from 'expo-router';
import { useTheme } from '../../hooks/useTheme';

export default function DMLayout() {
  const { themeColors } = useTheme();

  return (
    <Stack
      screenOptions={{
        headerShown: false,
        contentStyle: { backgroundColor: themeColors.bgPrimary },
        animation: 'fade',
        animationDuration: 150,
      }}
    />
  );
}
