"use client";

import Image from "next/image";
import Link from "next/link";
import { motion } from "framer-motion";
import {
  ArrowRight,
  BadgeCheck,
  Clock3,
  CreditCard,
  Download,
  ExternalLink,
  HelpCircle,
  Layers3,
  LifeBuoy,
  LockKeyhole,
  MessageSquare,
  Search,
  ShieldAlert,
  Sparkles,
  TriangleAlert,
  type LucideIcon,
} from "lucide-react";

const fadeInUp = {
  hidden: { opacity: 0, y: 60 },
  visible: {
    opacity: 1,
    y: 0,
    transition: { duration: 0.6, ease: [0.25, 0.4, 0.25, 1] },
  },
};

const fadeIn = {
  hidden: { opacity: 0 },
  visible: {
    opacity: 1,
    transition: { duration: 0.8, ease: "easeOut" },
  },
};

const slideIn = {
  hidden: { opacity: 0, x: -60 },
  visible: {
    opacity: 1,
    x: 0,
    transition: { duration: 0.7, ease: [0.25, 0.4, 0.25, 1] },
  },
};

const scaleIn = {
  hidden: { opacity: 0, scale: 0.92 },
  visible: {
    opacity: 1,
    scale: 1,
    transition: { duration: 0.6, ease: [0.25, 0.4, 0.25, 1] },
  },
};

type QuickAction = {
  icon: LucideIcon;
  title: string;
  description: string;
  href: string;
  accent: string;
  glow: string;
};

type SupportTrack = {
  id: string;
  icon: LucideIcon;
  eyebrow: string;
  title: string;
  description: string;
  points: string[];
  primary: { label: string; href: string };
  secondary?: { label: string; href: string };
  accent: string;
  glow: string;
};

type PopularAnswer = {
  title: string;
  description: string;
  href: string;
};

const starDots = [
  { top: "8%", left: "12%", size: "h-1.5 w-1.5", delay: "0s" },
  { top: "16%", left: "76%", size: "h-1 w-1", delay: "0.6s" },
  { top: "24%", left: "54%", size: "h-1.5 w-1.5", delay: "1.1s" },
  { top: "34%", left: "88%", size: "h-1 w-1", delay: "1.6s" },
  { top: "42%", left: "18%", size: "h-1 w-1", delay: "0.8s" },
  { top: "54%", left: "66%", size: "h-1.5 w-1.5", delay: "1.4s" },
  { top: "66%", left: "9%", size: "h-1 w-1", delay: "2.1s" },
  { top: "78%", left: "80%", size: "h-1 w-1", delay: "0.4s" },
  { top: "86%", left: "38%", size: "h-1.5 w-1.5", delay: "1.8s" },
  { top: "92%", left: "92%", size: "h-1 w-1", delay: "2.4s" },
];

const quickActions: QuickAction[] = [
  {
    icon: LockKeyhole,
    title: "Account & login help",
    description: "Password resets, 2FA issues, login codes, and account access problems.",
    href: "#account",
    accent: "bg-[#5865F2]/16 text-[#B6C0FF]",
    glow: "from-[#5865F2]/28 via-[#5865F2]/10 to-transparent",
  },
  {
    icon: CreditCard,
    title: "Billing & Flicko Plus",
    description: "Subscription renewals, gifts, refunds, payment methods, and plan questions.",
    href: "#billing",
    accent: "bg-[#EB459E]/16 text-[#FF9BD0]",
    glow: "from-[#EB459E]/24 via-[#EB459E]/10 to-transparent",
  },
  {
    icon: ShieldAlert,
    title: "Safety & reports",
    description: "Blocked users, abuse reports, privacy concerns, and safer space guidance.",
    href: "#safety",
    accent: "bg-[#FEE75C]/16 text-[#FFF1A8]",
    glow: "from-[#FEE75C]/22 via-[#FEE75C]/10 to-transparent",
  },
  {
    icon: Download,
    title: "App, install, and bugs",
    description: "Downloads, device setup, update issues, broken features, and performance bugs.",
    href: "#apps",
    accent: "bg-[#57F287]/14 text-[#9AF7B7]",
    glow: "from-[#57F287]/22 via-[#57F287]/10 to-transparent",
  },
];

const supportTracks: SupportTrack[] = [
  {
    id: "account",
    icon: LockKeyhole,
    eyebrow: "Access & identity",
    title: "Get back into your account without the usual maze",
    description:
      "Start here if the problem is tied to sign-in, verification, account ownership, or profile access.",
    points: [
      "Password reset and email mismatch help",
      "Two-factor authentication recovery steps",
      "Username, profile, and device session checks",
    ],
    primary: { label: "Review privacy details", href: "/privacy" },
    secondary: { label: "Read terms", href: "/terms" },
    accent: "bg-[#5865F2]/16 text-[#B6C0FF]",
    glow: "from-[#5865F2]/26 via-[#5865F2]/10 to-transparent",
  },
  {
    id: "billing",
    icon: CreditCard,
    eyebrow: "Payments & subscriptions",
    title: "Sort billing fast and get back to using Flicko Plus",
    description:
      "Use this path for plan upgrades, renewal issues, failed payments, gifts, and premium questions.",
    points: [
      "Subscription renewals and purchase troubleshooting",
      "Flicko Plus gifts, pricing, and premium perks",
      "Payment method and invoice-related questions",
    ],
    primary: { label: "Open Flicko Plus", href: "/flicko-pus" },
    secondary: { label: "Jump to billing answers", href: "#popular" },
    accent: "bg-[#EB459E]/16 text-[#FF9BD0]",
    glow: "from-[#EB459E]/24 via-[#EB459E]/10 to-transparent",
  },
  {
    id: "safety",
    icon: ShieldAlert,
    eyebrow: "Trust & safety",
    title: "Handle reports, harassment, and privacy concerns clearly",
    description:
      "This route is for abuse reports, unwanted contact, safety settings, and policy-related support.",
    points: [
      "Reporting harmful behavior and keeping records",
      "Privacy and visibility controls across Flicko",
      "Policy links and safer communication guidance",
    ],
    primary: { label: "Read privacy policy", href: "/privacy" },
    secondary: { label: "Review terms", href: "/terms" },
    accent: "bg-[#FEE75C]/16 text-[#FFF1A8]",
    glow: "from-[#FEE75C]/22 via-[#FEE75C]/10 to-transparent",
  },
  {
    id: "apps",
    icon: Download,
    eyebrow: "Apps & platform issues",
    title: "Fix install problems, device issues, and weird bugs",
    description:
      "Use this section when the app will not install, update correctly, or behave the way it should.",
    points: [
      "Desktop and mobile setup guidance",
      "Update loops, crashes, and stuck launches",
      "Performance problems and reproducible bugs",
    ],
    primary: { label: "See developer resources", href: "/developers" },
    secondary: { label: "Go back to top", href: "#top" },
    accent: "bg-[#57F287]/14 text-[#9AF7B7]",
    glow: "from-[#57F287]/22 via-[#57F287]/10 to-transparent",
  },
];

const popularAnswers: PopularAnswer[] = [
  {
    title: "Why can’t I log into Flicko?",
    description: "Start with account recovery, device session cleanup, and email verification checks.",
    href: "#account",
  },
  {
    title: "How do I manage Flicko Plus billing?",
    description: "Review active plans, renewals, gift issues, and payment troubleshooting.",
    href: "#billing",
  },
  {
    title: "Where do I report unsafe behavior?",
    description: "Use the safety route for harmful behavior, privacy concerns, and reporting guidance.",
    href: "#safety",
  },
  {
    title: "The app won’t install or update",
    description: "Use the app help path for download, update, and performance issues.",
    href: "#apps",
  },
];

function SectionHeader({
  eyebrow,
  title,
  description,
  align = "left",
}: {
  eyebrow: string;
  title: string;
  description: string;
  align?: "left" | "center";
}) {
  const alignment = align === "center" ? "mx-auto max-w-2xl text-center" : "max-w-2xl";

  return (
    <motion.div variants={fadeInUp} className={alignment}>
      <div className="mb-4 text-sm font-semibold uppercase tracking-[0.24em] text-white/55">{eyebrow}</div>
      <h2 className="text-4xl font-black uppercase leading-[1.02] tracking-tight text-white md:text-5xl">
        {title}
      </h2>
      <p className="mt-5 text-lg leading-relaxed text-white/72">{description}</p>
    </motion.div>
  );
}

export default function SupportPage() {
  return (
    <div id="top" className="min-h-screen w-full bg-[#1a153a] text-white">
      <motion.section
        initial="hidden"
        animate="visible"
        variants={fadeIn}
        className="relative overflow-hidden"
        style={{ background: "#1a153a" }}
      >
        <div className="pointer-events-none absolute inset-0 overflow-hidden">
          {starDots.map((star) => (
            <div
              key={`${star.top}-${star.left}`}
              className={`absolute rounded-full bg-white/35 animate-pulse ${star.size}`}
              style={{ top: star.top, left: star.left, animationDelay: star.delay }}
            />
          ))}
        </div>

        <div className="pointer-events-none absolute inset-0 overflow-hidden">
          <div className="absolute left-[-8%] top-[14%] h-72 w-72 rounded-full bg-[#5865F2]/26 blur-3xl" />
          <div className="absolute right-[4%] top-[16%] h-80 w-80 rounded-full bg-[#EB459E]/16 blur-3xl" />
          <div className="absolute bottom-[8%] left-[28%] h-72 w-72 rounded-full bg-[#57F287]/10 blur-3xl" />
        </div>

        <div className="relative z-10 mx-auto max-w-[1400px] px-6 pt-32 pb-20 md:pb-24">
          <div className="flex flex-col gap-12 lg:flex-row lg:items-center lg:gap-10">
            <motion.div variants={slideIn} className="flex-1 lg:max-w-[600px]">
              <motion.div
                variants={fadeInUp}
                className="mb-6 inline-flex items-center gap-2 rounded-full border border-white/15 bg-white/10 px-4 py-2 text-sm font-semibold uppercase tracking-[0.2em] text-white/90 backdrop-blur-sm"
              >
                <LifeBuoy className="h-4 w-4" />
                Support
              </motion.div>

              <motion.h1
                variants={fadeInUp}
                className="text-4xl font-black uppercase leading-[1.03] tracking-tight text-white md:text-5xl lg:text-6xl xl:text-7xl"
              >
                Support that gets you back into Flicko fast
              </motion.h1>

              <motion.p
                variants={fadeInUp}
                className="mt-8 max-w-2xl text-lg leading-relaxed text-white/80 md:text-xl lg:text-2xl"
              >
                Start with the route that matches your issue. This page is built to feel like the
                rest of Flicko, but work like an actual help hub instead of a dead footer link.
              </motion.p>

              <motion.div
                variants={scaleIn}
                className="mt-10 rounded-[32px] border border-white/15 bg-white/[0.08] p-4 shadow-[0_20px_60px_rgba(0,0,0,0.24)] backdrop-blur-[24px]"
              >
                <div className="flex items-center gap-3 rounded-[24px] border border-white/10 bg-[#130f31]/88 px-4 py-4">
                  <Search className="h-5 w-5 text-white/60" />
                  <div className="text-sm text-white/72">Search help topics: login, billing, safety, installs...</div>
                </div>
                <div className="mt-4 flex flex-wrap gap-3">
                  {[
                    { label: "Account access", href: "#account" },
                    { label: "Flicko Plus billing", href: "#billing" },
                    { label: "Safety reports", href: "#safety" },
                    { label: "App bugs", href: "#apps" },
                  ].map((item) => (
                    <Link
                      key={item.label}
                      href={item.href}
                      className="rounded-full border border-white/10 bg-white/[0.08] px-4 py-2 text-sm font-semibold text-white/86 transition-all duration-300 hover:-translate-y-0.5 hover:bg-white/[0.12]"
                    >
                      {item.label}
                    </Link>
                  ))}
                </div>
              </motion.div>

              <motion.div variants={fadeInUp} className="mt-10 flex flex-wrap gap-3">
                {[
                  { icon: BadgeCheck, label: "System status: green" },
                  { icon: Clock3, label: "Self-serve answers first" },
                  { icon: Sparkles, label: "Billing and Plus help included" },
                ].map((item) => (
                  <div
                    key={item.label}
                    className="inline-flex items-center gap-2 rounded-full border border-white/12 bg-white/[0.06] px-4 py-2 text-sm font-semibold text-white/82"
                  >
                    <item.icon className="h-4 w-4" />
                    {item.label}
                  </div>
                ))}
              </motion.div>
            </motion.div>

            <motion.div variants={scaleIn} className="flex-1">
              <div className="rounded-[44px] border border-white/15 bg-white/[0.08] p-4 shadow-[0_28px_90px_rgba(0,0,0,0.28)] backdrop-blur-[26px] md:p-5">
                <div className="rounded-[34px] border border-white/10 bg-[#140f34]/90 p-4 md:p-5">
                  <div className="mb-4 flex flex-wrap gap-2">
                    {["Account help", "Billing", "Safety", "App issues"].map((chip) => (
                      <span
                        key={chip}
                        className="rounded-full border border-white/10 bg-white/[0.08] px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.18em] text-white/72"
                      >
                        {chip}
                      </span>
                    ))}
                  </div>

                  <div className="relative overflow-hidden rounded-[28px] border border-white/10 bg-[#1b1550]">
                    <div className="relative aspect-[1.12/1] w-full md:aspect-[1.24/1]">
                      <Image
                        src="/hero.png"
                        alt="Flicko product support preview"
                        fill
                        priority
                        className="object-cover object-center"
                      />
                    </div>

                    <div className="pointer-events-none absolute inset-0 bg-[linear-gradient(180deg,rgba(17,13,47,0.08),rgba(17,13,47,0.6))]" />

                    <div className="absolute right-4 top-4 rounded-[22px] border border-white/10 bg-[#120d32]/82 px-4 py-3 backdrop-blur-md">
                      <div className="text-[11px] font-semibold uppercase tracking-[0.2em] text-white/55">
                        Fast route
                      </div>
                      <div className="mt-1 text-lg font-black tracking-tight text-white">Pick the right issue path</div>
                    </div>

                    <div className="absolute bottom-4 left-4 max-w-[320px] rounded-[24px] border border-white/10 bg-[#100c2d]/85 p-4 shadow-2xl backdrop-blur-md">
                      <div className="mb-3 flex items-center gap-2 text-[11px] font-semibold uppercase tracking-[0.22em] text-[#B6C0FF]">
                        <Sparkles className="h-3.5 w-3.5" />
                        Support flow
                      </div>
                      <div className="space-y-2 text-sm leading-6 text-white/78">
                        <div>1. Choose your issue type</div>
                        <div>2. Start with the most likely fix</div>
                        <div>3. Jump to policy, billing, or app help when needed</div>
                      </div>
                    </div>
                  </div>

                  <div className="mt-4 grid gap-3 sm:grid-cols-3">
                    {[
                      { label: "System status", value: "Operational" },
                      { label: "Best route", value: "Self-serve first" },
                      { label: "Premium help", value: "Flicko Plus ready" },
                    ].map((item) => (
                      <div
                        key={item.label}
                        className="rounded-[22px] border border-white/10 bg-white/[0.05] px-4 py-4"
                      >
                        <div className="text-xl font-black tracking-tight text-white">{item.value}</div>
                        <div className="mt-1 text-sm text-white/62">{item.label}</div>
                      </div>
                    ))}
                  </div>
                </div>
              </div>
            </motion.div>
          </div>
        </div>
      </motion.section>

      <motion.section
        initial="hidden"
        whileInView="visible"
        viewport={{ once: true, margin: "-80px" }}
        variants={fadeIn}
        className="py-20 md:py-28"
      >
        <div className="mx-auto max-w-[1340px] px-6">
          <SectionHeader
            eyebrow="Quick routes"
            title="Start with the part that matches your problem"
            description="These cards exist to keep users from hunting through random footer links. Pick the closest match and move straight into the right support lane."
            align="center"
          />

          <motion.div variants={fadeInUp} className="mt-12 grid gap-4 md:grid-cols-2 xl:grid-cols-4">
            {quickActions.map((item) => (
              <Link
                key={item.title}
                href={item.href}
                className="group relative overflow-hidden rounded-[32px] border border-white/12 bg-[#140f34]/88 p-6 shadow-[0_18px_48px_rgba(0,0,0,0.22)] transition-transform duration-300 hover:-translate-y-1"
              >
                <div className={`pointer-events-none absolute inset-0 bg-gradient-to-br ${item.glow}`} />
                <div className="relative z-10">
                  <div className={`flex h-12 w-12 items-center justify-center rounded-2xl ${item.accent}`}>
                    <item.icon className="h-5 w-5" />
                  </div>
                  <h3 className="mt-8 text-2xl font-black uppercase tracking-tight text-white">{item.title}</h3>
                  <p className="mt-4 text-base leading-7 text-white/72">{item.description}</p>
                  <div className="mt-8 inline-flex items-center gap-2 text-sm font-semibold text-white">
                    Open route
                    <ArrowRight className="h-4 w-4 transition-transform duration-300 group-hover:translate-x-1" />
                  </div>
                </div>
              </Link>
            ))}
          </motion.div>
        </div>
      </motion.section>

      <motion.section
        initial="hidden"
        whileInView="visible"
        viewport={{ once: true, margin: "-80px" }}
        variants={fadeIn}
        className="py-4 md:py-8"
      >
        <div className="mx-auto max-w-[1340px] px-6">
          <div className="grid gap-4 lg:grid-cols-2">
            {supportTracks.map((track) => (
              <motion.article
                key={track.id}
                id={track.id}
                variants={scaleIn}
                className="relative overflow-hidden rounded-[40px] border border-white/12 bg-white/[0.08] p-7 shadow-[0_18px_48px_rgba(0,0,0,0.22)] backdrop-blur-[24px] md:p-8"
              >
                <div className={`pointer-events-none absolute inset-0 bg-gradient-to-br ${track.glow}`} />
                <div className="relative z-10">
                  <div className="flex items-center gap-3">
                    <div className={`flex h-12 w-12 items-center justify-center rounded-2xl ${track.accent}`}>
                      <track.icon className="h-5 w-5" />
                    </div>
                    <div className="text-sm font-semibold uppercase tracking-[0.22em] text-white/55">
                      {track.eyebrow}
                    </div>
                  </div>

                  <h3 className="mt-6 text-3xl font-black uppercase leading-tight tracking-tight text-white">
                    {track.title}
                  </h3>
                  <p className="mt-4 text-base leading-7 text-white/72">{track.description}</p>

                  <div className="mt-8 grid gap-3">
                    {track.points.map((point) => (
                      <div
                        key={point}
                        className="rounded-[22px] border border-white/10 bg-[#120d2e]/70 px-4 py-4 text-sm leading-6 text-white/74"
                      >
                        {point}
                      </div>
                    ))}
                  </div>

                  <div className="mt-8 flex flex-wrap gap-3">
                    <Link
                      href={track.primary.href}
                      className="inline-flex items-center justify-center rounded-full bg-white px-5 py-3 text-sm font-semibold text-[#23272A] transition-all duration-300 hover:-translate-y-0.5"
                    >
                      {track.primary.label}
                    </Link>
                    {track.secondary ? (
                      <Link
                        href={track.secondary.href}
                        className="inline-flex items-center justify-center rounded-full border border-white/14 bg-white/10 px-5 py-3 text-sm font-semibold text-white transition-all duration-300 hover:-translate-y-0.5 hover:bg-white/14"
                      >
                        {track.secondary.label}
                      </Link>
                    ) : null}
                  </div>
                </div>
              </motion.article>
            ))}
          </div>
        </div>
      </motion.section>

      <motion.section
        initial="hidden"
        whileInView="visible"
        viewport={{ once: true, margin: "-80px" }}
        variants={fadeIn}
        className="py-20 md:py-28"
      >
        <div className="mx-auto max-w-[1340px] px-6">
          <div className="grid gap-8 lg:grid-cols-[1.1fr_0.9fr]">
            <div id="popular" className="rounded-[44px] border border-white/14 bg-white/[0.08] p-8 shadow-[0_20px_60px_rgba(0,0,0,0.2)] backdrop-blur-[24px] md:p-10">
              <SectionHeader
                eyebrow="Popular answers"
                title="Most common issues, without the noise"
                description="These are the places most people need first when they open a support page."
              />

              <div className="mt-10 space-y-4">
                {popularAnswers.map((item) => (
                  <Link
                    key={item.title}
                    href={item.href}
                    className="group flex items-start justify-between gap-4 rounded-[28px] border border-white/10 bg-[#130f31]/90 px-5 py-5 transition-all duration-300 hover:-translate-y-0.5 hover:border-white/16"
                  >
                    <div>
                      <div className="text-lg font-black uppercase tracking-tight text-white">{item.title}</div>
                      <p className="mt-2 max-w-xl text-sm leading-6 text-white/68">{item.description}</p>
                    </div>
                    <ArrowRight className="mt-1 h-5 w-5 shrink-0 text-white transition-transform duration-300 group-hover:translate-x-1" />
                  </Link>
                ))}
              </div>
            </div>

            <div className="space-y-4">
              <motion.article
                variants={scaleIn}
                className="rounded-[36px] border border-white/12 bg-white/[0.08] p-6 shadow-[0_18px_48px_rgba(0,0,0,0.22)] backdrop-blur-[24px]"
              >
                <div className="flex items-center gap-3">
                  <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-[#57F287]/14 text-[#9AF7B7]">
                    <BadgeCheck className="h-5 w-5" />
                  </div>
                  <div className="text-sm font-semibold uppercase tracking-[0.22em] text-white/55">
                    Platform status
                  </div>
                </div>
                <h3 className="mt-6 text-2xl font-black uppercase tracking-tight text-white">Everything looks operational</h3>
                <p className="mt-4 text-base leading-7 text-white/72">
                  If your issue is isolated to your account, billing, or device, use the support lanes above instead of waiting on a generic status page.
                </p>
              </motion.article>

              <motion.article
                variants={scaleIn}
                className="rounded-[36px] border border-white/12 bg-white/[0.08] p-6 shadow-[0_18px_48px_rgba(0,0,0,0.22)] backdrop-blur-[24px]"
              >
                <div className="flex items-center gap-3">
                  <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-[#FEE75C]/16 text-[#FFF1A8]">
                    <TriangleAlert className="h-5 w-5" />
                  </div>
                  <div className="text-sm font-semibold uppercase tracking-[0.22em] text-white/55">
                    Good next steps
                  </div>
                </div>
                <div className="mt-6 space-y-3">
                  {[
                    "Use the route that matches your issue instead of scrolling everything.",
                    "Check the related policy or billing page if your question is account-wide.",
                    "If you are a builder, jump to the developer page instead of consumer support.",
                  ].map((line) => (
                    <div
                      key={line}
                      className="rounded-[22px] border border-white/10 bg-[#120d2e]/70 px-4 py-4 text-sm leading-6 text-white/74"
                    >
                      {line}
                    </div>
                  ))}
                </div>
              </motion.article>

              <motion.article
                variants={scaleIn}
                className="rounded-[36px] border border-white/12 bg-white/[0.08] p-6 shadow-[0_18px_48px_rgba(0,0,0,0.22)] backdrop-blur-[24px]"
              >
                <div className="flex items-center gap-3">
                  <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-[#5865F2]/16 text-[#B6C0FF]">
                    <ExternalLink className="h-5 w-5" />
                  </div>
                  <div className="text-sm font-semibold uppercase tracking-[0.22em] text-white/55">
                    Related resources
                  </div>
                </div>

                <div className="mt-6 grid gap-3">
                  {[
                    { label: "Privacy", href: "/privacy", icon: HelpCircle },
                    { label: "Terms", href: "/terms", icon: Layers3 },
                    { label: "Developers", href: "/developers", icon: MessageSquare },
                  ].map((item) => (
                    <Link
                      key={item.label}
                      href={item.href}
                      className="group flex items-center justify-between rounded-[22px] border border-white/10 bg-[#120d2e]/70 px-4 py-4 text-sm font-semibold text-white/82 transition-all duration-300 hover:-translate-y-0.5"
                    >
                      <span className="flex items-center gap-3">
                        <item.icon className="h-4 w-4" />
                        {item.label}
                      </span>
                      <ArrowRight className="h-4 w-4 transition-transform duration-300 group-hover:translate-x-1" />
                    </Link>
                  ))}
                </div>
              </motion.article>
            </div>
          </div>
        </div>
      </motion.section>

      <motion.section
        initial="hidden"
        whileInView="visible"
        viewport={{ once: true, margin: "-80px" }}
        variants={fadeIn}
        className="pb-16 pt-4 md:pb-24"
      >
        <div className="mx-auto max-w-[1340px] px-6">
          <motion.div
            variants={scaleIn}
            className="overflow-hidden rounded-[40px] border border-white/14 bg-[linear-gradient(135deg,rgba(88,101,242,0.3),rgba(26,21,58,0.92),rgba(235,69,158,0.14))] p-8 shadow-[0_24px_80px_rgba(28,22,79,0.45)] md:p-10"
          >
            <div className="flex flex-col gap-8 lg:flex-row lg:items-end lg:justify-between">
              <div className="max-w-2xl">
                <div className="mb-4 inline-flex items-center gap-2 rounded-full border border-white/14 bg-white/10 px-4 py-2 text-sm font-semibold uppercase tracking-[0.2em] text-white/86">
                  <Sparkles className="h-4 w-4" />
                  Need another path
                </div>
                <h2 className="text-4xl font-black uppercase leading-[1.02] tracking-tight text-white md:text-5xl">
                  Start where the issue actually lives
                </h2>
                <p className="mt-5 text-lg leading-relaxed text-white/78">
                  Billing belongs in billing, policy questions belong in privacy and terms, and builder issues belong in developers. This page gives each one a clearer route from the footer.
                </p>
              </div>

              <div className="flex flex-col gap-3 sm:flex-row">
                <Link
                  href="#billing"
                  className="inline-flex items-center justify-center rounded-full bg-white px-6 py-3.5 text-base font-semibold text-[#23272A] transition-all duration-300 hover:-translate-y-1 hover:scale-105"
                >
                  Open billing help
                </Link>
                <Link
                  href="/developers"
                  className="inline-flex items-center justify-center gap-2 rounded-full border border-white/14 bg-white/10 px-6 py-3.5 text-base font-semibold text-white transition-all duration-300 hover:-translate-y-1 hover:bg-white/14"
                >
                  <ExternalLink className="h-4 w-4" />
                  Developer support
                </Link>
              </div>
            </div>
          </motion.div>

          <div className="relative mt-12 h-[280px] w-full md:h-[360px] lg:h-[440px]">
            <Image
              src="/img-2.png"
              alt="Flicko characters"
              fill
              className="object-contain object-center"
              priority
            />
          </div>
        </div>
      </motion.section>
    </div>
  );
}
