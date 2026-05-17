"use client";

import Link from "next/link";
import { Users, Gamepad2, Clock, Briefcase, ExternalLink } from "lucide-react";

const timelineEvents = [
  { year: "2012", month: "April", title: "The Beginning", description: "Jason Citron and Stanislav Vishnevskiy meet while building social gaming experiences and discover a shared frustration with existing voice chat tools." },
  { year: "2015", month: "May", title: "Flicko Launches", description: "Flicko officially launches as a free voice and text chat platform built specifically for gamers, offering crystal-clear voice quality and easy server creation." },
  { year: "2016", month: "", title: "Custom Emoji & Overlay", description: "Flicko introduces custom emoji for Nitro subscribers and an in-game overlay, letting users chat without leaving their games." },
  { year: "2017", month: "", title: "Video Chat & Screen Share", description: "Video calling and screen sharing capabilities launch, expanding Flicko beyond text and voice, a full communication platform." },
  { year: "2018", month: "", title: "Flicko Store & Nitro Games", description: "The Flicko Store opens and Nitro subscribers get access to a curated collection of games as part of their subscription." },
  { year: "2019", month: "", title: "Server Discovery", description: "Server Discovery launches on Flicko, making it easier to find and join public communities around shared interests and games." },
  { year: "2020", month: "", title: "Stage Channels", description: "Stage Channels bring audio-first experiences to Flicko, perfect for community events, Q&As, and live discussions." },
  { year: "2021", month: "", title: "Threads & Activities", description: "Threads help organize conversations, while Activities bring interactive games and experiences directly into voice channels." },
  { year: "2022", month: "", title: "Forum Channels", description: "Forum Channels launch on Flicko, giving communities a dedicated space for organized topic-based discussions." },
  { year: "2023", month: "", title: "Console Integration", description: "Flicko arrives on PlayStation and Xbox, letting console players connect with their communities while gaming." },
  { year: "2024", month: "", title: "Quests & New Activities", description: "Flicko Quests launch, offering players in-game rewards, while new Activities continue to expand the ways friends can play together." },
  { year: "2025", month: "Spring", title: "A New Chapter", description: "Flicko sharpens its focus on gaming as the platform continues to evolve and grow with its community." },
];

const stats = [
  { value: "90M+", label: "Daily Active Users", icon: <Users size={28} /> },
  { value: "90%+", label: "Play Video Games", icon: <Gamepad2 size={28} /> },
  { value: "~40%", label: "Start a game within an hour", icon: <Clock size={28} /> },
];

const founders = [
  { name: "Jason Citron", role: "Co-founder", description: "Serial entrepreneur with a passion for gaming and building social platforms." },
  { name: "Stanislav Vishnevskiy", role: "Co-founder", description: "Engineering visionary who built Flicko's real-time infrastructure from the ground up." },
];

export default function CompanyPage() {
  return (
    <div className="min-h-screen">
      {/* Hero */}
      <section className="bg-gradient-to-br from-[#5865F2] to-[#4752C4] py-20 md:py-28">
        <div className="max-w-[900px] mx-auto px-6 text-center">
          <h1 className="text-4xl md:text-6xl font-extrabold text-white mb-6">
            Our Mission
          </h1>
          <p className="text-lg md:text-xl text-white/90 max-w-3xl mx-auto leading-relaxed">
            Flicko is the communications platform that enables you to build meaningful connections around the joy of playing games through voice, video, and text features.
          </p>
        </div>
      </section>

      {/* Stats */}
      <section className="py-16 md:py-24 bg-white">
        <div className="max-w-[1260px] mx-auto px-6">
          <h2 className="text-3xl md:text-4xl font-extrabold text-center mb-16 text-[#23272A]">In Numbers</h2>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
            {stats.map((stat) => (
              <div key={stat.label} className="text-center p-8 rounded-2xl bg-[#F6F6F6]">
                <div className="w-14 h-14 bg-[#5865F2] rounded-full flex items-center justify-center mx-auto mb-4 text-white">
                  {stat.icon}
                </div>
                <div className="text-5xl md:text-6xl font-extrabold text-[#5865F2] mb-2">{stat.value}</div>
                <div className="text-gray-600 text-lg">{stat.label}</div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Timeline */}
      <section className="py-16 md:py-24 bg-[#F6F6F6]">
        <div className="max-w-[900px] mx-auto px-6">
          <h2 className="text-3xl md:text-4xl font-extrabold text-center mb-16 text-[#23272A]">The Flicko Story</h2>
          <div className="relative">
            <div className="absolute left-4 md:left-1/2 md:-translate-x-0.5 top-0 bottom-0 w-0.5 bg-[#5865F2]/20" />
            <div className="space-y-12">
              {timelineEvents.map((event, idx) => (
                <div key={idx} className={`relative flex items-start gap-6 md:gap-12 ${idx % 2 === 0 ? "md:flex-row" : "md:flex-row-reverse"}`}>
                  <div className="absolute left-4 md:left-1/2 -translate-x-1/2 w-4 h-4 bg-[#5865F2] rounded-full border-4 border-white shadow z-10" />
                  <div className={`ml-12 md:ml-0 md:w-1/2 ${idx % 2 === 0 ? "md:pr-16 md:text-right" : "md:pl-16"}`}>
                    <div className="text-sm font-bold text-[#5865F2] mb-1">
                      {event.month ? `${event.month} ` : ""}{event.year}
                    </div>
                    <h3 className="text-xl font-bold text-[#23272A] mb-2">{event.title}</h3>
                    <p className="text-gray-600">{event.description}</p>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </section>

      {/* Founders */}
      <section className="py-16 md:py-24 bg-white">
        <div className="max-w-[900px] mx-auto px-6">
          <h2 className="text-3xl md:text-4xl font-extrabold text-center mb-16 text-[#23272A]">Our Founders</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
            {founders.map((f) => (
              <div key={f.name} className="p-8 rounded-2xl bg-[#F6F6F6] text-center">
                <div className="w-24 h-24 bg-[#5865F2] rounded-full flex items-center justify-center mx-auto mb-4 text-white text-3xl font-bold">
                  {f.name.split(" ").map(n => n[0]).join("")}
                </div>
                <h3 className="text-xl font-bold text-[#23272A] mb-1">{f.name}</h3>
                <div className="text-[#5865F2] font-semibold text-sm mb-3">{f.role}</div>
                <p className="text-gray-600">{f.description}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Careers CTA */}
      <section className="bg-[#5865F2] py-16 md:py-24">
        <div className="max-w-[900px] mx-auto px-6 text-center">
          <Briefcase size={48} className="text-white/80 mx-auto mb-6" />
          <h2 className="text-3xl md:text-4xl font-extrabold text-white mb-4">
            Shape the Future of Gaming with Us
          </h2>
          <p className="text-white/80 text-lg mb-8 max-w-xl mx-auto">
            Join our team and help build the platform where millions of people play, talk, and hang out every day.
          </p>
          <Link
            href="#"
            className="inline-flex items-center gap-2 bg-white text-[#5865F2] font-semibold px-8 py-4 rounded-full text-lg hover:shadow-xl transition"
          >
            <ExternalLink size={20} />
            View Open Positions
          </Link>
        </div>
      </section>
    </div>
  );
}
