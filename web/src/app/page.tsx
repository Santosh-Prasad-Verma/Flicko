"use client";

import { Download, Globe } from "lucide-react";
import Link from "next/link";
import Image from "next/image";
import { useState, useEffect } from "react";
import { motion } from "framer-motion";

// Animation variants
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
  hidden: { opacity: 0, scale: 0.9 },
  visible: {
    opacity: 1,
    scale: 1,
    transition: { duration: 0.6, ease: [0.25, 0.4, 0.25, 1] as any },
  },
} as any;

// OS Detection
function getOS(): { name: string; downloadText: string } {
  if (typeof window === "undefined") {
    return { name: "Windows", downloadText: "Download for Windows" };
  }
  const userAgent = window.navigator.userAgent.toLowerCase();
  const platform = window.navigator.platform.toLowerCase();
  if (userAgent.includes("mac") || platform.includes("mac")) {
    return { name: "macOS", downloadText: "Download for macOS" };
  }
  if (userAgent.includes("linux") || platform.includes("linux")) {
    return { name: "Linux", downloadText: "Download for Linux" };
  }
  if (userAgent.includes("android")) {
    return { name: "Android", downloadText: "Download for Android" };
  }
  if (userAgent.includes("iphone") || userAgent.includes("ipad")) {
    return { name: "iOS", downloadText: "Download for iOS" };
  }
  return { name: "Windows", downloadText: "Download for Windows" };
}

function DownloadButton({ className }: { className?: string }) {
  const [downloadText, setDownloadText] = useState("Download");
  useEffect(() => {
    const os = getOS();
    setDownloadText(os.downloadText);
  }, []);
  return (
    <Link href="#" className={className}>
      <Download size={20} />
      {downloadText}
    </Link>
  );
}

// Marquee Component with Flicko Icons - Liquid Glass Effect
function Marquee() {
  const words = ["hang out", "talk", "play", "chat"];
  
  return (
    <div 
      className="py-12 md:py-16 overflow-hidden relative"
      style={{
        background: '#1a153a',
      }}
    >
      {/* Liquid Glass Background Effect */}
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <div 
          className="absolute top-1/4 left-1/4 w-96 h-96 rounded-full blur-3xl opacity-30"
          style={{ background: 'radial-gradient(circle, rgba(88,101,242,0.6) 0%, transparent 70%)' }}
        />
        <div 
          className="absolute bottom-1/4 right-1/4 w-80 h-80 rounded-full blur-3xl opacity-20"
          style={{ background: 'radial-gradient(circle, rgba(235,69,158,0.5) 0%, transparent 70%)' }}
        />
        <div 
          className="absolute top-1/2 left-1/2 w-64 h-64 rounded-full blur-3xl opacity-25"
          style={{ background: 'radial-gradient(circle, rgba(87,242,135,0.4) 0%, transparent 70%)' }}
        />
      </div>
      
      {/* Glassmorphism Overlay */}
      <div 
        className="absolute inset-0 backdrop-blur-sm"
        style={{ background: 'rgba(26, 21, 58, 0.3)' }}
      />
      
      <div className="flex animate-marquee whitespace-nowrap relative z-10">
        {[...Array(12)].map((_, i) => (
          <div key={i} className="flex items-center">
            {/* Flicko Icon */}
            <div className="flex items-center mx-8 md:mx-12">
              <img 
                src="/Flicko_icon.png" 
                alt="Flicko" 
                className="w-16 h-16 md:w-20 md:h-20 lg:w-24 lg:h-24 rounded-2xl shadow-2xl"
                style={{
                  boxShadow: '0 8px 32px rgba(88, 101, 242, 0.4), 0 0 0 4px rgba(255,255,255,0.1)',
                }}
              />
            </div>
            {/* Words */}
            {words.map((word, j) => (
              <span 
                key={j} 
                className="text-4xl md:text-6xl lg:text-7xl font-black text-white/40 uppercase tracking-tight mx-6 md:mx-8"
              >
                {word}
              </span>
            ))}
          </div>
        ))}
      </div>
    </div>
  );
}

// Hero Section Component - Discord Style Landing with Framer Motion
function HeroSection() {
  return (
    <motion.section 
      initial="hidden"
      animate="visible"
      variants={fadeIn}
      className="relative min-h-screen overflow-hidden w-full"
      style={{ background: '#1a153a' }}
    >
      {/* Stars Background */}
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        {[...Array(20)].map((_, i) => (
          <motion.div
            key={i}
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: i * 0.1, duration: 0.5 }}
            className="absolute w-1 h-1 bg-white/30 rounded-full animate-pulse"
            style={{
              top: `${Math.random() * 60}%`,
              left: `${Math.random() * 100}%`,
              animationDelay: `${Math.random() * 3}s`,
            }}
          />
        ))}
      </div>

      {/* Main Content */}
      <div className="relative z-10 max-w-[1400px] mx-auto px-6 pt-32 pb-20">
        <div className="flex flex-col lg:flex-row items-center gap-12 lg:gap-8">
          {/* Left Content */}
          <motion.div 
            variants={slideIn}
            className="flex-1 text-left lg:max-w-[500px]"
          >
            <motion.h1 
              variants={fadeInUp}
              className="text-4xl md:text-5xl lg:text-6xl xl:text-7xl font-black text-white leading-[1.05] mb-8 uppercase tracking-tight"
            >
              GROUP CHAT<br />
              THAT&apos;S ALL<br />
              FUN & GAMES
            </motion.h1>
            <motion.p 
              variants={fadeInUp}
              className="text-lg md:text-xl lg:text-2xl text-white/80 mb-10 leading-relaxed max-w-lg"
            >
              Flicko is great for playing games and chilling with friends, or even building a worldwide community. Customize your own space to talk, play, and hang out.
            </motion.p>
            
            <motion.div 
              variants={scaleIn}
              className="flex flex-col sm:flex-row items-start gap-4"
            >
              <DownloadButton className="flex items-center gap-2 bg-white text-[#23272A] font-semibold px-6 py-3.5 rounded-full text-base hover:shadow-xl hover:scale-110 hover:-translate-y-1 active:scale-95 transition-all duration-300" />
              <Link
                href="#"
                className="flex items-center gap-2 bg-[#5865F2]/80 backdrop-blur text-white font-semibold px-6 py-3.5 rounded-full text-base hover:bg-[#5865F2] hover:scale-110 hover:-translate-y-1 active:scale-95 transition-all duration-300"
              >
                <Globe size={18} />
                Open Flicko in your browser
              </Link>
            </motion.div>
          </motion.div>

          {/* Right Image - Full Screen */}
          <motion.div 
            variants={scaleIn}
            className="flex-1 relative w-full h-full min-h-[500px] lg:min-h-[700px]"
          >
            <div className="absolute inset-0">
              <Image
                src="/Hero-img.png"
                alt="Flicko App Preview"
                fill
                className="object-contain object-right"
                priority
              />
            </div>
          </motion.div>
        </div>
      </div>
    </motion.section>
  );
}

// Glassmorphism Feature Section - Exact Discord Style with Framer Motion
function GlassFeatureSection({ title, description, reverse = false, videoSet = 0 }: { title: string; description: string; reverse?: boolean; videoSet?: number }) {
  // Rotate through 6 videos based on videoSet
  const videos = [
    `/Videos/vid-${(videoSet % 6) + 1}.mp4`,
    `/Videos/vid-${((videoSet + 1) % 6) + 1}.mp4`,
    `/Videos/vid-${((videoSet + 2) % 6) + 1}.mp4`,
    `/Videos/vid-${((videoSet + 3) % 6) + 1}.mp4`,
  ];
  return (
    <section 
      className="py-24 md:py-32 w-full"
      style={{
        background: '#1a153a'
      }}
    >
      <div className="max-w-[1300px] mx-auto px-6">
        <motion.div 
          variants={scaleIn}
          className={`flex flex-col ${reverse ? "lg:flex-row-reverse" : "lg:flex-row"} gap-0 rounded-[80px] overflow-hidden backdrop-blur-[24px] bg-white/[0.08] border border-white/15 shadow-[0_20px_40px_rgba(0,0,0,0.3)] min-h-[520px] md:min-h-[580px]`}
        >
          
          {/* Left Text Section */}
          <motion.div 
            variants={slideIn}
            className="flex-1 p-12 md:p-16 flex flex-col justify-center"
          >
            <h2 className="text-4xl md:text-5xl font-black text-white uppercase leading-[1.05] mb-6 tracking-tight">
              {title}
            </h2>
            <p className="text-lg text-[#e0e0e0] leading-relaxed">
              {description}
            </p>
          </motion.div>
          
          {/* Right Media Section */}
          <motion.div 
            variants={slideIn}
            className="flex-[1.3] relative overflow-hidden"
            style={{
              background: 'rgba(255, 255, 255, 0.05)',
              borderRadius: '64px'
            }}
          >
            {/* Main Video - Draggable - Full bleed */}
            <div className="absolute inset-0 overflow-hidden cursor-grab active:cursor-grabbing">
              <motion.div
                drag
                dragConstraints={{ left: -50, right: 50, top: -50, bottom: 50 }}
                dragElastic={0.2}
                whileDrag={{ scale: 1.05 }}
                className="relative w-full h-full"
              >
                <video
                  src={videos[0]}
                  autoPlay
                  muted
                  loop
                  playsInline
                  className="w-full h-full object-cover pointer-events-none scale-105"
                />
              </motion.div>
            </div>
          </motion.div>
        </motion.div>
      </div>
    </section>
  );
}

export default function Home() {
  return (
    <div className="min-h-screen w-full bg-[#1a153a]">
      {/* Hero Section */}
      <HeroSection />

      {/* Section 1: MAKE YOUR GROUP CHATS MORE FUN */}
      <GlassFeatureSection
        title="Make your group chats more fun"
        description="Use custom emoji, stickers, soundboard effects and more to add your personality to your voice, video, or text chat. Set your avatar and a custom status, and write your own profile to show up in chat your way."
        videoSet={0}
      />

      {/* Section 2: Stream like you're in the same room */}
      <GlassFeatureSection
        title="stream like you're in the same room"
        description="High quality and low latency streaming makes it feel like you're hanging out on the couch with friends while playing a game, watching shows, looking at photos, or idk doing homework or something."
        reverse
        videoSet={1}
      />

      {/* Section 3: Hop in when you're free */}
      <GlassFeatureSection
        title="Hop in when you're free, no need to call"
        description="Easily hop in and out of voice or text chats without having to call or invite anyone, so your party chat lasts before, during, and after your game session."
        videoSet={2}
      />

      {/* Marquee Section */}
      <Marquee />

      {/* Section 4: See who's around */}
      <GlassFeatureSection
        title="See who's around to chill"
        description="See who's around, playing games, or just hanging out. For supported games, you can see what modes or characters your friends are playing and directly join up."
        reverse
        videoSet={3}
      />

      {/* Section 5: Always have something to do */}
      <GlassFeatureSection
        title="always have something to do together"
        description="Watch videos, play built-in games, listen to music, or just scroll together and spam memes. Seamlessly text, call, video chat, and play games, all in one group chat."
        videoSet={4}
      />

      {/* Section 6: Wherever you game */}
      <GlassFeatureSection
        title="wherever YOU GAME, HANG OUT HERE"
        description="On your PC, phone, or console, you can still hang out on Flicko. Easily switch between devices and use tools to manage multiple group chats with friends."
        reverse
        videoSet={5}
      />

      {/* CTA Text Section - YOU CAN'T SCROLL ANYMORE */}
      <motion.section 
        initial="hidden"
        whileInView="visible"
        viewport={{ once: true, margin: "-50px" }}
        variants={fadeInUp}
        className="py-32 md:py-40 relative overflow-hidden w-full"
        style={{ background: '#1a153a' }}
      >
        {/* Stars Background */}
        <div className="absolute inset-0 overflow-hidden pointer-events-none">
          {[...Array(30)].map((_, i) => (
            <div
              key={i}
              className="absolute w-1 h-1 bg-white/40 rounded-full animate-pulse"
              style={{
                top: `${Math.random() * 100}%`,
                left: `${Math.random() * 100}%`,
                animationDelay: `${Math.random() * 3}s`,
              }}
            />
          ))}
        </div>
        
        <div className="max-w-[1400px] mx-auto px-6 relative z-10 text-center">
          <motion.h2 
            variants={fadeInUp}
            className="text-4xl md:text-6xl lg:text-8xl font-black text-white leading-[1.1] mb-10 uppercase tracking-tight"
          >
            YOU CAN&apos;T SCROLL<br />ANYMORE. BETTER GO CHAT.
          </motion.h2>
          <motion.div variants={scaleIn}>
            <DownloadButton className="inline-flex items-center gap-2 bg-white text-[#23272A] font-semibold px-10 py-5 rounded-full text-xl hover:scale-105 transition-all shadow-2xl" />
          </motion.div>
        </div>
      </motion.section>

      {/* Character Banner Section */}
      <motion.section 
        initial="hidden"
        whileInView="visible"
        viewport={{ once: true, margin: "-50px" }}
        variants={fadeIn}
        className="relative pb-16 overflow-hidden"
        style={{ background: '#1a153a' }}
      >
        {/* Full Width Image */}
        <div className="relative w-full h-[400px] md:h-[500px] lg:h-[600px]">
          <Image
            src="/img-2.png"
            alt="Flicko Characters"
            fill
            className="object-contain object-center"
            priority
          />
        </div>
      </motion.section>

    </div>
  );
}
