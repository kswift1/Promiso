import {
  Card,
  CardContent,
  Chip,
  Stack,
  TextField,
  Typography,
} from "@mui/material";

export function UsersPage() {
  return (
    <Stack spacing={3}>
      <Stack spacing={1}>
        <Typography variant="h4">Users</Typography>
        <Typography color="text.secondary">
          userId, email, nickname 중심의 운영 조회 화면입니다.
        </Typography>
      </Stack>

      <Card elevation={0}>
        <CardContent>
          <Stack spacing={2}>
            <TextField
              label="Search users"
              placeholder="userId / email / nickname"
              fullWidth
            />
            <Stack direction="row" spacing={1}>
              <Chip label="Subscription status" />
              <Chip label="Override status" />
              <Chip label="Devices" />
              <Chip label="Recent audit logs" />
            </Stack>
          </Stack>
        </CardContent>
      </Card>
    </Stack>
  );
}

