import LockOutlinedIcon from "@mui/icons-material/LockOutlined";
import {
  Alert,
  Box,
  Button,
  Card,
  CardContent,
  Stack,
  Typography,
} from "@mui/material";
import {useAuth} from "../auth/AuthProvider";

export function LoginPage() {
  const {isFirebaseConfigured, signInWithGoogle, signOutUser, status} = useAuth();

  return (
    <Box
      sx={{
        minHeight: "100vh",
        display: "grid",
        placeItems: "center",
        p: 3,
        background:
          "linear-gradient(180deg, rgba(219,234,254,1) 0%, rgba(244,247,251,1) 100%)",
      }}
    >
      <Card elevation={0} sx={{maxWidth: 560, width: "100%"}}>
        <CardContent sx={{p: 4}}>
          <Stack spacing={3}>
            <Stack spacing={1} alignItems="flex-start">
              <Box
                sx={{
                  width: 44,
                  height: 44,
                  borderRadius: "50%",
                  display: "grid",
                  placeItems: "center",
                  bgcolor: "primary.main",
                  color: "common.white",
                }}
              >
                <LockOutlinedIcon />
              </Box>
              <Typography variant="h4">Promiso Admin</Typography>
              <Typography color="text.secondary">
                운영 콘솔 접근은 로그인 이후 서버 측 admin 권한 검증을 전제로 합니다.
              </Typography>
            </Stack>

            {!isFirebaseConfigured && (
              <Alert severity="warning">
                Firebase Web 설정이 비어 있습니다. `.env.local`에 Vite 환경 변수를
                먼저 채워야 합니다.
              </Alert>
            )}

            {status === "forbidden" && (
              <Alert severity="error">
                이 계정은 `adminUsers`에 등록되어 있지 않거나 비활성화되어 있습니다.
              </Alert>
            )}

            <Button
              variant="contained"
              size="large"
              disabled={!isFirebaseConfigured}
              onClick={() => void signInWithGoogle()}
            >
              Sign in with Google
            </Button>

            {status === "forbidden" && (
              <Button variant="text" onClick={() => void signOutUser()}>
                다른 계정으로 다시 시도
              </Button>
            )}
          </Stack>
        </CardContent>
      </Card>
    </Box>
  );
}
