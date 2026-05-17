"use client";

const sections = [
  { id: "welcome", title: "1. Welcome" },
  { id: "about", title: "2. About Flicko" },
  { id: "collection", title: "3. Information We Collect" },
  { id: "usage", title: "4. How We Use Your Information" },
  { id: "disclosure", title: "5. How We Disclose Your Information" },
  { id: "retention", title: "6. Data Retention" },
  { id: "security", title: "7. How We Protect Your Information" },
  { id: "controls", title: "8. Your Privacy Controls" },
  { id: "transfers", title: "9. International Data Transfers" },
  { id: "third-party", title: "10. Third-Party Services & Apps" },
  { id: "dpo", title: "11. Data Protection Officer" },
  { id: "local-laws", title: "12. Local Privacy Laws" },
  { id: "changes", title: "13. Changes to This Policy" },
  { id: "contact", title: "14. Contact Us" },
];

export default function PrivacyPage() {
  return (
    <div className="min-h-screen bg-white">
      {/* Header */}
      <section className="bg-[#5865F2] py-16 md:py-20">
        <div className="max-w-[800px] mx-auto px-6 text-center">
          <h1 className="text-3xl md:text-5xl font-extrabold text-white mb-4">
            Flicko Privacy Policy
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

        {/* Intro */}
        <div className="prose prose-gray max-w-none mb-12">
          <p className="text-gray-600 leading-relaxed">
            Flicko (&quot;we&quot;, &quot;us&quot;, &quot;our&quot;) is committed to protecting your privacy. This Privacy Policy describes how we collect, use, store, and share your information when you use our website, apps, and services (collectively, &quot;Services&quot;).
          </p>
          <p className="text-gray-600 leading-relaxed">
            We believe privacy is a right, and we&apos;re committed to building Flicko in a way that puts you in control of your information.
          </p>
        </div>

        {/* Sections */}
        {sections.map((section) => (
          <div key={section.id} id={section.id} className="mb-10 scroll-mt-24">
            <h2 className="text-xl font-bold text-[#23272A] mb-4 pb-2 border-b border-gray-100">
              {section.title}
            </h2>
            <div className="text-gray-600 leading-relaxed space-y-3">
              {section.id === "welcome" && (
                <>
                  <p>This Privacy Policy explains how Flicko collects, uses, and protects your personal information. We know privacy is important to you, and it&apos;s important to us too.</p>
                  <p>We process personal data on the basis of your consent, contractual necessity, compliance with legal obligations, and our legitimate interests.</p>
                </>
              )}
              {section.id === "about" && (
                <p>Flicko provides a communications platform that enables users to communicate via voice, video, and text. We offer our services through our website, desktop apps, and mobile apps.</p>
              )}
              {section.id === "collection" && (
                <>
                  <p>We collect information you provide directly, such as when you create an account, set up your profile, communicate with other users, or contact us for support.</p>
                  <p><strong>Account information:</strong> username, email, phone number, date of birth, and password.</p>
                  <p><strong>Content you create:</strong> messages, images, videos, and other content you share through our services.</p>
                  <p><strong>Payment information:</strong> if you purchase a subscription, we collect payment information processed by our payment providers.</p>
                  <p><strong>Device information:</strong> IP address, device type, operating system, browser type, and unique device identifiers.</p>
                </>
              )}
              {section.id === "usage" && (
                <>
                  <p>We use your information to provide, maintain, and improve our services. This includes:</p>
                  <ul className="list-disc pl-6 space-y-1">
                    <li>Operating and providing our platform and services</li>
                    <li>Personalizing your experience</li>
                    <li>Processing transactions and sending related information</li>
                    <li>Communicating with you about updates, security alerts, and support</li>
                    <li>Detecting, investigating, and preventing fraudulent or illegal activities</li>
                    <li>Complying with legal obligations</li>
                  </ul>
                </>
              )}
              {section.id === "disclosure" && (
                <p>We may share your information with service providers who help us operate our services, with your consent, to comply with legal obligations, or to protect our rights and safety.</p>
              )}
              {section.id === "retention" && (
                <p>We retain your information for as long as your account is active or as needed to provide services. You can request deletion of your data at any time through your account settings.</p>
              )}
              {section.id === "security" && (
                <p>We implement technical and organizational security measures to protect your information, including encryption in transit and at rest, access controls, and regular security audits.</p>
              )}
              {section.id === "controls" && (
                <>
                  <p>You have control over your personal information. You can:</p>
                  <ul className="list-disc pl-6 space-y-1">
                    <li>Access and update your account information through Settings</li>
                    <li>Request a copy of your data</li>
                    <li>Delete your account and associated data</li>
                    <li>Manage your privacy settings and who can contact you</li>
                    <li>Control data used for personalization</li>
                  </ul>
                </>
              )}
              {section.id === "transfers" && (
                <p>Your information may be transferred to and processed in countries other than your own. We use Standard Contractual Clauses and other mechanisms to ensure appropriate safeguards for international data transfers.</p>
              )}
              {section.id === "third-party" && (
                <p>Our platform allows developers to create applications and bots. When you interact with these third-party services, their own privacy policies apply. We encourage you to review the privacy practices of any third-party services.</p>
              )}
              {section.id === "dpo" && (
                <p>Our Data Protection Officer can be reached at privacy@flicko.com for any questions or concerns about our data practices.</p>
              )}
              {section.id === "local-laws" && (
                <p>Depending on your location, you may have additional rights under local privacy laws (such as GDPR, CCPA, or other regulations). We respect and comply with applicable local privacy laws.</p>
              )}
              {section.id === "changes" && (
                <p>We may update this Privacy Policy from time to time. We will notify you of material changes through the platform or via the email associated with your account.</p>
              )}
              {section.id === "contact" && (
                <p>If you have questions about this Privacy Policy, you can contact us through our Help Center or at the addresses listed below.</p>
              )}
            </div>
          </div>
        ))}

        {/* Contact */}
        <div className="bg-[#F6F6F6] rounded-2xl p-6 md:p-8 mt-12">
          <h3 className="font-bold text-[#23272A] mb-2">Contact Information</h3>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <p className="text-gray-600 text-sm">
                <strong>Flicko Inc.</strong><br />
                444 De Haro Street, Suite 200<br />
                San Francisco, CA 94107<br />
                United States
              </p>
            </div>
            <div>
              <p className="text-gray-600 text-sm">
                <strong>Flicko Netherlands B.V.</strong><br />
                Schiphol Boulevard 195<br />
                1118 BG Schiphol<br />
                Netherlands
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
