import {
  Alert,
  Card,
  CardContent,
  Chip,
  CircularProgress,
  Grid,
  Stack,
  Typography,
} from "@mui/material";
import {useQuery} from "@tanstack/react-query";
import {getAdminDashboardSummary} from "../api/admin";

const featureStatuses = [
  {
    name: "Admin Auth + Role Guard",
    status: "implemented",
    note: "Google 로그인, admin allowlist, 역할별 라우트/서버 제한",
  },
  {
    name: "Users",
    status: "implemented",
    note: "userId / email / nickname exact 검색",
  },
  {
    name: "Entitlements",
    status: "implemented",
    note: "override grant / revoke, reason, expiresAt",
  },
  {
    name: "Push Jobs",
    status: "implemented",
    note: "all / pro / free / test_user, dry-run 포함",
  },
  {
    name: "Release Controls",
    status: "implemented",
    note: "Remote Config 현재 키 조회/수정",
  },
  {
    name: "Audit Logs",
    status: "implemented",
    note: "최신 50개 action 로그 조회",
  },
  {
    name: "Dashboard Metrics",
    status: "implemented",
    note: "실사용자 수, Pro 수, override 수, push/log 수",
  },
  {
    name: "Advanced Search / Filters",
    status: "implemented",
    note: "Users / Audit Logs 검색 필드와 상태 필터 지원",
  },
  {
    name: "Remote Config Feature Flags",
    status: "partial",
    note: "현재 template에 있는 핵심 키만 연결",
  },
  {
    name: "Scheduled Push",
    status: "implemented",
    note: "예약 생성, 취소, 대상 preview, 안전장치 포함",
  },
  {
    name: "User Detail Timeline",
    status: "implemented",
    note: "subscription / override / audit log 상세 조회",
  },
  {
    name: "Admin User Management UI",
    status: "implemented",
    note: "owner 전용 admin 등록, role 변경, enabled 관리",
  },
];

function getStatusColor(status: string): "success" | "warning" | "default" {
  if (status === "implemented") {
    return "success";
  }

  if (status === "partial") {
    return "warning";
  }

  return "default";
}

function getStatusLabel(status: string): string {
  if (status === "implemented") {
    return "Implemented";
  }

  if (status === "partial") {
    return "Partial";
  }

  return "Not Yet";
}

export function DashboardPage() {
  const summaryQuery = useQuery({
    queryKey: ["admin-dashboard-summary"],
    queryFn: getAdminDashboardSummary,
  });

  const summaryCards = summaryQuery.data ? [
    {
      label: "Total Users",
      value: summaryQuery.data.totalUsers,
    },
    {
      label: "Pro Users",
      value: summaryQuery.data.proUsers,
    },
    {
      label: "Free Users",
      value: summaryQuery.data.freeUsers,
    },
    {
      label: "Active Overrides",
      value: summaryQuery.data.activeOverrides,
    },
    {
      label: "Admin Accounts",
      value: summaryQuery.data.totalAdmins,
    },
    {
      label: "Push Jobs",
      value: summaryQuery.data.pushJobCount,
    },
    {
      label: "Audit Logs",
      value: summaryQuery.data.auditLogCount,
    },
    {
      label: "Remote Config",
      value: summaryQuery.data.remoteConfigVersion ?? "-",
      detail: summaryQuery.data.remoteConfigUpdatedAt ?? "-",
    },
  ] : [];

  return (
    <Stack spacing={3}>
      <Stack spacing={1}>
        <Typography variant="h4">Dashboard</Typography>
        <Typography color="text.secondary">
          운영 현황과 현재 구현 범위를 한 화면에서 확인합니다.
        </Typography>
      </Stack>

      {summaryQuery.isLoading && (
        <Card elevation={0}>
          <CardContent>
            <Stack
              alignItems="center"
              justifyContent="center"
              minHeight={200}
              spacing={1}
            >
              <CircularProgress size={28} />
              <Typography color="text.secondary">
                운영 요약을 불러오는 중입니다.
              </Typography>
            </Stack>
          </CardContent>
        </Card>
      )}

      {summaryQuery.isError && (
        <Alert severity="error">
          Dashboard 요약을 불러오지 못했습니다.
        </Alert>
      )}

      {summaryQuery.data && (
        <Stack spacing={2}>
          <Stack spacing={0.5}>
            <Typography variant="h6">Live Summary</Typography>
            <Typography color="text.secondary" variant="body2">
              stage Firestore와 Remote Config 기준 실데이터입니다.
            </Typography>
          </Stack>

          <Grid container spacing={2}>
            {summaryCards.map((card) => (
              <Grid key={card.label} size={{xs: 12, sm: 6, md: 3}}>
                <Card elevation={0} sx={{height: "100%"}}>
                  <CardContent>
                    <Stack spacing={1}>
                      <Typography color="text.secondary" variant="body2">
                        {card.label}
                      </Typography>
                      <Typography variant="h4">{card.value}</Typography>
                      {"detail" in card && card.detail && (
                        <Typography color="text.secondary" variant="caption">
                          {card.detail}
                        </Typography>
                      )}
                    </Stack>
                  </CardContent>
                </Card>
              </Grid>
            ))}
          </Grid>
        </Stack>
      )}

      <Stack spacing={2}>
        <Stack spacing={0.5}>
          <Typography variant="h6">Feature Status</Typography>
          <Typography color="text.secondary" variant="body2">
            피드백용으로 현재 구현 범위를 명시적으로 표시합니다.
          </Typography>
        </Stack>

        <Grid container spacing={2}>
          {featureStatuses.map((feature) => (
            <Grid key={feature.name} size={{xs: 12, md: 6}}>
              <Card elevation={0} sx={{height: "100%"}}>
                <CardContent>
                  <Stack spacing={1.5}>
                    <Chip
                      label={getStatusLabel(feature.status)}
                      color={getStatusColor(feature.status)}
                      sx={{alignSelf: "flex-start"}}
                    />
                    <Typography variant="subtitle1">{feature.name}</Typography>
                    <Typography color="text.secondary" variant="body2">
                      {feature.note}
                    </Typography>
                  </Stack>
                </CardContent>
              </Card>
            </Grid>
          ))}
        </Grid>
      </Stack>
    </Stack>
  );
}
