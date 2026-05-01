import { handleAiVideoGenerate } from "../../server/aiVideoApi.mjs";

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

  try {
    const result = await handleAiVideoGenerate({
      method: req.method,
      url: req.url,
      body: parseBody(req.body),
      env: process.env,
      root: process.cwd(),
    });

    if (result.statusCode === 204) {
      res.status(204).end();
      return;
    }

    res.status(result.statusCode).json(result.payload);
  } catch (error) {
    res.status(500).json({
      error: error instanceof Error ? error.message : String(error),
    });
  }
}
