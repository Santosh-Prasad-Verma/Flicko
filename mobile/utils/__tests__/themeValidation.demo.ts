/**
 * Demo script to show theme validation in action
 * This demonstrates that the validation utility works correctly
 */

import {
  validateAllThemes,
  printValidationReport,
  isValidColorFormat,
} from '../themeValidation';

console.log('=== Theme Validation Demo ===\n');

// Test color format validation
console.log('Testing color format validation:');
console.log('  #FFFFFF:', isValidColorFormat('#FFFFFF'));
console.log('  rgba(0,0,0,0.75):', isValidColorFormat('rgba(0, 0, 0, 0.75)'));
console.log('  invalid:', isValidColorFormat('invalid'));
console.log('');

// Validate all themes
const results = validateAllThemes();

// Print detailed report
printValidationReport(results);

// Summary
console.log('=== Summary ===');
console.log(`Dark theme: ${results.dark.isValid ? '✓ VALID' : '✗ INVALID'}`);
console.log(`Light theme: ${results.light.isValid ? '✓ VALID' : '✗ INVALID'}`);
console.log(`AMOLED theme: ${results.amoled.isValid ? '✓ VALID' : '✗ INVALID'}`);
console.log('');

// Check if all themes are valid
const allValid = Object.values(results).every((r) => r.isValid);
console.log(`Overall: ${allValid ? '✓ All themes valid' : '✗ Some themes invalid'}`);
