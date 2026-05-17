"use client";

import Link from "next/link";
import { FaTwitter, FaInstagram, FaFacebook, FaYoutube, FaTiktok } from "react-icons/fa";
import { X } from "lucide-react";
import Image from "next/image";

const footerSections = [
  {
    title: "Product",
    links: [
      { label: "Download", href: "#" },
      { label: "Flicko Plus", href: "/flicko-pus" },
      { label: "Status", href: "#" },
      { label: "App Directory", href: "#" },
    ],
  },
  {
    title: "Company",
    links: [
      { label: "About", href: "/company" },
      { label: "Jobs", href: "#" },
      { label: "Brand", href: "/branding" },
      { label: "Newsroom", href: "#" },
    ],
  },
  {
    title: "Resources",
    links: [
      { label: "Support", href: "/support" },
      { label: "Safety", href: "#" },
      { label: "Blog", href: "#" },
      { label: "Creators", href: "#" },
      { label: "Community", href: "#" },
      { label: "Developers", href: "/developers" },
      { label: "Quests", href: "#" },
      { label: "Official 3rd Party Merch", href: "#" },
      { label: "Feedback", href: "#" },
    ],
  },
  {
    title: "Policies",
    links: [
      { label: "Terms", href: "/terms" },
      { label: "Privacy", href: "/privacy" },
      { label: "Cookie Settings", href: "#" },
      { label: "Guidelines", href: "#" },
      { label: "Acknowledgements", href: "#" },
      { label: "Licenses", href: "#" },
      { label: "Company Information", href: "#" },
    ],
  },
];

const FooterLink = ({ href, children }: { href: string; children: React.ReactNode }) => (
  <Link
    href={href}
    className="text-white/70 text-sm hover:text-white hover:underline transition-all duration-200 inline-block"
  >
    {children}
  </Link>
);

export default function Footer() {
  return (
    <footer 
      className="relative text-white overflow-hidden"
      style={{
        background: '#1a153a',
      }}
    >
      <div className="max-w-[1200px] mx-auto px-6 py-16 relative z-10">
        {/* Main Footer Grid */}
        <div className="grid grid-cols-2 md:grid-cols-6 gap-8 mb-16">
          {/* Brand Section - Left */}
          <div className="col-span-2 space-y-6">
            {/* Logo */}
            <Link href="/" className="flex items-center gap-2">
              <img src="/Flicko_icon.png" alt="Flicko" className="h-8 w-auto" />
            </Link>
            
            {/* Language */}
            <div className="space-y-2">
              <p className="text-white/50 text-xs">Language</p>
              <select 
                className="bg-[#1a153a]/80 text-white text-sm rounded-lg px-4 py-2.5 w-full max-w-[180px] border border-white/20 hover:bg-[#1a153a] hover:border-[#5865F2]/50 transition-all cursor-pointer outline-none"
                onChange={(e) => console.log('Language changed to:', e.target.value)}
              >
                <option>English</option>
                <option>Deutsch</option>
                <option>Español</option>
                <option>Français</option>
                <option>Italiano</option>
                <option>日本語</option>
                <option>한국어</option>
                <option>Polski</option>
                <option>Português</option>
                <option>Русский</option>
                <option>Türkçe</option>
                <option>中文</option>
              </select>
            </div>

            {/* Social */}
            <div className="space-y-2">
              <p className="text-white/50 text-xs">Social</p>
              <div className="flex items-center gap-4">
                <a href="#" aria-label="Twitter" className="text-white/70 hover:text-white transition-colors">
                  <X size={20} />
                </a>
                <a href="#" aria-label="Instagram" className="text-white/70 hover:text-white transition-colors">
                  <FaInstagram size={18} />
                </a>
                <a href="#" aria-label="Facebook" className="text-white/70 hover:text-white transition-colors">
                  <FaFacebook size={18} />
                </a>
                <a href="#" aria-label="YouTube" className="text-white/70 hover:text-white transition-colors">
                  <FaYoutube size={20} />
                </a>
                <a href="#" aria-label="TikTok" className="text-white/70 hover:text-white transition-colors">
                  <FaTiktok size={18} />
                </a>
              </div>
            </div>
          </div>

          {/* Link Sections - Right */}
          {footerSections.map((section) => (
            <div key={section.title}>
              <h3 className="text-white/50 text-xs font-medium mb-4">
                {section.title}
              </h3>
              <ul className="space-y-2">
                {section.links.map((link) => (
                  <li key={link.label}>
                    <FooterLink href={link.href}>
                      {link.label}
                    </FooterLink>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>
      </div>

      {/* Flicko Footer Image */}
      <div className="w-full overflow-hidden pb-4 pt-12 px-6" style={{ background: 'transparent' }}>
        <div className="relative w-full h-[250px] md:h-[350px] lg:h-[450px] mix-blend-screen opacity-40">
          <Image
            src="/Flicko-Footer.png"
            alt="Flicko"
            fill
            className="object-contain object-center"
            style={{ mixBlendMode: 'screen' }}
          />
        </div>
      </div>
      
    </footer>
  );
}
