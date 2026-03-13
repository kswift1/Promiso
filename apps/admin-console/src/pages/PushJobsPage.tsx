import {
  Alert,
  Button,
  Card,
  CardContent,
  Checkbox,
  FormControlLabel,
  MenuItem,
  Stack,
  TextField,
  Typography,
} from "@mui/material";
import {useMutation} from "@tanstack/react-query";
import {useState} from "react";
import {
  AdminPushAudience,
  sendAdminPush,
} from "../api/admin";

export function PushJobsPage() {
  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");
  const [audience, setAudience] = useState<AdminPushAudience>("all");
  const [dryRun, setDryRun] = useState(true);
  const [testUserId, setTestUserId] = useState("");
  const [message, setMessage] = useState<{
    type: "success" | "error";
    text: string;
  } | null>(null);

  const mutation = useMutation({
    mutationFn: () => sendAdminPush({
      title: title.trim(),
      body: body.trim(),
      audience,
      dryRun,
      testUserId: audience === "test_user" ? testUserId.trim() : null,
    }),
    onSuccess: (result) => {
      setMessage({
        type: "success",
        text: dryRun ?
          `dry-run 완료: 대상 ${result.targetCount}명` :
          `발송 완료: 대상 ${result.targetCount}명, 성공 ${result.successCount}건`,
      });
    },
    onError: () => {
      setMessage({
        type: "error",
        text: "푸시 작업 실행에 실패했습니다.",
      });
    },
  });

  const canSubmit = title.trim().length > 0 &&
    body.trim().length > 0 &&
    (audience !== "test_user" || testUserId.trim().length > 0);

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
            <Alert severity="info">
              <Stack spacing={0.5}>
                <Typography variant="body2">
                  <strong>Tip.</strong> `dry-run`이 켜져 있으면 실제 푸시는
                  발송되지 않고, 대상 수와 타겟 매칭만 확인합니다.
                </Typography>
                <Typography variant="body2">
                  가장 안전한 순서는 `test_user`로 내 계정을 넣고,
                  `dry-run`으로 먼저 확인한 뒤, 문제가 없으면 `dry-run`을
                  끄고 실제 1건을 보내 보는 것입니다.
                </Typography>
                <Typography variant="body2">
                  그 다음에만 `all`, `pro`, `free` 같은 큰 대상 발송으로
                  넘어가는 편이 안전합니다.
                </Typography>
              </Stack>
            </Alert>

            <TextField
              label="Title"
              placeholder="공지사항"
              value={title}
              onChange={(event) => setTitle(event.target.value)}
              fullWidth
            />
            <TextField
              label="Body"
              placeholder="원하는 메시지를 입력하세요"
              multiline
              minRows={4}
              value={body}
              onChange={(event) => setBody(event.target.value)}
              fullWidth
            />
            <TextField
              select
              label="Audience"
              value={audience}
              onChange={(event) =>
                setAudience(event.target.value as AdminPushAudience)
              }
              fullWidth
            >
              <MenuItem value="all">All users</MenuItem>
              <MenuItem value="pro">Pro users</MenuItem>
              <MenuItem value="free">Free users</MenuItem>
              <MenuItem value="test_user">Single test user</MenuItem>
            </TextField>

            {audience === "test_user" && (
              <TextField
                label="Test User ID"
                placeholder="target user id"
                value={testUserId}
                onChange={(event) => setTestUserId(event.target.value)}
                fullWidth
              />
            )}

            <FormControlLabel
              control={
                <Checkbox
                  checked={dryRun}
                  onChange={(event) => setDryRun(event.target.checked)}
                />
              }
              label="Dry run only"
            />

            {message && (
              <Alert severity={message.type}>
                {message.text}
              </Alert>
            )}

            <Stack direction="row" spacing={1}>
              <Button
                variant="contained"
                disabled={!canSubmit || mutation.isPending}
                onClick={() => {
                  setMessage(null);
                  mutation.mutate();
                }}
              >
                {dryRun ? "Run Dry Check" : "Send Push"}
              </Button>
            </Stack>
          </Stack>
        </CardContent>
      </Card>
    </Stack>
  );
}
