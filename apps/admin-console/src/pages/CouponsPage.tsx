import ContentCopyIcon from "@mui/icons-material/ContentCopy";
import {
  Alert,
  Button,
  Card,
  CardContent,
  Chip,
  IconButton,
  MenuItem,
  Select,
  Stack,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  TextField,
  Tooltip,
  Typography,
} from "@mui/material";
import {useMutation, useQuery, useQueryClient} from "@tanstack/react-query";
import {useState} from "react";
import {
  type AdminCoupon,
  createCoupon,
  expireCoupon,
  getAdminCoupons,
} from "../api/admin";

type CouponStatusFilter = "all" | "available" | "redeemed" | "expired";

function getCouponStatus(coupon: AdminCoupon): "available" | "redeemed" | "expired" {
  if (coupon.redeemedBy) return "redeemed";
  if (coupon.expiresAt && new Date(coupon.expiresAt) < new Date()) return "expired";
  return "available";
}

function StatusChip(props: {status: "available" | "redeemed" | "expired"}) {
  const config = {
    available: {label: "사용 가능", color: "success" as const},
    redeemed: {label: "사용됨", color: "default" as const},
    expired: {label: "만료", color: "error" as const},
  };
  const {label, color} = config[props.status];
  return <Chip label={label} color={color} size="small" />;
}

function formatDate(dateString: string | null): string {
  if (!dateString) return "-";
  return new Date(dateString).toLocaleString("ko-KR");
}

export function CouponsPage() {
  const queryClient = useQueryClient();
  const [code, setCode] = useState("");
  const [durationDays, setDurationDays] = useState<30 | 90>(30);
  const [memo, setMemo] = useState("");

  const calcDefaultExpiry = (days: number) => {
    const d = new Date(Date.now() + days * 24 * 60 * 60 * 1000);
    return d.toISOString().slice(0, 16);
  };

  const [expiresAt, setExpiresAt] = useState(() => calcDefaultExpiry(30));
  const [statusFilter, setStatusFilter] = useState<CouponStatusFilter>("all");
  const [message, setMessage] = useState<{
    type: "success" | "error";
    text: string;
  } | null>(null);

  const couponsQuery = useQuery({
    queryKey: ["admin-coupons", statusFilter],
    queryFn: () => getAdminCoupons({status: statusFilter}),
  });

  const createMutation = useMutation({
    mutationFn: () =>
      createCoupon({
        code: code.trim() || undefined,
        durationDays,
        memo: memo.trim() || undefined,
      }),
    onSuccess: (coupon) => {
      setMessage({
        type: "success",
        text: `쿠폰이 생성되었습니다: ${coupon.code}`,
      });
      setCode("");
      setMemo("");
      setExpiresAt(calcDefaultExpiry(durationDays));
      void queryClient.invalidateQueries({queryKey: ["admin-coupons"]});
    },
    onError: () => {
      setMessage({type: "error", text: "쿠폰 생성에 실패했습니다."});
    },
  });

  const expireMutation = useMutation({
    mutationFn: (couponCode: string) => expireCoupon(couponCode),
    onSuccess: () => {
      setMessage({type: "success", text: "쿠폰이 만료 처리되었습니다."});
      void queryClient.invalidateQueries({queryKey: ["admin-coupons"]});
    },
    onError: () => {
      setMessage({type: "error", text: "쿠폰 만료 처리에 실패했습니다."});
    },
  });

  const handleCopyCode = async (couponCode: string) => {
    await navigator.clipboard.writeText(couponCode);
  };

  return (
    <Stack spacing={3}>
      <Stack spacing={1}>
        <Typography variant="h4">쿠폰 관리</Typography>
        <Typography color="text.secondary">
          Pro 플랜 체험 쿠폰을 생성하고 관리하는 화면입니다.
        </Typography>
      </Stack>

      <Card elevation={0}>
        <CardContent>
          <Typography variant="h6" sx={{mb: 2}}>
            쿠폰 생성
          </Typography>
          <Stack spacing={2}>
            <TextField
              label="쿠폰 코드"
              placeholder="비워두면 자동 생성"
              value={code}
              onChange={(e) => setCode(e.target.value)}
              fullWidth
            />
            <Stack direction="row" spacing={2}>
              <Select
                value={durationDays}
                onChange={(e) => {
                  const days = e.target.value as 30 | 90;
                  setDurationDays(days);
                  setExpiresAt(calcDefaultExpiry(days));
                }}
                size="small"
                sx={{minWidth: 140}}
              >
                <MenuItem value={30}>30일</MenuItem>
                <MenuItem value={90}>90일</MenuItem>
              </Select>
              <TextField
                label="쿠폰 유효기한"
                type="datetime-local"
                value={expiresAt}
                InputLabelProps={{shrink: true}}
                size="small"
                fullWidth
                disabled
                helperText="기간 선택 시 자동 설정됨"
              />
            </Stack>
            <TextField
              label="메모"
              placeholder="쿠폰 용도 등 (선택)"
              value={memo}
              onChange={(e) => setMemo(e.target.value)}
              fullWidth
              size="small"
            />

            {message && (
              <Alert severity={message.type}>{message.text}</Alert>
            )}

            <Button
              variant="contained"
              disabled={createMutation.isPending}
              onClick={() => {
                setMessage(null);
                createMutation.mutate();
              }}
              sx={{alignSelf: "flex-start"}}
            >
              쿠폰 생성
            </Button>
          </Stack>
        </CardContent>
      </Card>

      <Card elevation={0}>
        <CardContent>
          <Stack
            direction="row"
            justifyContent="space-between"
            alignItems="center"
            sx={{mb: 2}}
          >
            <Typography variant="h6">쿠폰 목록</Typography>
            <Select
              value={statusFilter}
              onChange={(e) =>
                setStatusFilter(e.target.value as CouponStatusFilter)
              }
              size="small"
              sx={{minWidth: 120}}
            >
              <MenuItem value="all">전체</MenuItem>
              <MenuItem value="available">사용 가능</MenuItem>
              <MenuItem value="redeemed">사용됨</MenuItem>
              <MenuItem value="expired">만료</MenuItem>
            </Select>
          </Stack>

          {couponsQuery.isLoading && (
            <Typography color="text.secondary">로딩 중...</Typography>
          )}

          {couponsQuery.isError && (
            <Alert severity="error">쿠폰 목록을 불러오는데 실패했습니다.</Alert>
          )}

          {couponsQuery.data && (
            <TableContainer>
              <Table size="small">
                <TableHead>
                  <TableRow>
                    <TableCell>코드</TableCell>
                    <TableCell>기간</TableCell>
                    <TableCell>메모</TableCell>
                    <TableCell>상태</TableCell>
                    <TableCell>사용자</TableCell>
                    <TableCell>사용일</TableCell>
                    <TableCell>쿠폰 만료일</TableCell>
                    <TableCell>생성일</TableCell>
                    <TableCell>관리</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {couponsQuery.data.length === 0 ? (
                    <TableRow>
                      <TableCell colSpan={8} align="center">
                        <Typography color="text.secondary" sx={{py: 4}}>
                          쿠폰이 없습니다
                        </Typography>
                      </TableCell>
                    </TableRow>
                  ) : (
                    couponsQuery.data.map((coupon) => (
                      <TableRow key={coupon.code}>
                        <TableCell>
                          <Stack direction="row" alignItems="center" spacing={0.5}>
                            <Typography
                              variant="body2"
                              sx={{fontFamily: "monospace", fontWeight: 600}}
                            >
                              {coupon.code}
                            </Typography>
                            <Tooltip title="코드 복사">
                              <IconButton
                                size="small"
                                onClick={() => void handleCopyCode(coupon.code)}
                              >
                                <ContentCopyIcon fontSize="small" />
                              </IconButton>
                            </Tooltip>
                          </Stack>
                        </TableCell>
                        <TableCell>{coupon.durationDays}일</TableCell>
                        <TableCell>{coupon.memo || "-"}</TableCell>
                        <TableCell>
                          <StatusChip status={getCouponStatus(coupon)} />
                        </TableCell>
                        <TableCell>
                          <Typography
                            variant="body2"
                            sx={{
                              fontFamily: "monospace",
                              fontSize: 12,
                              maxWidth: 120,
                              overflow: "hidden",
                              textOverflow: "ellipsis",
                            }}
                          >
                            {coupon.redeemedBy ?? "-"}
                          </Typography>
                        </TableCell>
                        <TableCell>{formatDate(coupon.redeemedAt)}</TableCell>
                        <TableCell>{formatDate(coupon.expiresAt)}</TableCell>
                        <TableCell>{formatDate(coupon.createdAt)}</TableCell>
                        <TableCell>
                          {getCouponStatus(coupon) === "available" && (
                            <Button
                              size="small"
                              color="error"
                              variant="outlined"
                              disabled={expireMutation.isPending}
                              onClick={() => {
                                if (confirm(`${coupon.code} 쿠폰을 만료 처리하시겠습니까?`)) {
                                  expireMutation.mutate(coupon.code);
                                }
                              }}
                            >
                              만료
                            </Button>
                          )}
                        </TableCell>
                      </TableRow>
                    ))
                  )}
                </TableBody>
              </Table>
            </TableContainer>
          )}
        </CardContent>
      </Card>
    </Stack>
  );
}
