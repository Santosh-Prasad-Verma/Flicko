import { Text as RNText, TextProps, StyleSheet } from 'react-native';
import { FontFamily } from '@/constants/Typography';
import { useTheme } from '@/hooks/useTheme';

// Drop-in replacement for <Text> that uses GG Sans by default
export function Text({ style, children, ...props }: TextProps) {
    const { themeColors } = useTheme();
    
    return (
        <RNText
            style={[{ fontFamily: FontFamily.regular, color: themeColors.textPrimary, fontSize: 16 }, style]}
            {...props}
        >
            {children}
        </RNText>
    );
}

