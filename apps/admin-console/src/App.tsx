import {Box, CircularProgress} from "@mui/material";
import type {ReactElement} from "react";
import {Navigate, Route, Routes} from "react-router-dom";
import {useAuth} from "./auth/AuthProvider";
import {AdminRole, hasAdminRole} from "./auth/adminRoles";
import {AppShell} from "./layout/AppShell";
import {AdminUsersPage} from "./pages/AdminUsersPage";
import {AuditLogsPage} from "./pages/AuditLogsPage";
import {DashboardPage} from "./pages/DashboardPage";
import {EntitlementsPage} from "./pages/EntitlementsPage";
import {LoginPage} from "./pages/LoginPage";
import {PushJobsPage} from "./pages/PushJobsPage";
import {ReleaseControlsPage} from "./pages/ReleaseControlsPage";
import {UserTimelinePage} from "./pages/UserTimelinePage";
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

function RoleProtectedRoute(props: {
  allowedRoles?: AdminRole[];
  children: ReactElement;
}) {
  const {adminSession} = useAuth();

  if (!hasAdminRole(adminSession?.role, props.allowedRoles)) {
    return <Navigate replace to="/dashboard" />;
  }

  return props.children;
}

export function App() {
  return (
    <Routes>
      <Route path="/login" element={<PublicOnlyRoute />} />
      <Route element={<ProtectedShell />}>
        <Route index element={<Navigate replace to="/dashboard" />} />
        <Route path="/dashboard" element={<DashboardPage />} />
        <Route
          path="/admin-users"
          element={
            <RoleProtectedRoute allowedRoles={["owner"]}>
              <AdminUsersPage />
            </RoleProtectedRoute>
          }
        />
        <Route
          path="/users/:userId/timeline"
          element={
            <RoleProtectedRoute allowedRoles={["owner", "support"]}>
              <UserTimelinePage />
            </RoleProtectedRoute>
          }
        />
        <Route
          path="/users"
          element={
            <RoleProtectedRoute allowedRoles={["owner", "support"]}>
              <UsersPage />
            </RoleProtectedRoute>
          }
        />
        <Route
          path="/entitlements"
          element={
            <RoleProtectedRoute allowedRoles={["owner", "support"]}>
              <EntitlementsPage />
            </RoleProtectedRoute>
          }
        />
        <Route
          path="/push-jobs"
          element={
            <RoleProtectedRoute allowedRoles={["owner", "marketer"]}>
              <PushJobsPage />
            </RoleProtectedRoute>
          }
        />
        <Route
          path="/release-controls"
          element={
            <RoleProtectedRoute allowedRoles={["owner", "marketer"]}>
              <ReleaseControlsPage />
            </RoleProtectedRoute>
          }
        />
        <Route path="/audit-logs" element={<AuditLogsPage />} />
      </Route>
      <Route path="*" element={<Navigate replace to="/dashboard" />} />
    </Routes>
  );
}
