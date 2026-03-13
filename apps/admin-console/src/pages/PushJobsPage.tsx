import {
  Alert,
  Button,
  Card,
  CardContent,
  Checkbox,
  Chip,
  CircularProgress,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
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
  previewAdminPushAudience,
  scheduleAdminPush,
  sendAdminPush,
} from "../api/admin";

const minScheduleLeadTimeMinutes = 5;

function formatValue(value: string | null, fallback = "-"): string {
  return value && value.length > 0 ? value : fallback;
}

function getErrorMessage(error: unknown, fallback: string): string {
  return error instanceof Error && error.message.length > 0 ?
    error.message :
    fallback;
}

export function PushJobsPage() {
  const queryClient = useQueryClient();
  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");
  const [audience, setAudience] = useState<AdminPushAudience>("all");
  const [dryRun, setDryRun] = useState(true);
  const [testUserId, setTestUserId] = useState("");
  const [scheduledAt, setScheduledAt] = useState("");
  const [pendingAction, setPendingAction] = useState<"send" | "schedule" | null>(
    null
  );
  const [confirmed, setConfirmed] = useState(false);
  const [message, setMessage] = useState<{
    type: "success" | "error";
    text: string;
  } | null>(null);
  const trimmedTestUserId = testUserId.trim();
  const previewEnabled = audience !== "test_user" || trimmedTestUserId.length > 0;
  const scheduledDate = scheduledAt ? new Date(scheduledAt) : null;
  const scheduleLeadTimeValid = scheduledDate != null &&
    !Number.isNaN(scheduledDate.getTime()) &&
    scheduledDate.getTime() - Date.now() >=
      minScheduleLeadTimeMinutes * 60 * 1000;

  const previewQuery = useQuery({
    queryKey: ["admin-push-preview", audience, trimmedTestUserId],
    queryFn: () => previewAdminPushAudience({
      audience,
      testUserId: audience === "test_user" ? trimmedTestUserId : null,
    }),
    enabled: previewEnabled,
  });
  const jobsQuery = useQuery<AdminPushJob[]>({
    queryKey: ["admin-push-jobs", 20],
    queryFn: () => getAdminPushJobs({limit: 20}),
  });
  const targetCount = previewQuery.data ?? null;

  const sendMutation = useMutation({
    mutationFn: () => sendAdminPush({
      title: title.trim(),
      body: body.trim(),
      audience,
      dryRun,
      testUserId: audience === "test_user" ? trimmedTestUserId : null,
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
    onError: (error) => {
      setMessage({
        type: "error",
        text: getErrorMessage(error, "푸시 작업 실행에 실패했습니다."),
      });
    },
  });
  const scheduleMutation = useMutation({
    mutationFn: () => scheduleAdminPush({
      title: title.trim(),
      body: body.trim(),
      audience,
      scheduledAt: new Date(scheduledAt).toISOString(),
      testUserId: audience === "test_user" ? trimmedTestUserId : null,
    }),
    onSuccess: (result) => {
      void queryClient.invalidateQueries({queryKey: ["admin-push-jobs"]});
      setMessage({
        type: "success",
        text: `예약 완료: ${result.scheduledAt}`,
      });
    },
    onError: (error) => {
      setMessage({
        type: "error",
        text: getErrorMessage(error, "예약 푸시 생성에 실패했습니다."),
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
    onError: (error) => {
      setMessage({
        type: "error",
        text: getErrorMessage(error, "예약 푸시 취소에 실패했습니다."),
      });
    },
  });

  const canSubmit = title.trim().length > 0 &&
    body.trim().length > 0 &&
    (audience !== "test_user" || trimmedTestUserId.length > 0);
  const hasPreview = targetCount != null;
  const hasTargets = targetCount != null && targetCount > 0;
  const canSend = canSubmit &&
    hasPreview &&
    hasTargets &&
    !previewQuery.isFetching;
  const canSchedule = canSubmit &&
    hasPreview &&
    hasTargets &&
    scheduledAt.length > 0 &&
    scheduleLeadTimeValid &&
    !dryRun &&
    !previewQuery.isFetching;

  const resetConfirmation = () => {
    setPendingAction(null);
    setConfirmed(false);
  };

  const handleConfirm = () => {
    const action = pendingAction;
    resetConfirmation();
    setMessage(null);

    if (action === "send") {
      sendMutation.mutate();
      return;
    }

    if (action === "schedule") {
      scheduleMutation.mutate();
    }
  };

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
                  `dry-run`으로 먼저 확인한 뒤, 문제가 없으면 `dry-run`을 끄고
                  실제 1건을 보내 보는 것입니다.
                </Typography>
                <Typography variant="body2">
                  예약 발송은 실제 전송만 지원하고, 최소 5분 이후 시각만 허용합니다.
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

            <Card
              elevation={0}
              sx={{bgcolor: "rgba(15, 23, 42, 0.03)", borderRadius: 2}}
            >
              <CardContent>
                <Stack spacing={1}>
                  <Typography variant="subtitle2">Audience Preview</Typography>
                  {!previewEnabled ? (
                    <Typography color="text.secondary" variant="body2">
                      `test_user` 대상은 사용자 ID를 입력하면 preview가 표시됩니다.
                    </Typography>
                  ) : previewQuery.isPending ? (
                    <Stack direction="row" spacing={1} alignItems="center">
                      <CircularProgress size={18} />
                      <Typography color="text.secondary" variant="body2">
                        대상 수를 계산하는 중입니다.
                      </Typography>
                    </Stack>
                  ) : previewQuery.isError ? (
                    <Alert severity="error">
                      {getErrorMessage(
                        previewQuery.error,
                        "대상 수 preview를 불러오지 못했습니다."
                      )}
                    </Alert>
                  ) : hasPreview ? (
                    <Stack direction="row" spacing={1} alignItems="center">
                      <Chip label={audience} />
                      <Typography variant="body2">
                        현재 대상 수는 <strong>{targetCount}</strong>명입니다.
                      </Typography>
                    </Stack>
                  ) : (
                    <Typography color="text.secondary" variant="body2">
                      대상 선택 후 preview가 표시됩니다.
                    </Typography>
                  )}
                </Stack>
              </CardContent>
            </Card>

            {audience !== "test_user" && !dryRun && hasPreview && (
              <Alert severity="warning">
                {audience === "all" ?
                  `전체 사용자 ${targetCount}명에게 실제 푸시가 발송됩니다.` :
                  `${audience} 대상 ${targetCount}명에게 실제 푸시가 발송됩니다.`}
              </Alert>
            )}

            <TextField
              label="Scheduled At"
              type="datetime-local"
              value={scheduledAt}
              onChange={(event) => setScheduledAt(event.target.value)}
              InputLabelProps={{shrink: true}}
              helperText={
                scheduledAt.length > 0 && !scheduleLeadTimeValid ?
                  "예약 발송은 최소 5분 이후 시각만 허용됩니다." :
                  "비워 두면 즉시 실행만 가능합니다."
              }
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
                disabled={!canSend || sendMutation.isPending}
                onClick={() => {
                  setConfirmed(false);
                  setPendingAction("send");
                }}
              >
                {dryRun ? "Run Dry Check" : "Send Push"}
              </Button>
              <Button
                variant="outlined"
                disabled={!canSchedule || scheduleMutation.isPending}
                onClick={() => {
                  setConfirmed(false);
                  setPendingAction("schedule");
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

      <Dialog
        open={pendingAction != null}
        onClose={() => {
          if (!sendMutation.isPending && !scheduleMutation.isPending) {
            resetConfirmation();
          }
        }}
        fullWidth
        maxWidth="sm"
      >
        <DialogTitle>
          {pendingAction === "schedule" ?
            "Schedule Push 확인" :
            dryRun ?
              "Run Dry Check 확인" :
              "Send Push 확인"}
        </DialogTitle>
        <DialogContent>
          <Stack spacing={2} sx={{pt: 1}}>
            {audience === "all" ? (
              <Alert severity="warning">
                전체 사용자 대상 실제 발송입니다. 잘못 보내면 되돌릴 수 없습니다.
              </Alert>
            ) : audience !== "test_user" ? (
              <Alert severity="warning">
                다수 사용자 대상 실제 발송입니다. 대상 수와 문구를 다시 확인하세요.
              </Alert>
            ) : (
              <Alert severity="info">
                단일 테스트 사용자 대상입니다.
              </Alert>
            )}

            <Stack spacing={0.5}>
              <Typography variant="body2">
                Mode {pendingAction === "schedule" ? "schedule" : dryRun ? "dry-run" : "send"}
              </Typography>
              <Typography variant="body2">Audience {audience}</Typography>
              <Typography variant="body2">
                Target Count {targetCount ?? "-"}
              </Typography>
              {pendingAction === "schedule" && (
                <Typography variant="body2">
                  Scheduled At {scheduledAt || "-"}
                </Typography>
              )}
            </Stack>

            <Divider />

            <Stack spacing={0.5}>
              <Typography variant="subtitle2">{title.trim()}</Typography>
              <Typography color="text.secondary" variant="body2">
                {body.trim()}
              </Typography>
            </Stack>

            <FormControlLabel
              control={
                <Checkbox
                  checked={confirmed}
                  onChange={(event) => setConfirmed(event.target.checked)}
                />
              }
              label="대상 수와 발송 모드를 확인했고 그대로 진행합니다."
            />
          </Stack>
        </DialogContent>
        <DialogActions>
          <Button onClick={resetConfirmation}>Close</Button>
          <Button
            variant="contained"
            disabled={
              !confirmed ||
              sendMutation.isPending ||
              scheduleMutation.isPending
            }
            onClick={handleConfirm}
          >
            {pendingAction === "schedule" ?
              "Confirm Schedule" :
              dryRun ?
                "Confirm Dry Check" :
                "Confirm Send"}
          </Button>
        </DialogActions>
      </Dialog>
    </Stack>
  );
}
