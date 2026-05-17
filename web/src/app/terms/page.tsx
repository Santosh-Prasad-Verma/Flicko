"use client";

import Link from "next/link";

const sections = [
  { id: "age", title: "1. Age Requirements and Responsibility of Parents and Legal Guardians" },
  { id: "agreement", title: "2. What You Agree To" },
  { id: "rights", title: "3. Your Rights" },
  { id: "services", title: "4. Flicko's Services" },
  { id: "content", title: "5. Content in Flicko's Services" },
  { id: "software", title: "6. Software in Flicko's Services" },
  { id: "ip", title: "7. Copyright and Intellectual Property Policy" },
  { id: "restrictions", title: "8. Flicko's Restrictions" },
  { id: "termination", title: "9. Termination" },
  { id: "indemnity", title: "10. Indemnity" },
  { id: "disclaimers", title: "11. Disclaimers" },
  { id: "liability", title: "12. Limitation of Liability" },
  { id: "settlement", title: "13. Settlement and Arbitration" },
  { id: "exclusions", title: "14. Exclusions to Agreement to Arbitrate" },
  { id: "waiver", title: "15. No Class Actions" },
  { id: "general", title: "16. General" },
  { id: "contact", title: "17. Contacting Each Other" },
];

export default function TermsPage() {
  return (
    <div className="min-h-screen bg-white">
      {/* Header */}
      <section className="bg-[#5865F2] py-16 md:py-20">
        <div className="max-w-[800px] mx-auto px-6 text-center">
          <h1 className="text-3xl md:text-5xl font-extrabold text-white mb-4">
            Flicko's Terms of Service
          </h1>
          <p className="text-white/80 text-sm">
            Effective: September 29, 2025 &middot; Last Updated: August 29, 2025
          </p>
        </div>
      </section>

      {/* Content */}
      <div className="max-w-[800px] mx-auto px-6 py-12 md:py-16">
        {/* Table of Contents */}
        <div className="bg-[#F6F6F6] rounded-2xl p-6 md:p-8 mb-12">
          <h2 className="text-lg font-bold text-[#23272A] mb-4">Table of Contents</h2>
          <nav className="space-y-2">
            {sections.map((s) => (
              <a
                key={s.id}
                href={`#${s.id}`}
                className="block text-[#5865F2] hover:text-[#4752C4] text-sm transition-colors"
              >
                {s.title}
              </a>
            ))}
          </nav>
        </div>

        {/* Welcome Text */}
        <div className="prose prose-gray max-w-none mb-12">
          <p className="text-gray-600 leading-relaxed">
            Welcome! Flicko is the communications platform that lets people create space for gaming communities. These Terms of Service (&quot;Terms&quot;) govern your use of Flicko's products and services. By using our services, you agree to these terms. Please read them carefully.
          </p>
        </div>

        {/* Sections */}
        {sections.map((section) => (
          <div key={section.id} id={section.id} className="mb-10 scroll-mt-24">
            <h2 className="text-xl font-bold text-[#23272A] mb-4 pb-2 border-b border-gray-100">
              {section.title}
            </h2>
            <div className="text-gray-600 leading-relaxed space-y-3">
              <p>
                This section outlines the key policies and agreements related to {section.title.replace(/^\d+\.\s*/, "").toLowerCase()}. By using Flicko's services, you acknowledge and agree to these provisions.
              </p>
              <p>
                Flicko reserves the right to update these terms at any time. We will notify users of material changes through the platform or via email. Your continued use of the services after changes constitutes acceptance of the updated terms.
              </p>
            </div>
          </div>
        ))}

        {/* Contact */}
        <div className="bg-[#F6F6F6] rounded-2xl p-6 md:p-8 mt-12">
          <h3 className="font-bold text-[#23272A] mb-2">Contact Information</h3>
          <p className="text-gray-600 text-sm mb-4">
            Flicko Inc.<br />
            444 De Haro Street, Suite 200<br />
            San Francisco, CA 94107
          </p>
          <p className="text-gray-600 text-sm">
            Flicko Netherlands B.V.<br />
            Schiphol Boulevard 195<br />
            1118 BG Schiphol, Netherlands
          </p>
        </div>
      </div>
    </div>
  );
}
