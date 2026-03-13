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
import {useState} from "react";
import {
  AdminAnalyticsSummary,
  AdminAnalyticsWindowDays,
  getAdminAnalyticsSummary,
  getAdminDashboardSummary,
} from "../api/admin";

const analyticsWindowOptions: AdminAnalyticsWindowDays[] = [1, 7, 30];

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
    note: "섹션형 Remote Config 관리, 역할별 수정 제한, 저장 전 확인",
  },
  {
    name: "Audit Logs",
    status: "implemented",
    note: "최신 50개 action 로그 조회",
  },
  {
    name: "Dashboard Metrics",
    status: "implemented",
    note: "실사용자 수, Pro 수, override 수, push/log 수, analytics window",
  },
  {
    name: "Advanced Search / Filters",
    status: "implemented",
    note: "Users / Audit Logs 검색 필드와 상태 필터 지원",
  },
  {
    name: "Remote Config Feature Flags",
    status: "implemented",
    note: "현재 앱이 쓰는 allowlisted Remote Config 키를 운영 가이드와 함께 관리",
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
  {
    name: "Operational Analytics MVP",
    status: "implemented",
    note: "GA4 recent events + BigQuery funnel, 설정 미완료 시 fallback 안내",
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

function formatMetricValue(value: number | null): string {
  return value == null ? "-" : value.toLocaleString("ko-KR");
}

function AnalyticsMetricsCard(props: {
  title: string;
  description: string;
  note: string | null;
  metrics: Array<{
    label: string;
    value: number | null;
    detail: string;
  }>;
  severity: "info" | "warning";
}) {
  return (
    <Card elevation={0} sx={{height: "100%"}}>
      <CardContent>
        <Stack spacing={2}>
          <Stack spacing={0.5}>
            <Typography variant="h6">{props.title}</Typography>
            <Typography color="text.secondary" variant="body2">
              {props.description}
            </Typography>
          </Stack>

          {props.note && (
            <Alert severity={props.severity}>{props.note}</Alert>
          )}

          <Grid container spacing={2}>
            {props.metrics.map((metric) => (
              <Grid key={metric.label} size={{xs: 12, sm: 6}}>
                <Card
                  elevation={0}
                  sx={{height: "100%", border: "1px solid", borderColor: "divider"}}
                >
                  <CardContent>
                    <Stack spacing={1}>
                      <Typography color="text.secondary" variant="body2">
                        {metric.label}
                      </Typography>
                      <Typography variant="h4">
                        {formatMetricValue(metric.value)}
                      </Typography>
                      <Typography color="text.secondary" variant="caption">
                        {metric.detail}
                      </Typography>
                    </Stack>
                  </CardContent>
                </Card>
              </Grid>
            ))}
          </Grid>
        </Stack>
      </CardContent>
    </Card>
  );
}

function buildGa4Metrics(analytics: AdminAnalyticsSummary) {
  return [
    {
      label: "Signups",
      value: analytics.ga4.signups,
      detail: "GA4 event count",
    },
    {
      label: "Logins",
      value: analytics.ga4.logins,
      detail: "GA4 event count",
    },
    {
      label: "Paywall Opens",
      value: analytics.ga4.paywallOpens,
      detail: "GA4 event count",
    },
    {
      label: "Paywall Purchases",
      value: analytics.ga4.paywallPurchases,
      detail: "GA4 event count",
    },
  ];
}

function buildBigQueryMetrics(analytics: AdminAnalyticsSummary) {
  return [
    {
      label: "Signup Users",
      value: analytics.bigQuery.signups,
      detail: "distinct users in exported events",
    },
    {
      label: "Paywall Open Users",
      value: analytics.bigQuery.paywallOpens,
      detail: "distinct users in exported events",
    },
    {
      label: "Paywall Purchase Users",
      value: analytics.bigQuery.paywallPurchases,
      detail: "distinct users in exported events",
    },
  ];
}

export function DashboardPage() {
  const [analyticsWindow, setAnalyticsWindow] =
    useState<AdminAnalyticsWindowDays>(7);

  const summaryQuery = useQuery({
    queryKey: ["admin-dashboard-summary"],
    queryFn: getAdminDashboardSummary,
  });
  const analyticsQuery = useQuery({
    queryKey: ["admin-analytics-summary", analyticsWindow],
    queryFn: () => getAdminAnalyticsSummary({windowDays: analyticsWindow}),
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

      <Card elevation={0}>
        <CardContent>
          <Stack spacing={2}>
            <Typography variant="h6">운영 가이드</Typography>
            <Stack spacing={1.5}>
              <Stack direction="row" spacing={1.5} alignItems="flex-start">
                <Chip label="1" size="small" />
                <Stack spacing={0.5}>
                  <Typography variant="subtitle2">
                    `Live Summary`는 운영 총량 확인용
                  </Typography>
                  <Typography color="text.secondary" variant="body2">
                    전체 사용자 수, 활성 override 수, push/log 총량처럼
                    현재 운영 규모를 빠르게 확인할 때 봅니다.
                  </Typography>
                </Stack>
              </Stack>
              <Stack direction="row" spacing={1.5} alignItems="flex-start">
                <Chip label="2" size="small" />
                <Stack spacing={0.5}>
                  <Typography variant="subtitle2">
                    `GA4`는 최근 이벤트 흐름 확인용
                  </Typography>
                  <Typography color="text.secondary" variant="body2">
                    signup, login, paywall open, paywall purchase 같은 앱 이벤트
                    수를 최근 1/7/30일 기준으로 확인합니다.
                  </Typography>
                </Stack>
              </Stack>
              <Stack direction="row" spacing={1.5} alignItems="flex-start">
                <Chip label="3" size="small" />
                <Stack spacing={0.5}>
                  <Typography variant="subtitle2">
                    `BigQuery`는 이력 기반 퍼널 확인용
                  </Typography>
                  <Typography color="text.secondary" variant="body2">
                    Analytics export가 켜져 있어야 하고, 초기 설정 후 반영까지
                    시간이 걸릴 수 있습니다. 값이 없으면 아래 setup note를 먼저
                    확인합니다.
                  </Typography>
                </Stack>
              </Stack>
            </Stack>
          </Stack>
        </CardContent>
      </Card>

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
          <Typography variant="h6">Operational Analytics</Typography>
          <Typography color="text.secondary" variant="body2">
            기간 선택 기준의 앱 이벤트와 퍼널 지표를 함께 봅니다.
          </Typography>
        </Stack>

        <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
          {analyticsWindowOptions.map((windowDays) => (
            <Chip
              key={windowDays}
              label={`${windowDays}일`}
              color={analyticsWindow === windowDays ? "primary" : "default"}
              onClick={() => setAnalyticsWindow(windowDays)}
              clickable
            />
          ))}
        </Stack>

        {analyticsQuery.isLoading && (
          <Card elevation={0}>
            <CardContent>
              <Stack
                alignItems="center"
                justifyContent="center"
                minHeight={180}
                spacing={1}
              >
                <CircularProgress size={28} />
                <Typography color="text.secondary">
                  analytics 요약을 불러오는 중입니다.
                </Typography>
              </Stack>
            </CardContent>
          </Card>
        )}

        {analyticsQuery.isError && (
          <Alert severity="error">
            analytics 요약을 불러오지 못했습니다.
          </Alert>
        )}

        {analyticsQuery.data && (
          <Grid container spacing={2}>
            <Grid size={{xs: 12, md: 6}}>
              <AnalyticsMetricsCard
                title="GA4 Recent Events"
                description={
                  `최근 ${analyticsQuery.data.windowDays}일 기준 GA4 event count입니다.`
                }
                note={analyticsQuery.data.ga4.note}
                metrics={buildGa4Metrics(analyticsQuery.data)}
                severity="warning"
              />
            </Grid>
            <Grid size={{xs: 12, md: 6}}>
              <AnalyticsMetricsCard
                title="BigQuery Historical Funnel"
                description={
                  `최근 ${analyticsQuery.data.windowDays}일 기준 exported events distinct user 수입니다.`
                }
                note={analyticsQuery.data.bigQuery.note}
                metrics={buildBigQueryMetrics(analyticsQuery.data)}
                severity="info"
              />
            </Grid>
          </Grid>
        )}
      </Stack>

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
