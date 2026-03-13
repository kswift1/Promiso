import {useEffect, useState} from "react";
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
  const [logs, setLogs] = useState<AdminAuditLog[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const loadLogs = async (isManualRefresh = false) => {
    if (isManualRefresh) {
      setIsRefreshing(true);
    } else {
      setIsLoading(true);
    }

    setErrorMessage(null);

    try {
      const nextLogs = await getAdminAuditLogs(50);
      setLogs(nextLogs);
    } catch (error) {
      setErrorMessage(
        error instanceof Error ?
          error.message :
          "Audit Logs를 불러오지 못했습니다."
      );
    } finally {
      setIsLoading(false);
      setIsRefreshing(false);
    }
  };

  useEffect(() => {
    loadLogs();
  }, []);

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
          onClick={() => loadLogs(true)}
          disabled={isRefreshing}
        >
          {isRefreshing ? "Refreshing..." : "Refresh"}
        </Button>
      </Stack>

      {errorMessage && <Alert severity="error">{errorMessage}</Alert>}

      {isLoading ? (
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
