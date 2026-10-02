import assert from "node:assert/strict";
import test from "node:test";
import { createFirebaseAppCheckTokenProvider } from "../src/firebase-app-check.js";

test("App Check provider fails closed without an Enterprise site key", async () => {
  const token = createFirebaseAppCheckTokenProvider({
    firebaseConfig: { appId: "web-app" },
    recaptchaEnterpriseSiteKey: "",
  });
  await assert.rejects(token(), /site key is required/);
});

test("App Check initializes lazily and returns a reusable Firebase token", async () => {
  const imports = [];
  const app = { name: "daily-reel-web" };
  const appCheck = { app };
  const modules = {
    "firebase-app.js": {
      getApps: () => [],
      initializeApp: (config, name) => ({ name, options: config }),
    },
    "firebase-app-check.js": {
      ReCaptchaEnterpriseProvider: class {
        constructor(siteKey) { this.siteKey = siteKey; }
      },
      initializeAppCheck: (initializedApp, options) => {
        assert.equal(initializedApp.name, "daily-reel-web");
        assert.equal(options.provider.siteKey, "site-key");
        assert.equal(options.isTokenAutoRefreshEnabled, true);
        return appCheck;
      },
      getToken: async () => ({ token: "attested-token" }),
    },
  };
  const token = createFirebaseAppCheckTokenProvider({
    firebaseConfig: { appId: "web-app" },
    recaptchaEnterpriseSiteKey: "site-key",
    importModule: async (url) => {
      imports.push(url);
      return modules[url.endsWith("firebase-app-check.js") ? "firebase-app-check.js" : "firebase-app.js"];
    },
  });

  assert.equal(await token(), "attested-token");
  assert.equal(await token(), "attested-token");
  assert.equal(imports.length, 2);
});

test("App Check exposes a stable recovery code when Firebase throttles attestation", async () => {
  const providerError = Object.assign(new Error("throttled"), { code: "appCheck/initial-throttle" });
  const token = createFirebaseAppCheckTokenProvider({
    firebaseConfig: { appId: "web-app" },
    recaptchaEnterpriseSiteKey: "site-key",
    importModule: async (url) => url.endsWith("firebase-app-check.js") ? {
      ReCaptchaEnterpriseProvider: class {},
      initializeAppCheck: () => ({}),
      getToken: async () => { throw providerError; },
    } : {
      getApps: () => [],
      initializeApp: () => ({ name: "daily-reel-web" }),
    },
  });

  await assert.rejects(token(), (error) => {
    assert.equal(error.code, "app_check.unavailable");
    assert.equal(error.providerCode, "appCheck/initial-throttle");
    return true;
  });
});
