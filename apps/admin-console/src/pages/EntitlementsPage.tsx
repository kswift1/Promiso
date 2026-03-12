import {
  Card,
  CardContent,
  List,
  ListItem,
  ListItemText,
  Stack,
  Typography,
} from "@mui/material";

const tasks = [
  "Active subscription vs manual override 분리",
  "Grant / revoke / expiry / reason 입력",
  "모든 변경은 audit log 기록",
];

export function EntitlementsPage() {
  return (
    <Stack spacing={3}>
      <Stack spacing={1}>
        <Typography variant="h4">Entitlements</Typography>
        <Typography color="text.secondary">
          Apple 구독 상태와 운영자 수동 보정을 분리해서 다루는 화면입니다.
        </Typography>
      </Stack>

      <Card elevation={0}>
        <CardContent>
          <List>
            {tasks.map((task) => (
              <ListItem key={task} disableGutters>
                <ListItemText primary={task} />
              </ListItem>
            ))}
          </List>
        </CardContent>
      </Card>
    </Stack>
  );
}

