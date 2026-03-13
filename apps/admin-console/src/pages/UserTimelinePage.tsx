import {
  Alert,
  Button,
  Card,
  CardContent,
  Chip,
  CircularProgress,
  Divider,
  Grid,
  Stack,
  Typography,
} from "@mui/material";
import {useQuery} from "@tanstack/react-query";
import {Link as RouterLink, useParams} from "react-router-dom";
import {getAdminUserTimeline} from "../api/admin";

function formatJson(value: unknown): string {
  if (value == null) {
    return "null";
  }

  try {
    return JSON.stringify(value, null, 2);
  } catch {
    return String(value);
  }
}

function formatValue(value: string | null, fallback = "-"): string {
  return value && value.length > 0 ? value : fallback;
}

export function UserTimelinePage() {
  const params = useParams<{userId: string}>();
  const userId = params.userId ?? "";
  const timelineQuery = useQuery({
    queryKey: ["admin-user-timeline", userId],
    queryFn: () => getAdminUserTimeline({userId, limit: 20}),
    enabled: userId.length > 0,
  });

  return (
    <Stack spacing={3}>
      <Stack
        direction={{xs: "column", sm: "row"}}
        justifyContent="space-between"
        spacing={2}
      >
        <Stack spacing={1}>
          <Typography variant="h4">User Timeline</Typography>
          <Typography color="text.secondary">
            사용자별 현재 상태와 운영 이력을 한 화면에서 확인합니다.
          </Typography>
        </Stack>

        <Stack direction="row" spacing={1}>
          <Button component={RouterLink} to="/users" variant="outlined">
            Back to Users
          </Button>
          <Button
            component={RouterLink}
            to={`/entitlements?userId=${userId}`}
            variant="contained"
          >
            Manage entitlement
          </Button>
        </Stack>
      </Stack>

      {timelineQuery.isPending && (
        <Card elevation={0}>
          <CardContent>
            <Stack
              alignItems="center"
              justifyContent="center"
              minHeight={240}
              spacing={1}
            >
              <CircularProgress size={28} />
              <Typography color="text.secondary">
                사용자 timeline을 불러오는 중입니다.
              </Typography>
            </Stack>
          </CardContent>
        </Card>
      )}

      {timelineQuery.isError && (
        <Alert severity="error">
          사용자 timeline을 불러오지 못했습니다.
        </Alert>
      )}

      {timelineQuery.data && (
        <Stack spacing={3}>
          <Card elevation={0}>
            <CardContent>
              <Stack spacing={2}>
                <Stack spacing={0.5}>
                  <Typography variant="h5">
                    {timelineQuery.data.summary.nickname ??
                      timelineQuery.data.summary.name ??
                      timelineQuery.data.summary.userId}
                  </Typography>
                  <Typography color="text.secondary" variant="body2">
                    {timelineQuery.data.summary.userId}
                  </Typography>
                  <Typography color="text.secondary" variant="body2">
                    {formatValue(timelineQuery.data.summary.email, "email unavailable")}
                  </Typography>
                </Stack>

                <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
                  <Chip
                    color={timelineQuery.data.summary.subscriptionStatus ?
                      "primary" :
                      "default"}
                    label={
                      timelineQuery.data.summary.subscriptionStatus ??
                      "no subscription"
                    }
                  />
                  <Chip
                    color={timelineQuery.data.summary.overrideActive ?
                      "secondary" :
                      "default"}
                    label={
                      timelineQuery.data.summary.overrideActive ?
                        "override active" :
                        "override none"
                    }
                  />
                  <Chip label={`groups ${timelineQuery.data.summary.groupCount}`} />
                  <Chip label={`devices ${timelineQuery.data.summary.deviceCount}`} />
                </Stack>
              </Stack>
            </CardContent>
          </Card>

          <Grid container spacing={2}>
            <Grid size={{xs: 12, md: 6}}>
              <Card elevation={0} sx={{height: "100%"}}>
                <CardContent>
                  <Stack spacing={1.5}>
                    <Typography variant="h6">Subscription</Typography>
                    <Typography variant="body2" color="text.secondary">
                      Status {formatValue(timelineQuery.data.subscription.status)}
                    </Typography>
                    <Typography variant="body2" color="text.secondary">
                      Product {formatValue(timelineQuery.data.subscription.productId)}
                    </Typography>
                    <Typography variant="body2" color="text.secondary">
                      Purchase {formatValue(timelineQuery.data.subscription.purchaseDate)}
                    </Typography>
                    <Typography variant="body2" color="text.secondary">
                      Expiration {formatValue(timelineQuery.data.subscription.expirationDate)}
                    </Typography>
                    <Typography variant="body2" color="text.secondary">
                      Updated {formatValue(timelineQuery.data.subscription.updatedAt)}
                    </Typography>
                  </Stack>
                </CardContent>
              </Card>
            </Grid>

            <Grid size={{xs: 12, md: 6}}>
              <Card elevation={0} sx={{height: "100%"}}>
                <CardContent>
                  <Stack spacing={1.5}>
                    <Typography variant="h6">Entitlement Override</Typography>
                    <Typography variant="body2" color="text.secondary">
                      Active {timelineQuery.data.override?.isActive ? "yes" : "no"}
                    </Typography>
                    <Typography variant="body2" color="text.secondary">
                      Type {formatValue(timelineQuery.data.override?.type ?? null)}
                    </Typography>
                    <Typography variant="body2" color="text.secondary">
                      Reason {formatValue(timelineQuery.data.override?.reason ?? null)}
                    </Typography>
                    <Typography variant="body2" color="text.secondary">
                      Expires {formatValue(timelineQuery.data.override?.expiresAt ?? null)}
                    </Typography>
                    <Typography variant="body2" color="text.secondary">
                      Created {formatValue(timelineQuery.data.override?.createdAt ?? null)}
                    </Typography>
                    <Typography variant="body2" color="text.secondary">
                      Revoked {formatValue(timelineQuery.data.override?.revokedAt ?? null)}
                    </Typography>
                  </Stack>
                </CardContent>
              </Card>
            </Grid>
          </Grid>

          <Stack spacing={2}>
            <Stack spacing={0.5}>
              <Typography variant="h6">Audit Timeline</Typography>
              <Typography color="text.secondary" variant="body2">
                대상 user와 직접 연결된 최근 audit log를 표시합니다.
              </Typography>
            </Stack>

            {timelineQuery.data.auditLogs.length === 0 ? (
              <Alert severity="info">
                이 사용자와 직접 연결된 Audit Log가 아직 없습니다.
              </Alert>
            ) : (
              <Stack spacing={2}>
                {timelineQuery.data.auditLogs.map((log) => (
                  <Card key={log.id} elevation={0}>
                    <CardContent>
                      <Stack spacing={1.5}>
                        <Stack spacing={0.5}>
                          <Typography variant="subtitle1">
                            {log.action ?? "-"}
                          </Typography>
                          <Typography color="text.secondary" variant="body2">
                            Actor {log.actorId ?? "-"}
                          </Typography>
                          <Typography color="text.secondary" variant="body2">
                            Created At {log.createdAt ?? "-"}
                          </Typography>
                        </Stack>

                        <Divider />

                        <Stack spacing={1}>
                          <Typography variant="subtitle2">Before</Typography>
                          <Typography
                            component="pre"
                            sx={{
                              bgcolor: "rgba(15, 23, 42, 0.04)",
                              borderRadius: 2,
                              fontFamily: "monospace",
                              fontSize: 12,
                              m: 0,
                              overflowX: "auto",
                              p: 2,
                            }}
                          >
                            {formatJson(log.before)}
                          </Typography>
                        </Stack>

                        <Stack spacing={1}>
                          <Typography variant="subtitle2">After</Typography>
                          <Typography
                            component="pre"
                            sx={{
                              bgcolor: "rgba(15, 23, 42, 0.04)",
                              borderRadius: 2,
                              fontFamily: "monospace",
                              fontSize: 12,
                              m: 0,
                              overflowX: "auto",
                              p: 2,
                            }}
                          >
                            {formatJson(log.after)}
                          </Typography>
                        </Stack>
                      </Stack>
                    </CardContent>
                  </Card>
                ))}
              </Stack>
            )}
          </Stack>
        </Stack>
      )}
    </Stack>
  );
}
