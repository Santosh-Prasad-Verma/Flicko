const { getDefaultConfig } = require('expo/metro-config');
const path = require('path');

const config = getDefaultConfig(__dirname);

const sharedDir = path.resolve(__dirname, '..', 'shared');

// Watch the shared directory so Metro can resolve files from it
config.watchFolders = [sharedDir];

// Alias mapping: @stores/authStore -> shared/stores/authStore, etc.
const aliases = {
  '@shared': sharedDir,
  '@services': path.resolve(sharedDir, 'services'),
  '@stores': path.resolve(sharedDir, 'stores'),
  '@hooks': path.resolve(sharedDir, 'hooks'),
  '@types': path.resolve(sharedDir, 'types'),
  '@utils': path.resolve(sharedDir, 'utils'),
  '@lib': path.resolve(sharedDir, 'lib'),
};

config.resolver.extraNodeModules = new Proxy(aliases, {
  // For any module not in our alias map, fall back to mobile/node_modules
  get: (target, name) =>
    name in target
      ? target[name]
      : path.resolve(__dirname, 'node_modules', String(name)),
});

// Ensure shared code finds dependencies in mobile/node_modules
config.resolver.nodeModulesPaths = [
  path.resolve(__dirname, 'node_modules'),
];

module.exports = config;
