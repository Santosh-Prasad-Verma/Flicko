/**
 * Input Component
 *
 * Styled text input with label, error state, and secure-entry mode
 * for passwords. Meets accessibility and touch-target requirements.
 *
 * Requirements: 16.4
 */
import React, { useCallback, useMemo, useState } from 'react';
import {
  View,
  TextInput,
  Text,
  StyleSheet,
  Pressable,
  TextInputProps,
  ViewStyle,
} from 'react-native';
import {
  spacing,
  borderRadius,
  typography,
  MINIMUM_TOUCH_TARGET,
} from '../../constants/Colors';
import { useTheme } from '@/hooks/useTheme';

interface InputProps extends Omit<TextInputProps, 'style'> {
  label?: string;
  error?: string;
  /** Non-error helper text shown below input */
  hint?: string;
  /** Show a toggle to reveal/hide password */
  isPassword?: boolean;
  containerStyle?: ViewStyle;
}

export const Input = React.memo<InputProps>(function Input({
  label,
  error,
  hint,
  isPassword = false,
  containerStyle,
  accessibilityLabel,
  ...textInputProps
}) {
  const { themeColors } = useTheme();
  const [secureEntry, setSecureEntry] = useState(isPassword);
  const [isFocused, setIsFocused] = useState(false);

  const toggleSecureEntry = useCallback(() => {
    setSecureEntry((prev) => !prev);
  }, []);

  const handleFocus = useCallback(
    (e: any) => {
      setIsFocused(true);
      textInputProps.onFocus?.(e);
    },
    [textInputProps.onFocus],
  );

  const handleBlur = useCallback(
    (e: any) => {
      setIsFocused(false);
      textInputProps.onBlur?.(e);
    },
    [textInputProps.onBlur],
  );

  const inputContainerStyle = useMemo((): ViewStyle => {
    const base: ViewStyle = {
      flexDirection: 'row',
      alignItems: 'center',
      backgroundColor: themeColors.inputBg,
      borderRadius: 12,
      borderWidth: 0,
      minHeight: MINIMUM_TOUCH_TARGET,
      paddingHorizontal: spacing.lg,
    };
    if (error) {
      base.backgroundColor = themeColors.danger + '10';
    }
    return base;
  }, [themeColors, error, isFocused]);

  return (
    <View style={[styles.wrapper, containerStyle]}>
      {label ? (
        <Text
          style={[styles.label, { color: error ? themeColors.danger : themeColors.textSecondary }]}
          accessibilityRole="text"
        >
          {label}
        </Text>
      ) : null}

      <View style={inputContainerStyle}>
        <TextInput
          {...textInputProps}
          secureTextEntry={secureEntry}
          onFocus={handleFocus}
          onBlur={handleBlur}
          placeholderTextColor={themeColors.textMuted}
          accessibilityLabel={accessibilityLabel ?? label}
          accessibilityState={{ disabled: textInputProps.editable === false }}
          scrollEnabled={false}
          style={[
            styles.input,
            {
              color: themeColors.textPrimary,
            },
          ]}
        />
        {isPassword ? (
          <Pressable
            onPress={toggleSecureEntry}
            hitSlop={12}
            accessibilityLabel={secureEntry ? 'Show password' : 'Hide password'}
            accessibilityRole="button"
            style={styles.toggleButton}
          >
            <Text style={{ color: themeColors.accentPrimary, fontSize: 13, fontFamily: 'gg-sans-medium' }}>
              {secureEntry ? 'Show' : 'Hide'}
            </Text>
          </Pressable>
        ) : null}
      </View>

      {error ? (
        <Text
          style={[styles.errorText, { color: themeColors.danger }]}
          accessibilityLiveRegion="polite"
          accessibilityRole="alert"
        >
          {error}
        </Text>
      ) : hint ? (
        <Text style={[styles.hintText, { color: themeColors.textMuted }]}>
          {hint}
        </Text>
      ) : null}
    </View>
  );
});

const styles = StyleSheet.create({
  wrapper: {
    width: '100%',
    marginBottom: 14,
  },
  label: {
    fontSize: 11,
    fontFamily: 'gg-sans-semibold',
    textTransform: 'uppercase',
    letterSpacing: 0.6,
    marginBottom: 6,
    marginLeft: 2,
  },
  input: {
    flex: 1,
    fontSize: 15,
    fontFamily: 'gg-sans',
    paddingVertical: 14,
    lineHeight: 20,
  },
  toggleButton: {
    paddingLeft: spacing.sm,
    paddingRight: 2,
    minHeight: MINIMUM_TOUCH_TARGET,
    justifyContent: 'center',
    alignItems: 'flex-end',
  },
  errorText: {
    fontSize: 12,
    fontFamily: 'gg-sans',
    marginTop: 4,
    marginLeft: 2,
  },
  hintText: {
    fontSize: 12,
    fontFamily: 'gg-sans',
    marginTop: 4,
    marginLeft: 2,
  },
});
