import type { Metadata } from "next";
import "./globals.css";
import { VisualEditsMessenger } from "orchids-visual-edits";
import Script from "next/script";
import Navbar from "@/components/Navbar";
import Footer from "@/components/Footer";

export const metadata: Metadata = {
  title: "Flicko | Your Place to Talk and Hang Out",
  description: "Flicko is the easiest way to talk over voice, video, and text. Talk, chat, hang out, and stay close with your friends and communities.",
  icons: {
    icon: "/Flicko_icon.png",
    shortcut: "/Flicko_icon.png",
    apple: "/Flicko_icon.png",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  const enableVisualBridge =
    process.env.NEXT_PUBLIC_ENABLE_VISUAL_BRIDGE === "true";

  return (
    <html lang="en">
      <body className="antialiased bg-[#1a153a]">
        {enableVisualBridge ? (
          <Script
            src="https://slelguoygbfzlpylpxfs.supabase.co/storage/v1/object/public/scripts//route-messenger.js"
            strategy="afterInteractive"
            data-target-origin="*"
            data-message-type="ROUTE_CHANGE"
            data-include-search-params="true"
            data-only-in-iframe="true"
            data-debug="false"
            data-custom-data='{"appName": "Flicko", "version": "1.0.0"}'
          />
        ) : null}
        <Navbar />
        {children}
        <Footer />
        {enableVisualBridge ? <VisualEditsMessenger /> : null}
      </body>
    </html>
  );
}
