import { Stack } from 'expo-router';
import { useTheme } from '../../../hooks/useTheme';

export default function ServerLayout() {
  const { themeColors } = useTheme();
  
  return (
    <Stack
      screenOptions={{
        headerShown: false,
        animation: 'slide_from_right',
        contentStyle: { backgroundColor: themeColors.bgTertiary },
      }}
    />
  );
}
