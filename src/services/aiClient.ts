import type {
  GeneratedVideo,
  InfographicBlock,
  LearningSupportType,
} from "../types";

const DEFAULT_VIDEO_ENDPOINT = "/api/ai-video/generate";

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
}: {
  title: string;
  prompt: string;
}): Promise<GeneratedVideo> => {
  const proxyUrl = import.meta.env.VITE_AI_VIDEO_PROXY_URL?.trim() || DEFAULT_VIDEO_ENDPOINT;

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
    error?: string;
  };

  if (!response.ok) {
    throw new Error(
      data.error ??
        `API tao video loi ${response.status}. Kiem tra Vite dev server va token AIVideoAuto.`,
    );
  }

  const url = data.videoUrl ?? data.url;
  if (!url) {
    throw new Error("API tao video khong tra ve videoUrl/download_url.");
  }

  return {
    id: crypto.randomUUID(),
    title,
    prompt,
    url,
  };
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
