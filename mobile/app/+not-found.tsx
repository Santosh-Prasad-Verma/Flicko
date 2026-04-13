import {View, Text, StyleSheet} from 'react-native';
import {Link} from 'expo-router';

export default function NotFoundScreen() {
  return (
    <View style={styles.container}>
      <Text style={styles.title}>404</Text>
      <Text style={styles.subtitle}>This screen doesn't exist</Text>
      <Link href="/" style={styles.link}>
        <Text style={styles.linkText}>Go to home screen</Text>
      </Link>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#313338',
  },
  title: {
    fontSize: 72,
    fontFamily: 'gg-sans-bold',
    color: '#5865F2',
    marginBottom: 16,
  },
  subtitle: {
    fontSize: 18,
    color: '#B5BAC1',
    marginBottom: 32,
  },
  link: {
    paddingVertical: 12,
    paddingHorizontal: 24,
    backgroundColor: '#5865F2',
    borderRadius: 8,
  },
  linkText: {
    fontSize: 16,
    fontFamily: 'gg-sans-semibold',
    color: '#FFFFFF',
  },
});
