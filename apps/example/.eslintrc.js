module.exports = {
  root: true,
  extends: '@react-native',
  parserOptions: {
    requireConfigFile: false,
    babelOptions: {
      presets: ['module:@react-native/babel-preset'],
    },
  },
};
