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
    name: "관리자 인증 + 권한 가드",
    status: "implemented",
    note: "Google 로그인, 관리자 허용 목록, 역할별 라우트/서버 제한",
  },
  {
    name: "사용자",
    status: "implemented",
    note: "사용자 ID / 이메일 / 닉네임 정확 일치 검색",
  },
  {
    name: "Pro 수동 변경",
    status: "implemented",
    note: "Pro 수동 부여 / 회수, 사유, 만료 시각",
  },
  {
    name: "푸시 작업",
    status: "implemented",
    note: "전체 / 유료 / 무료 / 테스트 사용자 대상, 사전 점검 포함",
  },
  {
    name: "릴리스 제어",
    status: "implemented",
    note: "섹션형 원격 설정 관리, 역할별 수정 제한, 저장 전 확인",
  },
  {
    name: "감사 로그",
    status: "implemented",
    note: "최신 50개 동작 로그 조회",
  },
  {
    name: "대시보드 지표",
    status: "implemented",
    note: "실사용자 수, 유료 사용자 수, 수동 변경 수, 푸시/로그 수, 조회 기간",
  },
  {
    name: "고급 검색 / 필터",
    status: "implemented",
    note: "사용자 / 감사 로그 검색 필드와 상태 필터 지원",
  },
  {
    name: "원격 설정 기능 플래그",
    status: "implemented",
    note: "현재 앱이 쓰는 허용된 원격 설정 키를 운영 가이드와 함께 관리",
  },
  {
    name: "예약 푸시",
    status: "implemented",
    note: "예약 생성, 취소, 대상 미리보기, 안전장치 포함",
  },
  {
    name: "사용자 상세 이력",
    status: "implemented",
    note: "subscription / 수동 변경 / 감사 로그 상세 조회",
  },
  {
    name: "관리자 계정 관리 화면",
    status: "implemented",
    note: "소유자 전용 관리자 등록, 권한 변경, 활성화 관리",
  },
  {
    name: "운영 분석 초기 버전",
    status: "implemented",
    note: "GA4 최근 이벤트 + BigQuery 퍼널, 설정 미완료 시 대체 안내",
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
    return "구현됨";
  }

  if (status === "partial") {
    return "일부 구현";
  }

  return "미구현";
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
      label: "회원가입 수",
      value: analytics.ga4.signups,
      detail: "GA4 이벤트 수",
    },
    {
      label: "로그인 수",
      value: analytics.ga4.logins,
      detail: "GA4 이벤트 수",
    },
    {
      label: "페이월 열기 수",
      value: analytics.ga4.paywallOpens,
      detail: "GA4 이벤트 수",
    },
    {
      label: "페이월 결제 수",
      value: analytics.ga4.paywallPurchases,
      detail: "GA4 이벤트 수",
    },
  ];
}

function buildBigQueryMetrics(analytics: AdminAnalyticsSummary) {
  return [
    {
      label: "회원가입 사용자 수",
      value: analytics.bigQuery.signups,
      detail: "내보낸 이벤트 기준 고유 사용자 수",
    },
    {
      label: "페이월 열기 사용자 수",
      value: analytics.bigQuery.paywallOpens,
      detail: "내보낸 이벤트 기준 고유 사용자 수",
    },
    {
      label: "페이월 결제 사용자 수",
      value: analytics.bigQuery.paywallPurchases,
      detail: "내보낸 이벤트 기준 고유 사용자 수",
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
      label: "전체 사용자",
      value: summaryQuery.data.totalUsers,
    },
    {
      label: "유료 사용자",
      value: summaryQuery.data.proUsers,
    },
    {
      label: "무료 사용자",
      value: summaryQuery.data.freeUsers,
    },
    {
      label: "활성 수동 변경",
      value: summaryQuery.data.activeOverrides,
    },
    {
      label: "관리자 계정",
      value: summaryQuery.data.totalAdmins,
    },
    {
      label: "푸시 작업",
      value: summaryQuery.data.pushJobCount,
    },
    {
      label: "감사 로그",
      value: summaryQuery.data.auditLogCount,
    },
    {
      label: "원격 설정",
      value: summaryQuery.data.remoteConfigVersion ?? "-",
      detail: summaryQuery.data.remoteConfigUpdatedAt ?? "-",
    },
  ] : [];

  return (
    <Stack spacing={3}>
      <Stack spacing={1}>
        <Typography variant="h4">대시보드</Typography>
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
                    `실시간 요약`은 운영 총량 확인용
                  </Typography>
                  <Typography color="text.secondary" variant="body2">
                    전체 사용자 수, 활성 수동 변경 수, 푸시/로그 총량처럼
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
                    회원가입, 로그인, 페이월 열기, 페이월 결제 같은 앱 이벤트 수를
                    최근 1/7/30일 기준으로 확인합니다.
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
                    Analytics 내보내기가 켜져 있어야 하고, 초기 설정 후 반영까지
                    시간이 걸릴 수 있습니다. 값이 없으면 아래 설정 안내를 먼저
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
          대시보드 요약을 불러오지 못했습니다.
        </Alert>
      )}

      {summaryQuery.data && (
        <Stack spacing={2}>
          <Stack spacing={0.5}>
            <Typography variant="h6">실시간 요약</Typography>
            <Typography color="text.secondary" variant="body2">
              stage Firestore와 원격 설정 기준 실데이터입니다.
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
          <Typography variant="h6">운영 분석</Typography>
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
                  분석 요약을 불러오는 중입니다.
                </Typography>
              </Stack>
            </CardContent>
          </Card>
        )}

        {analyticsQuery.isError && (
          <Alert severity="error">
            분석 요약을 불러오지 못했습니다.
          </Alert>
        )}

        {analyticsQuery.data && (
          <Grid container spacing={2}>
            <Grid size={{xs: 12, md: 6}}>
              <AnalyticsMetricsCard
                title="GA4 최근 이벤트"
                description={
                  `최근 ${analyticsQuery.data.windowDays}일 기준 GA4 이벤트 수입니다.`
                }
                note={analyticsQuery.data.ga4.note}
                metrics={buildGa4Metrics(analyticsQuery.data)}
                severity="warning"
              />
            </Grid>
            <Grid size={{xs: 12, md: 6}}>
              <AnalyticsMetricsCard
                title="BigQuery 이력 퍼널"
                description={
                  `최근 ${analyticsQuery.data.windowDays}일 기준 내보낸 이벤트 고유 사용자 수입니다.`
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
          <Typography variant="h6">기능 현황</Typography>
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
