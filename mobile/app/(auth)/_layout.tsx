import { Stack } from 'expo-router';
import { useTheme } from '../../hooks/useTheme';

export default function AuthLayout() {
  const { themeColors } = useTheme();
  
  return (
    <Stack
      screenOptions={{
        headerShown: false,
        animation: 'fade',
        contentStyle: { backgroundColor: themeColors.bgSecondary },
      }}
    >
      <Stack.Screen name="login" options={{ contentStyle: { backgroundColor: themeColors.bgSecondary } }} />
      <Stack.Screen name="register" options={{ contentStyle: { backgroundColor: themeColors.bgSecondary } }} />
    </Stack>
  );
}
