import {
  Alert,
  Button,
  Card,
  CardContent,
  Chip,
  CircularProgress,
  Grid,
  Stack,
  TextField,
  Typography,
} from "@mui/material";
import {useQuery} from "@tanstack/react-query";
import {FormEvent, useState} from "react";
import {getAdminUserSummary} from "../api/admin";

export function UsersPage() {
  const [inputValue, setInputValue] = useState("");
  const [submittedQuery, setSubmittedQuery] = useState("");
  const query = useQuery({
    queryKey: ["admin-user-summary", submittedQuery],
    queryFn: () => getAdminUserSummary(submittedQuery),
    enabled: submittedQuery.length > 0,
  });

  const handleSubmit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const trimmed = inputValue.trim();
    if (!trimmed) return;
    setSubmittedQuery(trimmed);
  };

  return (
    <Stack spacing={3}>
      <Stack spacing={1}>
        <Typography variant="h4">Users</Typography>
        <Typography color="text.secondary">
          userId, email, nickname 기준의 운영 검색 화면입니다.
        </Typography>
      </Stack>

      <Card elevation={0}>
        <CardContent>
          <Stack component="form" spacing={2} onSubmit={handleSubmit}>
            <TextField
              label="Search users"
              placeholder="userId / email / nickname"
              fullWidth
              value={inputValue}
              onChange={(event) => setInputValue(event.target.value)}
            />
            <Stack direction="row" spacing={1}>
              <Button type="submit" variant="contained">
                Search
              </Button>
              <Chip label="Subscription status" />
              <Chip label="Override status" />
              <Chip label="Devices" />
            </Stack>
          </Stack>
        </CardContent>
      </Card>

      {query.isLoading && (
        <Stack direction="row" spacing={1} alignItems="center">
          <CircularProgress size={20} />
          <Typography color="text.secondary">검색 중입니다.</Typography>
        </Stack>
      )}

      {query.isError && (
        <Alert severity="error">
          사용자 요약 조회에 실패했습니다.
        </Alert>
      )}

      {submittedQuery.length > 0 && query.data && query.data.length === 0 && (
        <Alert severity="info">
          일치하는 사용자를 찾지 못했습니다.
        </Alert>
      )}

      {query.data && query.data.length > 0 && (
        <Grid container spacing={2}>
          {query.data.map((user) => (
            <Grid key={user.userId} size={{xs: 12, md: 6}}>
              <Card elevation={0}>
                <CardContent>
                  <Stack spacing={2}>
                    <Stack spacing={0.5}>
                      <Typography variant="h6">
                        {user.nickname ?? user.name ?? user.userId}
                      </Typography>
                      <Typography variant="body2" color="text.secondary">
                        {user.userId}
                      </Typography>
                    </Stack>

                    <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
                      <Chip
                        color={user.subscriptionStatus ? "primary" : "default"}
                        label={user.subscriptionStatus ?? "no subscription"}
                      />
                      <Chip
                        color={user.overrideActive ? "secondary" : "default"}
                        label={user.overrideActive ? "override active" : "override none"}
                      />
                      <Chip label={`groups ${user.groupCount}`} />
                      <Chip label={`devices ${user.deviceCount}`} />
                    </Stack>

                    <Typography variant="body2" color="text.secondary">
                      {user.email ?? "email unavailable"}
                    </Typography>
                  </Stack>
                </CardContent>
              </Card>
            </Grid>
          ))}
        </Grid>
      )}
    </Stack>
  );
}
