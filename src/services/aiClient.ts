import type {
  GeneratedVideo,
  InfographicBlock,
  LearningSupportType,
} from "../types";

const DEFAULT_VIDEO_ENDPOINT = "/api/ai-video/generate";
const DEFAULT_VIDEO_STATUS_ENDPOINT = "/api/ai-video/status";
const DEFAULT_VIDEO_MERGE_ENDPOINT = "/api/ai-video/merge";
const VIDEO_POLL_LIMIT = 120;

type LocalWritableFile = {
  write: (data: Blob) => Promise<void>;
  close: () => Promise<void>;
};

type LocalFileHandle = {
  createWritable: () => Promise<LocalWritableFile>;
};

type LocalDirectoryHandle = {
  getFileHandle: (
    name: string,
    options?: { create?: boolean },
  ) => Promise<LocalFileHandle>;
};

type LocalSaveResult = {
  count: number;
  mode: "folder" | "downloads";
  fallbackCount: number;
};

const supportCopy: Record<LearningSupportType, string> = {
  simulation: "mo phong truc quan tung buoc",
  lesson: "bai giang ngan gon theo mach khai niem - vi du - ket luan",
  "real-world": "ung dung doi song va tinh huong gan gui",
  practice: "bai tap mau co loi giai cham",
};

export const buildMathPrompt = ({
  topic,
  supportType,
  index = 1,
  total = 1,
  imageName,
}: {
  topic: string;
  supportType: LearningSupportType;
  index?: number;
  total?: number;
  imageName?: string;
}) => {
  const shot = total > 1 ? `Canh ${index}/${total}. ` : "";
  const imageLine = imageName ? `Tham chieu hinh anh nguoi hoc gui: ${imageName}. ` : "";

  return [
    `${shot}Tao video Toan hoc 9:16, thoi luong 6-10 giay, ngon ngu tieng Viet.`,
    `Chu de: ${topic.trim()}.`,
    `Kieu ho tro: ${supportCopy[supportType]}.`,
    imageLine,
    "Hinh anh can sach, bang phan hoac do thi ro net, ky hieu toan hoc chinh xac, khong dung nhan vat noi tieng.",
    "Uu tien chuyen dong camera cham, highlight cong thuc, mau sac tuong phan va ket luan de nho.",
  ]
    .filter(Boolean)
    .join(" ");
};

export const generateVideoClip = async ({
  title,
  prompt,
  onProgress,
}: {
  title: string;
  prompt: string;
  onProgress?: (message: string) => void;
}): Promise<GeneratedVideo> => {
  const proxyUrl = import.meta.env.VITE_AI_VIDEO_PROXY_URL?.trim() || DEFAULT_VIDEO_ENDPOINT;
  const inferredStatusUrl = /\/generate(\?.*)?$/.test(proxyUrl)
    ? proxyUrl.replace(/\/generate(\?.*)?$/, "/status")
    : DEFAULT_VIDEO_STATUS_ENDPOINT;
  const statusUrl =
    import.meta.env.VITE_AI_VIDEO_STATUS_URL?.trim() || inferredStatusUrl;

  const response = await fetch(proxyUrl, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      title,
      prompt,
      seconds: 10,
      aspectRatio: "portrait",
    }),
  });

  const data = (await response.json().catch(() => ({}))) as {
    videoUrl?: string;
    url?: string;
    idBase?: string;
    id_base?: string;
    status?: string;
    percent?: string | number;
    pollUrl?: string;
    error?: string;
  };

  if (!response.ok) {
    throw new Error(
      data.error ??
        `API tao video loi ${response.status}. Kiem tra Vite dev server va token AIVideoAuto.`,
    );
  }

  let url = data.videoUrl ?? data.url;
  const idBase = data.idBase ?? data.id_base;
  if (!url && idBase) {
    onProgress?.("Da tao job, dang cho AI render video...");
    url = await pollVideoCompletion({
      idBase,
      statusUrl: data.pollUrl ?? statusUrl,
      onProgress,
    });
  }

  if (!url) {
    throw new Error(
      data.status
        ? `API chua tra ve videoUrl/download_url. Trang thai hien tai: ${data.status}.`
        : "API tao video khong tra ve videoUrl/download_url.",
    );
  }

  return {
    id: crypto.randomUUID(),
    title,
    prompt,
    url,
    kind: "clip",
  };
};

export const mergeVideoClips = async ({
  title,
  videos,
  onProgress,
}: {
  title: string;
  videos: GeneratedVideo[];
  onProgress?: (message: string) => void;
}): Promise<GeneratedVideo> => {
  if (videos.length < 2) {
    throw new Error("Can it nhat 2 video de ghep.");
  }

  const mergeUrl =
    import.meta.env.VITE_AI_VIDEO_MERGE_URL?.trim() || DEFAULT_VIDEO_MERGE_ENDPOINT;

  onProgress?.(`Dang tai va ghep ${videos.length} video...`);
  const response = await fetch(mergeUrl, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      title,
      videos: videos.map((video) => ({
        url: video.url,
        title: video.title,
      })),
    }),
  });

  if (!response.ok) {
    const data = (await response.json().catch(() => ({}))) as { error?: string };
    throw new Error(data.error ?? `API ghep video loi ${response.status}.`);
  }

  const blob = await response.blob();
  if (!blob.size) {
    throw new Error("API ghep video tra ve file rong.");
  }

  onProgress?.("Da ghep xong video.");
  return {
    id: crypto.randomUUID(),
    title,
    prompt: `Video ghep tu ${videos.length} canh: ${videos.map((video) => video.title).join("; ")}`,
    url: URL.createObjectURL(blob),
    kind: "merged",
    sceneCount: videos.length,
  };
};

const sanitizeFileName = (value: string, fallback = "video") => {
  const safe =
    value
      .trim()
      .replace(/[^\p{L}\p{N}_-]+/gu, "-")
      .replace(/^-+|-+$/g, "")
      .slice(0, 90) || fallback;
  return safe.endsWith(".mp4") ? safe : `${safe}.mp4`;
};

const getDirectoryPicker = () =>
  (window as Window & {
    showDirectoryPicker?: () => Promise<LocalDirectoryHandle>;
  }).showDirectoryPicker;

const fetchVideoBlob = async (url: string) => {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`Khong tai duoc video: HTTP ${response.status}`);
  }
  return response.blob();
};

const writeBlobToDirectory = async (
  directory: LocalDirectoryHandle,
  filename: string,
  blob: Blob,
) => {
  const fileHandle = await directory.getFileHandle(filename, { create: true });
  const writable = await fileHandle.createWritable();
  await writable.write(blob);
  await writable.close();
};

const triggerBlobDownload = (blob: Blob, filename: string) => {
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = filename;
  document.body.append(anchor);
  anchor.click();
  anchor.remove();
  window.setTimeout(() => URL.revokeObjectURL(url), 30_000);
};

const triggerUrlDownload = (url: string, filename: string) => {
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = filename;
  anchor.target = "_blank";
  anchor.rel = "noopener";
  document.body.append(anchor);
  anchor.click();
  anchor.remove();
};

const pauseBetweenDownloads = () => sleep(350);

export const saveVideoToDevice = async ({
  video,
  onProgress,
}: {
  video: GeneratedVideo;
  onProgress?: (message: string) => void;
}): Promise<LocalSaveResult> => {
  return saveVideosToDevice({ videos: [video], onProgress });
};

export const saveVideosToDevice = async ({
  videos,
  onProgress,
}: {
  videos: GeneratedVideo[];
  onProgress?: (message: string) => void;
}): Promise<LocalSaveResult> => {
  if (videos.length === 0) {
    throw new Error("Chua co video de luu.");
  }

  const picker = getDirectoryPicker();
  const directory = picker ? await picker() : null;
  let savedCount = 0;
  let fallbackCount = 0;

  for (let index = 0; index < videos.length; index += 1) {
    const video = videos[index];
    const filename = sanitizeFileName(
      videos.length === 1
        ? video.title
        : `${String(index + 1).padStart(2, "0")}-${video.title}`,
    );
    onProgress?.(`Dang luu video ${index + 1}/${videos.length} ve may...`);

    try {
      const blob = await fetchVideoBlob(video.url);
      if (directory) {
        await writeBlobToDirectory(directory, filename, blob);
      } else {
        triggerBlobDownload(blob, filename);
        await pauseBetweenDownloads();
      }
      savedCount += 1;
    } catch {
      fallbackCount += 1;
      triggerUrlDownload(video.url, filename);
      await pauseBetweenDownloads();
    }
  }

  return {
    count: savedCount + fallbackCount,
    mode: directory ? "folder" : "downloads",
    fallbackCount,
  };
};

const sleep = (ms: number) => new Promise((resolve) => window.setTimeout(resolve, ms));

const pollDelay = (attempt: number) => {
  if (attempt <= 4) return 2500;
  if (attempt <= 18) return 5000;
  return 8000;
};

const statusMessage = (status?: string, percent?: string | number) => {
  const percentText =
    percent === undefined || percent === null || String(percent) === "0"
      ? ""
      : ` ${percent}%`;
  return `Dang render video${percentText}${status ? ` (${status})` : ""}...`;
};

const pollVideoCompletion = async ({
  idBase,
  statusUrl,
  onProgress,
}: {
  idBase: string;
  statusUrl: string;
  onProgress?: (message: string) => void;
}) => {
  let lastStatus = "PROCESSING";

  for (let attempt = 1; attempt <= VIDEO_POLL_LIMIT; attempt += 1) {
    await sleep(pollDelay(attempt));

    const response = await fetch(statusUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ idBase }),
    });

    const data = (await response.json().catch(() => ({}))) as {
      videoUrl?: string;
      url?: string;
      status?: string;
      percent?: string | number;
      error?: string;
    };

    if (!response.ok) {
      throw new Error(
        data.error ?? `API kiem tra trang thai video loi ${response.status}.`,
      );
    }

    const videoUrl = data.videoUrl ?? data.url;
    if (videoUrl) return videoUrl;

    lastStatus = data.status ?? lastStatus;
    onProgress?.(statusMessage(data.status, data.percent));
  }

  throw new Error(
    `Video chua hoan thanh sau thoi gian cho. Ma job: ${idBase}. Trang thai cuoi: ${lastStatus}.`,
  );
};

export const askMathAssistant = async (question: string, language: "vi" | "en") => {
  const proxyUrl = import.meta.env.VITE_GEMINI_PROXY_URL?.trim();

  if (proxyUrl) {
    const response = await fetch(proxyUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ question, language }),
    });

    if (!response.ok) throw new Error(`Gemini proxy loi ${response.status}`);
    const data = (await response.json()) as { answer?: string };
    return data.answer ?? "Chua co cau tra loi tu proxy.";
  }

  const trimmed = question.trim();
  if (language === "en") {
    return [
      `For "${trimmed}", start by naming the known quantities, then write the formula before substituting numbers.`,
      "If the topic contains a triangle, draw the triangle and mark sides/angles first. If it is an equation, move like terms together and check the result by substitution.",
    ].join("\n\n");
  }

  return [
    `Voi cau hoi "${trimmed}", em nen tach bai toan thanh 3 buoc: xac dinh gia thiet, chon cong thuc, roi thay so va kiem tra lai ket qua.`,
    "Neu bai co hinh hoc, hay ve hinh va danh dau du lieu truoc. Neu la dai so, gom hang tu cung loai va thu lai dap an vao de bai.",
  ].join("\n\n");
};

export const buildInfographic = (topic: string): InfographicBlock[] => [
  {
    title: "Y tuong chinh",
    value: topic.trim() || "Chu de Toan hoc",
    tone: "teal",
  },
  {
    title: "Cong thuc",
    value: "Viet cong thuc tong quat truoc khi thay so.",
    tone: "blue",
  },
  {
    title: "Loi giai",
    value: "Di tu gia thiet den ket luan, moi dong chi bien doi mot y.",
    tone: "amber",
  },
  {
    title: "Kiem tra",
    value: "Thu lai dap an, doi chieu don vi va dieu kien cua bien.",
    tone: "rose",
  },
];

export const buildLesson = (topic: string) => ({
  title: `Bai hoc nhanh: ${topic.trim() || "Toan hoc"}`,
  points: [
    "Xac dinh du lieu da cho va dieu can tim.",
    "Chon cong thuc hoac dinh ly phu hop voi dang bai.",
    "Trinh bay tung buoc ngan gon, uu tien ky hieu ro rang.",
    "Kiem tra dap an bang cach thay nguoc hoac so sanh voi truc quan.",
  ],
});
