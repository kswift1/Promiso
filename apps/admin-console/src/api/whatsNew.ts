import {httpsCallable} from "firebase/functions";
import {firebaseFunctions} from "../lib/firebase";

// ============================================================================
// Types
// ============================================================================

export type WhatsNewItem = {
  title: string;
  description: string;
  imageURL: string;
  displayOrder: number;
};

export type WhatsNewDocument = {
  version: string;
  enabled: boolean;
  items: WhatsNewItem[];
  createdBy: string;
  createdAt: string;
  updatedBy: string;
  updatedAt: string;
};

type AdminListWhatsNewResponse = {
  success: true;
  entries: WhatsNewDocument[];
};

type AdminSaveWhatsNewRequest = {
  version: string;
  enabled: boolean;
  items: WhatsNewItem[];
};

type AdminSaveWhatsNewResponse = {
  success: true;
  whatsNew: WhatsNewDocument;
};

type AdminDeleteWhatsNewRequest = {
  version: string;
};

type AdminDeleteWhatsNewResponse = {
  success: true;
};

// ============================================================================
// API Functions
// ============================================================================

export async function adminListWhatsNew(): Promise<WhatsNewDocument[]> {
  if (!firebaseFunctions) {
    throw new Error("Firebase Functions is not configured");
  }

  const callable = httpsCallable<Record<string, never>, AdminListWhatsNewResponse>(
    firebaseFunctions,
    "adminListWhatsNew"
  );
  const result = await callable({});
  return result.data.entries;
}

export async function adminSaveWhatsNew(params: {
  version: string;
  enabled: boolean;
  items: WhatsNewItem[];
}): Promise<WhatsNewDocument> {
  if (!firebaseFunctions) {
    throw new Error("Firebase Functions is not configured");
  }

  const callable = httpsCallable<AdminSaveWhatsNewRequest, AdminSaveWhatsNewResponse>(
    firebaseFunctions,
    "adminSaveWhatsNew"
  );
  const result = await callable(params);
  return result.data.whatsNew;
}

export async function adminDeleteWhatsNew(version: string): Promise<void> {
  if (!firebaseFunctions) {
    throw new Error("Firebase Functions is not configured");
  }

  const callable = httpsCallable<AdminDeleteWhatsNewRequest, AdminDeleteWhatsNewResponse>(
    firebaseFunctions,
    "adminDeleteWhatsNew"
  );
  await callable({version});
}

type AdminUploadWhatsNewImageRequest = {
  version: string;
  fileName: string;
  base64Data: string;
  contentType: string;
};

type AdminUploadWhatsNewImageResponse = {
  success: true;
  imageURL: string;
};

export async function adminUploadWhatsNewImage(params: {
  version: string;
  fileName: string;
  base64Data: string;
  contentType: string;
}): Promise<string> {
  if (!firebaseFunctions) {
    throw new Error("Firebase Functions is not configured");
  }

  const callable = httpsCallable<
    AdminUploadWhatsNewImageRequest,
    AdminUploadWhatsNewImageResponse
  >(firebaseFunctions, "adminUploadWhatsNewImage");
  const result = await callable(params);
  return result.data.imageURL;
}
