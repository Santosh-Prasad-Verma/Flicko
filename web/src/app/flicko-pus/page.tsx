"use client";

import Image from "next/image";
import Link from "next/link";
import {
  useCallback,
  useEffect,
  useRef,
  useState,
  type MouseEvent as ReactMouseEvent,
  type ReactNode,
} from "react";
import {
  AnimatePresence,
  motion,
  useMotionValue,
  useReducedMotion,
  useScroll,
  useSpring,
  useTransform,
  type MotionValue,
} from "framer-motion";
import {
  BadgeCheck,
  Check,
  ChevronDown,
  Crown,
  Gift,
  Layers3,
  Palette,
  Rocket,
  Smile,
  Sparkles,
  Upload,
  Video,
  X,
  Zap,
  type LucideIcon,
} from "lucide-react";

const fadeInUp = {
  hidden: { opacity: 0, y: 60 },
  visible: {
    opacity: 1,
    y: 0,
    transition: { duration: 0.7, ease: [0.25, 0.4, 0.25, 1] as any },
  },
} as any;

const fadeIn = {
  hidden: { opacity: 0 },
  visible: {
    opacity: 1,
    transition: { duration: 0.9, ease: ("easeOut" as any) },
  },
} as any;

const slideIn = {
  hidden: { opacity: 0, x: -60 },
  visible: {
    opacity: 1,
    x: 0,
    transition: { duration: 0.7, ease: [0.25, 0.4, 0.25, 1] as any },
  },
} as any;

const scaleIn = {
  hidden: { opacity: 0, scale: 0.88 },
  visible: {
    opacity: 1,
    scale: 1,
    transition: { duration: 0.65, ease: [0.25, 0.4, 0.25, 1] as any },
  },
} as any;

const staggerContainer = {
  hidden: {},
  visible: {
    transition: { staggerChildren: 0.1, delayChildren: 0.1 },
  },
} as any;

const popIn = {
  hidden: { opacity: 0, scale: 0.5, y: 20 },
  visible: {
    opacity: 1,
    scale: 1,
    y: 0,
    transition: { type: ("spring" as any), stiffness: 400, damping: 22 },
  },
} as any;

type Plan = {
  name: string;
  price: string;
  description: string;
  cta: string;
  popular?: boolean;
  icon: "basic" | "plus";
  features: string[];
};

type Highlight = {
  icon: LucideIcon;
  title: string;
  description: string;
  color: string;
};

type FeatureSection = {
  label: string;
  title: string;
  description: string;
  video: string;
  reverse?: boolean;
  badge: string;
};

type ComparisonValue = boolean | string;

type ComparisonRow = {
  label: string;
  basic: ComparisonValue;
  plus: ComparisonValue;
};

type FaqItem = {
  question: string;
  answer: string;
};

type FaqGroup = {
  label: string;
  items: FaqItem[];
};

type HeroPerkChip = {
  icon: LucideIcon;
  label: string;
  value: string;
  className: string;
  accent: string;
  xRange: [number, number];
  yRange: [number, number];
  rotateRange: [number, number];
};

type MotionShowcaseCard = {
  icon: LucideIcon;
  eyebrow: string;
  title: string;
  description: string;
  stat: string;
  className: string;
  accentClass: string;
  glowClass: string;
  xRange: [number, number, number];
  yRange: [number, number, number];
  rotateXRange: [number, number, number];
  rotateYRange: [number, number, number];
  scaleRange: [number, number, number];
};

type Particle = {
  id: number;
  x: number;
  y: number;
  dx: number;
  dy: number;
  color: string;
};

const starDots = [
  { top: "8%", left: "12%", size: "h-1.5 w-1.5", delay: "0s" },
  { top: "16%", left: "72%", size: "h-1 w-1", delay: "0.6s" },
  { top: "24%", left: "52%", size: "h-1.5 w-1.5", delay: "1.1s" },
  { top: "32%", left: "84%", size: "h-1 w-1", delay: "1.6s" },
  { top: "40%", left: "18%", size: "h-1 w-1", delay: "0.8s" },
  { top: "52%", left: "64%", size: "h-1.5 w-1.5", delay: "1.4s" },
  { top: "64%", left: "8%", size: "h-1 w-1", delay: "2.1s" },
  { top: "74%", left: "78%", size: "h-1 w-1", delay: "0.4s" },
  { top: "84%", left: "38%", size: "h-1.5 w-1.5", delay: "1.8s" },
  { top: "90%", left: "92%", size: "h-1 w-1", delay: "2.4s" },
];

const plans: Plan[] = [
  {
    name: "Flicko Basic",
    price: "$2.99 / month",
    description:
      "The essentials to make Flicko yours without losing the home-page energy.",
    cta: "Get Flicko Basic",
    icon: "basic",
    features: [
      "Custom emoji anywhere",
      "50MB uploads",
      "Custom app icons",
      "Super Reactions",
      "Flicko Plus badge",
    ],
  },
  {
    name: "Flicko Plus",
    price: "$9.99 / month",
    description:
      "All the perks, all the power. The best way to supercharge your world on Flicko.",
    cta: "Get Flicko Plus",
    popular: true,
    icon: "plus",
    features: [
      "Everything in Flicko Basic",
      "Custom profiles and banners",
      "500MB uploads",
      "HD video streaming",
      "Color themes",
      "2 boosts included",
      "Custom sounds and stickers",
      "Longer messages and guest passes",
    ],
  },
];

const highlights: Highlight[] = [
  {
    icon: Palette,
    title: "Show Off Your Style",
    description:
      "Animated avatars, profile themes, banner images, and custom looks that make every profile feel personal.",
    color: "from-[#EB459E] to-[#FF9BD0]",
  },
  {
    icon: Smile,
    title: "Emoji Everywhere",
    description:
      "Take your custom emoji, stickers, and reactions across Flicko without losing the personality.",
    color: "from-[#FEE75C] to-[#FFF4AE]",
  },
  {
    icon: Upload,
    title: "Bigger Uploads",
    description:
      "Share screenshots, clips, and chunky memes without compressing the fun out of them.",
    color: "from-[#5865F2] to-[#8EA1FF]",
  },
  {
    icon: Video,
    title: "Crystal-Clear Streams",
    description:
      "Go live in HD for game nights, watch parties, and all the weird stuff your group chat gets into.",
    color: "from-[#57F287] to-[#A4F5BD]",
  },
  {
    icon: Gift,
    title: "Boost Your Spaces",
    description:
      "Use included boosts to level up the communities you actually spend time in.",
    color: "from-[#FF7B54] to-[#FFB347]",
  },
  {
    icon: Sparkles,
    title: "Premium Presence",
    description:
      "Stand out with profile polish, cleaner identity layers, and more ways to feel unmistakably you.",
    color: "from-[#A855F7] to-[#D8B4FE]",
  },
];

const featureSections: FeatureSection[] = [
  {
    label: "Explore The Best Of Flicko Plus",
    title: "Turn heads in every chat",
    description:
      "Take your look to the next level with animated avatars, banner images, profile themes, and more.",
    video: "/Videos/vid-1.mp4",
    badge: "Profiles that feel alive",
  },
  {
    label: "Personalize Everything",
    title: "Make this place your space",
    description:
      "Add a little you to your Flicko space with custom color themes, app icons, and a profile setup that actually feels like yours.",
    video: "/Videos/vid-2.mp4",
    reverse: true,
    badge: "Color themes and icons",
  },
  {
    label: "Emoji Everywhere",
    title: "Hype and meme with better emoji",
    description:
      "Use custom emoji anywhere, including on your profile and across the communities you love most.",
    video: "/Videos/vid-3.mp4",
    badge: "Take reactions everywhere",
  },
  {
    label: "No Limits, All Fun",
    title: "Live life without limits",
    description:
      "From crystal-clear streams to bigger uploads, send it all without trimming the fun out of it first.",
    video: "/Videos/vid-4.mp4",
    reverse: true,
    badge: "500MB uploads and HD streams",
  },
];

const comparisonRows: ComparisonRow[] = [
  { label: "Custom emoji anywhere", basic: true, plus: true },
  { label: "Super Reactions", basic: true, plus: true },
  { label: "Custom app icons", basic: true, plus: true },
  { label: "Flicko Plus badge", basic: true, plus: true },
  { label: "Upload size", basic: "50MB", plus: "500MB" },
  { label: "Animated avatar", basic: false, plus: true },
  { label: "Custom profiles and banners", basic: false, plus: true },
  { label: "Color themes", basic: false, plus: true },
  { label: "HD video streaming", basic: false, plus: true },
  { label: "Boosts", basic: false, plus: "2 included" },
  { label: "Custom stickers anywhere", basic: false, plus: true },
  { label: "Longer messages", basic: false, plus: "4,000 chars" },
];

const faqGroups: FaqGroup[] = [
  {
    label: "General",
    items: [
      {
        question: "What is Flicko Plus?",
        answer:
          "Flicko Plus is a premium subscription that unlocks extra features across Flicko, giving you more ways to personalize your profile, share bigger moments, and stand out.",
      },
      {
        question: "How does Flicko Plus work?",
        answer:
          "When you subscribe to Flicko Plus, you get access to premium perks like custom emoji anywhere, bigger uploads, enhanced profiles, and more. When the subscription ends, those perks expire with your plan.",
      },
      {
        question: "What is the difference between Flicko Plus and Flicko Basic?",
        answer:
          "Flicko Plus is the full plan with every premium perk, while Flicko Basic covers the essentials like custom emoji, core personalization, and solid upload limits.",
      },
    ],
  },
  {
    label: "Billing",
    items: [
      {
        question: "How much does Flicko Plus cost?",
        answer:
          "Pricing depends on your region and plan. Check the Flicko subscription flow for the latest prices on Flicko Basic and Flicko Plus.",
      },
      {
        question: "Do you offer localized pricing?",
        answer:
          "Yes. We continue expanding localized pricing so Flicko Basic and Flicko Plus are more accessible across regions.",
      },
      {
        question: "What payment methods do you accept?",
        answer:
          "We support a range of payment methods depending on your region and platform.",
      },
    ],
  },
  {
    label: "Perks",
    items: [
      {
        question: "Can I gift Flicko Plus?",
        answer:
          "Yes. You can gift Flicko Plus or Flicko Basic directly from the subscription flow whenever gifting is enabled for your account.",
      },
      {
        question: "Do boosts stay active forever?",
        answer:
          "Boosts stay active while your subscription is active and do not stack forever over time unless you keep renewing or buy more.",
      },
      {
        question: "Why is my Flicko Plus not working?",
        answer:
          "If you are having trouble with your subscription, contact Flicko support and we will help you sort it out.",
      },
    ],
  },
];

const heroPerkChips: HeroPerkChip[] = [
  {
    icon: Upload,
    label: "Upload ceiling",
    value: "500MB by default",
    className: "left-[-2%] top-[8%] hidden md:block",
    accent: "from-[#5865F2] to-[#8EA1FF]",
    xRange: [0, -28],
    yRange: [0, -56],
    rotateRange: [-8, 4],
  },
  {
    icon: Palette,
    label: "Theme pack",
    value: "Custom colors and icons",
    className: "right-[-1%] top-[10%] hidden md:block",
    accent: "from-[#EB459E] to-[#FFB1DA]",
    xRange: [0, 24],
    yRange: [0, -72],
    rotateRange: [8, -5],
  },
  {
    icon: Gift,
    label: "Boost stack",
    value: "2 boosts included",
    className: "right-[4%] bottom-[18%] hidden md:block",
    accent: "from-[#57F287] to-[#A4F5BD]",
    xRange: [0, 38],
    yRange: [0, -34],
    rotateRange: [-5, 6],
  },
  {
    icon: Video,
    label: "Watch room",
    value: "HD streams that hold up",
    className: "left-[8%] bottom-[12%] hidden lg:block",
    accent: "from-[#FEE75C] to-[#FFF4AE]",
    xRange: [0, -34],
    yRange: [0, -18],
    rotateRange: [6, -6],
  },
];

const motionShowcaseCards: MotionShowcaseCard[] = [
  {
    icon: Palette,
    eyebrow: "Profile lab",
    title: "Animated identity layers",
    description:
      "Banners, avatars, and profile themes give every chat a stronger sense of who is showing up.",
    stat: "Themes, avatars, banners",
    className: "left-[4%] top-[11%] w-[290px]",
    accentClass: "bg-[#EB459E]/16 text-[#FF9BD0]",
    glowClass: "from-[#EB459E]/26 via-[#EB459E]/10",
    xRange: [-120, -36, -170],
    yRange: [120, 0, -92],
    rotateXRange: [18, 8, -4],
    rotateYRange: [-24, -8, 10],
    scaleRange: [0.9, 1.02, 0.97],
  },
  {
    icon: Video,
    eyebrow: "Stream deck",
    title: "HD rooms for every watch party",
    description:
      "Streams feel like a premium feature when the layout, quality, and motion all support the moment.",
    stat: "Sharper video, cleaner presence",
    className: "right-[4%] top-[16%] w-[312px]",
    accentClass: "bg-[#5865F2]/18 text-[#B6C0FF]",
    glowClass: "from-[#5865F2]/28 via-[#5865F2]/10",
    xRange: [118, 30, 164],
    yRange: [132, 14, -76],
    rotateXRange: [20, 10, -3],
    rotateYRange: [22, 8, -14],
    scaleRange: [0.88, 1.04, 0.98],
  },
  {
    icon: Gift,
    eyebrow: "Boost engine",
    title: "Level up the spaces that matter",
    description:
      "Included boosts make the upgrade feel immediately useful, not just visually premium.",
    stat: "2 included, ready to drop",
    className: "left-[16%] bottom-[8%] w-[320px]",
    accentClass: "bg-[#57F287]/14 text-[#9AF7B7]",
    glowClass: "from-[#57F287]/22 via-[#57F287]/10",
    xRange: [-58, 0, -112],
    yRange: [164, 8, -44],
    rotateXRange: [16, 7, -4],
    rotateYRange: [-18, -6, 8],
    scaleRange: [0.9, 1.03, 0.98],
  },
  {
    icon: Smile,
    eyebrow: "Emoji cloud",
    title: "Take custom reactions everywhere",
    description:
      "Stickers, emoji, and reactions stay personal across chats, profiles, and communities.",
    stat: "More personality per message",
    className: "right-[12%] bottom-[10%] w-[280px]",
    accentClass: "bg-[#FEE75C]/16 text-[#FFF1A8]",
    glowClass: "from-[#FEE75C]/22 via-[#FEE75C]/10",
    xRange: [70, 8, 120],
    yRange: [120, -8, -30],
    rotateXRange: [14, 5, -2],
    rotateYRange: [14, 4, -10],
    scaleRange: [0.9, 1.02, 0.97],
  },
];

const springSettings = { stiffness: 140, damping: 24, mass: 0.55 };

function useParticleBurst() {
  const [particles, setParticles] = useState<Particle[]>([]);
  const colors = ["#5865F2", "#EB459E", "#57F287", "#FEE75C", "#8EA1FF"];
  const idRef = useRef(0);
  const timeoutsRef = useRef<number[]>([]);

  useEffect(() => {
    return () => {
      timeoutsRef.current.forEach((timeout) => window.clearTimeout(timeout));
    };
  }, []);

  const burst = useCallback((event: ReactMouseEvent<HTMLElement>) => {
    const rect = event.currentTarget.getBoundingClientRect();
    const x = event.clientX - rect.left;
    const y = event.clientY - rect.top;

    const nextParticles = Array.from({ length: 10 }, () => ({
      id: idRef.current++,
      x,
      y,
      dx: (Math.random() - 0.5) * 120,
      dy: (Math.random() - 0.5) * 120,
      color: colors[Math.floor(Math.random() * colors.length)]!,
    }));

    setParticles((current) => [...current, ...nextParticles]);

    const timeout = window.setTimeout(() => {
      setParticles((current) =>
        current.filter(
          (particle) =>
            !nextParticles.some((newParticle) => newParticle.id === particle.id),
        ),
      );
    }, 700);

    timeoutsRef.current.push(timeout);
  }, []);

  return { particles, burst };
}

function MagneticButton({
  children,
  className,
  href,
  reduceMotion,
}: {
  children: ReactNode;
  className?: string;
  href: string;
  reduceMotion: boolean;
}) {
  const ref = useRef<HTMLAnchorElement>(null);
  const x = useMotionValue(0);
  const y = useMotionValue(0);
  const { particles, burst } = useParticleBurst();

  const handleMouseMove = (event: ReactMouseEvent<HTMLAnchorElement>) => {
    if (reduceMotion || !ref.current) return;

    const rect = ref.current.getBoundingClientRect();
    const centerX = rect.left + rect.width / 2;
    const centerY = rect.top + rect.height / 2;

    x.set((event.clientX - centerX) * 0.28);
    y.set((event.clientY - centerY) * 0.28);
  };

  const handleMouseLeave = () => {
    x.set(0);
    y.set(0);
  };

  return (
    <motion.a
      ref={ref}
      href={href}
      style={reduceMotion ? undefined : { x, y }}
      onMouseMove={handleMouseMove}
      onMouseLeave={handleMouseLeave}
      onMouseDown={burst}
      whileTap={{ scale: 0.96 }}
      className={`relative inline-flex items-center justify-center overflow-hidden ${className}`}
    >
      <span className="relative z-10">{children}</span>
      {particles.map((particle) => (
        <motion.span
          key={particle.id}
          initial={{ x: particle.x, y: particle.y, scale: 1, opacity: 1 }}
          animate={{
            x: particle.x + particle.dx,
            y: particle.y + particle.dy,
            scale: 0,
            opacity: 0,
          }}
          transition={{ duration: 0.65, ease: "easeOut" }}
          className="pointer-events-none absolute h-2 w-2 rounded-full"
          style={{ background: particle.color }}
        />
      ))}
    </motion.a>
  );
}

function CursorGlow() {
  const mouseX = useMotionValue(-200);
  const mouseY = useMotionValue(-200);
  const x = useSpring(mouseX, { stiffness: 180, damping: 24, mass: 0.35 });
  const y = useSpring(mouseY, { stiffness: 180, damping: 24, mass: 0.35 });

  useEffect(() => {
    const handleMouseMove = (event: MouseEvent) => {
      mouseX.set(event.clientX);
      mouseY.set(event.clientY);
    };

    window.addEventListener("mousemove", handleMouseMove);
    return () => window.removeEventListener("mousemove", handleMouseMove);
  }, [mouseX, mouseY]);

  return (
    <motion.div
      className="pointer-events-none fixed z-[200] hidden md:block"
      style={{
        x,
        y,
        translateX: "-50%",
        translateY: "-50%",
        width: 420,
        height: 420,
        background:
          "radial-gradient(circle, rgba(88,101,242,0.06) 0%, transparent 70%)",
        borderRadius: "50%",
      }}
    />
  );
}

function AnimatedCounter({
  value,
  suffix = "",
}: {
  value: number;
  suffix?: string;
}) {
  const [display, setDisplay] = useState(0);
  const ref = useRef<HTMLSpanElement>(null);
  const [inView, setInView] = useState(false);

  useEffect(() => {
    const element = ref.current;
    if (!element) return;

    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setInView(true);
          observer.disconnect();
        }
      },
      { threshold: 0.5 },
    );

    observer.observe(element);
    return () => observer.disconnect();
  }, []);

  useEffect(() => {
    if (!inView) return;

    const startedAt = performance.now();
    const duration = 1200;
    let frame = 0;

    const tick = (time: number) => {
      const progress = Math.min((time - startedAt) / duration, 1);
      const eased = 1 - (1 - progress) ** 3;
      setDisplay(Math.floor(value * eased));

      if (progress < 1) {
        frame = window.requestAnimationFrame(tick);
      } else {
        setDisplay(value);
      }
    };

    frame = window.requestAnimationFrame(tick);
    return () => window.cancelAnimationFrame(frame);
  }, [inView, value]);

  return (
    <span ref={ref}>
      {display}
      {suffix}
    </span>
  );
}

function GlitchText({ children }: { children: string }) {
  const [glitching, setGlitching] = useState(false);

  useEffect(() => {
    let startTimeout = 0;
    let stopTimeout = 0;
    let active = true;

    const schedule = () => {
      startTimeout = window.setTimeout(() => {
        if (!active) return;
        setGlitching(true);

        stopTimeout = window.setTimeout(() => {
          if (!active) return;
          setGlitching(false);
          schedule();
        }, 180);
      }, 3000 + Math.random() * 3500);
    };

    schedule();

    return () => {
      active = false;
      window.clearTimeout(startTimeout);
      window.clearTimeout(stopTimeout);
    };
  }, []);

  return (
    <span
      className="relative inline-block transition-all duration-150"
      style={
        glitching
          ? {
              textShadow: "2px 0 #EB459E, -2px 0 #5865F2",
              transform: "translate(1px,-1px)",
            }
          : undefined
      }
    >
      {children}
    </span>
  );
}

function FloatingPerkChip({
  chip,
  scrollY,
  reduceMotion,
}: {
  chip: HeroPerkChip;
  scrollY: MotionValue<number>;
  reduceMotion: boolean;
}) {
  const x = useSpring(
    useTransform(scrollY, [0, 700], reduceMotion ? [0, 0] : chip.xRange),
    springSettings,
  );
  const y = useSpring(
    useTransform(scrollY, [0, 700], reduceMotion ? [0, 0] : chip.yRange),
    springSettings,
  );
  const rotate = useSpring(
    useTransform(scrollY, [0, 700], reduceMotion ? [0, 0] : chip.rotateRange),
    springSettings,
  );
  const Icon = chip.icon;

  return (
    <motion.div
      style={{ x, y, rotate }}
      initial={{ opacity: 0, scale: 0.7 }}
      animate={{ opacity: 1, scale: 1 }}
      transition={{ type: "spring", stiffness: 260, damping: 20, delay: 0.4 }}
      whileHover={reduceMotion ? undefined : { scale: 1.06 }}
      className={`absolute z-20 ${chip.className}`}
    >
      <div className="relative overflow-hidden rounded-[24px] border border-white/14 bg-[#100c2d]/78 p-4 shadow-[0_22px_60px_rgba(0,0,0,0.32)] backdrop-blur-xl">
        <div className="absolute inset-0 bg-[linear-gradient(135deg,rgba(255,255,255,0.12),transparent_55%)]" />
        <div className="relative flex items-center gap-3">
          <div
            className={`flex h-11 w-11 items-center justify-center rounded-2xl bg-gradient-to-br ${chip.accent} text-white shadow-lg`}
          >
            <Icon className="h-5 w-5" />
          </div>
          <div>
            <div className="text-[11px] font-semibold uppercase tracking-[0.22em] text-white/52">
              {chip.label}
            </div>
            <div className="text-sm font-semibold text-white">{chip.value}</div>
          </div>
        </div>
      </div>
    </motion.div>
  );
}

function ShowcaseCardInner({ card }: { card: MotionShowcaseCard }) {
  const Icon = card.icon;

  return (
    <>
      <div className="flex items-start justify-between gap-4">
        <motion.div
          whileHover={{ rotate: [0, -10, 10, 0], transition: { duration: 0.4 } }}
          className={`flex h-12 w-12 items-center justify-center rounded-2xl ${card.accentClass}`}
        >
          <Icon className="h-5 w-5" />
        </motion.div>
        <div className="rounded-full border border-white/10 bg-white/[0.08] px-3 py-1 text-[11px] font-semibold uppercase tracking-[0.18em] text-white/58">
          {card.eyebrow}
        </div>
      </div>

      <h3 className="mt-8 text-2xl font-black uppercase tracking-tight text-white">
        {card.title}
      </h3>
      <p className="mt-4 text-sm leading-7 text-white/72">{card.description}</p>

      <div className="mt-8 inline-flex rounded-full border border-white/10 bg-white/[0.08] px-4 py-2 text-sm font-semibold text-white/86">
        {card.stat}
      </div>
    </>
  );
}

function ScrollShowcaseCard({
  card,
  progress,
  reduceMotion,
}: {
  card: MotionShowcaseCard;
  progress: MotionValue<number>;
  reduceMotion: boolean;
}) {
  const x = useSpring(
    useTransform(progress, [0, 0.5, 1], reduceMotion ? [0, 0, 0] : card.xRange),
    springSettings,
  );
  const y = useSpring(
    useTransform(progress, [0, 0.5, 1], reduceMotion ? [0, 0, 0] : card.yRange),
    springSettings,
  );
  const rotateX = useSpring(
    useTransform(
      progress,
      [0, 0.5, 1],
      reduceMotion ? [0, 0, 0] : card.rotateXRange,
    ),
    springSettings,
  );
  const rotateY = useSpring(
    useTransform(
      progress,
      [0, 0.5, 1],
      reduceMotion ? [0, 0, 0] : card.rotateYRange,
    ),
    springSettings,
  );
  const scale = useSpring(
    useTransform(progress, [0, 0.5, 1], reduceMotion ? [1, 1, 1] : card.scaleRange),
    springSettings,
  );

  return (
    <motion.article
      style={{ x, y, rotateX, rotateY, scale }}
      whileHover={{ zIndex: 10 }}
      className={`absolute ${card.className} [transform-style:preserve-3d]`}
    >
      <div
        className={`absolute inset-0 rounded-[32px] bg-gradient-to-br ${card.glowClass} to-transparent blur-2xl`}
      />
      <div className="relative rounded-[32px] border border-white/12 bg-[#140f34]/88 p-6 shadow-[0_24px_60px_rgba(0,0,0,0.28)] backdrop-blur-[24px]">
        <ShowcaseCardInner card={card} />
      </div>
    </motion.article>
  );
}

function ImmersiveShowcase({ reduceMotion }: { reduceMotion: boolean }) {
  const stageRef = useRef<HTMLDivElement | null>(null);
  const { scrollYProgress } = useScroll({
    target: stageRef,
    offset: ["start end", "end start"],
  });

  const coreY = useSpring(
    useTransform(
      scrollYProgress,
      [0, 0.5, 1],
      reduceMotion ? [0, 0, 0] : [124, 0, -84],
    ),
    springSettings,
  );
  const coreRotateX = useSpring(
    useTransform(
      scrollYProgress,
      [0, 0.5, 1],
      reduceMotion ? [0, 0, 0] : [18, 0, -8],
    ),
    springSettings,
  );
  const coreRotateY = useSpring(
    useTransform(
      scrollYProgress,
      [0, 0.5, 1],
      reduceMotion ? [0, 0, 0] : [-12, 0, 10],
    ),
    springSettings,
  );
  const ringScale = useSpring(
    useTransform(
      scrollYProgress,
      [0, 0.5, 1],
      reduceMotion ? [1, 1, 1] : [0.88, 1, 1.08],
    ),
    springSettings,
  );
  const outerRingScale = useSpring(
    useTransform(
      scrollYProgress,
      [0, 0.5, 1],
      reduceMotion ? [1, 1, 1] : [1, 1.12, 1.22],
    ),
    springSettings,
  );
  const haloOpacity = useTransform(
    scrollYProgress,
    [0, 0.5, 1],
    [0.28, 0.82, 0.45],
  );

  return (
    <motion.section
      initial="hidden"
      whileInView="visible"
      viewport={{ once: true, margin: "-50px" }}
      variants={fadeInUp}
      className="py-20 md:py-28"
    >
      <div ref={stageRef} className="mx-auto max-w-[1300px] px-6">
        <div className="text-center">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            className="text-sm font-semibold uppercase tracking-[0.22em] text-white/55"
          >
            Premium In Motion
          </motion.div>
          <motion.h2
            initial={{ opacity: 0, y: 30 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ delay: 0.1 }}
            className="mt-4 text-4xl font-black uppercase tracking-tight text-white md:text-6xl"
          >
            Scroll through the upgrade before you buy it
          </motion.h2>
          <motion.p
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ delay: 0.2 }}
            className="mx-auto mt-6 max-w-3xl text-lg leading-relaxed text-white/72"
          >
            Flicko Plus should feel more alive than a static pricing page. This
            section turns the premium perks into a moving scene with a deeper,
            more collectible feel.
          </motion.p>
        </div>

        <div className="mt-12 grid gap-4 lg:hidden">
          <div className="overflow-hidden rounded-[40px] border border-white/15 bg-white/[0.08] p-6 shadow-[0_20px_50px_rgba(0,0,0,0.3)] backdrop-blur-[24px]">
            <div className="rounded-[30px] border border-white/10 bg-[#120d2c] p-6 text-center shadow-[0_18px_60px_rgba(15,12,42,0.45)]">
              <div className="mx-auto flex h-20 w-20 items-center justify-center rounded-[28px] bg-[linear-gradient(135deg,rgba(88,101,242,0.85),rgba(235,69,158,0.75))] shadow-[0_20px_50px_rgba(88,101,242,0.3)]">
                <Image src="/Flicko_icon.png" alt="Flicko" width={42} height={42} />
              </div>
              <div className="mt-6 text-[11px] font-semibold uppercase tracking-[0.22em] text-white/52">
                Flicko Plus Engine
              </div>
              <h3 className="mt-3 text-3xl font-black uppercase tracking-tight text-white">
                Profiles, streams, boosts
              </h3>
              <p className="mt-4 text-sm leading-7 text-white/72">
                A premium layer that touches how you look, how you share, and
                how your spaces feel.
              </p>
            </div>
          </div>

          <div className="grid gap-4">
            {motionShowcaseCards.map((card, index) => (
              <motion.article
                key={card.title}
                initial={{ opacity: 0, y: 40 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true }}
                transition={{ delay: index * 0.1 }}
                className="rounded-[32px] border border-white/12 bg-[#140f34]/88 p-6 shadow-[0_20px_50px_rgba(0,0,0,0.26)] backdrop-blur-[24px]"
              >
                <ShowcaseCardInner card={card} />
              </motion.article>
            ))}
          </div>
        </div>

        <div className="relative mt-16 hidden lg:block lg:min-h-[150vh]">
          <div className="sticky top-24">
            <div className="relative min-h-[780px] overflow-hidden rounded-[64px] border border-white/15 bg-white/[0.08] p-8 shadow-[0_24px_80px_rgba(0,0,0,0.3)] backdrop-blur-[28px] [perspective:2200px]">
              <div className="absolute inset-0 bg-[radial-gradient(circle_at_center,rgba(88,101,242,0.12),transparent_55%)]" />
              <div className="absolute left-10 top-10 h-36 w-36 rounded-full bg-[#5865F2]/12 blur-3xl" />
              <div className="absolute bottom-12 right-16 h-44 w-44 rounded-full bg-[#EB459E]/10 blur-3xl" />

              <motion.div
                style={{ scale: ringScale, opacity: haloOpacity }}
                className="absolute left-1/2 top-1/2 h-[520px] w-[520px] -translate-x-1/2 -translate-y-1/2 rounded-full border border-white/12"
              />
              <motion.div
                style={{ scale: outerRingScale, opacity: haloOpacity }}
                className="absolute left-1/2 top-1/2 h-[640px] w-[640px] -translate-x-1/2 -translate-y-1/2 rounded-full border border-[#8EA1FF]/12"
              />

              <motion.div
                style={{ y: coreY, rotateX: coreRotateX, rotateY: coreRotateY }}
                className="absolute left-1/2 top-1/2 w-[430px] -translate-x-1/2 -translate-y-1/2 [transform-style:preserve-3d]"
              >
                <div className="rounded-[42px] border border-white/15 bg-[linear-gradient(180deg,rgba(88,101,242,0.22),rgba(18,13,44,0.94))] p-5 shadow-[0_32px_120px_rgba(12,11,40,0.52)]">
                  <div className="rounded-[34px] border border-white/10 bg-[#120d2c]/96 p-8 text-center shadow-[inset_0_1px_0_rgba(255,255,255,0.08)]">
                    <motion.div
                      animate={reduceMotion ? { rotate: 0 } : { rotate: 360 }}
                      transition={
                        reduceMotion
                          ? undefined
                          : { duration: 20, repeat: Infinity, ease: "linear" }
                      }
                      className="mx-auto flex h-24 w-24 items-center justify-center rounded-[30px] bg-[linear-gradient(135deg,rgba(88,101,242,0.92),rgba(235,69,158,0.78))] shadow-[0_22px_60px_rgba(88,101,242,0.3)]"
                    >
                      <motion.div
                        animate={reduceMotion ? { rotate: 0 } : { rotate: -360 }}
                        transition={
                          reduceMotion
                            ? undefined
                            : { duration: 20, repeat: Infinity, ease: "linear" }
                        }
                      >
                        <Image src="/Flicko_icon.png" alt="Flicko" width={50} height={50} />
                      </motion.div>
                    </motion.div>

                    <div className="mt-7 text-[11px] font-semibold uppercase tracking-[0.22em] text-white/50">
                      Flicko Plus Engine
                    </div>
                    <h3 className="mt-3 text-4xl font-black uppercase leading-[1.02] tracking-tight text-white">
                      Premium perks with real depth
                    </h3>
                    <p className="mt-5 text-base leading-7 text-white/72">
                      Instead of flat feature bullets, the page now has a
                      central premium object with perks orbiting around it as
                      the user scrolls.
                    </p>

                    <div className="mt-8 grid grid-cols-3 gap-3">
                      {[
                        { value: 500, suffix: "MB", label: "Uploads" },
                        { value: "HD", label: "Streams" },
                        { value: 2, suffix: "", label: "Boosts" },
                      ].map((item) => (
                        <motion.div
                          key={item.label}
                          whileHover={{
                            scale: 1.05,
                            borderColor: "rgba(255,255,255,0.25)",
                          }}
                          className="rounded-[22px] border border-white/10 bg-white/[0.06] px-4 py-4 transition-colors"
                        >
                          <div className="text-2xl font-black tracking-tight text-white">
                            {typeof item.value === "number" ? (
                              <AnimatedCounter value={item.value} suffix={item.suffix ?? ""} />
                            ) : (
                              item.value
                            )}
                          </div>
                          <div className="mt-1 text-[11px] font-semibold uppercase tracking-[0.2em] text-white/52">
                            {item.label}
                          </div>
                        </motion.div>
                      ))}
                    </div>
                  </div>
                </div>
              </motion.div>

              {motionShowcaseCards.map((card) => (
                <ScrollShowcaseCard
                  key={card.title}
                  card={card}
                  progress={scrollYProgress}
                  reduceMotion={reduceMotion}
                />
              ))}
            </div>
          </div>
        </div>
      </div>
    </motion.section>
  );
}

function Marquee() {
  const words = ["flicko plus", "boost", "stream", "customize"];
  const containerRef = useRef<HTMLDivElement | null>(null);
  const { scrollYProgress } = useScroll({
    target: containerRef,
    offset: ["start end", "end start"],
  });
  const x = useTransform(scrollYProgress, [0, 1], ["0%", "-10%"]);

  return (
    <div ref={containerRef} className="relative overflow-hidden py-12 md:py-16">
      <div
        className="absolute inset-0 backdrop-blur-sm"
        style={{ background: "rgba(26, 21, 58, 0.3)" }}
      />

      <motion.div
        style={{ x }}
        className="relative z-10 flex animate-marquee whitespace-nowrap"
      >
        {[...Array(10)].map((_, index) => (
          <div key={index} className="flex items-center">
            <motion.div
              whileHover={{ rotate: 15, scale: 1.08 }}
              className="mx-8 flex items-center md:mx-12"
            >
              <Image
                src="/Flicko_icon.png"
                alt="Flicko"
                width={96}
                height={96}
                className="h-16 w-16 rounded-2xl shadow-2xl md:h-20 md:w-20 lg:h-24 lg:w-24"
                style={{
                  boxShadow:
                    "0 8px 32px rgba(88, 101, 242, 0.4), 0 0 0 4px rgba(255,255,255,0.1)",
                }}
              />
            </motion.div>

            {words.map((word) => (
              <motion.span
                key={`${index}-${word}`}
                whileHover={{ color: "#8EA1FF", scale: 1.04 }}
                className="mx-6 text-4xl font-black uppercase tracking-tight text-white/35 transition-colors duration-200 md:mx-8 md:text-6xl lg:text-7xl"
              >
                {word}
              </motion.span>
            ))}
          </div>
        ))}
      </motion.div>
    </div>
  );
}

function PlanCard({
  plan,
  reduceMotion,
}: {
  plan: Plan;
  reduceMotion: boolean;
}) {
  const ref = useRef<HTMLElement>(null);
  const rotateX = useMotionValue(0);
  const rotateY = useMotionValue(0);
  const springRotateX = useSpring(rotateX, {
    stiffness: 200,
    damping: 20,
    mass: 0.4,
  });
  const springRotateY = useSpring(rotateY, {
    stiffness: 200,
    damping: 20,
    mass: 0.4,
  });

  const handleMouseMove = (event: ReactMouseEvent<HTMLElement>) => {
    if (reduceMotion || !ref.current) return;

    const rect = ref.current.getBoundingClientRect();
    const centerX = rect.left + rect.width / 2;
    const centerY = rect.top + rect.height / 2;

    rotateX.set(((event.clientY - centerY) / rect.height) * -14);
    rotateY.set(((event.clientX - centerX) / rect.width) * 14);
  };

  const handleMouseLeave = () => {
    rotateX.set(0);
    rotateY.set(0);
  };

  return (
    <motion.article
      ref={ref}
      variants={scaleIn}
      style={reduceMotion ? undefined : { rotateX: springRotateX, rotateY: springRotateY }}
      onMouseMove={handleMouseMove}
      onMouseLeave={handleMouseLeave}
      className={`relative h-full cursor-default rounded-[2rem] border p-8 backdrop-blur-[24px] [transform-style:preserve-3d] ${
        plan.popular
          ? "border-[#5865F2]/50 bg-[linear-gradient(180deg,rgba(88,101,242,0.22),rgba(26,21,58,0.92))] text-white shadow-[0_24px_80px_rgba(88,101,242,0.25)]"
          : "border-white/15 bg-white/[0.08] text-white shadow-[0_20px_60px_rgba(0,0,0,0.22)]"
      }`}
    >
      <div className="pointer-events-none absolute inset-0 rounded-[2rem] bg-[linear-gradient(145deg,rgba(255,255,255,0.12),transparent_48%)]" />

      {plan.popular ? (
        <motion.div
          initial={{ opacity: 0, y: -10 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.3, type: "spring" }}
          className="absolute -top-3 left-8 rounded-full bg-white px-4 py-1 text-xs font-black uppercase tracking-[0.2em] text-[#1a153a]"
        >
          Most Popular
        </motion.div>
      ) : null}

      <div className="relative">
        <motion.div
          whileHover={{ rotate: [0, -12, 12, 0] }}
          transition={{ duration: 0.5 }}
          className={`mb-6 flex h-14 w-14 items-center justify-center rounded-2xl ${
            plan.popular ? "bg-white text-[#5865F2]" : "bg-white/12 text-white"
          }`}
        >
          {plan.icon === "plus" ? (
            <Crown className="h-6 w-6" />
          ) : (
            <Zap className="h-6 w-6" />
          )}
        </motion.div>

        <h3 className="text-3xl font-black uppercase tracking-tight">{plan.name}</h3>
        <p
          className={`mt-2 text-sm leading-7 ${
            plan.popular ? "text-white/80" : "text-white/72"
          }`}
        >
          {plan.description}
        </p>

        <motion.div
          initial={{ opacity: 0, x: -20 }}
          whileInView={{ opacity: 1, x: 0 }}
          viewport={{ once: true }}
          transition={{ delay: 0.2 }}
          className="mt-6 text-5xl font-black tracking-tight"
        >
          {plan.price}
        </motion.div>

        <motion.ul
          variants={staggerContainer}
          initial="hidden"
          whileInView="visible"
          viewport={{ once: true }}
          className="mt-8 space-y-3"
        >
          {plan.features.map((feature) => (
            <motion.li
              key={feature}
              variants={popIn}
              className="flex items-start gap-3 text-sm leading-6"
            >
              <span className="mt-0.5 flex h-5 w-5 shrink-0 items-center justify-center rounded-full bg-white/12">
                <Check className="h-3.5 w-3.5" />
              </span>
              <span>{feature}</span>
            </motion.li>
          ))}
        </motion.ul>

        <Link
          href="#compare"
          className={`mt-8 inline-flex rounded-full px-6 py-3 text-sm font-semibold transition-all duration-300 hover:-translate-y-1 hover:shadow-xl ${
            plan.popular
              ? "bg-white text-[#23272A] hover:bg-white/90 hover:shadow-white/20"
              : "bg-[#5865F2] text-white hover:bg-[#4752C4] hover:shadow-[#5865F2]/30"
          }`}
        >
          {plan.cta}
        </Link>
      </div>
    </motion.article>
  );
}

function GlassFeatureSection({ section }: { section: FeatureSection }) {
  const ref = useRef<HTMLElement>(null);
  const { scrollYProgress } = useScroll({
    target: ref,
    offset: ["start end", "center center"],
  });
  const lineWidth = useTransform(scrollYProgress, [0, 1], ["0%", "100%"]);

  return (
    <motion.section
      ref={ref}
      initial="hidden"
      whileInView="visible"
      viewport={{ once: true, margin: "-80px" }}
      variants={fadeIn}
      className="py-20 md:py-28"
    >
      <div className="mx-auto max-w-[1300px] px-6">
        <div className="mb-8 overflow-hidden">
          <motion.div
            style={{ width: lineWidth }}
            className="h-px bg-gradient-to-r from-[#5865F2] via-[#EB459E] to-transparent"
          />
        </div>

        <motion.div
          variants={scaleIn}
          className={`flex flex-col overflow-hidden rounded-[56px] border border-white/15 bg-white/[0.08] shadow-[0_20px_40px_rgba(0,0,0,0.3)] backdrop-blur-[24px] md:rounded-[72px] ${
            section.reverse ? "lg:flex-row-reverse" : "lg:flex-row"
          }`}
        >
          <motion.div
            variants={slideIn}
            className="flex flex-1 flex-col justify-center p-10 md:p-14"
          >
            <div className="mb-4 text-sm font-semibold uppercase tracking-[0.22em] text-white/55">
              {section.label}
            </div>
            <h2 className="text-4xl font-black uppercase leading-[1.02] tracking-tight text-white md:text-5xl">
              {section.title}
            </h2>
            <p className="mt-6 max-w-xl text-lg leading-relaxed text-[#e0e0e0]">
              {section.description}
            </p>
            <motion.div
              whileHover={{ scale: 1.04, x: 4 }}
              className="mt-8 inline-flex w-fit cursor-default rounded-full border border-white/15 bg-white/10 px-4 py-2 text-sm font-semibold text-white/85"
            >
              {section.badge}
            </motion.div>
          </motion.div>

          <motion.div
            variants={slideIn}
            className="relative flex-[1.2] overflow-hidden bg-white/[0.05] p-4 md:p-5"
          >
            <div className="group relative h-full min-h-[320px] overflow-hidden rounded-[40px] border border-white/10 bg-[#141037] shadow-[0_18px_70px_rgba(10,12,34,0.45)] md:min-h-[420px]">
              <video
                src={section.video}
                autoPlay
                muted
                loop
                playsInline
                className="h-full w-full object-cover"
              />
              <div className="pointer-events-none absolute inset-x-0 top-0 h-24 bg-[linear-gradient(180deg,rgba(255,255,255,0.15),transparent)]" />
              <div className="pointer-events-none absolute inset-y-0 left-[-35%] w-1/3 -translate-x-[140%] skew-x-12 bg-gradient-to-r from-transparent via-white/15 to-transparent transition-transform duration-700 ease-out group-hover:translate-x-[420%]" />
            </div>
          </motion.div>
        </motion.div>
      </div>
    </motion.section>
  );
}

function ComparisonCell({ value, plus = false }: { value: ComparisonValue; plus?: boolean }) {
  if (typeof value === "boolean") {
    return value ? (
      <motion.span
        initial={{ scale: 0 }}
        whileInView={{ scale: 1 }}
        viewport={{ once: true }}
        transition={{ type: "spring", stiffness: 400, damping: 20 }}
        className="flex justify-center"
      >
        <Check className={`h-5 w-5 ${plus ? "text-[#8EA1FF]" : "text-[#57F287]"}`} />
      </motion.span>
    ) : (
      <X className="mx-auto h-5 w-5 text-white/30" />
    );
  }

  return (
    <span className={`text-sm font-semibold ${plus ? "text-white" : "text-white/80"}`}>
      {value}
    </span>
  );
}

export default function FlickoPlusPage() {
  const reduceMotion = useReducedMotion() ?? false;
  const [activeFaqGroup, setActiveFaqGroup] = useState(faqGroups[0].label);
  const [openFaq, setOpenFaq] = useState(faqGroups[0].items[0].question);
  const { scrollY, scrollYProgress } = useScroll();

  const progressScale = useSpring(scrollYProgress, {
    stiffness: 130,
    damping: 28,
    mass: 0.2,
  });
  const heroTextY = useSpring(
    useTransform(scrollY, [0, 800], reduceMotion ? [0, 0] : [0, 56]),
    springSettings,
  );
  const heroPanelY = useSpring(
    useTransform(scrollY, [0, 800], reduceMotion ? [0, 0] : [0, 118]),
    springSettings,
  );
  const heroPanelScale = useSpring(
    useTransform(scrollY, [0, 800], reduceMotion ? [1, 1] : [1, 0.94]),
    springSettings,
  );
  const heroPanelRotateX = useSpring(
    useTransform(scrollY, [0, 800], reduceMotion ? [0, 0] : [0, 9]),
    springSettings,
  );
  const heroPanelRotateY = useSpring(
    useTransform(scrollY, [0, 800], reduceMotion ? [0, 0] : [0, -10]),
    springSettings,
  );
  const heroBackdropY = useSpring(
    useTransform(scrollY, [0, 800], reduceMotion ? [0, 0] : [0, -64]),
    springSettings,
  );

  const currentFaqGroup =
    faqGroups.find((group) => group.label === activeFaqGroup) ?? faqGroups[0];

  return (
    <div className="min-h-screen w-full bg-[#1a153a]">
      {!reduceMotion ? <CursorGlow /> : null}

      <div className="pointer-events-none fixed inset-x-0 top-0 z-[70] h-[3px] bg-white/[0.04]">
        <motion.div
          style={{ scaleX: progressScale, transformOrigin: "0% 50%" }}
          className="h-full bg-[linear-gradient(90deg,#8EA1FF_0%,#EB459E_55%,#57F287_100%)] shadow-[0_0_20px_rgba(142,161,255,0.45)]"
        />
      </div>

      <motion.section
        initial="hidden"
        animate="visible"
        variants={fadeIn}
        className="relative min-h-screen overflow-hidden"
        style={{ background: "#1a153a" }}
      >
        <div className="pointer-events-none absolute inset-0 overflow-hidden">
          {starDots.map((star, index) => (
            <motion.div
              key={`${star.top}-${star.left}`}
              initial={{ opacity: 0, scale: 0 }}
              animate={{ opacity: 0.35, scale: 1 }}
              transition={{ delay: index * 0.08, duration: 0.4 }}
              className={`absolute rounded-full bg-white/35 animate-pulse ${star.size}`}
              style={{
                top: star.top,
                left: star.left,
                animationDelay: star.delay,
              }}
            />
          ))}
        </div>

        <div className="pointer-events-none absolute inset-0 overflow-hidden">
          <motion.div
            animate={reduceMotion ? undefined : { scale: [1, 1.12, 1], x: [0, 20, 0] }}
            transition={
              reduceMotion
                ? undefined
                : { duration: 8, repeat: Infinity, ease: "easeInOut" }
            }
            className="absolute left-[-10%] top-[18%] h-64 w-64 rounded-full bg-[#5865F2]/30 blur-3xl"
          />
          <motion.div
            animate={reduceMotion ? undefined : { scale: [1, 1.15, 1], x: [0, -18, 0] }}
            transition={
              reduceMotion
                ? undefined
                : { duration: 9, repeat: Infinity, ease: "easeInOut", delay: 1 }
            }
            className="absolute right-[8%] top-[12%] h-72 w-72 rounded-full bg-[#EB459E]/25 blur-3xl"
          />
          <motion.div
            animate={reduceMotion ? undefined : { scale: [1, 1.08, 1] }}
            transition={
              reduceMotion
                ? undefined
                : { duration: 11, repeat: Infinity, ease: "easeInOut", delay: 2 }
            }
            className="absolute bottom-[10%] left-[35%] h-64 w-64 rounded-full bg-[#57F287]/10 blur-3xl"
          />
        </div>

        <div className="relative z-10 mx-auto max-w-[1400px] px-6 pb-20 pt-32">
          <div className="flex flex-col items-center gap-14 lg:flex-row lg:gap-10">
            <motion.div
              variants={slideIn}
              style={{ y: heroTextY }}
              className="flex-1 text-left lg:max-w-[560px]"
            >
              <motion.div
                variants={popIn}
                className="mb-6 inline-flex items-center gap-2 rounded-full border border-white/15 bg-white/10 px-4 py-2 text-sm font-semibold uppercase tracking-[0.2em] text-white/90 backdrop-blur-sm"
              >
                <motion.span
                  animate={reduceMotion ? undefined : { rotate: [0, 15, -15, 0] }}
                  transition={
                    reduceMotion
                      ? undefined
                      : { duration: 2, repeat: Infinity, delay: 1 }
                  }
                >
                  <Sparkles className="h-4 w-4" />
                </motion.span>
                Flicko Plus
              </motion.div>

              <motion.h1
                variants={fadeInUp}
                className="text-4xl font-black uppercase leading-[1.05] tracking-tight text-white md:text-5xl lg:text-6xl xl:text-7xl"
              >
                Make your group chats feel <GlitchText>premium</GlitchText>,
                playable, and alive
              </motion.h1>

              <motion.p
                variants={fadeInUp}
                className="mt-8 max-w-xl text-lg leading-relaxed text-white/80 md:text-xl lg:text-2xl"
              >
                Flicko Plus keeps the same playful home-page energy, then adds a
                deeper premium layer: bigger uploads, sharper streams, richer
                profiles, better reactions, and a stronger visual identity across
                every space you use.
              </motion.p>

              <motion.div
                variants={scaleIn}
                className="mt-10 flex flex-col gap-4 sm:flex-row"
              >
                <MagneticButton
                  href="#plans"
                  reduceMotion={reduceMotion}
                  className="rounded-full bg-white px-6 py-3.5 text-base font-semibold text-[#23272A] shadow-2xl transition-all duration-300 hover:shadow-white/30"
                >
                  Get Flicko Plus
                </MagneticButton>
                <MagneticButton
                  href="#compare"
                  reduceMotion={reduceMotion}
                  className="rounded-full bg-[#5865F2]/80 px-6 py-3.5 text-base font-semibold text-white backdrop-blur transition-all duration-300 hover:bg-[#5865F2] hover:shadow-lg hover:shadow-[#5865F2]/30"
                >
                  Compare Plans
                </MagneticButton>
              </motion.div>

              <motion.div
                variants={staggerContainer}
                initial="hidden"
                animate="visible"
                className="mt-10 grid gap-3 sm:grid-cols-3"
              >
                {[
                  {
                    icon: BadgeCheck,
                    label: "Identity",
                    value: "Animated profiles",
                  },
                  {
                    icon: Rocket,
                    label: "Sharing",
                    value: "500MB + HD streams",
                  },
                  {
                    icon: Layers3,
                    label: "Servers",
                    value: "2 boosts included",
                  },
                ].map((item) => (
                  <motion.div
                    key={item.label}
                    variants={popIn}
                    whileHover={reduceMotion ? undefined : { y: -4, scale: 1.02 }}
                    className="cursor-default rounded-[24px] border border-white/12 bg-white/[0.06] px-4 py-4 backdrop-blur-[18px]"
                  >
                    <item.icon className="h-5 w-5 text-white/88" />
                    <div className="mt-4 text-[11px] font-semibold uppercase tracking-[0.2em] text-white/52">
                      {item.label}
                    </div>
                    <div className="mt-1 text-sm font-semibold text-white">
                      {item.value}
                    </div>
                  </motion.div>
                ))}
              </motion.div>
            </motion.div>

            <div className="flex-1">
              <div className="relative [perspective:2200px]">
                <motion.div
                  style={{ y: heroBackdropY }}
                  className="pointer-events-none absolute inset-[-8%] rounded-[64px] bg-[radial-gradient(circle_at_center,rgba(88,101,242,0.28),transparent_54%)] blur-3xl"
                />

                {heroPerkChips.map((chip) => (
                  <FloatingPerkChip
                    key={chip.label}
                    chip={chip}
                    scrollY={scrollY}
                    reduceMotion={reduceMotion}
                  />
                ))}

                <motion.div
                  variants={scaleIn}
                  style={{
                    y: heroPanelY,
                    scale: heroPanelScale,
                    rotateX: heroPanelRotateX,
                    rotateY: heroPanelRotateY,
                  }}
                  className="relative [transform-style:preserve-3d]"
                >
                  <div className="relative rounded-[48px] border border-white/15 bg-white/[0.08] p-4 pb-6 shadow-[0_20px_80px_rgba(0,0,0,0.34)] backdrop-blur-[24px] md:p-5 md:pb-24">
                    <div className="absolute left-5 top-5 rounded-full border border-white/15 bg-[#0f1430]/85 px-4 py-2 text-sm font-semibold text-white backdrop-blur-sm">
                      Flicko Plus scene
                    </div>
                    <div className="absolute right-5 top-5 hidden rounded-full border border-white/15 bg-[#0f1430]/85 px-4 py-2 text-[11px] font-semibold uppercase tracking-[0.22em] text-white/72 backdrop-blur-sm md:block">
                      Scroll-linked depth
                    </div>

                    <div className="relative overflow-hidden rounded-[36px] border border-white/10 bg-[#120d2c]">
                      <div className="absolute inset-x-16 top-12 z-10 h-28 rounded-full bg-[#5865F2]/22 blur-3xl" />
                      <Image
                        src="/flicko_banner.png"
                        alt="Flicko Plus preview"
                        width={1344}
                        height={768}
                        className="relative h-auto w-full object-cover"
                        priority
                      />
                      <motion.div
                        initial={{ x: "-100%" }}
                        animate={reduceMotion ? undefined : { x: "220%" }}
                        transition={
                          reduceMotion
                            ? undefined
                            : {
                                duration: 2.5,
                                repeat: Infinity,
                                repeatDelay: 4,
                                ease: "easeInOut",
                              }
                        }
                        className="pointer-events-none absolute inset-y-0 w-1/4 skew-x-12 bg-gradient-to-r from-transparent via-white/10 to-transparent"
                      />
                    </div>

                    <div className="mt-4 grid gap-3 sm:grid-cols-3">
                      {[
                        { label: "Upload power", value: "500MB" },
                        { label: "Streaming", value: "HD quality" },
                        { label: "Social perks", value: "Boosts + reactions" },
                      ].map((item, index) => (
                        <motion.div
                          key={item.label}
                          initial={{ opacity: 0, y: 20 }}
                          animate={{ opacity: 1, y: 0 }}
                          transition={{ delay: 0.5 + index * 0.1 }}
                          whileHover={reduceMotion ? undefined : { scale: 1.03 }}
                          className="cursor-default rounded-[24px] border border-white/10 bg-[#0f1430]/76 px-4 py-4 backdrop-blur-sm"
                        >
                          <div className="text-xl font-black tracking-tight text-white">
                            {item.value}
                          </div>
                          <div className="mt-1 text-[11px] font-semibold uppercase tracking-[0.2em] text-white/52">
                            {item.label}
                          </div>
                        </motion.div>
                      ))}
                    </div>

                    <div className="absolute bottom-6 left-6 hidden items-center gap-3 rounded-2xl border border-white/15 bg-[#0f1430]/85 px-4 py-3 backdrop-blur-sm md:flex">
                      <div className="flex h-11 w-11 items-center justify-center rounded-2xl bg-[linear-gradient(135deg,#5865F2,#EB459E)]">
                        <Image src="/Flicko_icon.png" alt="Flicko" width={22} height={22} />
                      </div>
                      <div>
                        <div className="text-xs uppercase tracking-[0.2em] text-white/55">
                          Included
                        </div>
                        <div className="text-sm font-semibold text-white">
                          2 boosts and HD streaming
                        </div>
                      </div>
                    </div>
                  </div>
                </motion.div>
              </div>
            </div>
          </div>
        </div>
      </motion.section>

      <motion.section
        initial="hidden"
        whileInView="visible"
        viewport={{ once: true, margin: "-50px" }}
        variants={fadeInUp}
        id="plans"
        className="py-24 md:py-32"
      >
        <div className="mx-auto max-w-[1300px] px-6">
          <div className="mb-12 text-center">
            <motion.div
              initial={{ opacity: 0, y: 10 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              className="text-sm font-semibold uppercase tracking-[0.22em] text-white/55"
            >
              Pick Your Plan
            </motion.div>
            <motion.h2
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ delay: 0.1 }}
              className="mt-4 text-4xl font-black uppercase tracking-tight text-white md:text-6xl"
            >
              Two levels. Same Flicko soul.
            </motion.h2>
          </div>

          <motion.div variants={staggerContainer} className="grid gap-8 lg:grid-cols-2">
            {plans.map((plan) => (
              <PlanCard key={plan.name} plan={plan} reduceMotion={reduceMotion} />
            ))}
          </motion.div>
        </div>
      </motion.section>

      <motion.section
        initial="hidden"
        whileInView="visible"
        viewport={{ once: true, margin: "-50px" }}
        variants={staggerContainer}
        className="py-8 md:py-12"
      >
        <div className="mx-auto max-w-[1300px] px-6">
          <div className="grid gap-6 md:grid-cols-2 xl:grid-cols-3">
            {highlights.map((item) => {
              const Icon = item.icon;

              return (
                <motion.article
                  key={item.title}
                  variants={scaleIn}
                  whileHover={reduceMotion ? undefined : { y: -10, scale: 1.018 }}
                  className="group relative cursor-default overflow-hidden rounded-[32px] border border-white/12 bg-white/[0.06] p-6 shadow-[0_18px_40px_rgba(0,0,0,0.24)] backdrop-blur-[24px]"
                >
                  <motion.div
                    initial={{ opacity: 0 }}
                    whileHover={{ opacity: 1 }}
                    className={`pointer-events-none absolute inset-0 rounded-[32px] bg-gradient-to-br ${item.color} opacity-[0.07]`}
                  />

                  <motion.div
                    whileHover={{ rotate: [0, -15, 15, 0], scale: 1.15 }}
                    transition={{ duration: 0.5 }}
                    className={`relative mb-5 inline-flex rounded-2xl bg-gradient-to-br ${item.color} p-3 text-[#1a153a]`}
                  >
                    <Icon className="h-6 w-6" />
                  </motion.div>
                  <h3 className="relative text-2xl font-black uppercase tracking-tight text-white">
                    {item.title}
                  </h3>
                  <p className="relative mt-4 text-base leading-7 text-white/72">
                    {item.description}
                  </p>
                </motion.article>
              );
            })}
          </div>
        </div>
      </motion.section>

      <ImmersiveShowcase reduceMotion={reduceMotion} />

      {featureSections.map((section) => (
        <GlassFeatureSection key={section.title} section={section} />
      ))}

      <Marquee />

      <motion.section
        initial="hidden"
        whileInView="visible"
        viewport={{ once: true, margin: "-50px" }}
        variants={fadeInUp}
        id="compare"
        className="py-24 md:py-32"
      >
        <div className="mx-auto max-w-[1300px] px-6">
          <div className="mb-12 text-center">
            <div className="text-sm font-semibold uppercase tracking-[0.22em] text-white/55">
              Compare Plans
            </div>
            <h2 className="mt-4 text-4xl font-black uppercase tracking-tight text-white md:text-6xl">
              See what changes when you upgrade
            </h2>
          </div>

          <div className="overflow-hidden rounded-[56px] border border-white/15 bg-white/[0.08] shadow-[0_20px_40px_rgba(0,0,0,0.3)] backdrop-blur-[24px] md:rounded-[72px]">
            <div className="overflow-x-auto">
              <table className="min-w-full border-collapse">
                <thead>
                  <tr className="border-b border-white/10">
                    <th className="px-6 py-5 text-left text-xs font-semibold uppercase tracking-[0.24em] text-white/50">
                      Feature
                    </th>
                    <th className="px-6 py-5 text-center text-xs font-semibold uppercase tracking-[0.24em] text-white/50">
                      Flicko Basic
                    </th>
                    <th className="px-6 py-5 text-center text-xs font-semibold uppercase tracking-[0.24em] text-white">
                      Flicko Plus
                    </th>
                  </tr>
                </thead>
                <tbody>
                  {comparisonRows.map((row, index) => (
                    <motion.tr
                      key={row.label}
                      initial={{ opacity: 0, x: -20 }}
                      whileInView={{ opacity: 1, x: 0 }}
                      viewport={{ once: true }}
                      transition={{ delay: index * 0.04 }}
                      whileHover={{ backgroundColor: "rgba(255,255,255,0.03)" }}
                      className="border-b border-white/10 last:border-b-0"
                    >
                      <td className="px-6 py-4 text-sm font-medium text-white">{row.label}</td>
                      <td className="px-6 py-4 text-center">
                        <ComparisonCell value={row.basic} />
                      </td>
                      <td className="px-6 py-4 text-center">
                        <ComparisonCell value={row.plus} plus />
                      </td>
                    </motion.tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </motion.section>

      <motion.section
        initial="hidden"
        whileInView="visible"
        viewport={{ once: true, margin: "-50px" }}
        variants={fadeInUp}
        id="faq"
        className="py-24 md:py-32"
      >
        <div className="mx-auto max-w-[1100px] px-6">
          <div className="mb-10 text-center">
            <div className="text-sm font-semibold uppercase tracking-[0.22em] text-white/55">
              Questions?
            </div>
            <h2 className="mt-4 text-4xl font-black uppercase tracking-tight text-white md:text-6xl">
              Flicko Plus FAQ
            </h2>
          </div>

          <div className="mb-6 flex flex-wrap justify-center gap-3">
            {faqGroups.map((group) => (
              <motion.button
                key={group.label}
                type="button"
                whileHover={{ scale: 1.04 }}
                whileTap={{ scale: 0.97 }}
                onClick={() => {
                  setActiveFaqGroup(group.label);
                  setOpenFaq(group.items[0]?.question ?? "");
                }}
                className={`rounded-full px-4 py-2 text-sm font-semibold transition-all duration-200 ${
                  activeFaqGroup === group.label
                    ? "bg-white text-[#23272A]"
                    : "bg-white/[0.08] text-white hover:bg-white/14"
                }`}
              >
                {group.label}
              </motion.button>
            ))}
          </div>

          <AnimatePresence mode="wait">
            <motion.div
              key={activeFaqGroup}
              initial={{ opacity: 0, y: 16 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -16 }}
              transition={{ duration: 0.25 }}
              className="space-y-4 rounded-[48px] border border-white/12 bg-white/[0.06] p-5 shadow-[0_18px_40px_rgba(0,0,0,0.24)] backdrop-blur-[24px]"
            >
              {currentFaqGroup.items.map((item) => {
                const isOpen = openFaq === item.question;

                return (
                  <article
                    key={item.question}
                    className="overflow-hidden rounded-[28px] border border-white/10 bg-white/[0.05]"
                  >
                    <motion.button
                      type="button"
                      onClick={() => setOpenFaq(isOpen ? "" : item.question)}
                      whileHover={{ backgroundColor: "rgba(255,255,255,0.03)" }}
                      className="flex w-full items-center justify-between gap-6 px-6 py-5 text-left"
                    >
                      <span className="text-base font-semibold text-white">{item.question}</span>
                      <motion.span
                        animate={{ rotate: isOpen ? 180 : 0 }}
                        transition={{ duration: 0.3, type: "spring", stiffness: 300 }}
                        className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-white/10 text-white"
                      >
                        <ChevronDown className="h-5 w-5" />
                      </motion.span>
                    </motion.button>

                    <AnimatePresence initial={false}>
                      {isOpen ? (
                        <motion.div
                          initial={{ height: 0, opacity: 0 }}
                          animate={{ height: "auto", opacity: 1 }}
                          exit={{ height: 0, opacity: 0 }}
                          transition={{ duration: 0.3, ease: [0.25, 0.4, 0.25, 1] }}
                          className="overflow-hidden"
                        >
                          <div className="px-6 pb-6 text-sm leading-7 text-white/72">
                            {item.answer}
                          </div>
                        </motion.div>
                      ) : null}
                    </AnimatePresence>
                  </article>
                );
              })}
            </motion.div>
          </AnimatePresence>
        </div>
      </motion.section>

      <motion.section
        initial="hidden"
        whileInView="visible"
        viewport={{ once: true, margin: "-50px" }}
        variants={fadeInUp}
        className="relative overflow-hidden py-32 md:py-40"
        style={{ background: "#1a153a" }}
      >
        <div className="pointer-events-none absolute inset-0 overflow-hidden">
          {starDots.concat(starDots).map((star, index) => (
            <motion.div
              key={`cta-${index}`}
              animate={reduceMotion ? undefined : { opacity: [0.15, 0.45, 0.15], scale: [0.8, 1.2, 0.8] }}
              transition={
                reduceMotion
                  ? undefined
                  : {
                      duration: 2 + Math.random() * 3,
                      repeat: Infinity,
                      delay: index * 0.15,
                    }
              }
              className={`absolute rounded-full bg-white ${star.size}`}
              style={{
                top: star.top,
                left: `${(Number.parseFloat(star.left) + index * 3) % 100}%`,
              }}
            />
          ))}
        </div>

        <div className="pointer-events-none absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2">
          {[1, 2, 3].map((ring) => (
            <motion.div
              key={ring}
              animate={reduceMotion ? undefined : { scale: [1, 2.2, 1], opacity: [0.15, 0, 0.15] }}
              transition={
                reduceMotion
                  ? undefined
                  : {
                      duration: 4,
                      repeat: Infinity,
                      delay: ring * 1.3,
                      ease: "easeOut",
                    }
              }
              className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 rounded-full border border-[#5865F2]/30"
              style={{ width: 200 + ring * 80, height: 200 + ring * 80 }}
            />
          ))}
        </div>

        <div className="relative z-10 mx-auto max-w-[1400px] px-6 text-center">
          <h2 className="text-4xl font-black uppercase leading-[1.1] tracking-tight text-white md:text-6xl lg:text-8xl">
            You cannot scroll anymore. Better go plus.
          </h2>
          <p className="mx-auto mt-6 max-w-2xl text-lg leading-relaxed text-white/72">
            Keep the Flicko mood, then turn every message, stream, profile, and
            server into something that feels visibly upgraded.
          </p>
          <div className="mt-10">
            <MagneticButton
              href="#plans"
              reduceMotion={reduceMotion}
              className="rounded-full bg-white px-10 py-5 text-xl font-semibold text-[#23272A] shadow-2xl transition-all duration-300 hover:shadow-white/25"
            >
              Get Flicko Plus
            </MagneticButton>
          </div>
        </div>
      </motion.section>

      <motion.section
        initial="hidden"
        whileInView="visible"
        viewport={{ once: true, margin: "-50px" }}
        variants={fadeIn}
        className="relative overflow-hidden pb-16"
        style={{ background: "#1a153a" }}
      >
        <div className="relative h-[400px] w-full md:h-[500px] lg:h-[600px]">
          <Image
            src="/img-2.png"
            alt="Flicko characters"
            fill
            className="object-contain object-center"
            priority
          />
        </div>
      </motion.section>
    </div>
  );
}
