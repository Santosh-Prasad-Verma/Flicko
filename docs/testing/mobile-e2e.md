# Mobile End-to-End Testing (E2E)

> **Reading time:** ~6 minutes · **Audience:** FrontEnd Developers · **Last Updated:** 2026-04-11

Unit testing Flutter components is useful, but it cannot verify if clicking the "Login" button correctly redirects to the Chat layout while successfully maintaining the JWT in SecureStorage. 
Flicko uses **Detox** to achieve true gray-box End-to-End automation.

---

## 1. What is Detox?

Detox is an open-source testing framework developed by Wix. Unlike Appium (which acts like a black box blindly tapping coordinates), Detox operates "gray box". It monitors the Flutter Javascript thread and the native iOS/Android Animation queues. 
It will **automatically wait** for all HTTP requests to finish and all loading spinners to vanish before attempting to tap a button, completely eliminating flaky `sleep(2000)` test hacks.

---

## 2. Configuration & Execution

Detox must compile a special debug binary of the Flutter app to inject its test listeners.

**To run the suite locally (iOS Simulator):**

```bash
cd mobile
# Build the test binary (Takes ~3-5 minutes)
npx detox build -c ios.sim.debug

# Boot the simulator and execute the Jest-Detox suite
npx detox test -c ios.sim.debug
```

---

## 3. Writing E2E Tests

Test files are located in `mobile/e2e/`. We use a Jest-like syntax.
To make elements targetable by Detox without relying on brittle localized text (e.g. `tap("Login")` breaking in French), we attach a `testID` prop to Critical UI components.

```tsx
// Inside components/ui/Button.tsx
<TouchableOpacity testID="login_submit_button">
  <Text>Login</Text>
</TouchableOpacity>
```

**Example Detox Test (`e2e/auth.spec.ts`):**

```typescript
import { by, device, element, expect } from 'detox';

describe('Authentication Flow', () => {
  beforeAll(async () => {
    // 1. Wipe simulator memory
    await device.launchApp({ delete: true });
  });

  it('should show validation errors on blank submit', async () => {
    // 2. Detox waits for the screen to render automatically
    await element(by.id('login_submit_button')).tap();
    await expect(element(by.text('Email is required'))).toBeVisible();
  });

  it('should successfully login and route to chat', async () => {
    // 3. Type text
    await element(by.id('email_input')).typeText('testuser@flicko.app');
    await element(by.id('password_input')).typeText('Password123!\n'); // \n dismisses keyboard
    
    // 4. Submit
    await element(by.id('login_submit_button')).tap();

    // 5. Assert successful routing to the main protected layout
    await expect(element(by.id('component_sidebar_server_list'))).toBeVisible();
  });
});
```

---

## 4. Continuous Integration (CI)

Because macOS Github Action runners limit execution minutes significantly, we do not run the Detox suite on every single pull request.

Instead, the E2E suite runs on a specialized `Cron` tag nightly, and as a mandatory gate check during the Release Pipeline before a new version is pushed to EAS/Testflight.
