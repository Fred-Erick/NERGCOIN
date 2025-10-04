module.exports = {
  env: {
    es6: true,
    node: true,
  },
  parserOptions: {
    "ecmaVersion": 2020, // Updated to 2020 to support modern JS features
  },
  extends: [
    "eslint:recommended",
    "google",
  ],
  rules: {
    "no-restricted-globals": ["error", "name", "length"],
    "prefer-arrow-callback": "error",
    "quotes": ["error", "double", {"allowTemplateLiterals": true}],
    "max-len": ["off"], // Added to disable max-len rule if it causes issues
    "require-jsdoc": ["off"], // Added to disable require-jsdoc rule if it causes issues
    "no-unused-vars": ["warn"], // Changed to warn for unused vars
  },
  overrides: [
    {
      files: ["**/*.spec.*"],
      env: {
        mocha: true,
      },
      rules: {},
    },
  ],
  globals: {},
};
