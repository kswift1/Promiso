import {
  Card,
  CardContent,
  Stack,
  Typography,
} from "@mui/material";

export function AuditLogsPage() {
  return (
    <Stack spacing={3}>
      <Stack spacing={1}>
        <Typography variant="h4">Audit Logs</Typography>
        <Typography color="text.secondary">
          위험한 액션은 모두 기록되고 추적 가능해야 합니다.
        </Typography>
      </Stack>

      <Card elevation={0}>
        <CardContent>
          <Typography variant="body2" color="text.secondary">
            actor, action, target, before, after, createdAt 중심의 로그 테이블을
            이곳에 배치합니다.
          </Typography>
        </CardContent>
      </Card>
    </Stack>
  );
}

