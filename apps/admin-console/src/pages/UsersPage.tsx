import {
  Alert,
  Button,
  Card,
  CardContent,
  Chip,
  CircularProgress,
  Grid,
  MenuItem,
  Stack,
  TextField,
  Typography,
} from "@mui/material";
import {useQuery} from "@tanstack/react-query";
import {FormEvent, useState} from "react";
import {Link as RouterLink} from "react-router-dom";
import {
  AdminOverrideFilter,
  AdminSubscriptionFilter,
  AdminUserSearchField,
  getAdminUserSummary,
} from "../api/admin";

const defaultSearchFilters = {
  query: "",
  field: "all" as AdminUserSearchField,
  subscription: "all" as AdminSubscriptionFilter,
  override: "all" as AdminOverrideFilter,
  limit: 25,
};

export function UsersPage() {
  const [filters, setFilters] = useState(defaultSearchFilters);
  const [submittedFilters, setSubmittedFilters] = useState(
    defaultSearchFilters
  );
  const query = useQuery({
    queryKey: ["admin-user-summary", submittedFilters],
    queryFn: () => getAdminUserSummary({
      ...submittedFilters,
      query: submittedFilters.query || undefined,
    }),
  });

  const handleSubmit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();

    setSubmittedFilters({
      ...filters,
      query: filters.query.trim(),
    });
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
            <Alert severity="info">
              검색어는 exact match 기준입니다. 화면 진입 시 기본 25명을 먼저
              보여주고, 검색/필터를 적용하면 결과를 다시 조회합니다.
            </Alert>

            <TextField
              label="Search users"
              placeholder="userId / email / nickname"
              fullWidth
              value={filters.query}
              onChange={(event) =>
                setFilters((current) => ({
                  ...current,
                  query: event.target.value,
                }))
              }
            />

            <Grid container spacing={2}>
              <Grid size={{xs: 12, md: 4}}>
                <TextField
                  select
                  label="Search field"
                  value={filters.field}
                  onChange={(event) =>
                    setFilters((current) => ({
                      ...current,
                      field: event.target.value as AdminUserSearchField,
                    }))
                  }
                  fullWidth
                >
                  <MenuItem value="all">All fields</MenuItem>
                  <MenuItem value="userId">User ID</MenuItem>
                  <MenuItem value="email">Email</MenuItem>
                  <MenuItem value="nickname">Nickname</MenuItem>
                </TextField>
              </Grid>

              <Grid size={{xs: 12, md: 4}}>
                <TextField
                  select
                  label="Subscription"
                  value={filters.subscription}
                  onChange={(event) =>
                    setFilters((current) => ({
                      ...current,
                      subscription: event.target.value as AdminSubscriptionFilter,
                    }))
                  }
                  fullWidth
                >
                  <MenuItem value="all">All users</MenuItem>
                  <MenuItem value="subscribed">Subscribed</MenuItem>
                  <MenuItem value="not_subscribed">Not subscribed</MenuItem>
                </TextField>
              </Grid>

              <Grid size={{xs: 12, md: 4}}>
                <TextField
                  select
                  label="Override"
                  value={filters.override}
                  onChange={(event) =>
                    setFilters((current) => ({
                      ...current,
                      override: event.target.value as AdminOverrideFilter,
                    }))
                  }
                  fullWidth
                >
                  <MenuItem value="all">All override states</MenuItem>
                  <MenuItem value="active">Override active</MenuItem>
                  <MenuItem value="inactive">Override inactive</MenuItem>
                </TextField>
              </Grid>
            </Grid>

            <Stack direction="row" spacing={1}>
              <Button type="submit" variant="contained">
                Search
              </Button>
              <Button
                type="button"
                variant="text"
                onClick={() => {
                  setFilters(defaultSearchFilters);
                  setSubmittedFilters(defaultSearchFilters);
                }}
              >
                Reset
              </Button>
              <Chip
                label={submittedFilters?.subscription === "all" ?
                  "All subscriptions" :
                  submittedFilters?.subscription ?? "Subscription"}
              />
              <Chip
                label={submittedFilters?.override === "all" ?
                  "All overrides" :
                  submittedFilters?.override ?? "Override"}
              />
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

      {query.data && query.data.length === 0 && (
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

                    <Stack direction="row" spacing={1}>
                      <Button
                        component={RouterLink}
                        to={`/users/${user.userId}/timeline`}
                        variant="contained"
                        size="small"
                      >
                        View timeline
                      </Button>
                      <Button
                        component={RouterLink}
                        to={`/entitlements?userId=${user.userId}`}
                        variant="text"
                        size="small"
                      >
                        Manage entitlement
                      </Button>
                    </Stack>
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
