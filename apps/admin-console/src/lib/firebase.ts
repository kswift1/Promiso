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

export const firebaseAuth: Auth | null = isFirebaseConfigured ?
  getAuth(getApps().length > 0 ? getApp() : initializeApp(firebaseConfig)) :
  null;

export const firebaseFunctions: Functions | null = isFirebaseConfigured ?
  getFunctions(getApps().length > 0 ? getApp() : initializeApp(firebaseConfig), "asia-northeast3") :
  null;
