import {
  Alert,
  Card,
  CardContent,
  Chip,
  CircularProgress,
  Grid,
  Stack,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Typography,
} from "@mui/material";
import {useQuery} from "@tanstack/react-query";
import {useState} from "react";
import {
  Cell,
  Legend,
  Pie,
  PieChart,
  ResponsiveContainer,
  Tooltip,
  Bar,
  BarChart,
  CartesianGrid,
  XAxis,
  YAxis,
} from "recharts";
import {
  AdminAnalyticsWindowDays,
  getAdminAnalyticsSummary,
  getAdminProPlanDashboard,
} from "../api/admin";

const analyticsWindowOptions: AdminAnalyticsWindowDays[] = [1, 7, 30];

const PLAN_COLORS = {
  monthly: "#3b82f6",
  yearly: "#8b5cf6",
  lifetime: "#f59e0b",
  override: "#10b981",
  gracePeriod: "#ef4444",
};

function formatCurrency(value: number): string {
  return value.toLocaleString("ko-KR") + "원";
}

function getStatusColor(
  status: string
): "success" | "error" | "info" | "warning" | "default" {
  switch (status) {
    case "subscribed":
      return "success";
    case "expired":
    case "revoked":
      return "error";
    case "lifetime":
      return "info";
    case "gracePeriod":
      return "warning";
    default:
      return "default";
  }
}

function getStatusLabel(status: string): string {
  switch (status) {
    case "subscribed":
      return "구독 중";
    case "expired":
      return "만료";
    case "lifetime":
      return "평생";
    case "gracePeriod":
      return "유예";
    case "revoked":
      return "취소";
    case "none":
      return "없음";
    default:
      return status;
  }
}

function getProductLabel(productId: string | null): string {
  if (!productId) return "-";
  if (productId.endsWith(".monthly")) return "월간";
  if (productId.endsWith(".yearly")) return "연간";
  if (productId.endsWith(".lifetime")) return "평생";
  return productId;
}

export function ProPlanDashboardPage() {
  const [analyticsWindow, setAnalyticsWindow] =
    useState<AdminAnalyticsWindowDays>(7);

  const dashboardQuery = useQuery({
    queryKey: ["admin-proplan-dashboard"],
    queryFn: getAdminProPlanDashboard,
  });

  const analyticsQuery = useQuery({
    queryKey: ["admin-analytics-summary", analyticsWindow],
    queryFn: () => getAdminAnalyticsSummary({windowDays: analyticsWindow}),
  });

  const dashboard = dashboardQuery.data;

  const pieData = dashboard
    ? [
        {name: "월간", value: dashboard.breakdown.monthly.count, color: PLAN_COLORS.monthly},
        {name: "연간", value: dashboard.breakdown.yearly.count, color: PLAN_COLORS.yearly},
        {name: "평생", value: dashboard.breakdown.lifetime.count, color: PLAN_COLORS.lifetime},
        {name: "Override", value: dashboard.breakdown.override.count, color: PLAN_COLORS.override},
        {name: "유예", value: dashboard.breakdown.gracePeriod.count, color: PLAN_COLORS.gracePeriod},
      ].filter((d) => d.value > 0)
    : [];

  const funnelData = analyticsQuery.data?.ga4
    ? [
        {name: "가입", value: analyticsQuery.data.ga4.signups ?? 0},
        {name: "로그인", value: analyticsQuery.data.ga4.logins ?? 0},
        {name: "페이월", value: analyticsQuery.data.ga4.paywallOpens ?? 0},
        {name: "구매", value: analyticsQuery.data.ga4.paywallPurchases ?? 0},
      ]
    : [];

  return (
    <Stack spacing={3}>
      <Stack spacing={1}>
        <Typography variant="h4">Pro 플랜 대시보드</Typography>
        <Typography color="text.secondary">
          Pro 플랜 구독 현황, 수익, 전환 퍼널을 한 화면에서 확인합니다.
        </Typography>
      </Stack>

      {dashboardQuery.isLoading && (
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
                Pro 플랜 데이터를 불러오는 중입니다.
              </Typography>
            </Stack>
          </CardContent>
        </Card>
      )}

      {dashboardQuery.isError && (
        <Alert severity="error">
          Pro 플랜 대시보드를 불러오지 못했습니다.
        </Alert>
      )}

      {dashboard && (
        <>
          {/* 섹션 1: 개요 카드 */}
          <Stack spacing={2}>
            <Typography variant="h6">개요</Typography>
            <Grid container spacing={2}>
              {[
                {label: "전체 사용자", value: dashboard.overview.totalUsers.toLocaleString("ko-KR")},
                {label: "Pro 사용자", value: dashboard.overview.proUsers.toLocaleString("ko-KR")},
                {label: "Free 사용자", value: dashboard.overview.freeUsers.toLocaleString("ko-KR")},
                {label: "Pro 전환율", value: `${dashboard.overview.proRate}%`},
              ].map((card) => (
                <Grid key={card.label} size={{xs: 12, sm: 6, md: 3}}>
                  <Card elevation={0} sx={{height: "100%"}}>
                    <CardContent>
                      <Stack spacing={1}>
                        <Typography color="text.secondary" variant="body2">
                          {card.label}
                        </Typography>
                        <Typography variant="h4">{card.value}</Typography>
                      </Stack>
                    </CardContent>
                  </Card>
                </Grid>
              ))}
            </Grid>
          </Stack>

          {/* 섹션 2: 플랜 분포 */}
          <Stack spacing={2}>
            <Typography variant="h6">플랜 분포</Typography>
            <Grid container spacing={2}>
              <Grid size={{xs: 12, md: 6}}>
                <Card elevation={0} sx={{height: "100%"}}>
                  <CardContent>
                    {pieData.length > 0 ? (
                      <ResponsiveContainer width="100%" height={280}>
                        <PieChart>
                          <Pie
                            data={pieData}
                            cx="50%"
                            cy="50%"
                            innerRadius={60}
                            outerRadius={100}
                            dataKey="value"
                            label={({name, value}) => `${name} ${value}`}
                          >
                            {pieData.map((entry) => (
                              <Cell key={entry.name} fill={entry.color} />
                            ))}
                          </Pie>
                          <Tooltip />
                          <Legend />
                        </PieChart>
                      </ResponsiveContainer>
                    ) : (
                      <Stack alignItems="center" justifyContent="center" minHeight={280}>
                        <Typography color="text.secondary">
                          구독 데이터가 없습니다.
                        </Typography>
                      </Stack>
                    )}
                  </CardContent>
                </Card>
              </Grid>
              <Grid size={{xs: 12, md: 6}}>
                <Card elevation={0} sx={{height: "100%"}}>
                  <CardContent>
                    <Stack spacing={2}>
                      <Typography variant="subtitle1">플랜별 상세</Typography>
                      {[
                        {label: "월간 구독", count: dashboard.breakdown.monthly.count, color: PLAN_COLORS.monthly},
                        {label: "연간 구독", count: dashboard.breakdown.yearly.count, color: PLAN_COLORS.yearly},
                        {label: "평생 플랜", count: dashboard.breakdown.lifetime.count, color: PLAN_COLORS.lifetime},
                        {label: "Override (쿠폰/수동)", count: dashboard.breakdown.override.count, color: PLAN_COLORS.override},
                        {label: "유예 기간", count: dashboard.breakdown.gracePeriod.count, color: PLAN_COLORS.gracePeriod},
                      ].map((item) => (
                        <Stack
                          key={item.label}
                          direction="row"
                          justifyContent="space-between"
                          alignItems="center"
                        >
                          <Stack direction="row" spacing={1} alignItems="center">
                            <div
                              style={{
                                width: 12,
                                height: 12,
                                borderRadius: 2,
                                backgroundColor: item.color,
                              }}
                            />
                            <Typography variant="body2">{item.label}</Typography>
                          </Stack>
                          <Typography variant="h6">{item.count}</Typography>
                        </Stack>
                      ))}
                    </Stack>
                  </CardContent>
                </Card>
              </Grid>
            </Grid>
          </Stack>

          {/* 섹션 3: 예상 수익 */}
          <Stack spacing={2}>
            <Typography variant="h6">예상 수익</Typography>
            <Grid container spacing={2}>
              <Grid size={{xs: 12, sm: 6, md: 3}}>
                <Card elevation={0} sx={{height: "100%"}}>
                  <CardContent>
                    <Stack spacing={1}>
                      <Typography color="text.secondary" variant="body2">
                        예상 MRR
                      </Typography>
                      <Typography variant="h4">
                        {formatCurrency(dashboard.revenue.estimatedMRR)}
                      </Typography>
                      <Typography color="text.secondary" variant="caption">
                        월간 + 연간(월 환산)
                      </Typography>
                    </Stack>
                  </CardContent>
                </Card>
              </Grid>
              <Grid size={{xs: 12, sm: 6, md: 3}}>
                <Card elevation={0} sx={{height: "100%"}}>
                  <CardContent>
                    <Stack spacing={1}>
                      <Typography color="text.secondary" variant="body2">
                        월간 구독 수익
                      </Typography>
                      <Typography variant="h4">
                        {formatCurrency(dashboard.breakdown.monthly.revenue)}
                      </Typography>
                      <Typography color="text.secondary" variant="caption">
                        {dashboard.breakdown.monthly.count}명 × ₩{dashboard.prices.monthly.toLocaleString("ko-KR")}
                      </Typography>
                    </Stack>
                  </CardContent>
                </Card>
              </Grid>
              <Grid size={{xs: 12, sm: 6, md: 3}}>
                <Card elevation={0} sx={{height: "100%"}}>
                  <CardContent>
                    <Stack spacing={1}>
                      <Typography color="text.secondary" variant="body2">
                        연간 구독 수익
                      </Typography>
                      <Typography variant="h4">
                        {formatCurrency(dashboard.breakdown.yearly.revenue)}
                      </Typography>
                      <Typography color="text.secondary" variant="caption">
                        {dashboard.breakdown.yearly.count}명 × ₩{dashboard.prices.yearly.toLocaleString("ko-KR")}
                      </Typography>
                    </Stack>
                  </CardContent>
                </Card>
              </Grid>
              <Grid size={{xs: 12, sm: 6, md: 3}}>
                <Card elevation={0} sx={{height: "100%"}}>
                  <CardContent>
                    <Stack spacing={1}>
                      <Typography color="text.secondary" variant="body2">
                        평생 플랜 누적
                      </Typography>
                      <Typography variant="h4">
                        {formatCurrency(dashboard.revenue.totalLifetimeRevenue)}
                      </Typography>
                      <Typography color="text.secondary" variant="caption">
                        {dashboard.breakdown.lifetime.count}명 × ₩{dashboard.prices.lifetime.toLocaleString("ko-KR")}
                      </Typography>
                    </Stack>
                  </CardContent>
                </Card>
              </Grid>
            </Grid>
          </Stack>

          {/* 섹션 4: 퍼널 분석 */}
          <Stack spacing={2}>
            <Stack spacing={0.5}>
              <Typography variant="h6">전환 퍼널</Typography>
              <Typography color="text.secondary" variant="body2">
                GA4 이벤트 기준 가입부터 구매까지의 전환 흐름입니다.
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
                  <Stack alignItems="center" justifyContent="center" minHeight={180} spacing={1}>
                    <CircularProgress size={28} />
                    <Typography color="text.secondary">
                      퍼널 데이터를 불러오는 중입니다.
                    </Typography>
                  </Stack>
                </CardContent>
              </Card>
            )}

            {analyticsQuery.isError && (
              <Alert severity="error">
                퍼널 데이터를 불러오지 못했습니다.
              </Alert>
            )}

            {analyticsQuery.data && (
              <Card elevation={0}>
                <CardContent>
                  {analyticsQuery.data.ga4.available ? (
                    <ResponsiveContainer width="100%" height={280}>
                      <BarChart data={funnelData}>
                        <CartesianGrid strokeDasharray="3 3" />
                        <XAxis dataKey="name" />
                        <YAxis />
                        <Tooltip />
                        <Bar dataKey="value" fill="#3b82f6" radius={[4, 4, 0, 0]} />
                      </BarChart>
                    </ResponsiveContainer>
                  ) : (
                    <Alert severity="info">
                      {analyticsQuery.data.ga4.note ?? "GA4 데이터를 사용할 수 없습니다."}
                    </Alert>
                  )}
                </CardContent>
              </Card>
            )}
          </Stack>

          {/* 섹션 5: 쿠폰 현황 */}
          <Stack spacing={2}>
            <Typography variant="h6">쿠폰 현황</Typography>
            <Grid container spacing={2}>
              {[
                {label: "전체 쿠폰", value: dashboard.coupons.total},
                {label: "사용 가능", value: dashboard.coupons.available},
                {label: "사용됨", value: dashboard.coupons.redeemed},
                {label: "만료됨", value: dashboard.coupons.expired},
              ].map((card) => (
                <Grid key={card.label} size={{xs: 12, sm: 6, md: 3}}>
                  <Card elevation={0} sx={{height: "100%"}}>
                    <CardContent>
                      <Stack spacing={1}>
                        <Typography color="text.secondary" variant="body2">
                          {card.label}
                        </Typography>
                        <Typography variant="h4">{card.value}</Typography>
                      </Stack>
                    </CardContent>
                  </Card>
                </Grid>
              ))}
            </Grid>
          </Stack>

          {/* 섹션 6: Apple Offer Code 현황 */}
          <Stack spacing={2}>
            <Typography variant="h6">Apple Offer Code 현황</Typography>
            <Grid container spacing={2}>
              <Grid size={{xs: 12, sm: 6, md: 3}}>
                <Card elevation={0} sx={{height: "100%"}}>
                  <CardContent>
                    <Stack spacing={1}>
                      <Typography color="text.secondary" variant="body2">
                        총 사용 횟수
                      </Typography>
                      <Typography variant="h4">
                        {dashboard.offerCodes.totalRedemptions}
                      </Typography>
                    </Stack>
                  </CardContent>
                </Card>
              </Grid>
            </Grid>
            <Card elevation={0}>
              <TableContainer>
                <Table size="small">
                  <TableHead>
                    <TableRow>
                      <TableCell>사용자 ID</TableCell>
                      <TableCell>Offer Identifier</TableCell>
                      <TableCell>플랜</TableCell>
                      <TableCell>시각</TableCell>
                    </TableRow>
                  </TableHead>
                  <TableBody>
                    {dashboard.offerCodes.recentRedemptions.length === 0 ? (
                      <TableRow>
                        <TableCell colSpan={4} align="center">
                          <Typography color="text.secondary" variant="body2" sx={{py: 2}}>
                            Offer Code 사용 내역이 없습니다.
                          </Typography>
                        </TableCell>
                      </TableRow>
                    ) : (
                      dashboard.offerCodes.recentRedemptions.map((redemption) => (
                        <TableRow key={`${redemption.userId}-${redemption.redeemedAt}`}>
                          <TableCell>
                            <Typography variant="body2" sx={{fontFamily: "monospace", fontSize: 12}}>
                              {redemption.userId.slice(0, 12)}…
                            </Typography>
                          </TableCell>
                          <TableCell>
                            <Typography variant="body2" sx={{fontFamily: "monospace", fontSize: 12}}>
                              {redemption.offerIdentifier || "-"}
                            </Typography>
                          </TableCell>
                          <TableCell>{getProductLabel(redemption.productId)}</TableCell>
                          <TableCell>
                            <Typography variant="body2" color="text.secondary">
                              {redemption.redeemedAt
                                ? new Date(redemption.redeemedAt).toLocaleString("ko-KR")
                                : "-"}
                            </Typography>
                          </TableCell>
                        </TableRow>
                      ))
                    )}
                  </TableBody>
                </Table>
              </TableContainer>
            </Card>
          </Stack>

          {/* 섹션 7: 최근 구독 활동 */}
          <Stack spacing={2}>
            <Typography variant="h6">최근 구독 활동</Typography>
            <Card elevation={0}>
              <TableContainer>
                <Table size="small">
                  <TableHead>
                    <TableRow>
                      <TableCell>사용자 ID</TableCell>
                      <TableCell>상태</TableCell>
                      <TableCell>플랜</TableCell>
                      <TableCell>시각</TableCell>
                    </TableRow>
                  </TableHead>
                  <TableBody>
                    {dashboard.recentActivities.length === 0 ? (
                      <TableRow>
                        <TableCell colSpan={4} align="center">
                          <Typography color="text.secondary" variant="body2" sx={{py: 2}}>
                            최근 활동이 없습니다.
                          </Typography>
                        </TableCell>
                      </TableRow>
                    ) : (
                      dashboard.recentActivities.map((activity) => (
                        <TableRow key={`${activity.userId}-${activity.timestamp}`}>
                          <TableCell>
                            <Typography variant="body2" sx={{fontFamily: "monospace", fontSize: 12}}>
                              {activity.userId.slice(0, 12)}…
                            </Typography>
                          </TableCell>
                          <TableCell>
                            <Chip
                              label={getStatusLabel(activity.type)}
                              color={getStatusColor(activity.type)}
                              size="small"
                            />
                          </TableCell>
                          <TableCell>{getProductLabel(activity.productId)}</TableCell>
                          <TableCell>
                            <Typography variant="body2" color="text.secondary">
                              {new Date(activity.timestamp).toLocaleString("ko-KR")}
                            </Typography>
                          </TableCell>
                        </TableRow>
                      ))
                    )}
                  </TableBody>
                </Table>
              </TableContainer>
            </Card>
          </Stack>
        </>
      )}
    </Stack>
  );
}
