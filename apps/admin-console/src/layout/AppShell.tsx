import AdminPanelSettingsRoundedIcon from "@mui/icons-material/AdminPanelSettingsRounded";
import CampaignRoundedIcon from "@mui/icons-material/CampaignRounded";
import HistoryRoundedIcon from "@mui/icons-material/HistoryRounded";
import HomeRoundedIcon from "@mui/icons-material/HomeRounded";
import PeopleRoundedIcon from "@mui/icons-material/PeopleRounded";
import TuneRoundedIcon from "@mui/icons-material/TuneRounded";
import ConfirmationNumberRoundedIcon from "@mui/icons-material/ConfirmationNumberRounded";
import WorkspacePremiumRoundedIcon from "@mui/icons-material/WorkspacePremiumRounded";
import {
  AppBar,
  Box,
  Button,
  Drawer,
  List,
  ListItemButton,
  ListItemIcon,
  ListItemText,
  Stack,
  Toolbar,
  Typography,
} from "@mui/material";
import {Outlet, useLocation, useNavigate} from "react-router-dom";
import {useAuth} from "../auth/AuthProvider";
import {AdminRole, getAdminRoleLabel, hasAdminRole} from "../auth/adminRoles";
import packageJson from "../../package.json";

const drawerWidth = 260;
const adminConsoleVersionLabel = `v${packageJson.version}`;

const navItems = [
  {
    label: "대시보드",
    path: "/dashboard",
    icon: <HomeRoundedIcon />,
  },
  {
    label: "관리자 계정",
    path: "/admin-users",
    icon: <AdminPanelSettingsRoundedIcon />,
    allowedRoles: ["owner"] as AdminRole[],
  },
  {
    label: "사용자",
    path: "/users",
    icon: <PeopleRoundedIcon />,
    allowedRoles: ["owner", "support"] as AdminRole[],
  },
  {
    label: "override 관리",
    path: "/entitlements",
    icon: <WorkspacePremiumRoundedIcon />,
    allowedRoles: ["owner", "support"] as AdminRole[],
  },
  {
    label: "쿠폰 관리",
    path: "/coupons",
    icon: <ConfirmationNumberRoundedIcon />,
    allowedRoles: ["owner", "marketer"] as AdminRole[],
  },
  {
    label: "푸시 작업",
    path: "/push-jobs",
    icon: <CampaignRoundedIcon />,
    allowedRoles: ["owner", "marketer"] as AdminRole[],
  },
  {
    label: "릴리스 제어",
    path: "/release-controls",
    icon: <TuneRoundedIcon />,
    allowedRoles: ["owner", "marketer"] as AdminRole[],
  },
  {label: "감사 로그", path: "/audit-logs", icon: <HistoryRoundedIcon />},
];

export function AppShell() {
  const location = useLocation();
  const navigate = useNavigate();
  const {adminSession, user, signOutUser} = useAuth();
  const visibleNavItems = navItems.filter((item) =>
    hasAdminRole(adminSession?.role, item.allowedRoles)
  );

  return (
    <Box sx={{display: "flex", minHeight: "100vh"}}>
      <AppBar
        position="fixed"
        elevation={0}
        sx={{
          width: `calc(100% - ${drawerWidth}px)`,
          ml: `${drawerWidth}px`,
          bgcolor: "background.paper",
          borderBottom: "1px solid",
          borderColor: "divider",
          color: "text.primary",
        }}
      >
        <Toolbar sx={{justifyContent: "space-between"}}>
          <Stack spacing={0.5}>
            <Typography variant="subtitle2" color="text.secondary">
              Promiso 운영 도구
            </Typography>
            <Typography variant="h6">운영 콘솔</Typography>
          </Stack>
          <Stack direction="row" spacing={2} alignItems="center">
            <Stack spacing={0.5} sx={{textAlign: "right"}}>
              <Typography variant="body2" color="text.secondary">
                {user?.email ?? "알 수 없는 관리자"}
              </Typography>
              <Typography variant="caption" color="text.secondary">
                {getAdminRoleLabel(adminSession?.role)} · {adminConsoleVersionLabel}
              </Typography>
            </Stack>
            <Button variant="outlined" onClick={() => void signOutUser()}>
              로그아웃
            </Button>
          </Stack>
        </Toolbar>
      </AppBar>

      <Drawer
        variant="permanent"
        sx={{
          width: drawerWidth,
          flexShrink: 0,
          "& .MuiDrawer-paper": {
            width: drawerWidth,
            boxSizing: "border-box",
            borderRight: "1px solid",
            borderColor: "divider",
            bgcolor: "#0f172a",
            color: "#f8fafc",
          },
        }}
      >
        <Toolbar>
          <Stack spacing={0.5}>
            <Typography variant="overline" sx={{color: "#94a3b8"}}>
              운영
            </Typography>
            <Typography variant="h6">Promiso 운영</Typography>
          </Stack>
        </Toolbar>
        <List sx={{px: 1}}>
          {visibleNavItems.map((item) => {
            const selected = location.pathname === item.path;
            return (
              <ListItemButton
                key={item.path}
                selected={selected}
                onClick={() => navigate(item.path)}
                sx={{
                  borderRadius: 2,
                  mb: 0.5,
                  "&.Mui-selected": {
                    bgcolor: "rgba(59, 130, 246, 0.18)",
                  },
                  "&.Mui-selected:hover": {
                    bgcolor: "rgba(59, 130, 246, 0.24)",
                  },
                }}
              >
                <ListItemIcon sx={{color: "#cbd5e1", minWidth: 40}}>
                  {item.icon}
                </ListItemIcon>
                <ListItemText primary={item.label} />
              </ListItemButton>
            );
          })}
        </List>
      </Drawer>

      <Box component="main" sx={{flexGrow: 1, p: 4, ml: `${drawerWidth}px`, mt: 8}}>
        <Outlet />
      </Box>
    </Box>
  );
}
