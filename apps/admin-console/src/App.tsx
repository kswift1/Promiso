import {Navigate, Route, Routes} from "react-router-dom";
import {AppShell} from "./layout/AppShell";
import {AuditLogsPage} from "./pages/AuditLogsPage";
import {DashboardPage} from "./pages/DashboardPage";
import {EntitlementsPage} from "./pages/EntitlementsPage";
import {PushJobsPage} from "./pages/PushJobsPage";
import {ReleaseControlsPage} from "./pages/ReleaseControlsPage";
import {UsersPage} from "./pages/UsersPage";

export function App() {
  return (
    <Routes>
      <Route element={<AppShell />}>
        <Route index element={<Navigate replace to="/dashboard" />} />
        <Route path="/dashboard" element={<DashboardPage />} />
        <Route path="/users" element={<UsersPage />} />
        <Route path="/entitlements" element={<EntitlementsPage />} />
        <Route path="/push-jobs" element={<PushJobsPage />} />
        <Route path="/release-controls" element={<ReleaseControlsPage />} />
        <Route path="/audit-logs" element={<AuditLogsPage />} />
      </Route>
    </Routes>
  );
}

