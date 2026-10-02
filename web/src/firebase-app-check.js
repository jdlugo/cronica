const FIREBASE_WEB_SDK_VERSION = "12.18.0";

export class FirebaseAppCheckUnavailableError extends Error {
  constructor(cause) {
    super("Secure session verification is temporarily unavailable");
    this.name = "FirebaseAppCheckUnavailableError";
    this.code = "app_check.unavailable";
    this.providerCode = cause?.code || "unknown";
    this.cause = cause;
  }
}

export function createFirebaseAppCheckTokenProvider({
  firebaseConfig,
  recaptchaEnterpriseSiteKey,
  enableDebug = false,
  importModule = (url) => import(url),
}) {
  let initialized;

  return async function appCheckToken() {
    if (!firebaseConfig?.appId) {
      throw new Error("Firebase Web configuration is required for App Check");
    }
    if (!recaptchaEnterpriseSiteKey) {
      throw new Error("A reCAPTCHA Enterprise site key is required for App Check");
    }
    if (!initialized) {
      initialized = initialize({
        firebaseConfig,
        recaptchaEnterpriseSiteKey,
        enableDebug,
        importModule,
      });
    }
    try {
      const { appCheck, getToken } = await initialized;
      const result = await getToken(appCheck, false);
      if (!result?.token) throw new Error("Firebase App Check did not return a token");
      return result.token;
    } catch (error) {
      if (error?.code === "app_check.unavailable") throw error;
      throw new FirebaseAppCheckUnavailableError(error);
    }
  };
}

async function initialize({ firebaseConfig, recaptchaEnterpriseSiteKey, enableDebug, importModule }) {
  if (enableDebug && ["localhost", "127.0.0.1"].includes(globalThis.location?.hostname)) {
    globalThis.FIREBASE_APPCHECK_DEBUG_TOKEN = true;
  }

  const base = `https://www.gstatic.com/firebasejs/${FIREBASE_WEB_SDK_VERSION}`;
  const [firebaseApp, firebaseAppCheck] = await Promise.all([
    importModule(`${base}/firebase-app.js`),
    importModule(`${base}/firebase-app-check.js`),
  ]);
  const appName = "daily-reel-web";
  const app = firebaseApp.getApps().find((candidate) => candidate.name === appName)
    ?? firebaseApp.initializeApp(firebaseConfig, appName);
  const appCheck = firebaseAppCheck.initializeAppCheck(app, {
    provider: new firebaseAppCheck.ReCaptchaEnterpriseProvider(recaptchaEnterpriseSiteKey),
    isTokenAutoRefreshEnabled: true,
  });
  return { appCheck, getToken: firebaseAppCheck.getToken };
}
