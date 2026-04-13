import { StatusBar } from 'expo-status-bar';
import { StyleSheet, Text, View } from 'react-native';
import { withDevCycleProvider, useVariableValue } from '@devcycle/react-native-expo-client-sdk';

function App() {
  // Use the DevCycle hook to check if the banner is enabled (defaults to false)
  const showBanner = useVariableValue('enable-welcome-banner', false);

  return (
    <View style={styles.container}>
      {/* Our Feature Flagged Banner */}
      {showBanner && (
        <View style={styles.banner}>
          <Text style={styles.bannerText}>👋 Welcome to Flicko! This is the New Feature!</Text>
        </View>
      )}
      
      <Text>Open up App.tsx to start working on your app!</Text>
      <StatusBar style="auto" />
    </View>
  );
}

// Wrap the App with the DevCycle Provider
export default withDevCycleProvider({
  sdkKey: 'dvc_mobile_fe8dedc2_ee46_49d7_8dce_e79a8cb1a271_5995623', // Your Flicko Development Mobile SDK Key
})(App);

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#fff',
    alignItems: 'center',
    justifyContent: 'center',
  },
  banner: {
    backgroundColor: '#06b6d4',
    padding: 15,
    borderRadius: 8,
    marginBottom: 20,
  },
  bannerText: {
    color: 'white',
    fontWeight: 'bold',
    fontSize: 16,
  }
});
