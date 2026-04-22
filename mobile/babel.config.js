module.exports = function (api) {
  api.cache(true);

  return {
    presets: ['babel-preset-expo'],
    plugins: [
      [
        'module-resolver',
        {
          root: ['./'],
          alias: {
            '@': './',
            '@constants': './constants',
            '@shared': '../shared',
            '@services': '../shared/services',
            '@stores': '../shared/stores',
            '@hooks': '../shared/hooks',
            '@types': '../shared/types',
            '@utils': '../shared/utils',
            '@lib': '../shared/lib',
          },
        },
      ],
      'react-native-reanimated/plugin',
    ],
  };
};
