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
import {FormEvent, useCallback, useEffect, useState} from "react";
import {Link as RouterLink} from "react-router-dom";
import {
  AdminOverrideFilter,
  AdminSubscriptionFilter,
  AdminUserSearchField,
  AdminUserSummary,
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
  const [allUsers, setAllUsers] = useState<AdminUserSummary[]>([]);
  const [startAfter, setStartAfter] = useState<string | undefined>(undefined);
  const [hasMore, setHasMore] = useState(false);

  const query = useQuery({
    queryKey: ["admin-user-summary", submittedFilters, startAfter],
    queryFn: () => getAdminUserSummary({
      ...submittedFilters,
      query: submittedFilters.query || undefined,
      startAfter,
    }),
  });

  // 새 데이터가 도착하면 누적
  useEffect(() => {
    if (query.data) {
      setAllUsers((prev) =>
        startAfter ? [...prev, ...query.data.results] : query.data.results
      );
      setHasMore(query.data.hasMore);
    }
  }, [query.data, startAfter]);

  const handleSubmit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    // 새 검색 시 결과 리셋
    setAllUsers([]);
    setStartAfter(undefined);
    setHasMore(false);
    setSubmittedFilters({
      ...filters,
      query: filters.query.trim(),
    });
  };

  const handleLoadMore = useCallback(() => {
    if (allUsers.length > 0) {
      setStartAfter(allUsers[allUsers.length - 1].userId);
    }
  }, [allUsers]);

  return (
    <Stack spacing={3}>
      <Stack spacing={1}>
        <Typography variant="h4">사용자</Typography>
        <Typography color="text.secondary">
          사용자 ID, 이메일, 닉네임 기준의 운영 검색 화면입니다.
        </Typography>
      </Stack>

      <Card elevation={0}>
        <CardContent>
          <Stack component="form" spacing={2} onSubmit={handleSubmit}>
            <Alert severity="info">
              검색어는 정확 일치 기준입니다. 화면 진입 시 기본 25명을 먼저
              보여주고, 검색/필터를 적용하면 결과를 다시 조회합니다.
            </Alert>

            <TextField
              label="사용자 검색"
              placeholder="사용자 ID / 이메일 / 닉네임"
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
                  label="검색 필드"
                  value={filters.field}
                  onChange={(event) =>
                    setFilters((current) => ({
                      ...current,
                      field: event.target.value as AdminUserSearchField,
                    }))
                  }
                  fullWidth
                >
                  <MenuItem value="all">전체 필드</MenuItem>
                  <MenuItem value="userId">사용자 ID</MenuItem>
                  <MenuItem value="email">이메일</MenuItem>
                  <MenuItem value="nickname">닉네임</MenuItem>
                </TextField>
              </Grid>

              <Grid size={{xs: 12, md: 4}}>
                <TextField
                  select
                  label="subscription"
                  value={filters.subscription}
                  onChange={(event) =>
                    setFilters((current) => ({
                      ...current,
                      subscription: event.target.value as AdminSubscriptionFilter,
                    }))
                  }
                  fullWidth
                >
                  <MenuItem value="all">전체 사용자</MenuItem>
                  <MenuItem value="subscribed">subscription 활성</MenuItem>
                  <MenuItem value="not_subscribed">subscription 없음</MenuItem>
                </TextField>
              </Grid>

              <Grid size={{xs: 12, md: 4}}>
                <TextField
                  select
                  label="Pro 수동 변경"
                  value={filters.override}
                  onChange={(event) =>
                    setFilters((current) => ({
                      ...current,
                      override: event.target.value as AdminOverrideFilter,
                    }))
                  }
                  fullWidth
                >
                  <MenuItem value="all">전체 수동 변경 상태</MenuItem>
                  <MenuItem value="active">수동 변경 활성</MenuItem>
                  <MenuItem value="inactive">수동 변경 비활성</MenuItem>
                </TextField>
              </Grid>
            </Grid>

            <Stack direction="row" spacing={1}>
              <Button type="submit" variant="contained">
                검색
              </Button>
              <Button
                type="button"
                variant="text"
                onClick={() => {
                  setFilters(defaultSearchFilters);
                  setAllUsers([]);
                  setStartAfter(undefined);
                  setHasMore(false);
                  setSubmittedFilters(defaultSearchFilters);
                }}
              >
                초기화
              </Button>
              <Chip
                label={submittedFilters?.subscription === "all" ?
                  "전체 subscription" :
                  submittedFilters?.subscription ?? "subscription"}
              />
              <Chip
                label={
                  submittedFilters?.override === "active"
                    ? "수동 변경 활성"
                    : submittedFilters?.override === "inactive"
                    ? "수동 변경 비활성"
                    : "전체 수동 변경"
                }
              />
            </Stack>
          </Stack>
        </CardContent>
      </Card>

      {query.isLoading && allUsers.length === 0 && (
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

      {!query.isLoading && allUsers.length === 0 && query.data && (
        <Alert severity="info">
          일치하는 사용자를 찾지 못했습니다.
        </Alert>
      )}

      {allUsers.length > 0 && (
        <>
          <Typography color="text.secondary">
            {allUsers.length}명 표시 중
          </Typography>
          <Grid container spacing={2}>
            {allUsers.map((user) => (
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
                          label={user.subscriptionStatus ?? "subscription 없음"}
                        />
                        <Chip
                          color={user.overrideActive ? "secondary" : "default"}
                          label={user.overrideActive ? "수동 변경 활성" : "수동 변경 없음"}
                        />
                        <Chip label={`그룹 ${user.groupCount}개`} />
                        <Chip label={`기기 ${user.deviceCount}개`} />
                        <Chip label={`개인일정 ${user.personalEventCount}개`} />
                      </Stack>

                      <Typography variant="body2" color="text.secondary">
                        {user.email ?? "이메일 없음"}
                      </Typography>

                      <Stack direction="row" spacing={1}>
                        <Button
                          component={RouterLink}
                          to={`/users/${user.userId}/timeline`}
                          variant="contained"
                          size="small"
                        >
                          이력 보기
                        </Button>
                        <Button
                          component={RouterLink}
                          to={`/entitlements?userId=${user.userId}`}
                          variant="text"
                          size="small"
                        >
                          Pro 수동 변경
                        </Button>
                      </Stack>
                    </Stack>
                  </CardContent>
                </Card>
              </Grid>
            ))}
          </Grid>

          {hasMore && (
            <Button
              variant="outlined"
              onClick={handleLoadMore}
              disabled={query.isFetching}
              startIcon={query.isFetching ? <CircularProgress size={16} /> : undefined}
            >
              {query.isFetching ? "불러오는 중..." : "더 보기"}
            </Button>
          )}
        </>
      )}
    </Stack>
  );
}
