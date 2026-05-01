import { defineConfig, loadEnv } from "vite";
import react from "@vitejs/plugin-react";
import { registerAiVideoApi } from "./server/aiVideoApi.mjs";
import { registerVideoMergeApi } from "./server/videoMergeApi.mjs";

const aiVideoApiPlugin = (env: Record<string, string>) => ({
  name: "videotoanhoc-ai-video-api",
  configureServer(server: Parameters<typeof registerAiVideoApi>[0]["server"]) {
    registerAiVideoApi({ server, env });
    registerVideoMergeApi({ server });
  },
});

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), "");

  return {
    plugins: [react(), aiVideoApiPlugin(env)],
    server: {
      host: "127.0.0.1",
      port: 5173,
    },
  };
});
