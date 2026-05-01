/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_AI_VIDEO_PROXY_URL?: string;
  readonly VITE_AI_VIDEO_STATUS_URL?: string;
  readonly VITE_GEMINI_PROXY_URL?: string;
  readonly VITE_OPENAI_PROXY_URL?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
