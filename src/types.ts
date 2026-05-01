export type UserRole = "student" | "teacher";

export interface UserModel {
  id: string;
  email: string;
  fullName: string;
  role: UserRole;
  className?: string;
  createdAt: string;
  loginCount: number;
  lastLoginAt?: string;
}

export interface UserRecord extends UserModel {
  password: string;
}

export interface ClassModel {
  id: string;
  className: string;
  teacherId: string;
  teacherName: string;
  createdAt: string;
  studentCount: number;
}

export type VideoSourceType = "text" | "image" | "text-image" | "series";

export interface SavedVideo {
  id: string;
  videoUrl: string;
  title: string;
  sourceType: VideoSourceType;
  createdAt: string;
  prompt?: string;
  createdBy?: string;
  thumbnailUrl?: string;
}

export type LearningSupportType = "simulation" | "lesson" | "real-world" | "practice";

export interface GeneratedVideo {
  id: string;
  url: string;
  title: string;
  prompt: string;
  kind?: "clip" | "merged";
  sceneCount?: number;
}

export interface ChatMessage {
  id: string;
  role: "user" | "assistant";
  content: string;
  createdAt: string;
}

export interface InfographicBlock {
  title: string;
  value: string;
  tone: "teal" | "rose" | "amber" | "blue";
}
