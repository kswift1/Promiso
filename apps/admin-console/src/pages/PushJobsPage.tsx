import {
  Card,
  CardContent,
  Chip,
  Stack,
  TextField,
  Typography,
} from "@mui/material";

export function PushJobsPage() {
  return (
    <Stack spacing={3}>
      <Stack spacing={1}>
        <Typography variant="h4">Push Jobs</Typography>
        <Typography color="text.secondary">
          전체 공지와 조건 발송을 다루는 운영 화면입니다.
        </Typography>
      </Stack>

      <Card elevation={0}>
        <CardContent>
          <Stack spacing={2}>
            <TextField label="Title" placeholder="공지사항" fullWidth />
            <TextField
              label="Body"
              placeholder="원하는 메시지를 입력하세요"
              multiline
              minRows={4}
              fullWidth
            />
            <Stack direction="row" spacing={1}>
              <Chip label="Dry run" color="primary" />
              <Chip label="Test send" color="secondary" />
              <Chip label="All users" />
              <Chip label="Pro users" />
              <Chip label="Free users" />
            </Stack>
          </Stack>
        </CardContent>
      </Card>
    </Stack>
  );
}

