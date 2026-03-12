import CampaignRoundedIcon from "@mui/icons-material/CampaignRounded";
import HistoryRoundedIcon from "@mui/icons-material/HistoryRounded";
import HomeRoundedIcon from "@mui/icons-material/HomeRounded";
import PeopleRoundedIcon from "@mui/icons-material/PeopleRounded";
import TuneRoundedIcon from "@mui/icons-material/TuneRounded";
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

const drawerWidth = 260;

const navItems = [
  {label: "Dashboard", path: "/dashboard", icon: <HomeRoundedIcon />},
  {label: "Users", path: "/users", icon: <PeopleRoundedIcon />},
  {
    label: "Entitlements",
    path: "/entitlements",
    icon: <WorkspacePremiumRoundedIcon />,
  },
  {label: "Push Jobs", path: "/push-jobs", icon: <CampaignRoundedIcon />},
  {
    label: "Release Controls",
    path: "/release-controls",
    icon: <TuneRoundedIcon />,
  },
  {label: "Audit Logs", path: "/audit-logs", icon: <HistoryRoundedIcon />},
];

export function AppShell() {
  const location = useLocation();
  const navigate = useNavigate();
  const {adminSession, user, signOutUser} = useAuth();

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
              Promiso Internal Tool
            </Typography>
            <Typography variant="h6">Admin Console</Typography>
          </Stack>
          <Stack direction="row" spacing={2} alignItems="center">
            <Stack spacing={0.5} sx={{textAlign: "right"}}>
              <Typography variant="body2" color="text.secondary">
                {user?.email ?? "Unknown admin"}
              </Typography>
              <Typography variant="caption" color="text.secondary">
                {adminSession?.role ?? "unknown"} · release/v1.2.0
              </Typography>
            </Stack>
            <Button variant="outlined" onClick={() => void signOutUser()}>
              Sign out
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
              OPERATIONS
            </Typography>
            <Typography variant="h6">Promiso Admin</Typography>
          </Stack>
        </Toolbar>
        <List sx={{px: 1}}>
          {navItems.map((item) => {
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
