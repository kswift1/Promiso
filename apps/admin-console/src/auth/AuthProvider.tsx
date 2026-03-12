import {
  GoogleAuthProvider,
  User,
  onAuthStateChanged,
  signInWithPopup,
  signOut,
} from "firebase/auth";
import {httpsCallable} from "firebase/functions";
import {
  ReactNode,
  createContext,
  useContext,
  useEffect,
  useMemo,
  useState,
} from "react";
import {firebaseAuth, firebaseFunctions, isFirebaseConfigured} from "../lib/firebase";

type AuthStatus =
  | "checking"
  | "authenticated"
  | "signedOut"
  | "unconfigured"
  | "forbidden";

type AdminRole = "owner" | "support" | "marketer";

type AdminSession = {
  success: true;
  userId: string;
  email: string | null;
  role: AdminRole;
  enabled: boolean;
};

type AuthContextValue = {
  status: AuthStatus;
  user: User | null;
  adminSession: AdminSession | null;
  isFirebaseConfigured: boolean;
  signInWithGoogle: () => Promise<void>;
  signOutUser: () => Promise<void>;
};

const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({children}: {children: ReactNode}) {
  const [status, setStatus] = useState<AuthStatus>(
    isFirebaseConfigured ? "checking" : "unconfigured"
  );
  const [user, setUser] = useState<User | null>(null);
  const [adminSession, setAdminSession] = useState<AdminSession | null>(null);

  useEffect(() => {
    if (!firebaseAuth || !firebaseFunctions) {
      setStatus("unconfigured");
      return;
    }

    const authClient = firebaseAuth;
    const functionsClient = firebaseFunctions;

    const unsubscribe = onAuthStateChanged(authClient, async (nextUser) => {
      setUser(nextUser);

      if (!nextUser) {
        setAdminSession(null);
        setStatus("signedOut");
        return;
      }

      setStatus("checking");

      try {
        const callable = httpsCallable<Record<string, never>, AdminSession>(
          functionsClient,
          "getAdminSession"
        );
        const result = await callable({});
        setAdminSession(result.data);
        setStatus("authenticated");
      } catch (error) {
        console.error("Failed to verify admin session", error);
        setAdminSession(null);
        setStatus("forbidden");
      }
    });

    return unsubscribe;
  }, []);

  const value = useMemo<AuthContextValue>(() => ({
    status,
    user,
    adminSession,
    isFirebaseConfigured,
    signInWithGoogle: async () => {
      if (!firebaseAuth) return;
      const provider = new GoogleAuthProvider();
      await signInWithPopup(firebaseAuth, provider);
    },
    signOutUser: async () => {
      if (!firebaseAuth) return;
      await signOut(firebaseAuth);
    },
  }), [adminSession, status, user]);

  return (
    <AuthContext.Provider value={value}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const value = useContext(AuthContext);

  if (!value) {
    throw new Error("useAuth must be used within AuthProvider");
  }

  return value;
}
