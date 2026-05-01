import {
  mergeVideosToFile,
  parseMergeRequestBody,
  streamMergedVideo,
  videoMergeDryRunPayload,
} from "../../server/videoMergeApi.mjs";

export const config = {
  maxDuration: 300,
};

const parseBody = (body) => {
  if (!body) return {};
  if (typeof body === "object" && !Buffer.isBuffer(body)) return body;

  const text = Buffer.isBuffer(body) ? body.toString("utf8") : String(body);
  return text ? JSON.parse(text) : {};
};

export default async function handler(req, res) {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");

  if (req.method === "OPTIONS") {
    res.status(204).end();
    return;
  }

  if (req.method !== "POST") {
    res.status(405).json({ error: "Method not allowed" });
    return;
  }

  try {
    if (req.url?.includes("dryRun=1")) {
      res.status(200).json(videoMergeDryRunPayload());
      return;
    }

    const input = parseMergeRequestBody(parseBody(req.body));
    const merged = await mergeVideosToFile(input);
    streamMergedVideo({ res, merged });
  } catch (error) {
    res.status(500).json({
      error: error instanceof Error ? error.message : String(error),
    });
  }
}
