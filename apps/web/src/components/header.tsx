import { BarChart3 } from "lucide-react";

const links = [
  { href: "/#waitlist", label: "Waitlist" },
  { href: "/demo-dashboard", label: "Demo" },
  { href: "/dashboard", label: "Dashboard" },
  { href: "/ai", label: "AI" },
];

export default function Header() {
  return (
    <header className="border-b border-white/8 bg-[#061512]/92 px-4 py-3 text-white backdrop-blur-xl">
      <div className="mx-auto flex max-w-7xl flex-wrap items-center justify-center gap-3 sm:justify-between">
        <a href="/" className="inline-flex items-center gap-2.5">
          <span className="flex size-8 items-center justify-center rounded-full border border-[#9cebd6]/20 bg-[#9cebd6]/10">
            <BarChart3 className="size-4 text-[#9cebd6]" />
          </span>
          <span className="font-serif text-xl leading-none tracking-normal text-white">
            Calendar Metrics
          </span>
        </a>

        <nav className="flex max-w-full items-center gap-1 overflow-x-auto rounded-full border border-white/8 bg-white/[0.035] p-1">
          {links.map(({ href, label }) => (
            <a
              key={href}
              href={href}
              className="rounded-full px-3 py-1.5 text-xs font-semibold text-white/58 transition-colors hover:bg-white/[0.07] hover:text-white sm:px-4"
            >
              {label}
            </a>
          ))}
        </nav>
      </div>
    </header>
  );
}
