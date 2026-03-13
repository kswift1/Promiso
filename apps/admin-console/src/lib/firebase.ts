import {getApp, getApps, initializeApp} from "firebase/app";
import {Auth, getAuth} from "firebase/auth";
import {Functions, getFunctions} from "firebase/functions";

const firebaseConfig = {
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY,
  authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN,
  projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID,
  appId: import.meta.env.VITE_FIREBASE_APP_ID,
};

export const isFirebaseConfigured = Object.values(firebaseConfig).every(Boolean);
const app = isFirebaseConfigured ?
  (getApps().length > 0 ? getApp() : initializeApp(firebaseConfig)) :
  null;

export const firebaseAuth: Auth | null = app ? getAuth(app) : null;

export const firebaseFunctions: Functions | null = app ?
  getFunctions(app, "asia-northeast3") :
  null;
