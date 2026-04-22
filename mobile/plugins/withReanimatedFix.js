const { withDangerousMod } = require('@expo/config-plugins');
const fs = require('fs');
const path = require('path');

// Patches react-native-reanimated 3.16.x to compile on RN 0.81 (Old Architecture)
// RN 0.81 removed TRACE_TAG_REACT_JAVA_BRIDGE from Systrace and changed
// LengthPercentage.resolve() signature.
const withReanimatedFix = (config) => {
  return withDangerousMod(config, [
    'android',
    (config) => {
      const reanimatedAndroid = path.join(
        config.modRequest.projectRoot,
        'node_modules/react-native-reanimated/android/src/main/java/com/swmansion/reanimated'
      );

      // Patch 1: Remove TRACE_TAG_REACT_JAVA_BRIDGE usage
      const filesToPatch = [
        path.join(reanimatedAndroid, 'NativeProxy.java'),
        path.join(reanimatedAndroid, 'ReanimatedModule.java'),
      ];

      for (const filePath of filesToPatch) {
        if (!fs.existsSync(filePath)) continue;
        let content = fs.readFileSync(filePath, 'utf8');
        if (content.includes('TRACE_TAG_REACT_JAVA_BRIDGE')) {
          content = content.replace(/Systrace\.TRACE_TAG_REACT_JAVA_BRIDGE/g, '0');
          fs.writeFileSync(filePath, content);
          console.log(`[withReanimatedFix] Patched TRACE_TAG in ${path.basename(filePath)}`);
        }
      }

      // Patch 2: Fix LengthPercentage.resolve() — RN 0.81 changed to single float arg
      const layoutFile = path.join(
        reanimatedAndroid,
        'layoutReanimation/animationsManager/LayoutAnimationsUtils.java'
      );
      if (fs.existsSync(layoutFile)) {
        let content = fs.readFileSync(layoutFile, 'utf8');
        if (content.includes('.resolve(')) {
          content = content.replace(/\.resolve\(\s*(\w+)\s*,\s*\w+\s*\)/g, '.resolve($1)');
          fs.writeFileSync(layoutFile, content);
          console.log('[withReanimatedFix] Patched LengthPercentage.resolve()');
        }
      }

      return config;
    },
  ]);
};

module.exports = withReanimatedFix;
