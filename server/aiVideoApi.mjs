import fs from "node:fs";
import path from "node:path";

let requestSequence = 0;

const readJsonBody = (req) =>
  new Promise((resolve, reject) => {
    let body = "";
    req.on("data", (chunk) => {
      body += chunk;
      if (body.length > 1024 * 1024) {
        req.destroy();
        reject(new Error("Request body qua lon."));
      }
    });
    req.on("end", () => {
      try {
        resolve(body ? JSON.parse(body) : {});
      } catch {
        reject(new Error("Request body khong phai JSON hop le."));
      }
    });
    req.on("error", reject);
  });

const sendJson = (res, statusCode, payload) => {
  res.statusCode = statusCode;
  res.setHeader("Content-Type", "application/json; charset=utf-8");
  res.end(JSON.stringify(payload));
};

const extractDartConst = (source, name) => {
  const pattern = new RegExp(
    `static\\s+const\\s+String\\s+${name}\\s*=\\s*[\\r\\n\\s]*(['"])([\\s\\S]*?)\\1\\s*;`,
    "m",
  );
  return source.match(pattern)?.[2]?.trim() ?? "";
};

const loadFlutterApiConfig = (root) => {
  const filePath = path.join(root, "lib", "config", "api_config.dart");
  if (!fs.existsSync(filePath)) {
    return {};
  }

  const source = fs.readFileSync(filePath, "utf8");
  return {
    accessToken: extractDartConst(source, "aiVideoAccessToken"),
    baseUrl: extractDartConst(source, "aiVideoBaseUrl"),
    domain: extractDartConst(source, "aiVideoDomain"),
    projectId: extractDartConst(source, "aiVideoProjectId"),
    modelId: extractDartConst(source, "aiVideoModel"),
    resolution: extractDartConst(source, "aiVideoResolution"),
  };
};

const resolveConfig = (root, env) => {
  const flutter = loadFlutterApiConfig(root);
  return {
    accessToken:
      env.AI_VIDEO_ACCESS_TOKEN ||
      process.env.AI_VIDEO_ACCESS_TOKEN ||
      flutter.accessToken ||
      "",
    baseUrl:
      env.AI_VIDEO_BASE_URL ||
      process.env.AI_VIDEO_BASE_URL ||
      flutter.baseUrl ||
      "https://api.gommo.net/ai",
    domain:
      env.AI_VIDEO_DOMAIN ||
      process.env.AI_VIDEO_DOMAIN ||
      flutter.domain ||
      "aivideoauto.com",
    projectId:
      env.AI_VIDEO_PROJECT_ID ||
      process.env.AI_VIDEO_PROJECT_ID ||
      flutter.projectId ||
      "default",
    modelId:
      env.AI_VIDEO_MODEL ||
      process.env.AI_VIDEO_MODEL ||
      flutter.modelId ||
      "grok_video_heavy",
    resolution:
      env.AI_VIDEO_RESOLUTION ||
      process.env.AI_VIDEO_RESOLUTION ||
      flutter.resolution ||
      "720p",
    mode: env.AI_VIDEO_MODE || process.env.AI_VIDEO_MODE || "normal",
  };
};

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

const responseSnippet = (responseBody) => {
  const compact = responseBody.replace(/\s+/g, " ").trim();
  return compact.length <= 500 ? compact : `${compact.slice(0, 500)}...`;
};

const preparePromptForBackend = (prompt, aggressive = false) => {
  let result = prompt.trim().replaceAll("\r", "");
  result = result.replaceAll("**", "").replaceAll("`", "");
  result = result.replace(/\n{3,}/g, "\n\n");

  if (aggressive) {
    result = result
      .replace(
        /^(diem hoc sinh chua hieu|kieu ho tro da ap dung|cau hoi goi mo cuoi video|nhan kien thuc|phuong trinh goi y \(neu co\)|canh \d+ \([^\n]*\):)\s*/gim,
        "",
      )
      .replace(/^-\s*/gim, "")
      .replaceAll("\n", ". ");
  }

  result = result.replace(/[ \t]+/g, " ").replace(/ *\n */g, "\n").trim();

  const maxLength = aggressive ? 520 : 850;
  if (result.length > maxLength) {
    const boundary = aggressive ? ". " : "\n";
    const cutIndex = result.lastIndexOf(boundary, maxLength);
    result = result.slice(0, cutIndex > 120 ? cutIndex : maxLength).trim();
  }

  if (aggressive && !result.toLowerCase().includes("safe for all audiences")) {
    result = `${result}. Safe for all audiences. Silent educational mathematics video.`;
  }

  return result;
};

const shouldRetryWithRecoveryProfile = (message) => {
  const text = message.toLowerCase();
  return (
    text.includes("#acr") ||
    text.includes("please try again later") ||
    text.includes("temporarily unavailable") ||
    text.includes("server is busy") ||
    text.includes("qua tai")
  );
};

const buildSaferPromptFrom = (basePrompt) =>
  `${basePrompt.trim()}\n\nSAFETY REQUIREMENTS: The video must be safe for all audiences, avoiding explicit violence, gore, blood, weapons usage, dangerous acts, hate speech, or adult content. Use inspirational, symbolic, and non-violent visuals instead.`;

const mapDuration = (seconds) => (seconds <= 10 ? 10 : 15);
const mapAspectRatio = () => "9:16";

const nextRequestProjectId = (projectId) => {
  const base = projectId.trim() || "default";
  const safeBase = base.replace(/[^A-Za-z0-9_-]/g, "_");
  const prefix = safeBase.length > 32 ? safeBase.slice(0, 32) : safeBase;
  const sequence = ++requestSequence;
  const timestamp = Date.now() * 1000;
  return `${prefix}_${timestamp}_${sequence}`;
};

const pollIntervalSeconds = (attempt) => {
  if (attempt <= 12) return 5;
  if (attempt <= 60) return 8;
  return 10;
};

const buildCreateFormBody = ({
  config,
  prompt,
  seconds,
  aspectRatio,
  isVeo,
  requestProjectId,
}) => {
  const durationToUse = String(seconds);
  const modeToUse = isVeo ? "fast" : config.mode;
  const fields = [
    `domain=${encodeURIComponent(config.domain)}`,
    `project_id=${encodeURIComponent(requestProjectId)}`,
    `access_token=${config.accessToken}`,
    `model=${encodeURIComponent(config.modelId)}`,
    `ratio=${encodeURIComponent(aspectRatio)}`,
    `resolution=${encodeURIComponent(config.resolution)}`,
    `duration=${encodeURIComponent(durationToUse)}`,
    `mode=${encodeURIComponent(modeToUse)}`,
    `prompt=${encodeURIComponent(prompt)}`,
  ];
  return fields.join("&");
};

const buildPollFormBody = ({ config, idBase }) =>
  [
    `access_token=${config.accessToken}`,
    `domain=${encodeURIComponent(config.domain)}`,
    `id_base=${encodeURIComponent(idBase)}`,
  ].join("&");

const postForm = async (url, body) => {
  const response = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
  });
  const text = await response.text();
  return { response, text };
};

const waitForPredictionCompletion = async ({ config, idBase, prompt }) => {
  const isVeo = config.modelId.toLowerCase().includes("veo");
  const maxAttempts = isVeo ? 180 : 100;
  let elapsedSeconds = 0;

  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    const interval = pollIntervalSeconds(attempt);
    await sleep(interval * 1000);
    elapsedSeconds += interval;

    const url = `${config.baseUrl}/video`;
    const { response, text } = await postForm(
      url,
      buildPollFormBody({ config, idBase }),
    );

    if (!response.ok) {
      throw new Error(
        `Loi kiem tra trang thai job (${response.status}): ${responseSnippet(text)}`,
      );
    }

    const data = JSON.parse(text);
    const videoInfo = data.videoInfo ?? data.data ?? {};
    const status = String(videoInfo.status ?? "").toUpperCase();
    const downloadUrl = videoInfo.download_url ?? videoInfo.result_url;
    const percent = videoInfo.percent ?? "0";

    if (status.includes("SUCCESS")) {
      if (downloadUrl) {
        return {
          videoUrl: downloadUrl,
          idBase,
          status,
          percent,
          elapsedSeconds,
        };
      }
      throw new Error("Video da hoan thanh nhung API khong tra ve download_url.");
    }

    if (status.includes("FAILED") || status === "ERROR" || status.includes("ERROR")) {
      const message = videoInfo.message ?? data.message ?? "Unknown error";
      throw new Error(`Loi khi tao video: ${message}`);
    }

    if (status.includes("CANCEL")) {
      throw new Error("Job tao video da bi huy.");
    }
  }

  throw new Error(
    `May chu tao video phan hoi qua cham. Job van co the dang xu ly tren server (id: ${idBase}).`,
  );
};

const createPrediction = async ({ config, prompt, seconds, aspectRatio }) => {
  const isVeo = config.modelId.toLowerCase().includes("veo");
  let preparedPrompt = preparePromptForBackend(prompt);
  const mappedDuration = isVeo ? 5 : mapDuration(seconds);
  const mappedRatio = isVeo ? "16:9" : mapAspectRatio(aspectRatio);
  const requestProjectId = nextRequestProjectId(config.projectId);
  const url = `${config.baseUrl}/create-video`;

  const { response, text } = await postForm(
    url,
    buildCreateFormBody({
      config,
      prompt: preparedPrompt,
      seconds: mappedDuration,
      aspectRatio: mappedRatio,
      isVeo,
      requestProjectId,
    }),
  );

  if (![200, 201, 202].includes(response.status)) {
    throw new Error(`Loi tao job video (${response.status}): ${responseSnippet(text)}`);
  }

  const data = JSON.parse(text);
  if (data.success !== true) {
    throw new Error(`Loi khi tao job video: ${data.message ?? responseSnippet(text)}`);
  }

  const videoInfo = data.videoInfo ?? data.data ?? {};
  const status = String(videoInfo.status ?? "").toUpperCase();
  const idBase = videoInfo.id_base;
  const downloadUrl = videoInfo.download_url ?? videoInfo.result_url;

  if (status.includes("SUCCESS") && downloadUrl) {
    return {
      videoUrl: downloadUrl,
      idBase,
      status,
      percent: "100",
      elapsedSeconds: 0,
    };
  }

  if (status.includes("FAILED") || status === "ERROR" || status.includes("ERROR")) {
    throw new Error(
      `Loi khi tao video: ${data.message ?? videoInfo.message ?? "Video generation failed immediately"}`,
    );
  }

  if (!idBase) {
    throw new Error(`API da nhan job nhung khong tra ve id_base: ${responseSnippet(text)}`);
  }

  return waitForPredictionCompletion({ config, idBase, prompt: preparedPrompt });
};

const generateVideoWithRecovery = async ({ config, prompt, seconds, aspectRatio }) => {
  try {
    return await createPrediction({ config, prompt, seconds, aspectRatio });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    if (!shouldRetryWithRecoveryProfile(message)) {
      throw error;
    }

    return createPrediction({
      config,
      prompt: preparePromptForBackend(buildSaferPromptFrom(prompt), true),
      seconds: seconds <= 10 ? 10 : 15,
      aspectRatio,
    });
  }
};

export const registerAiVideoApi = ({ server, env }) => {
  const root = server.config.root;

  server.middlewares.use("/api/ai-video/generate", async (req, res) => {
    res.setHeader("Access-Control-Allow-Origin", "*");
    res.setHeader("Access-Control-Allow-Methods", "POST, OPTIONS");
    res.setHeader("Access-Control-Allow-Headers", "Content-Type");

    if (req.method === "OPTIONS") {
      res.statusCode = 204;
      res.end();
      return;
    }

    if (req.method !== "POST") {
      sendJson(res, 405, { error: "Method not allowed" });
      return;
    }

    try {
      const body = await readJsonBody(req);
      const config = resolveConfig(root, env);

      if (!config.accessToken) {
        sendJson(res, 500, {
          error:
            "Thieu AI_VIDEO_ACCESS_TOKEN va khong doc duoc token tu lib/config/api_config.dart.",
        });
        return;
      }

      if (req.url?.includes("dryRun=1")) {
        sendJson(res, 200, {
          ok: true,
          modelId: config.modelId,
          resolution: config.resolution,
          baseUrl: config.baseUrl,
          domain: config.domain,
          tokenSource: "server-side",
        });
        return;
      }

      const prompt = String(body.prompt ?? "").trim();
      if (!prompt) {
        sendJson(res, 400, { error: "Vui long gui prompt de tao video." });
        return;
      }

      const result = await generateVideoWithRecovery({
        config,
        prompt,
        seconds: Number(body.seconds ?? 10),
        aspectRatio: String(body.aspectRatio ?? "portrait"),
      });

      sendJson(res, 200, {
        ...result,
        title: body.title ?? "Video Toan hoc",
        modelId: config.modelId,
        resolution: config.resolution,
      });
    } catch (error) {
      sendJson(res, 500, {
        error: error instanceof Error ? error.message : String(error),
      });
    }
  });
};
