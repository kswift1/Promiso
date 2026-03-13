import {
  Alert,
  Button,
  Card,
  CardContent,
  Stack,
  TextField,
  Typography,
} from "@mui/material";
import {useMutation} from "@tanstack/react-query";
import {useEffect, useMemo, useState} from "react";
import {useSearchParams} from "react-router-dom";
import {
  grantEntitlementOverride,
  revokeEntitlementOverride,
} from "../api/admin";

export function EntitlementsPage() {
  const [searchParams] = useSearchParams();
  const [userId, setUserId] = useState("");
  const [reason, setReason] = useState("");
  const [expiresAt, setExpiresAt] = useState("");
  const [message, setMessage] = useState<{
    type: "success" | "error";
    text: string;
  } | null>(null);

  useEffect(() => {
    const nextUserId = searchParams.get("userId");
    if (nextUserId) {
      setUserId(nextUserId);
    }
  }, [searchParams]);

  const expiresAtISO = useMemo(
    () => (expiresAt ? new Date(expiresAt).toISOString() : null),
    [expiresAt]
  );

  const grantMutation = useMutation({
    mutationFn: () => grantEntitlementOverride({
      userId: userId.trim(),
      reason: reason.trim(),
      expiresAt: expiresAtISO,
    }),
    onSuccess: () => {
      setMessage({
        type: "success",
        text: "override를 부여했습니다.",
      });
    },
    onError: () => {
      setMessage({
        type: "error",
        text: "override 부여에 실패했습니다.",
      });
    },
  });

  const revokeMutation = useMutation({
    mutationFn: () => revokeEntitlementOverride({
      userId: userId.trim(),
      reason: reason.trim() || null,
    }),
    onSuccess: () => {
      setMessage({
        type: "success",
        text: "override를 회수했습니다.",
      });
    },
    onError: () => {
      setMessage({
        type: "error",
        text: "override 회수에 실패했습니다.",
      });
    },
  });

  const canGrant = userId.trim().length > 0 && reason.trim().length > 0;
  const canRevoke = userId.trim().length > 0;

  return (
    <Stack spacing={3}>
      <Stack spacing={1}>
        <Typography variant="h4">override 관리</Typography>
        <Typography color="text.secondary">
          Apple 구독 상태와 운영자 수동 보정을 분리해서 다루는 화면입니다.
        </Typography>
      </Stack>

      <Card elevation={0}>
        <CardContent>
          <Stack spacing={2}>
            <TextField
              label="사용자 ID"
              placeholder="대상 사용자 ID"
              value={userId}
              onChange={(event) => setUserId(event.target.value)}
              fullWidth
            />
            <TextField
              label="사유"
              placeholder="보상 사유"
              value={reason}
              onChange={(event) => setReason(event.target.value)}
              fullWidth
            />
            <TextField
              label="만료 시각"
              type="datetime-local"
              value={expiresAt}
              onChange={(event) => setExpiresAt(event.target.value)}
              InputLabelProps={{shrink: true}}
              fullWidth
            />

            {message && (
              <Alert severity={message.type}>
                {message.text}
              </Alert>
            )}

            <Stack direction="row" spacing={1}>
              <Button
                variant="contained"
                disabled={!canGrant || grantMutation.isPending}
                onClick={() => {
                  setMessage(null);
                  grantMutation.mutate();
                }}
              >
                override 부여
              </Button>
              <Button
                variant="outlined"
                color="warning"
                disabled={!canRevoke || revokeMutation.isPending}
                onClick={() => {
                  setMessage(null);
                  revokeMutation.mutate();
                }}
              >
                override 회수
              </Button>
            </Stack>
          </Stack>
        </CardContent>
      </Card>
    </Stack>
  );
}
