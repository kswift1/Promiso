import {
  Alert,
  Button,
  Card,
  CardContent,
  Checkbox,
  Chip,
  CircularProgress,
  Divider,
  FormControlLabel,
  MenuItem,
  Stack,
  TextField,
  Typography,
} from "@mui/material";
import {useMutation, useQuery, useQueryClient} from "@tanstack/react-query";
import {useState} from "react";
import {
  AdminPushAudience,
  AdminPushJob,
  cancelAdminPushJob,
  getAdminPushJobs,
  scheduleAdminPush,
  sendAdminPush,
} from "../api/admin";

function formatValue(value: string | null, fallback = "-"): string {
  return value && value.length > 0 ? value : fallback;
}

export function PushJobsPage() {
  const queryClient = useQueryClient();
  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");
  const [audience, setAudience] = useState<AdminPushAudience>("all");
  const [dryRun, setDryRun] = useState(true);
  const [testUserId, setTestUserId] = useState("");
  const [scheduledAt, setScheduledAt] = useState("");
  const [message, setMessage] = useState<{
    type: "success" | "error";
    text: string;
  } | null>(null);
  const jobsQuery = useQuery<AdminPushJob[]>({
    queryKey: ["admin-push-jobs", 20],
    queryFn: () => getAdminPushJobs({limit: 20}),
  });

  const mutation = useMutation({
    mutationFn: () => sendAdminPush({
      title: title.trim(),
      body: body.trim(),
      audience,
      dryRun,
      testUserId: audience === "test_user" ? testUserId.trim() : null,
    }),
    onSuccess: (result) => {
      void queryClient.invalidateQueries({queryKey: ["admin-push-jobs"]});
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
  const scheduleMutation = useMutation({
    mutationFn: () => scheduleAdminPush({
      title: title.trim(),
      body: body.trim(),
      audience,
      scheduledAt: new Date(scheduledAt).toISOString(),
      testUserId: audience === "test_user" ? testUserId.trim() : null,
    }),
    onSuccess: (result) => {
      void queryClient.invalidateQueries({queryKey: ["admin-push-jobs"]});
      setMessage({
        type: "success",
        text: `예약 완료: ${result.scheduledAt}`,
      });
    },
    onError: () => {
      setMessage({
        type: "error",
        text: "예약 푸시 생성에 실패했습니다.",
      });
    },
  });
  const cancelMutation = useMutation({
    mutationFn: (jobId: string) => cancelAdminPushJob({jobId}),
    onSuccess: () => {
      void queryClient.invalidateQueries({queryKey: ["admin-push-jobs"]});
      setMessage({
        type: "success",
        text: "예약 푸시를 취소했습니다.",
      });
    },
    onError: () => {
      setMessage({
        type: "error",
        text: "예약 푸시 취소에 실패했습니다.",
      });
    },
  });

  const canSubmit = title.trim().length > 0 &&
    body.trim().length > 0 &&
    (audience !== "test_user" || testUserId.trim().length > 0);
  const canSchedule = canSubmit &&
    scheduledAt.length > 0 &&
    !dryRun;

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
                <Typography variant="body2">
                  예약 발송은 실제 전송만 지원합니다. `dry-run`은 즉시 실행에서만
                  사용할 수 있습니다.
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

            <TextField
              label="Scheduled At"
              type="datetime-local"
              value={scheduledAt}
              onChange={(event) => setScheduledAt(event.target.value)}
              InputLabelProps={{shrink: true}}
              fullWidth
            />

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
              <Button
                variant="outlined"
                disabled={!canSchedule || scheduleMutation.isPending}
                onClick={() => {
                  setMessage(null);
                  scheduleMutation.mutate();
                }}
              >
                Schedule Push
              </Button>
            </Stack>
          </Stack>
        </CardContent>
      </Card>

      <Stack spacing={2}>
        <Stack
          direction={{xs: "column", sm: "row"}}
          justifyContent="space-between"
          spacing={1}
        >
          <Stack spacing={0.5}>
            <Typography variant="h6">Recent Jobs</Typography>
            <Typography color="text.secondary" variant="body2">
              최근 push job 20개를 상태와 함께 확인합니다.
            </Typography>
          </Stack>
          <Button
            variant="text"
            onClick={() => void jobsQuery.refetch()}
            disabled={jobsQuery.isRefetching}
          >
            {jobsQuery.isRefetching ? "Refreshing..." : "Refresh"}
          </Button>
        </Stack>

        {jobsQuery.isPending ? (
          <Card elevation={0}>
            <CardContent>
              <Stack
                alignItems="center"
                justifyContent="center"
                minHeight={180}
                spacing={1}
              >
                <CircularProgress size={24} />
                <Typography color="text.secondary">
                  push job 목록을 불러오는 중입니다.
                </Typography>
              </Stack>
            </CardContent>
          </Card>
        ) : jobsQuery.isError ? (
          <Alert severity="error">
            push job 목록을 불러오지 못했습니다.
          </Alert>
        ) : jobsQuery.data && jobsQuery.data.length > 0 ? (
          <Stack spacing={2}>
            {jobsQuery.data.map((job) => (
              <Card key={job.id} elevation={0}>
                <CardContent>
                  <Stack spacing={1.5}>
                    <Stack
                      direction={{xs: "column", sm: "row"}}
                      justifyContent="space-between"
                      spacing={1}
                    >
                      <Stack spacing={0.5}>
                        <Typography variant="subtitle1">{job.title}</Typography>
                        <Typography color="text.secondary" variant="body2">
                          {job.body}
                        </Typography>
                      </Stack>
                      <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
                        <Chip label={job.status} />
                        <Chip label={job.audience} />
                        {job.dryRun && <Chip label="dry-run" />}
                      </Stack>
                    </Stack>

                    <Divider />

                    <Stack spacing={0.5}>
                      <Typography color="text.secondary" variant="body2">
                        Scheduled {formatValue(job.scheduledAt)}
                      </Typography>
                      <Typography color="text.secondary" variant="body2">
                        Created {formatValue(job.createdAt)}
                      </Typography>
                      <Typography color="text.secondary" variant="body2">
                        Completed {formatValue(job.completedAt)}
                      </Typography>
                      <Typography color="text.secondary" variant="body2">
                        Target Count {job.targetCount ?? "-"}
                      </Typography>
                      <Typography color="text.secondary" variant="body2">
                        Result {job.result ?
                          `success ${job.result.successCount} / failure ${job.result.failureCount}` :
                          "-"}
                      </Typography>
                      <Typography color="text.secondary" variant="body2">
                        Error {formatValue(job.errorMessage)}
                      </Typography>
                    </Stack>

                    {job.status === "scheduled" && (
                      <Stack direction="row" spacing={1}>
                        <Button
                          variant="outlined"
                          color="warning"
                          disabled={
                            cancelMutation.isPending &&
                            cancelMutation.variables === job.id
                          }
                          onClick={() => {
                            setMessage(null);
                            cancelMutation.mutate(job.id);
                          }}
                        >
                          Cancel Scheduled Push
                        </Button>
                      </Stack>
                    )}
                  </Stack>
                </CardContent>
              </Card>
            ))}
          </Stack>
        ) : (
          <Alert severity="info">
            아직 생성된 push job이 없습니다.
          </Alert>
        )}
      </Stack>
    </Stack>
  );
}
