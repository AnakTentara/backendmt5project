module.exports = {
  root: true,
  env: { browser: true, es2022: true },
  extends: [
    'eslint:recommended',
    'plugin:@typescript-eslint/recommended',
    'plugin:@typescript-eslint/recommended-requiring-type-checking',
  ],
  parser: '@typescript-eslint/parser',
  parserOptions: {
    ecmaVersion: 'latest',
    sourceType: 'module',
    project: ['./tsconfig.json'],
    tsconfigRootDir: __dirname,
  },
  plugins: ['@typescript-eslint', 'react-hooks', 'react-refresh'],
  ignorePatterns: ['dist', 'node_modules', '*.config.js', '*.config.ts'],
  rules: {
    ...require('eslint-plugin-react-hooks').configs.recommended.rules,

    'react-refresh/only-export-components': [
      'warn',
      { allowConstantExport: true },
    ],

    /**
     * Floating promises are errors, not warnings.
     *
     * An un-awaited mutation or invalidation fails silently, which on a trading
     * dashboard means a command appears to have been sent when it was not.
     * `void` is the explicit opt-out where fire-and-forget is intended.
     */
    '@typescript-eslint/no-floating-promises': 'error',

    /** Unused variables are errors; the leading-underscore escape hatch remains. */
    '@typescript-eslint/no-unused-vars': [
      'error',
      { argsIgnorePattern: '^_', varsIgnorePattern: '^_' },
    ],

    /**
     * `any` defeats the entire point of the validated API boundary. If a type is
     * genuinely unknown, `unknown` forces a narrowing step.
     */
    '@typescript-eslint/no-explicit-any': 'error',

    /** Prefer `??` over `||` so 0 and '' are not treated as absent values. */
    '@typescript-eslint/prefer-nullish-coalescing': 'error',

    /** Type-only imports are elided at build time and clarify intent. */
    '@typescript-eslint/consistent-type-imports': [
      'error',
      { prefer: 'type-imports', fixStyle: 'separate-type-imports' },
    ],

    /** console.warn/error are permitted; stray console.log is not. */
    'no-console': ['error', { allow: ['warn', 'error'] }],

    eqeqeq: ['error', 'always'],
    'no-var': 'error',
    'prefer-const': 'error',
  },
};
