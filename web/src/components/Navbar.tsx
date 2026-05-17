"use client";

import Link from "next/link";
import { useState } from "react";
import { Menu, X } from "lucide-react";

const navLinks = [
  { label: "Download", href: "#" },
  { label: "Flicko Plus", href: "/flicko-pus" },
  { label: "Discover", href: "#" },
  { label: "Safety", href: "#" },
  { label: "Quests", href: "#" },
  { label: "Support", href: "/support" },
  { label: "Blog", href: "#" },
  { label: "Developers", href: "/developers" },
  { label: "Careers", href: "#" },
];

export default function Navbar() {
  const [mobileOpen, setMobileOpen] = useState(false);

  return (
    <>
      {/* Fixed Logo - Left Side */}
      <div className="fixed top-0 left-0 z-50 p-6">
        <Link href="/" className="flex items-center gap-2">
          <img src="/Flicko_icon.png" alt="Flicko" className="h-8 w-auto" />
          <span className="text-xl font-black tracking-wider text-white" style={{
            fontFamily: "'GG Sans', 'Abcgintodiscordnord', sans-serif",
            textShadow: '2px 2px 4px rgba(0,0,0,0.8)',
          }}>FLICKO</span>
        </Link>
      </div>

      {/* Fixed Login Button - Right Side */}
      <div className="fixed top-0 right-0 z-50 p-6">
        <Link
          href="#"
          className="bg-white hover:bg-gray-100 text-[#23272A] text-sm font-semibold px-6 py-2.5 rounded-full transition-colors shadow-lg"
        >
          Log In
        </Link>
      </div>

      {/* Nav Links - Center (In Normal Flow, Transparent) */}
      <nav className="absolute top-0 left-0 right-0 z-40 bg-transparent">
        <div className="max-w-[1260px] mx-auto px-6 flex items-center justify-center h-20">
          <div className="hidden lg:flex items-center gap-8">
            {navLinks.map((link) => (
              <Link
                key={link.label}
                href={link.href}
                className="text-base font-semibold text-white hover:bg-[#5865F2] hover:text-white px-4 py-2 rounded-full hover:scale-110 hover:-translate-y-0.5 transition-all duration-300 drop-shadow-lg"
              >
                {link.label}
              </Link>
            ))}
          </div>

          <button
            className="lg:hidden fixed top-6 right-24 z-50 p-2 text-white"
            onClick={() => setMobileOpen(!mobileOpen)}
          >
            {mobileOpen ? <X size={24} /> : <Menu size={24} />}
          </button>
        </div>

        {mobileOpen && (
          <div className="lg:hidden fixed inset-0 bg-[#1A1B2E]/98 backdrop-blur-md z-40 pt-24 px-6">
            {navLinks.map((link) => (
              <Link
                key={link.label}
                href={link.href}
                className="block text-lg font-semibold text-white hover:text-[#5865F2] py-4 border-b border-white/10"
                onClick={() => setMobileOpen(false)}
              >
                {link.label}
              </Link>
            ))}
          </div>
        )}
      </nav>
    </>
  );
}
