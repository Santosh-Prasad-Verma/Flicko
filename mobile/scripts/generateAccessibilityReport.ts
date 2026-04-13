/**
 * Generate Accessibility Report Script
 * 
 * Generates a comprehensive WCAG accessibility report for all themes.
 * Run with: npx ts-node mobile/scripts/generateAccessibilityReport.ts
 */

import { generateAccessibilityReport, formatAccessibilityReport } from '../utils/accessibility';
import * as fs from 'fs';
import * as path from 'path';

function main() {
  console.log('Generating accessibility report...\n');

  // Generate the report
  const report = generateAccessibilityReport();

  // Format as human-readable text
  const formattedReport = formatAccessibilityReport(report);

  // Display to console
  console.log(formattedReport);

  // Save to file
  const outputDir = path.join(__dirname, '..', '..', 'reports');
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  const outputPath = path.join(outputDir, 'accessibility-report.txt');
  fs.writeFileSync(outputPath, formattedReport, 'utf-8');

  console.log(`\n✓ Report saved to: ${outputPath}`);

  // Save JSON version for programmatic access
  const jsonOutputPath = path.join(outputDir, 'accessibility-report.json');
  fs.writeFileSync(jsonOutputPath, JSON.stringify(report, null, 2), 'utf-8');

  console.log(`✓ JSON report saved to: ${jsonOutputPath}`);

  // Exit with error code if any theme fails WCAG AA
  if (!report.summary.allThemesPassAA) {
    console.error('\n⚠️  WARNING: Some themes do not meet WCAG AA standards!');
    process.exit(1);
  } else {
    console.log('\n✓ All themes meet WCAG AA standards!');
    process.exit(0);
  }
}

main();
