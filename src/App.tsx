import type {
  ButtonHTMLAttributes,
  FormEvent,
  InputHTMLAttributes,
  ReactNode,
} from "react";
import { useEffect, useMemo, useState } from "react";
import type { LucideIcon } from "lucide-react";
import {
  ArrowLeft,
  BadgeCheck,
  BookOpen,
  Brain,
  Calculator,
  CheckCircle2,
  ChevronRight,
  CircleAlert,
  Copy,
  Eye,
  Film,
  GraduationCap,
  ImagePlus,
  Images,
  LayoutDashboard,
  Library,
  LoaderCircle,
  LogOut,
  MessageSquareText,
  MonitorPlay,
  Palette,
  Play,
  Plus,
  RefreshCw,
  School,
  Search,
  Send,
  Sparkles,
  Trash2,
  Trophy,
  UserRound,
  UsersRound,
  Video,
  WandSparkles,
  X,
} from "lucide-react";
import {
  askMathAssistant,
  buildInfographic,
  buildLesson,
  buildMathPrompt,
  generateVideoClip,
} from "./services/aiClient";
import {
  createClass,
  deleteClass,
  deleteVideo,
  getAllClasses,
  getClassById,
  getCurrentUser,
  getStudentsByClass,
  getUserRecords,
  getVideos,
  initializeDemoData,
  loginUser,
  logoutUser,
  registerUser,
  saveVideo,
  updateUserClass,
} from "./services/localDatabase";
import type {
  ChatMessage,
  ClassModel,
  GeneratedVideo,
  InfographicBlock,
  LearningSupportType,
  SavedVideo,
  UserModel,
  UserRole,
  VideoSourceType,
} from "./types";

type ViewKey =
  | "dashboard"
  | "studio"
  | "gallery"
  | "qa"
  | "quiz"
  | "infographic"
  | "classes"
  | "class-detail";

type ToastTone = "success" | "error" | "info";

type ToastState = {
  message: string;
  tone: ToastTone;
} | null;

const cn = (...classes: Array<string | false | null | undefined>) =>
  classes.filter(Boolean).join(" ");

const roleLabel: Record<UserRole, string> = {
  student: "Hoc sinh",
  teacher: "Giao vien",
};

const sourceLabel: Record<VideoSourceType, string> = {
  text: "Text",
  image: "Anh",
  "text-image": "Text + anh",
  series: "Chuoi video",
};

const supportOptions: Array<{
  type: LearningSupportType;
  label: string;
  icon: LucideIcon;
}> = [
  { type: "simulation", label: "Mo phong", icon: MonitorPlay },
  { type: "lesson", label: "Bai giang", icon: BookOpen },
  { type: "real-world", label: "Ung dung", icon: Sparkles },
  { type: "practice", label: "Luyen tap", icon: Calculator },
];

const quizQuestions = [
  {
    question: "Neu a/b = c/d thi ti le thuc nao luon dung?",
    answers: ["ad = bc", "ab = cd", "a + b = c + d", "a - d = b - c"],
    correct: 0,
  },
  {
    question: "Dien tich tam giac co day a va chieu cao h la gi?",
    answers: ["a x h", "(a x h) / 2", "a + h", "2 x a x h"],
    correct: 1,
  },
  {
    question: "Dinh ly Pythagoras dung cho tam giac nao?",
    answers: ["Tam giac deu", "Tam giac can", "Tam giac vuong", "Moi tam giac"],
    correct: 2,
  },
  {
    question: "Phuong trinh 2x + 6 = 14 co nghiem x bang bao nhieu?",
    answers: ["3", "4", "5", "10"],
    correct: 1,
  },
];

const formatDate = (value?: string) => {
  if (!value) return "Chua co";
  return new Intl.DateTimeFormat("vi-VN", {
    dateStyle: "medium",
    timeStyle: "short",
  }).format(new Date(value));
};

function Button({
  icon: Icon,
  variant = "primary",
  className,
  children,
  ...props
}: ButtonHTMLAttributes<HTMLButtonElement> & {
  icon?: LucideIcon;
  variant?: "primary" | "ghost" | "danger";
}) {
  return (
    <button
      className={cn(
        variant === "primary" && "mesh-button",
        variant === "ghost" && "ghost-button",
        variant === "danger" && "danger-button",
        className,
      )}
      {...props}
    >
      {Icon ? <Icon className="h-4 w-4 shrink-0" /> : null}
      <span className="truncate">{children}</span>
    </button>
  );
}

function IconButton({
  icon: Icon,
  label,
  className,
  ...props
}: ButtonHTMLAttributes<HTMLButtonElement> & {
  icon: LucideIcon;
  label: string;
}) {
  return (
    <button className={cn("icon-button", className)} title={label} aria-label={label} {...props}>
      <Icon className="h-5 w-5" />
    </button>
  );
}

function Field({
  label,
  className,
  ...props
}: InputHTMLAttributes<HTMLInputElement> & { label: string }) {
  return (
    <label className={cn("grid gap-2 text-sm font-semibold text-slate-200", className)}>
      {label}
      <input className="input-field" {...props} />
    </label>
  );
}

function TextArea({
  label,
  value,
  onChange,
  placeholder,
  rows = 5,
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
  rows?: number;
}) {
  return (
    <label className="grid gap-2 text-sm font-semibold text-slate-200">
      {label}
      <textarea
        className="input-field min-h-32 resize-y"
        value={value}
        onChange={(event) => onChange(event.target.value)}
        placeholder={placeholder}
        rows={rows}
      />
    </label>
  );
}

function StatTile({
  icon: Icon,
  label,
  value,
  tone = "teal",
}: {
  icon: LucideIcon;
  label: string;
  value: ReactNode;
  tone?: "teal" | "rose" | "amber" | "blue";
}) {
  const toneClass = {
    teal: "bg-teal-300/15 text-teal-100",
    rose: "bg-rose-300/15 text-rose-100",
    amber: "bg-amber-300/15 text-amber-100",
    blue: "bg-sky-300/15 text-sky-100",
  }[tone];

  return (
    <div className="glass-card min-w-0 p-4">
      <div className={cn("mb-4 inline-flex rounded-lg p-2", toneClass)}>
        <Icon className="h-5 w-5" />
      </div>
      <div className="text-flow-safe text-2xl font-black tracking-normal text-white">{value}</div>
      <div className="mt-1 text-sm font-medium text-slate-300">{label}</div>
    </div>
  );
}

function EmptyState({
  icon: Icon,
  title,
  action,
}: {
  icon: LucideIcon;
  title: string;
  action?: ReactNode;
}) {
  return (
    <div className="glass-panel grid min-h-64 place-items-center p-8 text-center">
      <div>
        <div className="mx-auto mb-4 grid h-14 w-14 place-items-center rounded-lg bg-white/10 text-teal-100">
          <Icon className="h-7 w-7" />
        </div>
        <p className="text-base font-bold text-white">{title}</p>
        {action ? <div className="mt-5">{action}</div> : null}
      </div>
    </div>
  );
}

function Toast({ toast, onClose }: { toast: ToastState; onClose: () => void }) {
  if (!toast) return null;
  const Icon = toast.tone === "error" ? CircleAlert : toast.tone === "info" ? Sparkles : CheckCircle2;

  return (
    <div className="fixed right-4 top-4 z-50 max-w-sm">
      <div
        className={cn(
          "glass-card flex items-start gap-3 p-4",
          toast.tone === "error" && "border-rose-300/30",
          toast.tone === "success" && "border-teal-200/30",
        )}
      >
        <Icon className="mt-0.5 h-5 w-5 shrink-0 text-teal-100" />
        <p className="min-w-0 flex-1 text-sm font-semibold leading-6 text-white">{toast.message}</p>
        <IconButton icon={X} label="Dong thong bao" onClick={onClose} className="h-8 w-8" />
      </div>
    </div>
  );
}

export default function App() {
  const [currentUser, setCurrentUser] = useState<UserModel | null>(null);
  const [view, setView] = useState<ViewKey>("dashboard");
  const [selectedClassId, setSelectedClassId] = useState<string | null>(null);
  const [toast, setToast] = useState<ToastState>(null);
  const [refreshKey, setRefreshKey] = useState(0);

  useEffect(() => {
    initializeDemoData();
    setCurrentUser(getCurrentUser());
  }, []);

  const notify = (message: string, tone: ToastTone = "success") => {
    setToast({ message, tone });
    window.setTimeout(() => setToast(null), 3200);
  };

  const refresh = () => setRefreshKey((key) => key + 1);

  const handleLogout = () => {
    logoutUser();
    setCurrentUser(null);
    setView("dashboard");
    setSelectedClassId(null);
    notify("Da dang xuat.", "info");
  };

  if (!currentUser) {
    return (
      <div className="mesh-grain min-h-screen bg-mesh text-white">
        <Toast toast={toast} onClose={() => setToast(null)} />
        <AuthScreen
          onAuthenticated={(user) => {
            setCurrentUser(user);
            setView("dashboard");
            notify(`Xin chao ${user.fullName}!`);
          }}
          onToast={notify}
        />
      </div>
    );
  }

  return (
    <div className="mesh-grain min-h-screen bg-mesh text-white">
      <Toast toast={toast} onClose={() => setToast(null)} />
      <Shell
        user={currentUser}
        activeView={view}
        onNavigate={(nextView) => {
          setView(nextView);
          if (nextView !== "class-detail") setSelectedClassId(null);
        }}
        onLogout={handleLogout}
      >
        {view === "dashboard" ? (
          <Dashboard user={currentUser} onNavigate={setView} refreshKey={refreshKey} />
        ) : null}

        {view === "studio" ? (
          <VideoStudio
            user={currentUser}
            onSaved={() => {
              refresh();
              notify("Da luu video vao phong trien lam.");
            }}
            onToast={notify}
          />
        ) : null}

        {view === "gallery" ? <GalleryScreen onToast={notify} /> : null}

        {view === "qa" ? <QAScreen onToast={notify} /> : null}

        {view === "quiz" ? <QuizScreen /> : null}

        {view === "infographic" ? <InfographicScreen /> : null}

        {view === "classes" ? (
          <ClassroomsScreen
            user={currentUser}
            onOpenClass={(classId) => {
              setSelectedClassId(classId);
              setView("class-detail");
            }}
            onToast={(message, tone) => {
              refresh();
              notify(message, tone);
            }}
          />
        ) : null}

        {view === "class-detail" ? (
          <ClassDetailScreen
            classId={selectedClassId}
            onBack={() => setView("classes")}
            onToast={(message, tone) => {
              refresh();
              notify(message, tone);
            }}
          />
        ) : null}
      </Shell>
    </div>
  );
}

function AuthScreen({
  onAuthenticated,
  onToast,
}: {
  onAuthenticated: (user: UserModel) => void;
  onToast: (message: string, tone?: ToastTone) => void;
}) {
  const [isRegistering, setIsRegistering] = useState(false);
  const [role, setRole] = useState<UserRole>("student");
  const [email, setEmail] = useState("student@MathVision.com");
  const [password, setPassword] = useState("student123");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [fullName, setFullName] = useState("");
  const [className, setClassName] = useState("6A1");

  const handleSubmit = (event: FormEvent) => {
    event.preventDefault();

    try {
      if (isRegistering) {
        if (password.length < 6) throw new Error("Mat khau can it nhat 6 ky tu.");
        if (password !== confirmPassword) throw new Error("Mat khau xac nhan khong khop.");
        if (!fullName.trim()) throw new Error("Vui long nhap ho ten.");

        onAuthenticated(
          registerUser({
            email,
            password,
            fullName,
            role,
            className: role === "student" ? className : undefined,
          }),
        );
      } else {
        onAuthenticated(loginUser(email, password));
      }
    } catch (error) {
      onToast(error instanceof Error ? error.message : "Khong the xu ly tai khoan.", "error");
    }
  };

  const loginDemo = (nextRole: UserRole) => {
    const demoEmail = nextRole === "teacher" ? "teacher@MathVision.com" : "student@MathVision.com";
    const demoPassword = nextRole === "teacher" ? "teacher123" : "student123";
    try {
      onAuthenticated(loginUser(demoEmail, demoPassword));
    } catch (error) {
      onToast(error instanceof Error ? error.message : "Khong the dang nhap demo.", "error");
    }
  };

  return (
    <main className="relative z-10 mx-auto grid min-h-screen w-full max-w-6xl items-center gap-8 px-4 py-8 lg:grid-cols-[1.05fr_0.95fr]">
      <section className="min-w-0 space-y-6">
        <div className="inline-flex items-center gap-3 rounded-lg border border-teal-200/25 bg-white/10 px-4 py-2 font-bold text-teal-50 backdrop-blur-xl">
          <Sparkles className="h-5 w-5" />
          TOAN HOC 4.0
        </div>
        <div className="max-w-2xl">
          <h1 className="text-flow-safe text-3xl font-black leading-tight tracking-normal text-white sm:text-6xl">
            Video Toan hoc AI cho lop hoc hien dai
          </h1>
          <p className="text-flow-safe mt-5 max-w-xl text-base leading-7 text-slate-300">
            Ban React web cua du an VIDEOTOANHOC, chay local database trong trinh duyet va san sang ket noi AI qua proxy.
          </p>
        </div>
        <div className="grid gap-3 sm:grid-cols-3">
          <StatTile icon={Video} label="AI video studio" value="1/5 clip" tone="teal" />
          <StatTile icon={School} label="Quan ly lop" value="Local" tone="amber" />
          <StatTile icon={Brain} label="Hoi dap" value="Gemini" tone="rose" />
        </div>
      </section>

      <section className="glass-card min-w-0 p-5 sm:p-6">
        <div className="mb-6 flex flex-col items-start justify-between gap-3 sm:flex-row sm:items-center">
          <div>
            <h2 className="section-title">{isRegistering ? "Dang ky" : "Dang nhap"}</h2>
            <p className="subtle-text">Tai khoan demo da duoc khoi tao san.</p>
          </div>
          <div className="rounded-lg border border-white/10 bg-white/10 p-1">
            <button
              className={cn(
                "rounded-md px-3 py-2 text-sm font-bold",
                !isRegistering ? "bg-white text-slate-950" : "text-slate-300",
              )}
              onClick={() => setIsRegistering(false)}
            >
              Dang nhap
            </button>
            <button
              className={cn(
                "rounded-md px-3 py-2 text-sm font-bold",
                isRegistering ? "bg-white text-slate-950" : "text-slate-300",
              )}
              onClick={() => setIsRegistering(true)}
            >
              Dang ky
            </button>
          </div>
        </div>

        <form className="space-y-4" onSubmit={handleSubmit}>
          {isRegistering ? (
            <Field label="Ho ten" value={fullName} onChange={(event) => setFullName(event.target.value)} />
          ) : null}

          <Field
            label="Email"
            type="email"
            value={email}
            onChange={(event) => setEmail(event.target.value)}
            required
          />

          <Field
            label="Mat khau"
            type="password"
            value={password}
            onChange={(event) => setPassword(event.target.value)}
            required
          />

          {isRegistering ? (
            <>
              <Field
                label="Xac nhan mat khau"
                type="password"
                value={confirmPassword}
                onChange={(event) => setConfirmPassword(event.target.value)}
                required
              />
              <div className="grid gap-3 sm:grid-cols-2">
                {(["student", "teacher"] as UserRole[]).map((item) => {
                  const Icon = item === "student" ? GraduationCap : School;
                  return (
                    <button
                      key={item}
                      type="button"
                      onClick={() => setRole(item)}
                      className={cn(
                        "rounded-lg border p-4 text-left transition",
                        role === item
                          ? "border-teal-200/50 bg-teal-300/15"
                          : "border-white/10 bg-white/10 hover:bg-white/15",
                      )}
                    >
                      <Icon className="mb-3 h-5 w-5 text-teal-100" />
                      <span className="font-bold text-white">{roleLabel[item]}</span>
                    </button>
                  );
                })}
              </div>
              {role === "student" ? (
                <Field
                  label="Lop hoc"
                  value={className}
                  onChange={(event) => setClassName(event.target.value)}
                />
              ) : null}
            </>
          ) : null}

          <Button className="w-full" icon={isRegistering ? Plus : Play} type="submit">
            {isRegistering ? "Tao tai khoan" : "Vao ung dung"}
          </Button>
        </form>

        <div className="mt-5 grid gap-3 sm:grid-cols-2">
          <Button variant="ghost" icon={GraduationCap} onClick={() => loginDemo("student")}>
            Demo hoc sinh
          </Button>
          <Button variant="ghost" icon={School} onClick={() => loginDemo("teacher")}>
            Demo giao vien
          </Button>
        </div>
      </section>
    </main>
  );
}

function Shell({
  user,
  activeView,
  onNavigate,
  onLogout,
  children,
}: {
  user: UserModel;
  activeView: ViewKey;
  onNavigate: (view: ViewKey) => void;
  onLogout: () => void;
  children: ReactNode;
}) {
  const navItems: Array<{ view: ViewKey; label: string; icon: LucideIcon }> = [
    { view: "dashboard", label: "Tong quan", icon: LayoutDashboard },
    { view: "studio", label: "Tao video", icon: WandSparkles },
    { view: "gallery", label: "Thu vien", icon: Images },
    { view: "qa", label: "Hoi dap", icon: MessageSquareText },
    { view: "quiz", label: "Quiz", icon: Trophy },
    { view: "infographic", label: "Infographic", icon: Palette },
  ];

  if (user.role === "teacher") {
    navItems.splice(1, 0, { view: "classes", label: "Lop hoc", icon: School });
  }

  return (
    <div className="relative z-10">
      <header className="sticky top-0 z-30 border-b border-white/10 bg-slate-950/55 backdrop-blur-2xl">
        <div className="mx-auto flex max-w-7xl flex-col gap-4 px-4 py-4 lg:flex-row lg:items-center lg:justify-between">
          <div className="flex items-center justify-between gap-4">
            <button
              className="flex items-center gap-3 text-left"
              onClick={() => onNavigate("dashboard")}
            >
              <div className="grid h-11 w-11 place-items-center rounded-lg bg-teal-300 text-slate-950 shadow-glow">
                <Calculator className="h-6 w-6" />
              </div>
              <div>
                <div className="text-lg font-black tracking-normal text-white">TOAN HOC 4.0</div>
                <div className="text-xs font-semibold text-slate-400">{roleLabel[user.role]}</div>
              </div>
            </button>
            <IconButton icon={LogOut} label="Dang xuat" onClick={onLogout} className="lg:hidden" />
          </div>

          <nav className="flex flex-wrap items-center gap-2">
            {navItems.map((item) => {
              const Icon = item.icon;
              const active = activeView === item.view || (activeView === "class-detail" && item.view === "classes");
              return (
                <button
                  key={item.view}
                  className={cn("nav-button", active && "nav-button-active")}
                  onClick={() => onNavigate(item.view)}
                >
                  <Icon className="h-4 w-4 shrink-0" />
                  <span>{item.label}</span>
                </button>
              );
            })}
          </nav>

          <div className="hidden items-center gap-3 lg:flex">
            <div className="text-right">
              <div className="text-sm font-bold text-white">{user.fullName}</div>
              <div className="text-xs text-slate-400">{user.email}</div>
            </div>
            <IconButton icon={LogOut} label="Dang xuat" onClick={onLogout} />
          </div>
        </div>
      </header>

      <main className="mx-auto max-w-7xl px-4 py-6 sm:py-8">{children}</main>
    </div>
  );
}

function Dashboard({
  user,
  onNavigate,
  refreshKey,
}: {
  user: UserModel;
  onNavigate: (view: ViewKey) => void;
  refreshKey: number;
}) {
  const stats = useMemo(() => {
    const classes = getAllClasses();
    const totalStudents = getUserRecords().filter((item) => item.role === "student").length;
    const videos = getVideos();
    return { classes, totalStudents, videos };
  }, [refreshKey]);

  if (user.role === "teacher") {
    return (
      <div className="space-y-6">
        <PageHeader
          eyebrow="Giao vien"
          title={`Xin chao, ${user.fullName}`}
          actions={<Button icon={Plus} onClick={() => onNavigate("classes")}>Tao lop</Button>}
        />

        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          <StatTile icon={School} label="Lop hoc" value={stats.classes.length} tone="teal" />
          <StatTile icon={UsersRound} label="Hoc sinh" value={stats.totalStudents} tone="blue" />
          <StatTile icon={Video} label="Video da luu" value={stats.videos.length} tone="rose" />
          <StatTile icon={BadgeCheck} label="Lan truy cap" value={user.loginCount} tone="amber" />
        </div>

        <ActionGrid
          actions={[
            { icon: School, title: "Quan ly lop hoc", view: "classes" },
            { icon: WandSparkles, title: "Tao video bai giang", view: "studio" },
            { icon: Images, title: "Phong trien lam", view: "gallery" },
            { icon: MessageSquareText, title: "Tro ly Toan hoc", view: "qa" },
          ]}
          onNavigate={onNavigate}
        />
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <PageHeader
        eyebrow={user.className ? `Lop ${user.className}` : "Hoc sinh"}
        title={`Xin chao, ${user.fullName}`}
        actions={<Button icon={WandSparkles} onClick={() => onNavigate("studio")}>Tao video</Button>}
      />

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <StatTile icon={BadgeCheck} label="Lan truy cap" value={user.loginCount} tone="teal" />
        <StatTile icon={School} label="Lop hoc" value={user.className ?? "Chua co"} tone="amber" />
        <StatTile icon={Library} label="Video thu vien" value={stats.videos.length} tone="blue" />
        <StatTile icon={Brain} label="Che do hoc" value="AI" tone="rose" />
      </div>

      <ActionGrid
        actions={[
          { icon: WandSparkles, title: "Tao video tu text", view: "studio" },
          { icon: Images, title: "Phong trien lam", view: "gallery" },
          { icon: MessageSquareText, title: "Hoi dap Toan hoc", view: "qa" },
          { icon: Trophy, title: "Quiz nhanh", view: "quiz" },
          { icon: Palette, title: "Infographic", view: "infographic" },
        ]}
        onNavigate={onNavigate}
      />
    </div>
  );
}

function PageHeader({
  eyebrow,
  title,
  actions,
}: {
  eyebrow: string;
  title: string;
  actions?: ReactNode;
}) {
  return (
    <div className="flex flex-col justify-between gap-4 sm:flex-row sm:items-end">
      <div>
        <div className="mb-2 inline-flex rounded-full border border-white/15 bg-white/10 px-3 py-1 text-xs font-bold uppercase tracking-wide text-teal-100">
          {eyebrow}
        </div>
        <h1 className="text-flow-safe text-3xl font-black tracking-normal text-white sm:text-4xl">{title}</h1>
      </div>
      {actions ? <div className="flex flex-wrap gap-2">{actions}</div> : null}
    </div>
  );
}

function ActionGrid({
  actions,
  onNavigate,
}: {
  actions: Array<{ icon: LucideIcon; title: string; view: ViewKey }>;
  onNavigate: (view: ViewKey) => void;
}) {
  return (
    <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
      {actions.map((action) => {
        const Icon = action.icon;
        return (
          <button
            key={action.title}
            className="glass-card group flex min-h-36 min-w-0 flex-col justify-between p-5 text-left transition hover:-translate-y-1 hover:border-teal-200/35"
            onClick={() => onNavigate(action.view)}
          >
              <div className="grid h-11 w-11 place-items-center rounded-lg bg-white/15 text-teal-100">
              <Icon className="h-6 w-6" />
            </div>
            <div className="flex items-end justify-between gap-4">
              <h3 className="text-flow-safe text-lg font-black tracking-normal text-white">{action.title}</h3>
              <ChevronRight className="h-5 w-5 shrink-0 text-slate-400 transition group-hover:translate-x-1 group-hover:text-teal-100" />
            </div>
          </button>
        );
      })}
    </div>
  );
}

function VideoStudio({
  user,
  onSaved,
  onToast,
}: {
  user: UserModel;
  onSaved: () => void;
  onToast: (message: string, tone?: ToastTone) => void;
}) {
  const [topic, setTopic] = useState("");
  const [supportType, setSupportType] = useState<LearningSupportType>("simulation");
  const [seriesCount, setSeriesCount] = useState<1 | 5>(1);
  const [imageFile, setImageFile] = useState<File | null>(null);
  const [isGenerating, setIsGenerating] = useState(false);
  const [currentStep, setCurrentStep] = useState("");
  const [promptPreview, setPromptPreview] = useState("");
  const [generatedVideos, setGeneratedVideos] = useState<GeneratedVideo[]>([]);

  const lesson = useMemo(() => buildLesson(topic), [topic]);

  const handleGenerate = async () => {
    if (!topic.trim()) {
      onToast("Vui long nhap mo ta bai hoc.", "error");
      return;
    }

    setIsGenerating(true);
    setGeneratedVideos([]);

    try {
      const total = seriesCount;
      const results: GeneratedVideo[] = [];

      for (let index = 1; index <= total; index += 1) {
        const prompt = buildMathPrompt({
          topic,
          supportType,
          index,
          total,
          imageName: imageFile?.name,
        });

        if (index === 1) setPromptPreview(prompt);
        setCurrentStep(total === 1 ? "Dang tao video..." : `Dang tao video ${index}/${total}...`);

        const video = await generateVideoClip({
          title: total === 1 ? topic : `${topic} - canh ${index}`,
          prompt,
        });

        results.push(video);
        saveVideo({
          videoUrl: video.url,
          title: video.title,
          prompt,
          createdBy: user.id,
          sourceType: total === 5 ? "series" : imageFile ? "text-image" : "text",
        });
      }

      setGeneratedVideos(results);
      setCurrentStep("Hoan thanh");
      onSaved();
    } catch (error) {
      onToast(error instanceof Error ? error.message : "Khong the tao video.", "error");
    } finally {
      setIsGenerating(false);
    }
  };

  const speakLesson = () => {
    if (!("speechSynthesis" in window)) {
      onToast("Trinh duyet khong ho tro doc noi dung.", "error");
      return;
    }

    window.speechSynthesis.cancel();
    const utterance = new SpeechSynthesisUtterance(
      [lesson.title, ...lesson.points].join(". "),
    );
    utterance.lang = "vi-VN";
    window.speechSynthesis.speak(utterance);
  };

  return (
    <div className="space-y-6">
      <PageHeader
        eyebrow="AI video studio"
        title="Tao video ngan Toan hoc"
        actions={
          <Button icon={isGenerating ? LoaderCircle : WandSparkles} onClick={handleGenerate} disabled={isGenerating}>
            {isGenerating ? "Dang tao" : seriesCount === 5 ? "Tao 5 video" : "Tao 1 video"}
          </Button>
        }
      />

      <div className="grid gap-5 lg:grid-cols-[minmax(0,1fr)_390px]">
        <section className="glass-card space-y-5 p-5">
          <TextArea
            label="Mo ta bai hoc"
            value={topic}
            onChange={setTopic}
            placeholder="Vi du: Giai thich dinh ly Pythagoras bang hinh anh truc quan"
          />

          <div>
            <div className="mb-2 text-sm font-semibold text-slate-200">Kieu ho tro</div>
            <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
              {supportOptions.map((option) => {
                const Icon = option.icon;
                const active = supportType === option.type;
                return (
                  <button
                    key={option.type}
                    className={cn(
                      "rounded-lg border p-4 text-left transition",
                      active ? "border-teal-200/45 bg-teal-300/15" : "border-white/10 bg-white/10 hover:bg-white/15",
                    )}
                    onClick={() => setSupportType(option.type)}
                  >
                    <Icon className="mb-3 h-5 w-5 text-teal-100" />
                    <span className="font-bold text-white">{option.label}</span>
                  </button>
                );
              })}
            </div>
          </div>

          <div className="grid gap-4 md:grid-cols-2">
            <label className="grid gap-2 text-sm font-semibold text-slate-200">
              So luong video
              <select
                className="input-field"
                value={seriesCount}
                onChange={(event) => setSeriesCount(Number(event.target.value) === 5 ? 5 : 1)}
              >
                <option value={1}>1 video</option>
                <option value={5}>5 video dong nhat</option>
              </select>
            </label>

            <label className="grid gap-2 text-sm font-semibold text-slate-200">
              Anh tham chieu
              <span className="flex items-center gap-3 rounded-lg border border-dashed border-white/20 bg-slate-950/25 px-4 py-3">
                <ImagePlus className="h-5 w-5 text-teal-100" />
                <span className="min-w-0 flex-1 truncate text-sm text-slate-300">
                  {imageFile ? imageFile.name : "Chon file anh"}
                </span>
                <input
                  type="file"
                  accept="image/*"
                  className="sr-only"
                  onChange={(event) => setImageFile(event.target.files?.[0] ?? null)}
                />
              </span>
            </label>
          </div>

          {isGenerating ? (
            <div className="glass-panel flex items-center gap-3 p-4">
              <LoaderCircle className="h-5 w-5 animate-spin text-teal-100" />
              <span className="font-semibold text-white">{currentStep}</span>
            </div>
          ) : null}
        </section>

        <aside className="glass-card space-y-5 p-5">
          <div>
            <h2 className="section-title">Bai hoc nhanh</h2>
            <p className="mt-2 text-sm font-semibold text-teal-100">{lesson.title}</p>
          </div>
          <div className="space-y-3">
            {lesson.points.map((point, index) => (
              <div key={point} className="flex gap-3 text-sm leading-6 text-slate-200">
                <span className="mt-0.5 grid h-6 w-6 shrink-0 place-items-center rounded-full bg-white/10 text-xs font-black text-teal-100">
                  {index + 1}
                </span>
                <span>{point}</span>
              </div>
            ))}
          </div>
          <Button variant="ghost" icon={Play} onClick={speakLesson} className="w-full">
            Doc bai hoc
          </Button>
        </aside>
      </div>

      {promptPreview ? (
        <section className="glass-panel p-5">
          <div className="mb-3 flex items-center justify-between gap-3">
            <h2 className="section-title">Prompt AI</h2>
            <IconButton
              icon={Copy}
              label="Copy prompt"
              onClick={() => {
                void navigator.clipboard?.writeText(promptPreview);
                onToast("Da copy prompt.", "info");
              }}
            />
          </div>
          <p className="whitespace-pre-wrap text-sm leading-7 text-slate-200">{promptPreview}</p>
        </section>
      ) : null}

      {generatedVideos.length > 0 ? (
        <section className="space-y-4">
          <h2 className="section-title">Video vua tao</h2>
          <div className="grid gap-4 lg:grid-cols-2">
            {generatedVideos.map((video) => (
              <article key={video.id} className="glass-card overflow-hidden">
                <video src={video.url} controls className="aspect-video w-full bg-slate-950 object-cover" />
                <div className="p-4">
                  <h3 className="font-bold text-white">{video.title}</h3>
                  <p className="mt-2 line-clamp-2 text-sm leading-6 text-slate-300">{video.prompt}</p>
                </div>
              </article>
            ))}
          </div>
        </section>
      ) : null}
    </div>
  );
}

function GalleryScreen({ onToast }: { onToast: (message: string, tone?: ToastTone) => void }) {
  const [videos, setVideos] = useState<SavedVideo[]>(() => getVideos());
  const [query, setQuery] = useState("");
  const [selectedVideo, setSelectedVideo] = useState<SavedVideo | null>(null);

  const filtered = videos.filter((video) =>
    `${video.title} ${video.prompt ?? ""}`.toLowerCase().includes(query.toLowerCase()),
  );

  const reload = () => setVideos(getVideos());

  return (
    <div className="space-y-6">
      <PageHeader
        eyebrow="Phong trien lam"
        title="Thu vien video"
        actions={
          <Button variant="ghost" icon={RefreshCw} onClick={reload}>
            Lam moi
          </Button>
        }
      />

      <label className="glass-panel flex items-center gap-3 px-4 py-3">
        <Search className="h-5 w-5 text-slate-400" />
        <input
          className="w-full bg-transparent text-sm font-semibold text-white outline-none placeholder:text-slate-500"
          placeholder="Tim video"
          value={query}
          onChange={(event) => setQuery(event.target.value)}
        />
      </label>

      {filtered.length === 0 ? (
        <EmptyState icon={Images} title="Chua co video trong thu vien" />
      ) : (
        <div className="grid gap-4 lg:grid-cols-[minmax(0,1fr)_420px]">
          <div className="grid gap-4 sm:grid-cols-2">
            {filtered.map((video) => (
              <article key={video.id} className="glass-card overflow-hidden">
                <button className="block w-full" onClick={() => setSelectedVideo(video)}>
                  <video src={video.videoUrl} className="aspect-video w-full bg-slate-950 object-cover" muted />
                </button>
                <div className="space-y-3 p-4">
                  <div className="flex items-start justify-between gap-3">
                    <div className="min-w-0">
                      <h3 className="truncate font-bold text-white">{video.title}</h3>
                      <p className="mt-1 text-xs font-semibold text-slate-400">{formatDate(video.createdAt)}</p>
                    </div>
                    <span className="badge shrink-0">{sourceLabel[video.sourceType]}</span>
                  </div>
                  <div className="flex gap-2">
                    <Button variant="ghost" icon={Eye} onClick={() => setSelectedVideo(video)} className="flex-1">
                      Xem
                    </Button>
                    <IconButton
                      icon={Trash2}
                      label="Xoa video"
                      onClick={() => {
                        deleteVideo(video.id);
                        reload();
                        if (selectedVideo?.id === video.id) setSelectedVideo(null);
                        onToast("Da xoa video.", "info");
                      }}
                    />
                  </div>
                </div>
              </article>
            ))}
          </div>

          <aside className="glass-card h-fit p-4">
            {selectedVideo ? (
              <div className="space-y-4">
                <video src={selectedVideo.videoUrl} controls className="aspect-video w-full rounded-lg bg-slate-950 object-cover" />
                <div>
                  <h2 className="text-lg font-black text-white">{selectedVideo.title}</h2>
                  <p className="mt-2 text-sm leading-6 text-slate-300">{selectedVideo.prompt}</p>
                </div>
              </div>
            ) : (
              <EmptyState icon={Film} title="Chon mot video de xem" />
            )}
          </aside>
        </div>
      )}
    </div>
  );
}

function QAScreen({ onToast }: { onToast: (message: string, tone?: ToastTone) => void }) {
  const [language, setLanguage] = useState<"vi" | "en">("vi");
  const [question, setQuestion] = useState("");
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [loading, setLoading] = useState(false);

  const submit = async (event: FormEvent) => {
    event.preventDefault();
    if (!question.trim()) return;

    const userMessage: ChatMessage = {
      id: crypto.randomUUID(),
      role: "user",
      content: question.trim(),
      createdAt: new Date().toISOString(),
    };

    setMessages((items) => [...items, userMessage]);
    setQuestion("");
    setLoading(true);

    try {
      const answer = await askMathAssistant(userMessage.content, language);
      setMessages((items) => [
        ...items,
        {
          id: crypto.randomUUID(),
          role: "assistant",
          content: answer,
          createdAt: new Date().toISOString(),
        },
      ]);
    } catch (error) {
      onToast(error instanceof Error ? error.message : "Khong the hoi dap.", "error");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="space-y-6">
      <PageHeader
        eyebrow="AI Q&A"
        title="Hoi dap Toan hoc"
        actions={
          <div className="flex rounded-lg border border-white/15 bg-white/10 p-1">
            <button
              className={cn("rounded-md px-3 py-2 text-sm font-bold", language === "vi" ? "bg-white text-slate-950" : "text-slate-300")}
              onClick={() => setLanguage("vi")}
            >
              VI
            </button>
            <button
              className={cn("rounded-md px-3 py-2 text-sm font-bold", language === "en" ? "bg-white text-slate-950" : "text-slate-300")}
              onClick={() => setLanguage("en")}
            >
              EN
            </button>
          </div>
        }
      />

      <section className="glass-card flex min-h-[620px] flex-col p-4">
        <div className="flex-1 space-y-3 overflow-y-auto pr-1">
          {messages.length === 0 ? (
            <EmptyState icon={MessageSquareText} title="Dat cau hoi Toan hoc de bat dau" />
          ) : (
            messages.map((message) => (
              <div
                key={message.id}
                className={cn(
                  "max-w-[86%] rounded-lg border px-4 py-3 text-sm leading-7",
                  message.role === "user"
                    ? "ml-auto border-teal-200/25 bg-teal-300/15 text-white"
                    : "border-white/10 bg-white/10 text-slate-200",
                )}
              >
                {message.content}
              </div>
            ))
          )}
          {loading ? (
            <div className="inline-flex items-center gap-2 rounded-lg border border-white/10 bg-white/10 px-4 py-3 text-sm font-semibold text-slate-200">
              <LoaderCircle className="h-4 w-4 animate-spin" />
              Dang suy nghi
            </div>
          ) : null}
        </div>

        <form className="mt-4 flex flex-col gap-3 sm:flex-row" onSubmit={submit}>
          <input
            className="input-field"
            value={question}
            onChange={(event) => setQuestion(event.target.value)}
            placeholder="Nhap cau hoi"
          />
          <Button icon={Send} type="submit" disabled={loading}>
            Gui
          </Button>
        </form>
      </section>
    </div>
  );
}

function QuizScreen() {
  const [questionIndex, setQuestionIndex] = useState(0);
  const [selected, setSelected] = useState<number | null>(null);
  const [score, setScore] = useState(0);

  const question = quizQuestions[questionIndex];
  const done = questionIndex === quizQuestions.length - 1 && selected !== null;
  const isCorrect = selected === question.correct;

  const next = () => {
    if (selected === question.correct) setScore((value) => value + 1);
    if (questionIndex < quizQuestions.length - 1) {
      setQuestionIndex((value) => value + 1);
      setSelected(null);
    }
  };

  const reset = () => {
    setQuestionIndex(0);
    setSelected(null);
    setScore(0);
  };

  return (
    <div className="space-y-6">
      <PageHeader eyebrow="Quiz" title="Luyen tap nhanh" />

      <section className="glass-card mx-auto max-w-3xl p-5">
        <div className="mb-6 flex items-center justify-between gap-4">
          <span className="badge">Cau {questionIndex + 1}/{quizQuestions.length}</span>
          <span className="badge">Diem {score}</span>
        </div>

        <h2 className="text-2xl font-black leading-tight text-white">{question.question}</h2>

        <div className="mt-6 grid gap-3">
          {question.answers.map((answer, index) => {
            const active = selected === index;
            const showCorrect = selected !== null && index === question.correct;
            const showWrong = active && selected !== question.correct;
            return (
              <button
                key={answer}
                className={cn(
                  "rounded-lg border p-4 text-left text-sm font-bold transition",
                  active && "border-teal-200/45 bg-teal-300/15",
                  showCorrect && "border-teal-200/45 bg-teal-300/20",
                  showWrong && "border-rose-200/45 bg-rose-300/15",
                  !active && !showCorrect && !showWrong && "border-white/10 bg-white/10 hover:bg-white/15",
                )}
                onClick={() => setSelected(index)}
                disabled={selected !== null}
              >
                {answer}
              </button>
            );
          })}
        </div>

        {selected !== null ? (
          <div className="mt-5 glass-panel p-4">
            <p className="font-bold text-white">{isCorrect ? "Dung!" : "Chua dung."}</p>
            <div className="mt-4 flex gap-3">
              {done ? (
                <Button icon={RefreshCw} onClick={reset}>Lam lai</Button>
              ) : (
                <Button icon={ChevronRight} onClick={next}>Cau tiep</Button>
              )}
            </div>
          </div>
        ) : null}
      </section>
    </div>
  );
}

function InfographicScreen() {
  const [topic, setTopic] = useState("Dinh ly Pythagoras");
  const [blocks, setBlocks] = useState<InfographicBlock[]>(() => buildInfographic("Dinh ly Pythagoras"));

  const toneClasses: Record<InfographicBlock["tone"], string> = {
    teal: "border-teal-200/30 bg-teal-300/15",
    rose: "border-rose-200/30 bg-rose-300/15",
    amber: "border-amber-200/30 bg-amber-300/15",
    blue: "border-sky-200/30 bg-sky-300/15",
  };

  return (
    <div className="space-y-6">
      <PageHeader eyebrow="Infographic" title="Bang tom tat Toan hoc" />

      <section className="glass-card space-y-4 p-5">
        <div className="grid gap-3 sm:grid-cols-[minmax(0,1fr)_auto]">
          <input
            className="input-field"
            value={topic}
            onChange={(event) => setTopic(event.target.value)}
            placeholder="Nhap chu de"
          />
          <Button icon={Palette} onClick={() => setBlocks(buildInfographic(topic))}>
            Tao bang
          </Button>
        </div>
      </section>

      <section className="grid gap-4 md:grid-cols-2">
        {blocks.map((block) => (
          <article key={block.title} className={cn("rounded-lg border p-6 backdrop-blur-xl", toneClasses[block.tone])}>
            <p className="text-sm font-black uppercase tracking-wide text-slate-300">{block.title}</p>
            <p className="mt-4 text-2xl font-black leading-tight text-white">{block.value}</p>
          </article>
        ))}
      </section>
    </div>
  );
}

function ClassroomsScreen({
  user,
  onOpenClass,
  onToast,
}: {
  user: UserModel;
  onOpenClass: (classId: string) => void;
  onToast: (message: string, tone?: ToastTone) => void;
}) {
  const [className, setClassName] = useState("");
  const [reloadKey, setReloadKey] = useState(0);
  const classes = useMemo(() => getAllClasses(), [reloadKey]);

  const addClass = (event: FormEvent) => {
    event.preventDefault();
    try {
      createClass(className, user);
      setClassName("");
      setReloadKey((key) => key + 1);
      onToast("Da tao lop hoc.");
    } catch (error) {
      onToast(error instanceof Error ? error.message : "Khong the tao lop.", "error");
    }
  };

  return (
    <div className="space-y-6">
      <PageHeader eyebrow="Quan ly" title="Lop hoc" />

      <form className="glass-card grid gap-3 p-4 sm:grid-cols-[minmax(0,1fr)_auto]" onSubmit={addClass}>
        <input
          className="input-field"
          value={className}
          onChange={(event) => setClassName(event.target.value)}
          placeholder="VD: 6A1, 7B2"
        />
        <Button icon={Plus} type="submit">Tao lop</Button>
      </form>

      {classes.length === 0 ? (
        <EmptyState icon={School} title="Chua co lop hoc" />
      ) : (
        <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
          {classes.map((classModel) => (
            <article key={classModel.id} className="glass-card p-5">
              <div className="mb-5 flex items-start justify-between gap-3">
                <div>
                  <div className="grid h-11 w-11 place-items-center rounded-lg bg-white/15 text-teal-100">
                    <School className="h-6 w-6" />
                  </div>
                  <h2 className="mt-4 text-2xl font-black text-white">{classModel.className}</h2>
                  <p className="mt-1 text-sm font-semibold text-slate-400">{classModel.teacherName}</p>
                </div>
                <span className="badge">{classModel.studentCount} HS</span>
              </div>
              <p className="mb-5 text-sm text-slate-400">{formatDate(classModel.createdAt)}</p>
              <div className="flex gap-2">
                <Button variant="ghost" icon={Eye} onClick={() => onOpenClass(classModel.id)} className="flex-1">
                  Chi tiet
                </Button>
                <IconButton
                  icon={Trash2}
                  label="Xoa lop"
                  onClick={() => {
                    deleteClass(classModel.id);
                    setReloadKey((key) => key + 1);
                    onToast("Da xoa lop.", "info");
                  }}
                />
              </div>
            </article>
          ))}
        </div>
      )}
    </div>
  );
}

function ClassDetailScreen({
  classId,
  onBack,
  onToast,
}: {
  classId: string | null;
  onBack: () => void;
  onToast: (message: string, tone?: ToastTone) => void;
}) {
  const [reloadKey, setReloadKey] = useState(0);
  const classModel = classId ? getClassById(classId) : null;
  const students = useMemo(
    () => (classModel ? getStudentsByClass(classModel.className) : []),
    [classModel?.className, reloadKey],
  );

  if (!classModel) {
    return (
      <div className="space-y-6">
        <Button variant="ghost" icon={ArrowLeft} onClick={onBack}>Quay lai</Button>
        <EmptyState icon={CircleAlert} title="Khong tim thay lop hoc" />
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <PageHeader
        eyebrow="Chi tiet lop"
        title={classModel.className}
        actions={<Button variant="ghost" icon={ArrowLeft} onClick={onBack}>Quay lai</Button>}
      />

      <div className="grid gap-4 sm:grid-cols-3">
        <StatTile icon={UsersRound} label="Hoc sinh" value={students.length} tone="teal" />
        <StatTile icon={UserRound} label="Giao vien" value={classModel.teacherName} tone="blue" />
        <StatTile icon={Copy} label="Ma lop" value={classModel.className} tone="amber" />
      </div>

      <div className="glass-card p-4">
        <div className="flex flex-col justify-between gap-3 sm:flex-row sm:items-center">
          <div>
            <h2 className="section-title">Danh sach hoc sinh</h2>
            <p className="subtle-text">Cap nhat theo du lieu dang ky local.</p>
          </div>
          <Button
            variant="ghost"
            icon={Copy}
            onClick={() => {
              void navigator.clipboard?.writeText(classModel.className);
              onToast("Da copy ma lop.", "info");
            }}
          >
            Copy ma lop
          </Button>
        </div>
      </div>

      {students.length === 0 ? (
        <EmptyState icon={UsersRound} title="Chua co hoc sinh trong lop" />
      ) : (
        <div className="grid gap-3">
          {students.map((student) => (
            <article key={student.id} className="glass-card flex flex-col gap-4 p-4 sm:flex-row sm:items-center sm:justify-between">
              <div className="flex items-center gap-3">
                <div className="grid h-11 w-11 place-items-center rounded-lg bg-white/15 text-teal-100">
                  <UserRound className="h-5 w-5" />
                </div>
                <div className="min-w-0">
                  <h3 className="truncate font-bold text-white">{student.fullName}</h3>
                  <p className="truncate text-sm text-slate-400">{student.email}</p>
                </div>
              </div>
              <div className="flex flex-wrap items-center gap-2">
                <span className="badge">{student.loginCount} lan</span>
                <Button
                  variant="danger"
                  icon={Trash2}
                  onClick={() => {
                    updateUserClass(student.id, undefined);
                    setReloadKey((key) => key + 1);
                    onToast("Da dua hoc sinh khoi lop.", "info");
                  }}
                >
                  Xoa khoi lop
                </Button>
              </div>
            </article>
          ))}
        </div>
      )}
    </div>
  );
}
