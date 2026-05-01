import type { ClassModel, SavedVideo, UserModel, UserRecord, UserRole } from "../types";

const USERS_KEY = "videotoanhoc_users";
const CLASSES_KEY = "videotoanhoc_classes";
const CURRENT_USER_KEY = "videotoanhoc_current_user_id";
const GALLERY_KEY = "videotoanhoc_gallery";

const nowIso = () => new Date().toISOString();

const makeId = (prefix: string) => {
  if (typeof crypto !== "undefined" && "randomUUID" in crypto) {
    return `${prefix}_${crypto.randomUUID()}`;
  }

  return `${prefix}_${Date.now()}_${Math.random().toString(16).slice(2)}`;
};

const readJson = <T>(key: string, fallback: T): T => {
  try {
    const raw = localStorage.getItem(key);
    return raw ? (JSON.parse(raw) as T) : fallback;
  } catch {
    return fallback;
  }
};

const writeJson = <T>(key: string, value: T) => {
  localStorage.setItem(key, JSON.stringify(value));
};

const toUser = (record: UserRecord): UserModel => {
  const { password: _password, ...user } = record;
  return user;
};

const normalizeEmail = (email: string) => email.trim().toLowerCase();
const classKey = (className: string) => className.trim().toLowerCase().replace(/\s+/g, "_");

export const getUserRecords = () => readJson<UserRecord[]>(USERS_KEY, []);
const saveUserRecords = (users: UserRecord[]) => writeJson(USERS_KEY, users);

const getClassRecords = () => readJson<Omit<ClassModel, "studentCount">[]>(CLASSES_KEY, []);
const saveClassRecords = (classes: Omit<ClassModel, "studentCount">[]) =>
  writeJson(CLASSES_KEY, classes);

export const getCurrentUser = (): UserModel | null => {
  const currentId = localStorage.getItem(CURRENT_USER_KEY);
  if (!currentId) return null;

  const record = getUserRecords().find((user) => user.id === currentId);
  return record ? toUser(record) : null;
};

export const logoutUser = () => {
  localStorage.removeItem(CURRENT_USER_KEY);
};

const setCurrentUser = (userId: string) => {
  localStorage.setItem(CURRENT_USER_KEY, userId);
};

const ensureClassForStudent = (className?: string) => {
  if (!className?.trim()) return;

  const classes = getClassRecords();
  const exists = classes.some((item) => classKey(item.className) === classKey(className));
  if (exists) return;

  classes.push({
    id: makeId("class"),
    className: className.trim(),
    teacherId: "system",
    teacherName: "He thong",
    createdAt: nowIso(),
  });
  saveClassRecords(classes);
};

export const initializeDemoData = () => {
  if (getUserRecords().length > 0) return;

  const createdAt = nowIso();
  const teacher: UserRecord = {
    id: makeId("user"),
    email: "teacher@MathVision.com",
    password: "teacher123",
    fullName: "Giao vien Demo",
    role: "teacher",
    createdAt,
    loginCount: 0,
  };

  const student: UserRecord = {
    id: makeId("user"),
    email: "student@MathVision.com",
    password: "student123",
    fullName: "Hoc sinh Demo",
    role: "student",
    className: "6A1",
    createdAt,
    loginCount: 0,
  };

  saveUserRecords([teacher, student]);
  saveClassRecords([
    {
      id: makeId("class"),
      className: "6A1",
      teacherId: teacher.id,
      teacherName: teacher.fullName,
      createdAt,
    },
  ]);
  logoutUser();
};

export const loginUser = (email: string, password: string): UserModel => {
  const users = getUserRecords();
  const emailKey = normalizeEmail(email);
  const index = users.findIndex((user) => normalizeEmail(user.email) === emailKey);

  if (index < 0) {
    throw new Error("Tai khoan khong ton tai. Vui long dang ky.");
  }

  if (users[index].password !== password) {
    throw new Error("Mat khau khong dung. Vui long thu lai.");
  }

  users[index] = {
    ...users[index],
    loginCount: (users[index].loginCount ?? 0) + 1,
    lastLoginAt: nowIso(),
  };

  saveUserRecords(users);
  setCurrentUser(users[index].id);
  return toUser(users[index]);
};

export const registerUser = (input: {
  email: string;
  password: string;
  fullName: string;
  role: UserRole;
  className?: string;
}): UserModel => {
  const users = getUserRecords();
  const emailKey = normalizeEmail(input.email);

  if (users.some((user) => normalizeEmail(user.email) === emailKey)) {
    throw new Error("Email da duoc su dung. Vui long chon email khac.");
  }

  if (input.role === "student") {
    ensureClassForStudent(input.className);
  }

  const user: UserRecord = {
    id: makeId("user"),
    email: input.email.trim(),
    password: input.password,
    fullName: input.fullName.trim(),
    role: input.role,
    className: input.role === "student" ? input.className?.trim() : undefined,
    createdAt: nowIso(),
    loginCount: 1,
    lastLoginAt: nowIso(),
  };

  saveUserRecords([...users, user]);
  setCurrentUser(user.id);
  return toUser(user);
};

export const updateUserClass = (userId: string, className?: string) => {
  const users = getUserRecords().map((user) =>
    user.id === userId ? { ...user, className: className?.trim() || undefined } : user,
  );
  saveUserRecords(users);
};

const withStudentCount = (classRecord: Omit<ClassModel, "studentCount">): ClassModel => {
  const count = getUserRecords().filter(
    (user) =>
      user.role === "student" &&
      user.className &&
      classKey(user.className) === classKey(classRecord.className),
  ).length;

  return { ...classRecord, studentCount: count };
};

export const getAllClasses = (): ClassModel[] =>
  getClassRecords()
    .map(withStudentCount)
    .sort((a, b) => Date.parse(b.createdAt) - Date.parse(a.createdAt));

export const getClassById = (classId: string): ClassModel | null => {
  const record = getClassRecords().find((item) => item.id === classId);
  return record ? withStudentCount(record) : null;
};

export const createClass = (className: string, teacher: UserModel): ClassModel => {
  const trimmed = className.trim();
  if (!trimmed) throw new Error("Vui long nhap ten lop.");

  const classes = getClassRecords();
  if (classes.some((item) => classKey(item.className) === classKey(trimmed))) {
    throw new Error("Lop hoc nay da ton tai.");
  }

  const nextClass = {
    id: makeId("class"),
    className: trimmed,
    teacherId: teacher.id,
    teacherName: teacher.fullName,
    createdAt: nowIso(),
  };

  saveClassRecords([nextClass, ...classes]);
  return withStudentCount(nextClass);
};

export const deleteClass = (classId: string) => {
  const classes = getClassRecords();
  const removed = classes.find((item) => item.id === classId);
  saveClassRecords(classes.filter((item) => item.id !== classId));

  if (removed) {
    const users = getUserRecords().map((user) =>
      user.className && classKey(user.className) === classKey(removed.className)
        ? { ...user, className: undefined }
        : user,
    );
    saveUserRecords(users);
  }
};

export const getStudentsByClass = (className: string): UserModel[] =>
  getUserRecords()
    .filter(
      (user) =>
        user.role === "student" &&
        user.className &&
        classKey(user.className) === classKey(className),
    )
    .map(toUser)
    .sort((a, b) => a.fullName.localeCompare(b.fullName, "vi"));

export const getVideos = (): SavedVideo[] =>
  readJson<SavedVideo[]>(GALLERY_KEY, []).sort(
    (a, b) => Date.parse(b.createdAt) - Date.parse(a.createdAt),
  );

export const saveVideo = (input: Omit<SavedVideo, "id" | "createdAt">): SavedVideo => {
  const video: SavedVideo = {
    id: makeId("video"),
    createdAt: nowIso(),
    ...input,
  };

  writeJson(GALLERY_KEY, [video, ...getVideos()]);
  return video;
};

export const deleteVideo = (videoId: string) => {
  writeJson(
    GALLERY_KEY,
    getVideos().filter((video) => video.id !== videoId),
  );
};

export const clearLocalData = () => {
  localStorage.removeItem(USERS_KEY);
  localStorage.removeItem(CLASSES_KEY);
  localStorage.removeItem(CURRENT_USER_KEY);
  localStorage.removeItem(GALLERY_KEY);
  initializeDemoData();
};
