import {
  Alert,
  Button,
  Card,
  CardContent,
  CircularProgress,
  Divider,
  Stack,
  Typography,
} from "@mui/material";
import {useQuery} from "@tanstack/react-query";
import {AdminAuditLog, getAdminAuditLogs} from "../api/admin";

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

export function AuditLogsPage() {
  const logsQuery = useQuery<AdminAuditLog[]>({
    queryKey: ["admin-audit-logs", 50],
    queryFn: () => getAdminAuditLogs(50),
  });
  const errorMessage = logsQuery.error instanceof Error ?
    logsQuery.error.message :
    logsQuery.isError ?
      "Audit Logs를 불러오지 못했습니다." :
      null;
  const logs = logsQuery.data ?? [];

  return (
    <Stack spacing={3}>
      <Stack
        direction={{xs: "column", sm: "row"}}
        justifyContent="space-between"
        spacing={2}
      >
        <Stack spacing={1}>
          <Typography variant="h4">Audit Logs</Typography>
          <Typography color="text.secondary">
            위험한 액션은 모두 기록되고 추적 가능해야 합니다.
          </Typography>
        </Stack>

        <Button
          variant="outlined"
          onClick={() => void logsQuery.refetch()}
          disabled={logsQuery.isRefetching}
        >
          {logsQuery.isRefetching ? "Refreshing..." : "Refresh"}
        </Button>
      </Stack>

      {errorMessage && <Alert severity="error">{errorMessage}</Alert>}

      {logsQuery.isPending ? (
        <Card elevation={0}>
          <CardContent>
            <Stack
              alignItems="center"
              justifyContent="center"
              minHeight={240}
            >
              <CircularProgress size={28} />
            </Stack>
          </CardContent>
        </Card>
      ) : (
        <Stack spacing={2}>
          {logs.map((log) => (
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
                      Target {log.targetType ?? "-"} / {log.targetId ?? "-"}
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
  );
}
