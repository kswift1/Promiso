import {Box, CircularProgress} from "@mui/material";
import {Navigate, Route, Routes} from "react-router-dom";
import {useAuth} from "./auth/AuthProvider";
import {AppShell} from "./layout/AppShell";
import {AuditLogsPage} from "./pages/AuditLogsPage";
import {DashboardPage} from "./pages/DashboardPage";
import {EntitlementsPage} from "./pages/EntitlementsPage";
import {LoginPage} from "./pages/LoginPage";
import {PushJobsPage} from "./pages/PushJobsPage";
import {ReleaseControlsPage} from "./pages/ReleaseControlsPage";
import {UsersPage} from "./pages/UsersPage";

function LoadingScreen() {
  return (
    <Box
      sx={{
        minHeight: "100vh",
        display: "grid",
        placeItems: "center",
        bgcolor: "background.default",
      }}
    >
      <CircularProgress />
    </Box>
  );
}

function ProtectedShell() {
  const {status} = useAuth();

  if (status === "checking") {
    return <LoadingScreen />;
  }

  if (status !== "authenticated") {
    return <Navigate replace to="/login" />;
  }

  return <AppShell />;
}

function PublicOnlyRoute() {
  const {status} = useAuth();

  if (status === "checking") {
    return <LoadingScreen />;
  }

  if (status === "authenticated") {
    return <Navigate replace to="/dashboard" />;
  }

  return <LoginPage />;
}

export function App() {
  return (
    <Routes>
      <Route path="/login" element={<PublicOnlyRoute />} />
      <Route element={<ProtectedShell />}>
        <Route index element={<Navigate replace to="/dashboard" />} />
        <Route path="/dashboard" element={<DashboardPage />} />
        <Route path="/users" element={<UsersPage />} />
        <Route path="/entitlements" element={<EntitlementsPage />} />
        <Route path="/push-jobs" element={<PushJobsPage />} />
        <Route path="/release-controls" element={<ReleaseControlsPage />} />
        <Route path="/audit-logs" element={<AuditLogsPage />} />
      </Route>
      <Route path="*" element={<Navigate replace to="/dashboard" />} />
    </Routes>
  );
}
