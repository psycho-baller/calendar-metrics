import { useMemo, useState } from "react";

import { cn } from "@/lib/utils";

type SubmitStatus = "idle" | "loading" | "success" | "already-added" | "error";

type InlineWaitlistFormProps = {
  align?: "left" | "center";
  caption?: string;
  className?: string;
  platform?: string;
};

function isValidEmail(value: string) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value.trim());
}

export default function InlineWaitlistForm({
  align = "left",
  caption = "",
  className,
  platform = "Web",
}: InlineWaitlistFormProps) {
  const [email, setEmail] = useState("");
  const [status, setStatus] = useState<SubmitStatus>("idle");
  const [message, setMessage] = useState<string | null>(null);

  const isJoined = status === "success" || status === "already-added";
  const isLoading = status === "loading";

  const noteToneClass = useMemo(() => {
    if (status === "error") {
      return "text-red-300";
    }
    if (isJoined) {
      return "text-[#9cebd6]";
    }
    return "text-white/52";
  }, [isJoined, status]);

  async function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();

    if (!isValidEmail(email)) {
      setStatus("error");
      setMessage("Use a valid email address.");
      return;
    }

    try {
      setStatus("loading");
      setMessage(null);

      const response = await fetch("/api/waitlist", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          email: email.trim(),
          platform,
        }),
      });

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || "Failed to join the waitlist.");
      }

      if (data.alreadyAdded) {
        setStatus("already-added");
        setMessage("We already have your email.");
        return;
      }

      setStatus("success");
      setMessage("You are on the waitlist.");
    } catch (error) {
      setStatus("error");
      setMessage(
        error instanceof Error
          ? error.message
          : "There was an issue processing the request. Please try again.",
      );
    }
  }

  const note = message ?? caption;

  return (
    <form
      onSubmit={handleSubmit}
      className={cn("w-full max-w-xl", className)}
      aria-label="Intent waitlist form"
    >
      <div className="flex items-center gap-3 rounded-full border border-white/12 bg-white/[0.045] py-[6px] pl-5 pr-[8px] shadow-[0_20px_80px_-50px_rgba(20,184,166,0.7)] backdrop-blur-xl">
        <input
          type="email"
          placeholder="you@company.com"
          value={email}
          onChange={(event) => {
            setEmail(event.target.value);
            if (status === "error") {
              setStatus("idle");
              setMessage(null);
            }
          }}
          className="h-11 min-w-0 flex-1 appearance-none border-0 bg-transparent px-0 text-[0.98rem] leading-none text-white outline-none placeholder:text-white/34"
          disabled={isLoading || isJoined}
          aria-invalid={status === "error"}
        />
        <button
          type="submit"
          disabled={isLoading || isJoined}
          className="h-11 min-w-[6rem] shrink-0 rounded-full bg-[#9cebd6] px-5 text-[0.95rem] font-semibold leading-none text-[#061512] transition-colors duration-200 hover:bg-[#c2f7e8] disabled:cursor-default disabled:opacity-100"
        >
          {isJoined ? "Joined" : isLoading ? "Joining..." : "Join"}
        </button>
      </div>

      {note ? (
        <div
          className={cn(
            "mt-3 text-sm",
            align === "center" ? "text-center" : "text-left",
            noteToneClass,
          )}
        >
          {note}
        </div>
      ) : null}
    </form>
  );
}
