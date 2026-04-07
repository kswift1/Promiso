import {firebaseAuth} from "./firebase";

const DEFAULT_RUST_API_BASE_URL =
  "https://promiso-api-809932911903.asia-northeast3.run.app";

type RustApiErrorResponse = {
  error?: {
    code?: string;
    message?: string;
  };
};

type RustApiEnvelope<T> = {
  data?: T;
};

function buildRustApiUrl(
  path: string,
  query?: Record<string, string | number | boolean | null | undefined>
): string {
  const baseURL =
    import.meta.env.VITE_RUST_API_BASE_URL ?? DEFAULT_RUST_API_BASE_URL;
  const url = new URL(path, baseURL);

  if (query) {
    for (const [key, value] of Object.entries(query)) {
      if (value == null || value === "") {
        continue;
      }

      url.searchParams.set(key, String(value));
    }
  }

  return url.toString();
}

async function getAuthToken(): Promise<string> {
  if (!firebaseAuth) {
    throw new Error("Firebase Auth is not configured");
  }

  const currentUser = firebaseAuth.currentUser;
  if (!currentUser) {
    throw new Error("로그인이 필요합니다.");
  }

  return currentUser.getIdToken();
}

async function parseError(response: Response): Promise<Error> {
  try {
    const payload = (await response.json()) as RustApiErrorResponse;
    if (payload.error?.message) {
      return new Error(payload.error.message);
    }
  } catch {
    // ignore parse failure
  }

  return new Error(`Rust API request failed (${response.status})`);
}

async function request<T>(
  method: "GET" | "POST",
  path: string,
  options?: {
    body?: unknown;
    query?: Record<string, string | number | boolean | null | undefined>;
  }
): Promise<T> {
  const token = await getAuthToken();
  const response = await fetch(buildRustApiUrl(path, options?.query), {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: options?.body ? JSON.stringify(options.body) : undefined,
  });

  if (!response.ok) {
    throw await parseError(response);
  }

  const payload = (await response.json()) as RustApiEnvelope<T>;
  if (payload.data === undefined) {
    throw new Error("Rust API returned no data");
  }

  return payload.data;
}

export async function rustApiGet<T>(
  path: string,
  query?: Record<string, string | number | boolean | null | undefined>
): Promise<T> {
  return request<T>("GET", path, {query});
}

export async function rustApiPost<T>(
  path: string,
  body: unknown
): Promise<T> {
  return request<T>("POST", path, {body});
}
