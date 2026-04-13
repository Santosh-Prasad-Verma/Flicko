/**
 * Script to validate all theme palettes
 * Run with: npx ts-node mobile/utils/validateThemes.ts
 */

import { runValidation } from './themeValidation';

const allValid = runValidation();

if (allValid) {
  console.log('✓ All themes are valid!');
  process.exit(0);
} else {
  console.log('✗ Some themes have validation errors');
  process.exit(1);
}
