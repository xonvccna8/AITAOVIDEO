import { execFile } from "node:child_process";
import { createReadStream, createWriteStream } from "node:fs";
import {
  mkdtemp,
  rm,
  stat,
  writeFile,
} from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { Readable, Transform } from "node:stream";
import { pipeline } from "node:stream/promises";
import ffmpegPath from "ffmpeg-static";

const MAX_CLIPS = 10;
const MAX_CLIP_BYTES = 80 * 1024 * 1024;
const FFMPEG_TIMEOUT_MS = 280_000;

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

export const videoMergeDryRunPayload = () => ({
  ok: true,
  hasFfmpeg: Boolean(ffmpegPath),
  maxClips: MAX_CLIPS,
  maxClipMb: Math.round(MAX_CLIP_BYTES / 1024 / 1024),
});

export const parseMergeRequestBody = (body = {}) => {
  const rawVideos = Array.isArray(body.videos)
    ? body.videos
    : Array.isArray(body.urls)
      ? body.urls
      : [];

  const videos = rawVideos
    .map((item) => (typeof item === "string" ? item : item?.url))
    .filter((url) => typeof url === "string" && /^https?:\/\//i.test(url.trim()))
    .map((url) => url.trim());

  if (videos.length < 2) {
    throw new Error("Can it nhat 2 video URL de ghep.");
  }

  if (videos.length > MAX_CLIPS) {
    throw new Error(`Chi ho tro ghep toi da ${MAX_CLIPS} video moi lan.`);
  }

  const title = String(body.title ?? "video-da-ghep")
    .trim()
    .replace(/[^\p{L}\p{N}_-]+/gu, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 80) || "video-da-ghep";

  return { videos, title };
};

const escapeConcatPath = (filePath) =>
  path.resolve(filePath).replace(/\\/g, "/").replace(/'/g, "'\\''");

const makeConcatList = (files) =>
  files.map((filePath) => `file '${escapeConcatPath(filePath)}'`).join("\n");

const downloadVideo = async ({ url, outputPath, index, total, onProgress }) => {
  onProgress?.(`Dang tai video ${index}/${total}...`);

  const response = await fetch(url);
  if (!response.ok || !response.body) {
    throw new Error(`Khong tai duoc video ${index}: HTTP ${response.status}`);
  }

  let downloaded = 0;
  const limiter = new Transform({
    transform(chunk, _encoding, callback) {
      downloaded += chunk.length;
      if (downloaded > MAX_CLIP_BYTES) {
        callback(
          new Error(
            `Video ${index} qua lon. Gioi han moi clip la ${Math.round(
              MAX_CLIP_BYTES / 1024 / 1024,
            )}MB.`,
          ),
        );
        return;
      }
      callback(null, chunk);
    },
  });

  await pipeline(
    Readable.fromWeb(response.body),
    limiter,
    createWriteStream(outputPath),
  );

  return outputPath;
};

const runFfmpeg = (args) =>
  new Promise((resolve, reject) => {
    if (!ffmpegPath) {
      reject(new Error("Khong tim thay ffmpeg-static binary."));
      return;
    }

    const child = execFile(
      ffmpegPath,
      args,
      {
        timeout: FFMPEG_TIMEOUT_MS,
        maxBuffer: 1024 * 1024 * 8,
      },
      (error, stdout, stderr) => {
        if (error) {
          reject(
            new Error(
              [
                error.message,
                stderr?.trim(),
                stdout?.trim(),
              ]
                .filter(Boolean)
                .join("\n"),
            ),
          );
          return;
        }
        resolve();
      },
    );

    child.on("error", reject);
  });

const concatWithCopy = async ({ listPath, outputPath }) => {
  await runFfmpeg([
    "-hide_banner",
    "-loglevel",
    "warning",
    "-y",
    "-f",
    "concat",
    "-safe",
    "0",
    "-i",
    listPath,
    "-c",
    "copy",
    "-movflags",
    "+faststart",
    outputPath,
  ]);
};

const concatWithReencode = async ({ listPath, outputPath }) => {
  await runFfmpeg([
    "-hide_banner",
    "-loglevel",
    "warning",
    "-y",
    "-f",
    "concat",
    "-safe",
    "0",
    "-i",
    listPath,
    "-c:v",
    "libx264",
    "-preset",
    "veryfast",
    "-pix_fmt",
    "yuv420p",
    "-c:a",
    "aac",
    "-b:a",
    "128k",
    "-movflags",
    "+faststart",
    outputPath,
  ]);
};

export const mergeVideosToFile = async ({ videos, title, onProgress }) => {
  const workDir = await mkdtemp(path.join(os.tmpdir(), "videotoanhoc-merge-"));
  let cleaned = false;
  const cleanup = async () => {
    if (cleaned) return;
    cleaned = true;
    await rm(workDir, { recursive: true, force: true }).catch(() => {});
  };

  try {
    const clipPaths = [];
    for (let index = 0; index < videos.length; index += 1) {
      const clipPath = path.join(workDir, `clip_${index + 1}.mp4`);
      clipPaths.push(
        await downloadVideo({
          url: videos[index],
          outputPath: clipPath,
          index: index + 1,
          total: videos.length,
          onProgress,
        }),
      );
    }

    const listPath = path.join(workDir, "concat_list.txt");
    const outputPath = path.join(workDir, `${title || "merged-video"}.mp4`);
    await writeFile(listPath, `${makeConcatList(clipPaths)}\n`, "utf8");

    onProgress?.(`Dang ghep ${videos.length} video...`);
    try {
      await concatWithCopy({ listPath, outputPath });
    } catch (copyError) {
      await rm(outputPath, { force: true }).catch(() => {});
      onProgress?.("Dang ghep lai voi che do tuong thich...");
      await concatWithReencode({ listPath, outputPath });
    }

    const info = await stat(outputPath);
    return {
      outputPath,
      filename: `${title || "merged-video"}.mp4`,
      sizeBytes: info.size,
      cleanup,
    };
  } catch (error) {
    await cleanup();
    throw error;
  }
};

export const streamMergedVideo = ({ res, merged }) => {
  res.statusCode = 200;
  res.setHeader("Content-Type", "video/mp4");
  res.setHeader(
    "Content-Disposition",
    `inline; filename="${encodeURIComponent(merged.filename)}"`,
  );
  res.setHeader("Cache-Control", "no-store");
  res.setHeader("Content-Length", String(merged.sizeBytes));

  const cleanup = () => {
    void merged.cleanup();
  };
  res.on("finish", cleanup);
  res.on("close", cleanup);

  const stream = createReadStream(merged.outputPath);
  stream.on("error", cleanup);
  stream.pipe(res);
};

export const registerVideoMergeApi = ({ server }) => {
  server.middlewares.use("/api/ai-video/merge", async (req, res) => {
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
      if (req.url?.includes("dryRun=1")) {
        sendJson(res, 200, videoMergeDryRunPayload());
        return;
      }

      const input = parseMergeRequestBody(await readJsonBody(req));
      const merged = await mergeVideosToFile(input);
      streamMergedVideo({ res, merged });
    } catch (error) {
      sendJson(res, 500, {
        error: error instanceof Error ? error.message : String(error),
      });
    }
  });
};
