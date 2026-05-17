"use client";

import { Download, Copy, Check, ExternalLink } from "lucide-react";
import { useState } from "react";

const colors = [
  { name: "Blurple", hex: "#5865F2", textColor: "text-white" },
  { name: "Light Blurple", hex: "#E0E3FF", textColor: "text-[#23272A]" },
  { name: "Green", hex: "#57F287", textColor: "text-[#23272A]" },
  { name: "Yellow", hex: "#FEE75C", textColor: "text-[#23272A]" },
  { name: "Fuchsia", hex: "#EB459E", textColor: "text-white" },
  { name: "Red", hex: "#ED4245", textColor: "text-white" },
  { name: "Black", hex: "#000000", textColor: "text-white" },
  { name: "White", hex: "#FFFFFF", textColor: "text-[#23272A]" },
];

const dos = [
  "Use the Flicko logos provided to link to our platform",
  "Use the brand colors from the palette provided",
  "Give the logo enough breathing room",
  "Use the wordmark lockup when the brand needs introduction",
];

const donts = [
  "Alter the logo colors outside of what's shown here",
  "Rotate, skew, or add effects to the logo",
  "Use our old logos or any modified versions",
  "Combine our logo with your own branding in a way that implies partnership",
  "Use our trademarks as part of your own product name",
];

function CopyButton({ text }: { text: string }) {
  const [copied, setCopied] = useState(false);
  return (
    <button
      onClick={() => {
        navigator.clipboard.writeText(text);
        setCopied(true);
        setTimeout(() => setCopied(false), 2000);
      }}
      className="flex items-center gap-1 text-xs opacity-0 group-hover:opacity-100 transition-opacity bg-black/20 px-2 py-1 rounded"
    >
      {copied ? <Check size={12} /> : <Copy size={12} />}
      {copied ? "Copied!" : "Copy"}
    </button>
  );
}

export default function BrandingPage() {
  return (
    <div className="min-h-screen">
      {/* Hero */}
      <section className="bg-[#5865F2] py-20 md:py-28">
        <div className="max-w-[900px] mx-auto px-6 text-center">
          <h1 className="text-4xl md:text-6xl font-extrabold text-white mb-4">
            Brand Assets
          </h1>
          <p className="text-lg md:text-xl text-white/90 max-w-xl mx-auto mb-8">
            Make sure to get our good side. Here you&apos;ll find our brand guidelines, logos, and color information.
          </p>
          <a
            href="#"
            className="inline-flex items-center gap-2 bg-white text-[#5865F2] font-semibold px-8 py-4 rounded-full text-lg hover:shadow-xl transition"
          >
            <Download size={20} />
            Download Brand Kit
          </a>
        </div>
      </section>

      {/* Logos */}
      <section className="py-16 md:py-24 bg-white">
        <div className="max-w-[1260px] mx-auto px-6">
          <h2 className="text-3xl md:text-4xl font-extrabold text-center mb-4 text-[#23272A]">Our Logo</h2>
          <p className="text-gray-600 text-center mb-16 max-w-xl mx-auto">
            The Flicko wordmark and icon are our most recognizable brand assets. Use them thoughtfully.
          </p>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-8 mb-16">
            {[
              { bg: "bg-[#5865F2]", label: "On Blurple", logoColor: "text-white" },
              { bg: "bg-white border-2 border-gray-100", label: "On White", logoColor: "text-[#23272A]" },
              { bg: "bg-[#23272A]", label: "On Dark", logoColor: "text-white" },
            ].map((variant) => (
              <div key={variant.label} className="text-center">
                <div className={`${variant.bg} rounded-2xl p-12 flex items-center justify-center h-48 mb-4`}>
                  <svg width="160" height="44" viewBox="0 0 124 34" fill="currentColor" className={variant.logoColor}>
                    <path d="M26.0015 6.9529C24.0021 6.03845 21.8787 5.37198 19.6623 5C19.3833 5.48048 19.0733 6.13144 18.8563 6.64292C16.4989 6.30193 14.1585 6.30193 11.8346 6.64292C11.6176 6.13144 11.2916 5.48048 11.0126 5C8.77965 5.37198 6.65765 6.03845 4.65861 6.9529C0.667817 12.8736 -0.409634 18.6548 0.129366 24.3585C2.79651 26.2959 5.36818 27.4739 7.88965 28.2489C8.51765 27.4119 9.07865 26.5129 9.55765 25.5675C8.64365 25.2265 7.77165 24.8085 6.93765 24.3175C7.15465 24.1595 7.36765 23.9935 7.57265 23.8275C12.5816 26.1159 18.0346 26.1159 22.9866 23.8275C23.1916 23.9935 23.4046 24.1595 23.6216 24.3175C22.7876 24.8085 21.9156 25.2265 21.0016 25.5675C21.4806 26.5129 22.0416 27.4119 22.6696 28.2489C25.1916 27.4739 27.7636 26.2959 30.4306 24.3585C31.0526 17.7559 29.3346 11.9329 26.0015 6.9529ZM10.2249 20.8402C8.71465 20.8402 7.47465 19.4596 7.47465 17.7559C7.47465 16.0522 8.68065 14.6716 10.2249 14.6716C11.7526 14.6716 13.0086 16.0522 12.9756 17.7559C12.9756 19.4596 11.7526 20.8402 10.2249 20.8402ZM20.3346 20.8402C18.8246 20.8402 17.5846 19.4596 17.5846 17.7559C17.5846 16.0522 18.7906 14.6716 20.3346 14.6716C21.8626 14.6716 23.1186 16.0522 23.0856 17.7559C23.0856 19.4596 21.8626 20.8402 20.3346 20.8402Z" />
                  </svg>
                </div>
                <p className="text-sm font-semibold text-gray-600">{variant.label}</p>
              </div>
            ))}
          </div>

          {/* Symbols */}
          <h3 className="text-2xl font-bold text-[#23272A] mb-4 text-center">Symbol</h3>
          <p className="text-gray-600 text-center mb-8 max-w-xl mx-auto">
            Use these only when the Flicko brand is clearly visible or already established in context.
          </p>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
            {[
              { bg: "bg-[#5865F2]", color: "text-white" },
              { bg: "bg-white border-2 border-gray-100", color: "text-[#23272A]" },
              { bg: "bg-[#23272A]", color: "text-white" },
            ].map((v, i) => (
              <div key={i} className={`${v.bg} rounded-2xl p-8 flex items-center justify-center h-40`}>
                <svg width="60" height="46" viewBox="0 0 31 30" fill="currentColor" className={v.color}>
                  <path d="M26.0015 6.9529C24.0021 6.03845 21.8787 5.37198 19.6623 5C19.3833 5.48048 19.0733 6.13144 18.8563 6.64292C16.4989 6.30193 14.1585 6.30193 11.8346 6.64292C11.6176 6.13144 11.2916 5.48048 11.0126 5C8.77965 5.37198 6.65765 6.03845 4.65861 6.9529C0.667817 12.8736 -0.409634 18.6548 0.129366 24.3585C2.79651 26.2959 5.36818 27.4739 7.88965 28.2489C8.51765 27.4119 9.07865 26.5129 9.55765 25.5675C8.64365 25.2265 7.77165 24.8085 6.93765 24.3175C7.15465 24.1595 7.36765 23.9935 7.57265 23.8275C12.5816 26.1159 18.0346 26.1159 22.9866 23.8275C23.1916 23.9935 23.4046 24.1595 23.6216 24.3175C22.7876 24.8085 21.9156 25.2265 21.0016 25.5675C21.4806 26.5129 22.0416 27.4119 22.6696 28.2489C25.1916 27.4739 27.7636 26.2959 30.4306 24.3585C31.0526 17.7559 29.3346 11.9329 26.0015 6.9529ZM10.2249 20.8402C8.71465 20.8402 7.47465 19.4596 7.47465 17.7559C7.47465 16.0522 8.68065 14.6716 10.2249 14.6716C11.7526 14.6716 13.0086 16.0522 12.9756 17.7559C12.9756 19.4596 11.7526 20.8402 10.2249 20.8402ZM20.3346 20.8402C18.8246 20.8402 17.5846 19.4596 17.5846 17.7559C17.5846 16.0522 18.7906 14.6716 20.3346 14.6716C21.8626 14.6716 23.1186 16.0522 23.0856 17.7559C23.0856 19.4596 21.8626 20.8402 20.3346 20.8402Z" />
                </svg>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Clearspace */}
      <section className="py-16 md:py-24 bg-[#F6F6F6]">
        <div className="max-w-[900px] mx-auto px-6">
          <h2 className="text-3xl md:text-4xl font-extrabold text-center mb-4 text-[#23272A]">Clearspace</h2>
          <p className="text-gray-600 text-center mb-12 max-w-xl mx-auto">
            Always give the Flicko logo proper breathing room. The minimum clearspace is equal to the height of the &ldquo;F&rdquo; in Flicko.
          </p>
          <div className="bg-white rounded-2xl p-12 flex items-center justify-center">
            <div className="border-2 border-dashed border-[#5865F2]/30 p-12 rounded-xl inline-block">
              <svg width="160" height="44" viewBox="0 0 124 34" fill="#5865F2">
                <path d="M26.0015 6.9529C24.0021 6.03845 21.8787 5.37198 19.6623 5C19.3833 5.48048 19.0733 6.13144 18.8563 6.64292C16.4989 6.30193 14.1585 6.30193 11.8346 6.64292C11.6176 6.13144 11.2916 5.48048 11.0126 5C8.77965 5.37198 6.65765 6.03845 4.65861 6.9529C0.667817 12.8736 -0.409634 18.6548 0.129366 24.3585C2.79651 26.2959 5.36818 27.4739 7.88965 28.2489C8.51765 27.4119 9.07865 26.5129 9.55765 25.5675C8.64365 25.2265 7.77165 24.8085 6.93765 24.3175C7.15465 24.1595 7.36765 23.9935 7.57265 23.8275C12.5816 26.1159 18.0346 26.1159 22.9866 23.8275C23.1916 23.9935 23.4046 24.1595 23.6216 24.3175C22.7876 24.8085 21.9156 25.2265 21.0016 25.5675C21.4806 26.5129 22.0416 27.4119 22.6696 28.2489C25.1916 27.4739 27.7636 26.2959 30.4306 24.3585C31.0526 17.7559 29.3346 11.9329 26.0015 6.9529ZM10.2249 20.8402C8.71465 20.8402 7.47465 19.4596 7.47465 17.7559C7.47465 16.0522 8.68065 14.6716 10.2249 14.6716C11.7526 14.6716 13.0086 16.0522 12.9756 17.7559C12.9756 19.4596 11.7526 20.8402 10.2249 20.8402ZM20.3346 20.8402C18.8246 20.8402 17.5846 19.4596 17.5846 17.7559C17.5846 16.0522 18.7906 14.6716 20.3346 14.6716C21.8626 14.6716 23.1186 16.0522 23.0856 17.7559C23.0856 19.4596 21.8626 20.8402 20.3346 20.8402Z" />
              </svg>
            </div>
          </div>
        </div>
      </section>

      {/* Color Palette */}
      <section className="py-16 md:py-24 bg-white">
        <div className="max-w-[1260px] mx-auto px-6">
          <h2 className="text-3xl md:text-4xl font-extrabold text-center mb-4 text-[#23272A]">Color Palette</h2>
          <p className="text-gray-600 text-center mb-16 max-w-xl mx-auto">
            Our official brand colors. Click to copy the hex value.
          </p>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            {colors.map((c) => (
              <div key={c.name} className="group cursor-pointer">
                <div
                  className={`h-32 rounded-xl flex items-end justify-between p-4 ${c.textColor} ${c.hex === "#FFFFFF" ? "border-2 border-gray-100" : ""}`}
                  style={{ backgroundColor: c.hex }}
                >
                  <div>
                    <div className="font-bold text-sm">{c.name}</div>
                    <div className="text-xs opacity-80">{c.hex}</div>
                  </div>
                  <CopyButton text={c.hex} />
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Guidelines */}
      <section className="py-16 md:py-24 bg-[#F6F6F6]">
        <div className="max-w-[1060px] mx-auto px-6">
          <h2 className="text-3xl md:text-4xl font-extrabold text-center mb-16 text-[#23272A]">Usage Guidelines</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-12">
            <div>
              <h3 className="text-xl font-bold text-[#57F287] mb-6 flex items-center gap-2">
                <Check size={24} /> Do&apos;s
              </h3>
              <ul className="space-y-4">
                {dos.map((d) => (
                  <li key={d} className="flex items-start gap-3">
                    <Check size={18} className="text-[#57F287] mt-0.5 flex-shrink-0" />
                    <span className="text-gray-700">{d}</span>
                  </li>
                ))}
              </ul>
            </div>
            <div>
              <h3 className="text-xl font-bold text-[#ED4245] mb-6 flex items-center gap-2">
                <X size={24} /> Don&apos;ts
              </h3>
              <ul className="space-y-4">
                {donts.map((d) => (
                  <li key={d} className="flex items-start gap-3">
                    <X size={18} className="text-[#ED4245] mt-0.5 flex-shrink-0" />
                    <span className="text-gray-700">{d}</span>
                  </li>
                ))}
              </ul>
            </div>
          </div>
        </div>
      </section>
    </div>
  );
}

function X({ size, className }: { size: number; className?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round" className={className}>
      <line x1="18" y1="6" x2="6" y2="18" />
      <line x1="6" y1="6" x2="18" y2="18" />
    </svg>
  );
}
