import AddPhotoAlternateRoundedIcon from "@mui/icons-material/AddPhotoAlternateRounded";
import AddRoundedIcon from "@mui/icons-material/AddRounded";
import ArrowDownwardRoundedIcon from "@mui/icons-material/ArrowDownwardRounded";
import ArrowUpwardRoundedIcon from "@mui/icons-material/ArrowUpwardRounded";
import ChevronLeftRoundedIcon from "@mui/icons-material/ChevronLeftRounded";
import ChevronRightRoundedIcon from "@mui/icons-material/ChevronRightRounded";
import DeleteRoundedIcon from "@mui/icons-material/DeleteRounded";
import {
  Alert,
  Box,
  Button,
  Card,
  CardContent,
  Chip,
  CircularProgress,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  IconButton,
  Stack,
  Switch,
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
import {useRef, useState} from "react";
import {
  type WhatsNewDocument,
  type WhatsNewItem,
  adminDeleteWhatsNew,
  adminListWhatsNew,
  adminSaveWhatsNew,
  adminUploadWhatsNewImage,
} from "../api/whatsNew";

// ============================================================================
// Helpers
// ============================================================================

function formatDate(dateString: string | null | undefined): string {
  if (!dateString) return "-";
  return new Date(dateString).toLocaleString("ko-KR");
}

function makeEmptyItem(displayOrder: number): WhatsNewItem {
  return {title: "", description: "", imageURL: "", displayOrder};
}

// ============================================================================
// iPhone Preview
// ============================================================================

function IPhonePreview(props: {items: WhatsNewItem[]}) {
  const {items} = props;
  const [currentIndex, setCurrentIndex] = useState(0);

  const safeIndex = Math.min(currentIndex, Math.max(0, items.length - 1));
  const currentItem = items[safeIndex];

  const handlePrev = () => {
    setCurrentIndex((i) => Math.max(0, i - 1));
  };

  const handleNext = () => {
    setCurrentIndex((i) => Math.min(items.length - 1, i + 1));
  };

  return (
    <Box sx={{display: "flex", flexDirection: "column", alignItems: "center", gap: 2}}>
      <Typography variant="subtitle2" color="text.secondary">
        미리보기
      </Typography>

      {/* iPhone frame */}
      <Box
        sx={{
          width: 300,
          height: 580,
          borderRadius: "40px",
          border: "10px solid #1a1a2e",
          boxShadow: "0 0 0 2px #374151, 0 20px 60px rgba(0,0,0,0.4)",
          overflow: "hidden",
          position: "relative",
          background: "linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%)",
          flexShrink: 0,
        }}
      >
        {/* Notch */}
        <Box
          sx={{
            position: "absolute",
            top: 0,
            left: "50%",
            transform: "translateX(-50%)",
            width: 100,
            height: 28,
            bgcolor: "#1a1a2e",
            borderBottomLeftRadius: 16,
            borderBottomRightRadius: 16,
            zIndex: 10,
          }}
        />

        {/* Content area */}
        <Box
          sx={{
            height: "100%",
            display: "flex",
            flexDirection: "column",
            pt: "28px",
            pb: 2,
            overflow: "hidden",
          }}
        >
          {items.length === 0 || !currentItem ? (
            <Box
              sx={{
                flex: 1,
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                px: 2,
              }}
            >
              <Typography
                variant="body2"
                sx={{color: "rgba(255,255,255,0.4)", textAlign: "center"}}
              >
                항목을 추가하세요
              </Typography>
            </Box>
          ) : (
            <>
              {/* Image area */}
              <Box
                sx={{
                  width: "100%",
                  height: 200,
                  flexShrink: 0,
                  overflow: "hidden",
                  bgcolor: "rgba(255,255,255,0.05)",
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                }}
              >
                {currentItem.imageURL ? (
                  <Box
                    component="img"
                    src={currentItem.imageURL}
                    alt={currentItem.title}
                    sx={{
                      width: "100%",
                      height: "100%",
                      objectFit: "cover",
                    }}
                  />
                ) : (
                  <Typography
                    variant="caption"
                    sx={{color: "rgba(255,255,255,0.3)"}}
                  >
                    이미지 없음
                  </Typography>
                )}
              </Box>

              {/* Text content */}
              <Box sx={{flex: 1, px: 2.5, pt: 2.5, overflow: "hidden"}}>
                <Typography
                  sx={{
                    color: "#ffffff",
                    fontWeight: 700,
                    fontSize: 18,
                    lineHeight: 1.3,
                    mb: 1,
                    display: "-webkit-box",
                    WebkitLineClamp: 2,
                    WebkitBoxOrient: "vertical",
                    overflow: "hidden",
                  }}
                >
                  {currentItem.title || "제목"}
                </Typography>
                <Typography
                  sx={{
                    color: "rgba(255,255,255,0.6)",
                    fontSize: 13,
                    lineHeight: 1.5,
                    display: "-webkit-box",
                    WebkitLineClamp: 3,
                    WebkitBoxOrient: "vertical",
                    overflow: "hidden",
                  }}
                >
                  {currentItem.description || "설명을 입력하세요"}
                </Typography>
              </Box>

              {/* Dot indicator */}
              {items.length > 1 && (
                <Stack
                  direction="row"
                  spacing={0.75}
                  justifyContent="center"
                  sx={{py: 1}}
                >
                  {items.map((_, idx) => (
                    <Box
                      key={idx}
                      sx={{
                        width: idx === safeIndex ? 16 : 6,
                        height: 6,
                        borderRadius: 3,
                        bgcolor:
                          idx === safeIndex ?
                            "#6366f1" :
                            "rgba(255,255,255,0.3)",
                        transition: "all 0.2s ease",
                      }}
                    />
                  ))}
                </Stack>
              )}

              {/* Confirm button */}
              <Box sx={{px: 2.5, pb: 1}}>
                <Box
                  sx={{
                    bgcolor: "#6366f1",
                    borderRadius: "14px",
                    py: 1.25,
                    textAlign: "center",
                    cursor: "pointer",
                  }}
                >
                  <Typography
                    sx={{color: "#ffffff", fontWeight: 600, fontSize: 15}}
                  >
                    확인
                  </Typography>
                </Box>
              </Box>
            </>
          )}
        </Box>
      </Box>

      {/* Navigation buttons */}
      {items.length > 1 && (
        <Stack direction="row" spacing={1} alignItems="center">
          <IconButton
            size="small"
            disabled={safeIndex === 0}
            onClick={handlePrev}
          >
            <ChevronLeftRoundedIcon />
          </IconButton>
          <Typography variant="caption" color="text.secondary">
            {safeIndex + 1} / {items.length}
          </Typography>
          <IconButton
            size="small"
            disabled={safeIndex === items.length - 1}
            onClick={handleNext}
          >
            <ChevronRightRoundedIcon />
          </IconButton>
        </Stack>
      )}
    </Box>
  );
}

// ============================================================================
// Image Upload Button
// ============================================================================

function ImageUploadCell(props: {
  item: WhatsNewItem;
  version: string;
  itemIndex: number;
  onUploaded: (imageURL: string) => void;
  disabled?: boolean;
}) {
  const {item, version, itemIndex, onUploaded, disabled} = props;
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [uploading, setUploading] = useState(false);
  const [uploadError, setUploadError] = useState<string | null>(null);

  const handleFileChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    setUploading(true);
    setUploadError(null);

    try {
      const base64Data = await new Promise<string>((resolve, reject) => {
        const reader = new FileReader();
        reader.onload = () => {
          const result = reader.result as string;
          // Remove the data URL prefix (e.g. "data:image/png;base64,")
          const base64 = result.split(",")[1];
          if (base64) {
            resolve(base64);
          } else {
            reject(new Error("base64 변환 실패"));
          }
        };
        reader.onerror = () => reject(new Error("파일 읽기 실패"));
        reader.readAsDataURL(file);
      });

      const fileName = `item-${itemIndex}-${Date.now()}-${file.name}`;
      const imageURL = await adminUploadWhatsNewImage({
        version,
        fileName,
        base64Data,
        contentType: file.type,
      });
      onUploaded(imageURL);
    } catch {
      setUploadError("이미지 업로드에 실패했습니다.");
    } finally {
      setUploading(false);
      if (fileInputRef.current) {
        fileInputRef.current.value = "";
      }
    }
  };

  return (
    <Stack spacing={1}>
      <input
        ref={fileInputRef}
        type="file"
        accept="image/*"
        style={{display: "none"}}
        onChange={(e) => void handleFileChange(e)}
      />
      <Stack direction="row" spacing={1} alignItems="center">
        <Button
          variant="outlined"
          size="small"
          startIcon={
            uploading ? (
              <CircularProgress size={14} />
            ) : (
              <AddPhotoAlternateRoundedIcon />
            )
          }
          disabled={uploading || disabled}
          onClick={() => fileInputRef.current?.click()}
        >
          {uploading ? "업로드 중..." : "이미지 선택"}
        </Button>
        {item.imageURL && !uploading && (
          <Box
            component="img"
            src={item.imageURL}
            alt="thumbnail"
            sx={{
              width: 48,
              height: 48,
              objectFit: "cover",
              borderRadius: 1,
              border: "1px solid",
              borderColor: "divider",
            }}
          />
        )}
      </Stack>
      {uploadError && (
        <Typography variant="caption" color="error">
          {uploadError}
        </Typography>
      )}
    </Stack>
  );
}

// ============================================================================
// Edit Dialog
// ============================================================================

type EditDialogProps = {
  open: boolean;
  initialDoc: WhatsNewDocument | null;
  isNew: boolean;
  onClose: () => void;
  onSave: (params: {version: string; enabled: boolean; items: WhatsNewItem[]}) => void;
  isSaving: boolean;
};

function EditDialog(props: EditDialogProps) {
  const {open, initialDoc, isNew, onClose, onSave, isSaving} = props;

  const [version, setVersion] = useState(initialDoc?.version ?? "");
  const [enabled, setEnabled] = useState(initialDoc?.enabled ?? true);
  const [items, setItems] = useState<WhatsNewItem[]>(
    initialDoc?.items.length ?
      [...initialDoc.items].sort((a, b) => a.displayOrder - b.displayOrder) :
      [makeEmptyItem(0)]
  );

  const handleAddItem = () => {
    setItems((prev) => [...prev, makeEmptyItem(prev.length)]);
  };

  const handleDeleteItem = (index: number) => {
    setItems((prev) =>
      prev
        .filter((_, i) => i !== index)
        .map((item, i) => ({...item, displayOrder: i}))
    );
  };

  const handleMoveUp = (index: number) => {
    if (index === 0) return;
    setItems((prev) => {
      const next = [...prev];
      [next[index - 1], next[index]] = [next[index], next[index - 1]];
      return next.map((item, i) => ({...item, displayOrder: i}));
    });
  };

  const handleMoveDown = (index: number) => {
    setItems((prev) => {
      if (index === prev.length - 1) return prev;
      const next = [...prev];
      [next[index], next[index + 1]] = [next[index + 1], next[index]];
      return next.map((item, i) => ({...item, displayOrder: i}));
    });
  };

  const handleItemChange = (index: number, field: keyof WhatsNewItem, value: string | number) => {
    setItems((prev) =>
      prev.map((item, i) => (i === index ? {...item, [field]: value} : item))
    );
  };

  const handleSave = () => {
    onSave({version: version.trim(), enabled, items});
  };

  const canSave = version.trim().length > 0 && !isSaving;

  return (
    <Dialog open={open} onClose={isSaving ? undefined : onClose} fullWidth maxWidth="lg">
      <DialogTitle>
        {isNew ? "새 버전 추가" : `버전 ${initialDoc?.version ?? ""} 편집`}
      </DialogTitle>
      <DialogContent sx={{pt: 2}}>
        <Stack direction="row" spacing={3} sx={{minHeight: 500}}>
          {/* Left: edit form */}
          <Stack spacing={3} sx={{flex: 1, minWidth: 0}}>
            {/* Header fields */}
            <Stack direction="row" spacing={2} alignItems="center">
              <TextField
                label="버전 (x.y.z)"
                value={version}
                onChange={(e) => setVersion(e.target.value)}
                disabled={!isNew || isSaving}
                placeholder="1.3.0"
                size="small"
                sx={{width: 160}}
                helperText={!isNew ? "생성 후 변경 불가" : undefined}
              />
              <Stack direction="row" alignItems="center" spacing={1}>
                <Typography variant="body2" color="text.secondary">
                  활성화
                </Typography>
                <Switch
                  checked={enabled}
                  onChange={(e) => setEnabled(e.target.checked)}
                  disabled={isSaving}
                />
              </Stack>
            </Stack>

            {/* Items */}
            <Stack spacing={2}>
              <Typography variant="subtitle2">항목 목록</Typography>
              {items.map((item, index) => (
                <Card
                  key={index}
                  elevation={0}
                  sx={{bgcolor: "rgba(15, 23, 42, 0.03)", borderRadius: 2}}
                >
                  <CardContent>
                    <Stack spacing={2}>
                      <Stack
                        direction="row"
                        justifyContent="space-between"
                        alignItems="center"
                      >
                        <Typography variant="subtitle2" color="text.secondary">
                          항목 {index + 1}
                        </Typography>
                        <Stack direction="row" spacing={0.5}>
                          <Tooltip title="위로">
                            <span>
                              <IconButton
                                size="small"
                                disabled={index === 0 || isSaving}
                                onClick={() => handleMoveUp(index)}
                              >
                                <ArrowUpwardRoundedIcon fontSize="small" />
                              </IconButton>
                            </span>
                          </Tooltip>
                          <Tooltip title="아래로">
                            <span>
                              <IconButton
                                size="small"
                                disabled={index === items.length - 1 || isSaving}
                                onClick={() => handleMoveDown(index)}
                              >
                                <ArrowDownwardRoundedIcon fontSize="small" />
                              </IconButton>
                            </span>
                          </Tooltip>
                          <Tooltip title="삭제">
                            <span>
                              <IconButton
                                size="small"
                                color="error"
                                disabled={isSaving}
                                onClick={() => {
                                  if (confirm(`항목 ${index + 1}을 삭제하시겠습니까?`)) {
                                    handleDeleteItem(index);
                                  }
                                }}
                              >
                                <DeleteRoundedIcon fontSize="small" />
                              </IconButton>
                            </span>
                          </Tooltip>
                        </Stack>
                      </Stack>

                      <TextField
                        label="제목"
                        value={item.title}
                        onChange={(e) => handleItemChange(index, "title", e.target.value)}
                        disabled={isSaving}
                        fullWidth
                        size="small"
                      />
                      <TextField
                        label="설명"
                        value={item.description}
                        onChange={(e) =>
                          handleItemChange(index, "description", e.target.value)
                        }
                        disabled={isSaving}
                        fullWidth
                        size="small"
                        multiline
                        rows={2}
                      />

                      <ImageUploadCell
                        item={item}
                        version={version.trim() || "draft"}
                        itemIndex={index}
                        onUploaded={(imageURL) =>
                          handleItemChange(index, "imageURL", imageURL)
                        }
                        disabled={!version.trim()}
                      />
                    </Stack>
                  </CardContent>
                </Card>
              ))}

              <Button
                variant="outlined"
                startIcon={<AddRoundedIcon />}
                onClick={handleAddItem}
                disabled={isSaving}
                sx={{alignSelf: "flex-start"}}
              >
                항목 추가
              </Button>
            </Stack>
          </Stack>

          {/* Right: iPhone preview */}
          <Box sx={{flexShrink: 0, pt: 1}}>
            <IPhonePreview items={items} />
          </Box>
        </Stack>
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose} disabled={isSaving}>
          취소
        </Button>
        <Button
          variant="contained"
          onClick={handleSave}
          disabled={!canSave}
        >
          {isSaving ? "저장 중..." : "저장"}
        </Button>
      </DialogActions>
    </Dialog>
  );
}

// ============================================================================
// WhatsNewPage
// ============================================================================

export function WhatsNewPage() {
  const queryClient = useQueryClient();
  const [message, setMessage] = useState<{type: "success" | "error"; text: string} | null>(
    null
  );
  const [dialogOpen, setDialogOpen] = useState(false);
  const [editingDoc, setEditingDoc] = useState<WhatsNewDocument | null>(null);
  const [isNew, setIsNew] = useState(false);

  const listQuery = useQuery({
    queryKey: ["admin-whats-new"],
    queryFn: adminListWhatsNew,
  });

  const saveMutation = useMutation({
    mutationFn: (params: {version: string; enabled: boolean; items: WhatsNewItem[]}) =>
      adminSaveWhatsNew(params),
    onSuccess: () => {
      void queryClient.invalidateQueries({queryKey: ["admin-whats-new"]});
      setMessage({type: "success", text: "저장되었습니다."});
      setDialogOpen(false);
    },
    onError: () => {
      setMessage({type: "error", text: "저장에 실패했습니다."});
    },
  });

  const deleteMutation = useMutation({
    mutationFn: (version: string) => adminDeleteWhatsNew(version),
    onSuccess: () => {
      void queryClient.invalidateQueries({queryKey: ["admin-whats-new"]});
      setMessage({type: "success", text: "삭제되었습니다."});
    },
    onError: () => {
      setMessage({type: "error", text: "삭제에 실패했습니다."});
    },
  });

  const handleOpenNew = () => {
    setEditingDoc(null);
    setIsNew(true);
    setDialogOpen(true);
  };

  const handleOpenEdit = (doc: WhatsNewDocument) => {
    setEditingDoc(doc);
    setIsNew(false);
    setDialogOpen(true);
  };

  const handleDelete = (doc: WhatsNewDocument) => {
    if (confirm(`버전 ${doc.version}을 삭제하시겠습니까?`)) {
      deleteMutation.mutate(doc.version);
    }
  };

  const handleSave = (params: {version: string; enabled: boolean; items: WhatsNewItem[]}) => {
    setMessage(null);
    saveMutation.mutate(params);
  };

  const sortedDocs = listQuery.data ?
    [...listQuery.data].sort((a, b) => {
      const [aMaj, aMin, aPat] = a.version.split(".").map(Number);
      const [bMaj, bMin, bPat] = b.version.split(".").map(Number);
      if (bMaj !== aMaj) return bMaj - aMaj;
      if (bMin !== aMin) return bMin - aMin;
      return bPat - aPat;
    }) :
    [];

  return (
    <Stack spacing={3}>
      <Stack spacing={1}>
        <Typography variant="h4">What's New 관리</Typography>
        <Typography color="text.secondary">
          앱 업데이트 후 사용자에게 보여줄 신규 기능을 관리합니다.
        </Typography>
      </Stack>

      {message && (
        <Alert severity={message.type} onClose={() => setMessage(null)}>
          {message.text}
        </Alert>
      )}

      <Card elevation={0}>
        <CardContent>
          <Stack
            direction="row"
            justifyContent="space-between"
            alignItems="center"
            sx={{mb: 2}}
          >
            <Typography variant="h6">버전 목록</Typography>
            <Button
              variant="contained"
              startIcon={<AddRoundedIcon />}
              onClick={handleOpenNew}
            >
              새 버전 추가
            </Button>
          </Stack>

          {listQuery.isLoading && (
            <Stack alignItems="center" justifyContent="center" minHeight={120} spacing={1}>
              <CircularProgress size={28} />
              <Typography color="text.secondary">불러오는 중...</Typography>
            </Stack>
          )}

          {listQuery.isError && (
            <Alert severity="error">목록을 불러오는데 실패했습니다.</Alert>
          )}

          {listQuery.data && (
            <TableContainer>
              <Table size="small">
                <TableHead>
                  <TableRow>
                    <TableCell>버전</TableCell>
                    <TableCell>항목 수</TableCell>
                    <TableCell>상태</TableCell>
                    <TableCell>수정일</TableCell>
                    <TableCell>수정자</TableCell>
                    <TableCell>관리</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {sortedDocs.length === 0 ? (
                    <TableRow>
                      <TableCell colSpan={6} align="center">
                        <Typography color="text.secondary" sx={{py: 4}}>
                          등록된 버전이 없습니다
                        </Typography>
                      </TableCell>
                    </TableRow>
                  ) : (
                    sortedDocs.map((doc) => (
                      <TableRow key={doc.version}>
                        <TableCell>
                          <Typography
                            variant="body2"
                            sx={{fontFamily: "monospace", fontWeight: 600}}
                          >
                            {doc.version}
                          </Typography>
                        </TableCell>
                        <TableCell>{doc.items.length}개</TableCell>
                        <TableCell>
                          <Chip
                            label={doc.enabled ? "활성" : "비활성"}
                            color={doc.enabled ? "success" : "default"}
                            size="small"
                          />
                        </TableCell>
                        <TableCell>{formatDate(doc.updatedAt)}</TableCell>
                        <TableCell>
                          <Typography
                            variant="body2"
                            sx={{
                              fontFamily: "monospace",
                              fontSize: 12,
                              maxWidth: 160,
                              overflow: "hidden",
                              textOverflow: "ellipsis",
                              whiteSpace: "nowrap",
                            }}
                          >
                            {doc.updatedBy || "-"}
                          </Typography>
                        </TableCell>
                        <TableCell>
                          <Stack direction="row" spacing={1}>
                            <Button
                              size="small"
                              variant="outlined"
                              onClick={() => handleOpenEdit(doc)}
                              disabled={deleteMutation.isPending}
                            >
                              편집
                            </Button>
                            <Button
                              size="small"
                              variant="outlined"
                              color="error"
                              onClick={() => handleDelete(doc)}
                              disabled={deleteMutation.isPending}
                            >
                              삭제
                            </Button>
                          </Stack>
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

      <EditDialog
        key={editingDoc?.version ?? "new"}
        open={dialogOpen}
        initialDoc={editingDoc}
        isNew={isNew}
        onClose={() => setDialogOpen(false)}
        onSave={handleSave}
        isSaving={saveMutation.isPending}
      />
    </Stack>
  );
}
