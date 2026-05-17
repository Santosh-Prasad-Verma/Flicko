"use client";

import Image from "next/image";
import Link from "next/link";
import { motion } from "framer-motion";
import {
  ArrowRight,
  BadgeCheck,
  BookOpen,
  Bot,
  Bug,
  Code2,
  DollarSign,
  ExternalLink,
  Gamepad2,
  Globe,
  HelpCircle,
  Layers3,
  Link2,
  Megaphone,
  Rocket,
  ShieldCheck,
  Sparkles,
  Users,
  Workflow,
  type LucideIcon,
} from "lucide-react";

const fadeInUp = {
  hidden: { opacity: 0, y: 60 },
  visible: {
    opacity: 1,
    y: 0,
    transition: { duration: 0.6, ease: [0.25, 0.4, 0.25, 1] as any },
  },
} as any;

const fadeIn = {
  hidden: { opacity: 0 },
  visible: {
    opacity: 1,
    transition: { duration: 0.8, ease: ("easeOut" as any) },
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
  hidden: { opacity: 0, scale: 0.92 },
  visible: {
    opacity: 1,
    scale: 1,
    transition: { duration: 0.6, ease: [0.25, 0.4, 0.25, 1] as any },
  },
} as any;

type Stat = {
  value: string;
  label: string;
  note: string;
  icon: LucideIcon;
  accent: string;
};

type Solution = {
  icon: LucideIcon;
  title: string;
  description: string;
  tag: string;
  footer: string;
  accent: string;
  glow: string;
  span: string;
};

type Track = {
  icon: LucideIcon;
  eyebrow: string;
  title: string;
  description: string;
  points: string[];
  accent: string;
};

type CaseStudy = {
  name: string;
  result: string;
  detail: string;
  color: string;
};

type Resource = {
  icon: LucideIcon;
  title: string;
  description: string;
  link: string;
  cta: string;
  accent: string;
};

type PlaybookStep = {
  icon: LucideIcon;
  title: string;
  description: string;
  points: string[];
  accent: string;
  glow: string;
};

type DeveloperQuestion = {
  question: string;
  answer: string;
  href: string;
  cta: string;
};

const starDots = [
  { top: "8%", left: "10%", size: "h-1.5 w-1.5", delay: "0s" },
  { top: "14%", left: "74%", size: "h-1 w-1", delay: "0.6s" },
  { top: "22%", left: "46%", size: "h-1.5 w-1.5", delay: "1.3s" },
  { top: "34%", left: "88%", size: "h-1 w-1", delay: "1.8s" },
  { top: "42%", left: "18%", size: "h-1 w-1", delay: "0.9s" },
  { top: "54%", left: "62%", size: "h-1.5 w-1.5", delay: "1.5s" },
  { top: "68%", left: "9%", size: "h-1 w-1", delay: "2.1s" },
  { top: "74%", left: "81%", size: "h-1 w-1", delay: "0.3s" },
  { top: "84%", left: "36%", size: "h-1.5 w-1.5", delay: "1.9s" },
  { top: "92%", left: "92%", size: "h-1 w-1", delay: "2.4s" },
];

const stats: Stat[] = [
  {
    value: "90M+",
    label: "Daily active users",
    note: "Players already hang out here before they launch your game.",
    icon: Users,
    accent: "text-[#8EA1FF]",
  },
  {
    value: "90%+",
    label: "Players actively gaming",
    note: "Flicko sits in the same flow as parties, streams, and squads.",
    icon: Gamepad2,
    accent: "text-[#57F287]",
  },
  {
    value: "~40%",
    label: "Start a game within an hour",
    note: "It is a strong moment to surface presence, identity, and offers.",
    icon: Rocket,
    accent: "text-[#FEE75C]",
  },
];

const solutions: Solution[] = [
  {
    icon: Link2,
    title: "Connect player identity to Flicko",
    description:
      "Link accounts, sync entitlements, and turn your game profile into a living social surface instead of an isolated login.",
    tag: "OAuth2, presence, account linking",
    footer: "Give players one identity layer across your game and their communities.",
    accent: "bg-[#5865F2]/15 text-[#B6C0FF]",
    glow: "from-[#5865F2]/30 via-[#5865F2]/8 to-transparent",
    span: "lg:col-span-7",
  },
  {
    icon: Globe,
    title: "Build official community hubs",
    description:
      "Create the place where your players gather, share clips, organize squads, and stay close to your studio between major beats.",
    tag: "Servers, moderation, retention",
    footer: "Move your community from scattered channels into one durable home base.",
    accent: "bg-[#57F287]/12 text-[#8BFFB8]",
    glow: "from-[#57F287]/22 via-[#57F287]/8 to-transparent",
    span: "lg:col-span-5",
  },
  {
    icon: DollarSign,
    title: "Monetize social moments",
    description:
      "Bring premium drops, subscriptions, and event access closer to the conversations where hype actually happens.",
    tag: "Commerce, drops, premium access",
    footer: "Treat community energy like a revenue channel instead of a side effect.",
    accent: "bg-[#EB459E]/15 text-[#FF9BD0]",
    glow: "from-[#EB459E]/24 via-[#EB459E]/8 to-transparent",
    span: "lg:col-span-5",
  },
  {
    icon: Megaphone,
    title: "Reach new players without cold-starting attention",
    description:
      "Use ads, quests, and activations to put your game in front of people who already spend their time with friends on Flicko.",
    tag: "Ads, quests, launches",
    footer: "Launch into an audience that is already in discovery mode with friends.",
    accent: "bg-[#FEE75C]/15 text-[#FFE987]",
    glow: "from-[#FEE75C]/20 via-[#FEE75C]/8 to-transparent",
    span: "lg:col-span-7",
  },
];

const tracks: Track[] = [
  {
    icon: Workflow,
    eyebrow: "Launch with the right layer first",
    title: "Start where player behavior is already visible",
    description:
      "Presence, linked identity, and social graph signals make the first integration feel native instead of bolted on.",
    points: [
      "Linked accounts that reduce friction",
      "Presence hooks for live game state",
      "Shared profile signals across community spaces",
    ],
    accent: "from-[#5865F2]/24 to-transparent",
  },
  {
    icon: Layers3,
    eyebrow: "Keep the community warm",
    title: "Turn every release into a longer conversation",
    description:
      "Patch notes, events, clips, and watch parties work better when the audience already has a place to react together.",
    points: [
      "Official spaces for squads and creators",
      "Announcements that meet players in context",
      "Retention loops that continue after launch day",
    ],
    accent: "from-[#57F287]/18 to-transparent",
  },
  {
    icon: ShieldCheck,
    eyebrow: "Scale without chaos",
    title: "Operate like a real platform team",
    description:
      "Support moderation, app management, documentation, and rollout surfaces that can grow with your studio.",
    points: [
      "Developer portal and application controls",
      "Documentation for faster iteration",
      "Support surfaces when teams need help shipping",
    ],
    accent: "from-[#EB459E]/18 to-transparent",
  },
];

const caseStudies: CaseStudy[] = [
  {
    name: "Marvel Rivals",
    result: "500K+ community members in the first week",
    detail: "Fast growth driven by launch energy, squad coordination, and social sharing.",
    color: "from-[#C73866] via-[#E9583A] to-[#F7A54A]",
  },
  {
    name: "Battlefield 6",
    result: "3x engagement over traditional channels",
    detail: "Players stayed in the loop because updates lived inside their social flow.",
    color: "from-[#1E8B6A] via-[#2CB67D] to-[#6BE4A7]",
  },
  {
    name: "Delta Force",
    result: "200K+ players driven through quests",
    detail: "Activation surfaces converted interest into actual participation.",
    color: "from-[#2F55E7] via-[#3D8BFF] to-[#66D5FF]",
  },
  {
    name: "Fortnite",
    result: "One of the largest gaming communities on Flicko",
    detail: "A flagship example of how persistent communities amplify every beat.",
    color: "from-[#6D38FF] via-[#9158FF] to-[#F15BB5]",
  },
  {
    name: "Valorant",
    result: "2M+ members and still expanding",
    detail: "Competitive energy compounds when squads, clips, and updates live together.",
    color: "from-[#D63A5E] via-[#F04E61] to-[#FF9A66]",
  },
  {
    name: "Minecraft",
    result: "A thriving modding and creator hub",
    detail: "Community creativity keeps the platform useful long after the first install.",
    color: "from-[#25A25A] via-[#62CB74] to-[#C7F36B]",
  },
];

const resources: Resource[] = [
  {
    icon: BookOpen,
    title: "Documentation",
    description:
      "API references, integration guides, and the implementation details your team needs to ship without guessing.",
    link: "#playbook",
    cta: "Read the playbook",
    accent: "bg-[#5865F2]/15 text-[#B6C0FF]",
  },
  {
    icon: Code2,
    title: "Developer Portal",
    description:
      "Create applications, manage bots, configure OAuth2, and keep your developer operations in one place.",
    link: "#playbook",
    cta: "Open the setup flow",
    accent: "bg-[#57F287]/12 text-[#8BFFB8]",
  },
  {
    icon: HelpCircle,
    title: "Support",
    description:
      "When your team hits edge cases, find answers quickly through support and developer help resources.",
    link: "/support",
    cta: "Get support",
    accent: "bg-[#EB459E]/15 text-[#FF9BD0]",
  },
];

const playbookSteps: PlaybookStep[] = [
  {
    icon: Code2,
    title: "Create the app surface first",
    description:
      "Set up your application, scopes, and ownership model before you start wiring game-side behavior.",
    points: [
      "Define your app identity and OAuth entry points",
      "Plan permissions and account-linking scopes early",
      "Keep launch ownership clear across product and backend teams",
    ],
    accent: "bg-[#5865F2]/15 text-[#B6C0FF]",
    glow: "from-[#5865F2]/28 via-[#5865F2]/10 to-transparent",
  },
  {
    icon: Workflow,
    title: "Ship presence and live state",
    description:
      "Presence is usually the first thing that makes the integration feel native to players instead of bolted on.",
    points: [
      "Model party state, joinability, and game context",
      "Expose live updates that make social play obvious",
      "Connect identity and activity into one player story",
    ],
    accent: "bg-[#57F287]/12 text-[#8BFFB8]",
    glow: "from-[#57F287]/22 via-[#57F287]/10 to-transparent",
  },
  {
    icon: Bot,
    title: "Activate communities around the game",
    description:
      "Once identity is in place, official communities, announcements, and events create the durable loop around the game.",
    points: [
      "Stand up a clear official hub for squads and updates",
      "Use events, posts, and activations to maintain momentum",
      "Bridge the game team and community team with shared surfaces",
    ],
    accent: "bg-[#EB459E]/15 text-[#FF9BD0]",
    glow: "from-[#EB459E]/24 via-[#EB459E]/10 to-transparent",
  },
  {
    icon: Bug,
    title: "Close the loop with support and QA",
    description:
      "A good developer launch includes the paths people need when things break, billing gets involved, or reports come in.",
    points: [
      "Route player-facing issues into support instead of the product page",
      "Keep policy, privacy, and billing links easy to reach",
      "Document repro steps and rollout checks before launch day",
    ],
    accent: "bg-[#FEE75C]/15 text-[#FFE987]",
    glow: "from-[#FEE75C]/20 via-[#FEE75C]/10 to-transparent",
  },
];

const developerQuestions: DeveloperQuestion[] = [
  {
    question: "Where should player-facing issues go?",
    answer:
      "Use the support route for account, billing, safety, and app issues so the developers page stays focused on builders.",
    href: "/support",
    cta: "Open support",
  },
  {
    question: "Where should teams begin the integration?",
    answer:
      "Start with app setup, OAuth, and presence before expanding into growth or monetization surfaces.",
    href: "#playbook",
    cta: "See the playbook",
  },
  {
    question: "What about privacy, billing, and policy coverage?",
    answer:
      "Keep privacy, terms, and premium support easy to reach so launch-day questions do not get lost in docs alone.",
    href: "/privacy",
    cta: "Read privacy",
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

export default function DevelopersPage() {
  return (
    <div className="min-h-screen w-full bg-[#1a153a] text-white">
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
          <div className="absolute left-[-8%] top-[14%] h-56 w-56 rounded-full bg-[#5865F2]/18 blur-2xl" />
          <div className="absolute right-[6%] top-[18%] h-64 w-64 rounded-full bg-[#EB459E]/12 blur-2xl" />
          <div className="absolute bottom-[8%] left-[28%] h-52 w-52 rounded-full bg-[#57F287]/8 blur-2xl" />
        </div>

        <div className="relative z-10 mx-auto max-w-[1400px] px-6 pt-32 pb-20 md:pb-24">
          <div className="flex flex-col items-start gap-12 lg:flex-row lg:items-center lg:gap-10">
            <motion.div variants={slideIn} className="flex-1 lg:max-w-[580px]">
              <motion.div
                variants={fadeInUp}
                className="mb-6 inline-flex items-center gap-2 rounded-full border border-white/15 bg-white/10 px-4 py-2 text-sm font-semibold uppercase tracking-[0.2em] text-white/90 backdrop-blur-sm"
              >
                <Code2 className="h-4 w-4" />
                For developers
              </motion.div>

              <motion.h1
                variants={fadeInUp}
                className="text-4xl font-black uppercase leading-[1.03] tracking-tight text-white md:text-5xl lg:text-6xl xl:text-7xl"
              >
                Build where players already hang out
              </motion.h1>

              <motion.p
                variants={fadeInUp}
                className="mt-8 max-w-2xl text-lg leading-relaxed text-white/80 md:text-xl lg:text-2xl"
              >
                Flicko is the social layer wrapped around games, group chats, clips, watch parties,
                and squad planning. Meet players where they already spend time together, then turn
                that attention into identity, community, and growth.
              </motion.p>

              <motion.div variants={scaleIn} className="mt-10 flex flex-col gap-4 sm:flex-row">
                <Link
                  href="#solutions"
                  className="inline-flex items-center justify-center rounded-full bg-white px-6 py-3.5 text-base font-semibold text-[#23272A] shadow-2xl transition-all duration-300 hover:-translate-y-1 hover:scale-105"
                >
                  Explore the platform
                </Link>
                <Link
                  href="#resources"
                  className="inline-flex items-center justify-center gap-2 rounded-full border border-white/15 bg-white/10 px-6 py-3.5 text-base font-semibold text-white backdrop-blur-sm transition-all duration-300 hover:-translate-y-1 hover:bg-white/14"
                >
                  <BookOpen className="h-4 w-4" />
                  Read resources
                </Link>
              </motion.div>

              <motion.div
                variants={fadeInUp}
                className="mt-12 grid gap-4 md:grid-cols-3"
              >
                {stats.map((stat) => (
                  <div
                    key={stat.label}
                    className="rounded-[28px] border border-white/10 bg-white/[0.06] p-5 shadow-[0_10px_30px_rgba(0,0,0,0.18)]"
                  >
                    <div
                      className={`mb-4 flex h-11 w-11 items-center justify-center rounded-2xl bg-white/10 ${stat.accent}`}
                    >
                      <stat.icon className="h-5 w-5" />
                    </div>
                    <div className="text-3xl font-black tracking-tight text-white">{stat.value}</div>
                    <div className="mt-1 text-sm font-semibold uppercase tracking-[0.18em] text-white/62">
                      {stat.label}
                    </div>
                    <p className="mt-3 text-sm leading-6 text-white/68">{stat.note}</p>
                  </div>
                ))}
              </motion.div>
            </motion.div>

            <motion.div variants={scaleIn} className="w-full flex-1">
              <div className="rounded-[44px] border border-white/12 bg-white/[0.06] p-4 shadow-[0_16px_48px_rgba(0,0,0,0.2)] backdrop-blur-md md:p-5">
                <div className="rounded-[34px] border border-white/10 bg-[#140f34]/90 p-4 md:p-5">
                  <div className="mb-4 flex flex-wrap gap-2">
                    {["OAuth2", "Activities", "Presence API", "Social graph"].map((chip) => (
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
                        alt="Flicko multi-device product preview"
                        fill
                        priority
                        className="object-cover object-center"
                      />
                    </div>

                    <div className="pointer-events-none absolute inset-0 bg-[linear-gradient(180deg,rgba(17,13,47,0.15),rgba(17,13,47,0.55))]" />

                    <div className="absolute right-4 top-4 rounded-[22px] border border-white/10 bg-[#120d32]/82 px-4 py-3 backdrop-blur-md">
                      <div className="text-[11px] font-semibold uppercase tracking-[0.2em] text-white/55">
                        Players linked
                      </div>
                      <div className="mt-1 text-3xl font-black tracking-tight text-white">18.4M</div>
                    </div>

                    <div className="absolute bottom-4 left-4 max-w-[280px] rounded-[24px] border border-white/10 bg-[#100c2d]/85 p-4 shadow-2xl backdrop-blur-md">
                      <div className="mb-3 flex items-center gap-2 text-[11px] font-semibold uppercase tracking-[0.22em] text-[#B6C0FF]">
                        <Sparkles className="h-3.5 w-3.5" />
                        Presence event
                      </div>
                      <div className="space-y-1 font-mono text-[12px] leading-5 text-white/78">
                        <div>POST /activity/presence</div>
                        <div>{'{'}</div>
                        <div className="pl-3">&quot;game&quot;: &quot;Squad Queue&quot;,</div>
                        <div className="pl-3">&quot;party_size&quot;: 3,</div>
                        <div className="pl-3">&quot;joinable&quot;: true</div>
                        <div>{'}'}</div>
                      </div>
                    </div>
                  </div>

                  <div className="mt-4 grid gap-3 sm:grid-cols-3">
                    {[
                      { label: "Live presence updates", value: "24M / day" },
                      { label: "Community events launched", value: "1.2K+" },
                      { label: "Player support surfaces", value: "Always on" },
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
        id="solutions"
        initial="hidden"
        whileInView="visible"
        viewport={{ once: true, margin: "-80px" }}
        variants={fadeIn}
        className="py-20 md:py-28"
      >
        <div className="mx-auto max-w-[1340px] px-6">
          <div className="rounded-[52px] border border-white/12 bg-white/[0.06] p-6 shadow-[0_14px_40px_rgba(0,0,0,0.18)] backdrop-blur-md md:rounded-[68px] md:p-8">
            <SectionHeader
              eyebrow="What you can build"
              title="Four ways to plug Flicko into your game business"
              description="From linked identity to community growth, Flicko gives studios multiple surfaces to reach players before, during, and after they play."
            />

            <motion.div
              variants={fadeInUp}
              className="mt-12 grid gap-4 lg:grid-cols-12"
            >
              {solutions.map((solution) => (
                <article
                  key={solution.title}
                  className={`group relative overflow-hidden rounded-[32px] border border-white/10 bg-[#140f34]/88 p-6 shadow-[0_12px_30px_rgba(0,0,0,0.18)] ${solution.span}`}
                >
                  <div className={`pointer-events-none absolute inset-0 bg-gradient-to-br ${solution.glow}`} />
                  <div className="relative z-10">
                    <div className="flex items-start justify-between gap-4">
                      <div
                        className={`flex h-12 w-12 items-center justify-center rounded-2xl ${solution.accent}`}
                      >
                        <solution.icon className="h-5 w-5" />
                      </div>
                      <span className="rounded-full border border-white/10 bg-white/[0.08] px-3 py-1 text-[11px] font-semibold uppercase tracking-[0.18em] text-white/62">
                        {solution.tag}
                      </span>
                    </div>

                    <h3 className="mt-8 max-w-xl text-2xl font-black uppercase leading-tight tracking-tight text-white">
                      {solution.title}
                    </h3>
                    <p className="mt-4 max-w-2xl text-base leading-7 text-white/72">
                      {solution.description}
                    </p>

                    <div className="mt-8 border-t border-white/10 pt-5 text-sm leading-6 text-white/64">
                      {solution.footer}
                    </div>

                    <div className="mt-6 inline-flex items-center gap-2 text-sm font-semibold text-white">
                      Learn more
                      <ArrowRight className="h-4 w-4 transition-transform duration-300 group-hover:translate-x-1" />
                    </div>
                  </div>
                </article>
              ))}
            </motion.div>
          </div>
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
          <div className="grid items-start gap-8 lg:grid-cols-[0.95fr_1.05fr]">
            <div className="rounded-[44px] border border-white/12 bg-white/[0.06] p-8 shadow-[0_14px_40px_rgba(0,0,0,0.18)] backdrop-blur-md md:p-10">
              <SectionHeader
                eyebrow="How teams usually start"
                title="Think in layers, not one big integration"
                description="The best rollouts start with a clear sequence. Ship identity and presence first, then expand into community, operations, and growth."
              />

              <div className="mt-10 rounded-[30px] border border-white/10 bg-[#130f31]/90 p-6">
                <div className="text-sm font-semibold uppercase tracking-[0.24em] text-white/55">
                  Recommended rollout
                </div>
                <div className="mt-5 space-y-4">
                  {[
                    "Ship linked identity and presence first.",
                    "Stand up the official community second.",
                    "Layer on monetization and growth after the base loop is working.",
                  ].map((item, index) => (
                    <div key={item} className="flex items-start gap-4">
                      <div className="mt-0.5 flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-white/10 text-sm font-black text-white">
                        {index + 1}
                      </div>
                      <p className="text-base leading-7 text-white/72">{item}</p>
                    </div>
                  ))}
                </div>
              </div>
            </div>

            <div className="space-y-4">
              {tracks.map((track) => (
                <article
                  key={track.title}
                  className="relative overflow-hidden rounded-[36px] border border-white/10 bg-white/[0.06] p-6 shadow-[0_12px_32px_rgba(0,0,0,0.18)] md:p-7"
                >
                  <div className={`pointer-events-none absolute inset-0 bg-gradient-to-br ${track.accent}`} />
                  <div className="relative z-10">
                    <div className="flex items-center gap-3">
                      <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-white/10 text-white">
                        <track.icon className="h-5 w-5" />
                      </div>
                      <div className="text-sm font-semibold uppercase tracking-[0.2em] text-white/55">
                        {track.eyebrow}
                      </div>
                    </div>

                    <h3 className="mt-5 text-2xl font-black uppercase leading-tight tracking-tight text-white">
                      {track.title}
                    </h3>
                    <p className="mt-4 text-base leading-7 text-white/72">{track.description}</p>

                    <div className="mt-6 grid gap-3 sm:grid-cols-3">
                      {track.points.map((point) => (
                        <div
                          key={point}
                          className="rounded-[22px] border border-white/10 bg-[#120d2e]/70 px-4 py-4 text-sm leading-6 text-white/72"
                        >
                          {point}
                        </div>
                      ))}
                    </div>
                  </div>
                </article>
              ))}
            </div>
          </div>
        </div>
      </motion.section>

      <motion.section
        id="playbook"
        initial="hidden"
        whileInView="visible"
        viewport={{ once: true, margin: "-80px" }}
        variants={fadeIn}
        className="py-20 md:py-28"
      >
        <div className="mx-auto max-w-[1340px] px-6">
          <div className="rounded-[52px] border border-white/12 bg-white/[0.06] p-6 shadow-[0_14px_40px_rgba(0,0,0,0.18)] backdrop-blur-md md:rounded-[68px] md:p-8">
            <SectionHeader
              eyebrow="Developer playbook"
              title="A clearer path from app setup to launch day"
              description="This fills the gap between high-level value props and actual execution. It gives teams a practical rollout shape instead of leaving the page to end at inspiration."
            />

            <motion.div variants={fadeInUp} className="mt-12 grid gap-4 md:grid-cols-2">
              {playbookSteps.map((step) => (
                <article
                  key={step.title}
                  className="group relative overflow-hidden rounded-[36px] border border-white/10 bg-[#140f34]/88 p-6 shadow-[0_12px_32px_rgba(0,0,0,0.18)]"
                >
                  <div className={`pointer-events-none absolute inset-0 bg-gradient-to-br ${step.glow}`} />
                  <div className="relative z-10">
                    <div className="flex items-start justify-between gap-4">
                      <div className={`flex h-12 w-12 items-center justify-center rounded-2xl ${step.accent}`}>
                        <step.icon className="h-5 w-5" />
                      </div>
                      <div className="rounded-full border border-white/10 bg-white/[0.08] px-3 py-1 text-[11px] font-semibold uppercase tracking-[0.18em] text-white/58">
                        Launch step
                      </div>
                    </div>

                    <h3 className="mt-8 text-2xl font-black uppercase leading-tight tracking-tight text-white">
                      {step.title}
                    </h3>
                    <p className="mt-4 text-base leading-7 text-white/72">{step.description}</p>

                    <div className="mt-6 space-y-3">
                      {step.points.map((point) => (
                        <div
                          key={point}
                          className="rounded-[22px] border border-white/10 bg-[#120d2e]/70 px-4 py-4 text-sm leading-6 text-white/74"
                        >
                          {point}
                        </div>
                      ))}
                    </div>
                  </div>
                </article>
              ))}
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
            eyebrow="Success stories"
            title="Proof that the platform can move real communities"
            description="Studios use Flicko to grow communities, activate players, and keep momentum alive between launches."
            align="center"
          />

          <motion.div variants={fadeInUp} className="mt-12 grid gap-4 md:grid-cols-2 xl:grid-cols-3">
            {caseStudies.map((study) => (
              <article
                key={study.name}
                className={`group relative overflow-hidden rounded-[32px] border border-white/10 bg-gradient-to-br p-6 shadow-[0_12px_30px_rgba(0,0,0,0.18)] ${study.color}`}
              >
                <div className="absolute inset-0 bg-[linear-gradient(180deg,rgba(11,10,30,0.12),rgba(11,10,30,0.5))]" />
                <div className="relative z-10 flex h-full min-h-[220px] flex-col justify-between">
                  <div>
                    <div className="inline-flex rounded-full border border-white/18 bg-white/10 px-3 py-1 text-[11px] font-semibold uppercase tracking-[0.18em] text-white/78">
                      Case study
                    </div>
                    <h3 className="mt-5 text-2xl font-black uppercase tracking-tight text-white">{study.name}</h3>
                    <p className="mt-3 max-w-sm text-base leading-7 text-white/88">{study.result}</p>
                  </div>

                  <div className="mt-8 flex items-end justify-between gap-4">
                    <p className="max-w-xs text-sm leading-6 text-white/76">{study.detail}</p>
                    <ArrowRight className="h-5 w-5 shrink-0 text-white transition-transform duration-300 group-hover:translate-x-1" />
                  </div>
                </div>
              </article>
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
          <div className="grid gap-8 lg:grid-cols-[1.05fr_0.95fr]">
            <div className="rounded-[44px] border border-white/12 bg-white/[0.06] p-8 shadow-[0_14px_40px_rgba(0,0,0,0.18)] backdrop-blur-md md:p-10">
              <SectionHeader
                eyebrow="Common developer questions"
                title="The links teams usually need before and after launch"
                description="This closes the page with actual navigation routes so builders are not stranded on a nice-looking page with nowhere to go."
              />

              <div className="mt-10 space-y-4">
                {developerQuestions.map((item) => (
                  <Link
                    key={item.question}
                    href={item.href}
                    className="group flex items-start justify-between gap-4 rounded-[28px] border border-white/10 bg-[#130f31]/90 px-5 py-5 transition-all duration-300 hover:-translate-y-0.5 hover:border-white/16"
                  >
                    <div>
                      <div className="text-lg font-black uppercase tracking-tight text-white">{item.question}</div>
                      <p className="mt-2 max-w-xl text-sm leading-6 text-white/68">{item.answer}</p>
                    </div>
                    <ArrowRight className="mt-1 h-5 w-5 shrink-0 text-white transition-transform duration-300 group-hover:translate-x-1" />
                  </Link>
                ))}
              </div>
            </div>

            <div className="space-y-4">
              <article className="rounded-[36px] border border-white/10 bg-white/[0.06] p-6 shadow-[0_12px_32px_rgba(0,0,0,0.18)]">
                <div className="flex items-center gap-3">
                  <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-[#5865F2]/16 text-[#B6C0FF]">
                    <BadgeCheck className="h-5 w-5" />
                  </div>
                  <div className="text-sm font-semibold uppercase tracking-[0.22em] text-white/55">
                    What this page covers
                  </div>
                </div>
                <div className="mt-6 space-y-3">
                  {[
                    "Product and platform value for game studios",
                    "Rollout guidance for identity, presence, and community",
                    "Real routes to docs, support, and policy pages",
                  ].map((line) => (
                    <div
                      key={line}
                      className="rounded-[22px] border border-white/10 bg-[#120d2e]/70 px-4 py-4 text-sm leading-6 text-white/74"
                    >
                      {line}
                    </div>
                  ))}
                </div>
              </article>

              <article className="rounded-[36px] border border-white/10 bg-white/[0.06] p-6 shadow-[0_12px_32px_rgba(0,0,0,0.18)]">
                <div className="flex items-center gap-3">
                  <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-[#57F287]/12 text-[#8BFFB8]">
                    <Sparkles className="h-5 w-5" />
                  </div>
                  <div className="text-sm font-semibold uppercase tracking-[0.22em] text-white/55">
                    Recommended next stop
                  </div>
                </div>

                <h3 className="mt-6 text-2xl font-black uppercase tracking-tight text-white">
                  Use support for operational issues, not the developer landing page
                </h3>
                <p className="mt-4 text-base leading-7 text-white/72">
                  Account, billing, safety, and app bugs now have a dedicated support route. That keeps this page focused on teams building on Flicko.
                </p>

                <Link
                  href="/support"
                  className="mt-8 inline-flex items-center gap-2 rounded-full border border-white/14 bg-white/10 px-5 py-3 text-sm font-semibold text-white transition-all duration-300 hover:-translate-y-0.5 hover:bg-white/14"
                >
                  Open support
                  <ExternalLink className="h-4 w-4" />
                </Link>
              </article>
            </div>
          </div>
        </div>
      </motion.section>

      <motion.section
        id="resources"
        initial="hidden"
        whileInView="visible"
        viewport={{ once: true, margin: "-80px" }}
        variants={fadeIn}
        className="pb-24 pt-4 md:pb-32"
      >
        <div className="mx-auto max-w-[1340px] px-6">
          <div className="rounded-[52px] border border-white/12 bg-white/[0.06] p-6 shadow-[0_14px_40px_rgba(0,0,0,0.18)] backdrop-blur-md md:rounded-[68px] md:p-8">
            <SectionHeader
              eyebrow="Developer resources"
              title="Everything your team needs to start shipping"
              description="Documentation, app controls, and support surfaces for teams that want to ship faster and scale cleanly."
            />

            <motion.div variants={fadeInUp} className="mt-12 grid gap-4 md:grid-cols-3">
              {resources.map((resource) => (
                <Link
                  key={resource.title}
                  href={resource.link}
                  className="group rounded-[32px] border border-white/10 bg-[#140f34]/88 p-6 shadow-[0_12px_30px_rgba(0,0,0,0.18)] transition-transform duration-300 hover:-translate-y-1"
                >
                  <div
                    className={`flex h-12 w-12 items-center justify-center rounded-2xl ${resource.accent}`}
                  >
                    <resource.icon className="h-5 w-5" />
                  </div>
                  <h3 className="mt-8 text-2xl font-black uppercase tracking-tight text-white">{resource.title}</h3>
                  <p className="mt-4 text-base leading-7 text-white/72">{resource.description}</p>
                  <div className="mt-8 inline-flex items-center gap-2 text-sm font-semibold text-white">
                    {resource.cta}
                    <ExternalLink className="h-4 w-4 transition-transform duration-300 group-hover:translate-x-1" />
                  </div>
                </Link>
              ))}
            </motion.div>

            <motion.div
              id="cta"
              variants={scaleIn}
              className="mt-8 overflow-hidden rounded-[40px] border border-white/12 bg-[linear-gradient(135deg,rgba(88,101,242,0.22),rgba(26,21,58,0.92),rgba(235,69,158,0.1))] p-8 shadow-[0_16px_48px_rgba(28,22,79,0.3)] md:p-10"
            >
              <div className="flex flex-col gap-8 lg:flex-row lg:items-end lg:justify-between">
                <div className="max-w-2xl">
                  <div className="mb-4 inline-flex items-center gap-2 rounded-full border border-white/14 bg-white/10 px-4 py-2 text-sm font-semibold uppercase tracking-[0.2em] text-white/86">
                    <Sparkles className="h-4 w-4" />
                    Ready to build
                  </div>
                  <h2 className="text-4xl font-black uppercase leading-[1.02] tracking-tight text-white md:text-5xl">
                    Bring your game closer to the players already talking about it
                  </h2>
                  <p className="mt-5 text-lg leading-relaxed text-white/78">
                    Start with the developer portal, explore the docs, and build the social layer
                    your players will actually use before, during, and after they play.
                  </p>
                </div>

                <div className="flex flex-col gap-3 sm:flex-row">
                  <Link
                    href="#playbook"
                    className="inline-flex items-center justify-center rounded-full bg-white px-6 py-3.5 text-base font-semibold text-[#23272A] transition-all duration-300 hover:-translate-y-1 hover:scale-105"
                  >
                    Open the playbook
                  </Link>
                  <Link
                    href="/support"
                    className="inline-flex items-center justify-center gap-2 rounded-full border border-white/14 bg-white/10 px-6 py-3.5 text-base font-semibold text-white transition-all duration-300 hover:-translate-y-1 hover:bg-white/14"
                  >
                    <Globe className="h-4 w-4" />
                    Developer support
                  </Link>
                </div>
              </div>
            </motion.div>
          </div>
        </div>
      </motion.section>
    </div>
  );
}
