import { getToken, clearToken } from "./auth";

// Intercept fetch globally since customFetch is likely using window.fetch
export function setupApiInterceptor() {
  const originalFetch = window.fetch;
  window.fetch = async (input: RequestInfo | URL, init?: RequestInit) => {
    const token = getToken();
    const headers = new Headers(init?.headers);
    if (token) {
      headers.set("Authorization", `Bearer ${token}`);
    }
    
    const newInit: RequestInit = {
      ...init,
      headers
    };

    const response = await originalFetch(input, newInit);
    if (response.status === 401) {
      clearToken();
      // Redirect handled by app logic
    }
    return response;
  };
}
