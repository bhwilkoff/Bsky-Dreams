"use client";

import { useRef, useEffect, useState, useCallback } from "react";
import { toPng } from "html-to-image";

// ─── Canvas dimensions ───────────────────────────────────────────────────────
const W = 1320;
const H = 2868;

// ─── Design tokens ───────────────────────────────────────────────────────────
const NB_BLACK  = "#0A0A0A";
const NB_WHITE  = "#FFFFFF";
const NB_BLUE   = "#0047FF";
const NB_CORAL  = "#FF5C35";
const NB_LIME   = "#B8E04A";
const NB_BG     = "#FFFDF8";
const NB_BORDER = "#E0E0E0";

// ─── iPhone mockup measurements ──────────────────────────────────────────────
const MK_W  = 1022;
const MK_H  = 2082;
const SC_L  = (52   / MK_W) * 100;
const SC_T  = (46   / MK_H) * 100;
const SC_W  = (918  / MK_W) * 100;
const SC_H  = (1990 / MK_H) * 100;
const SC_RX = (126  / 918)  * 100;
const SC_RY = (126  / 1990) * 100;

// ─── Style helpers ────────────────────────────────────────────────────────────
const nb = (extra?: React.CSSProperties): React.CSSProperties => ({
  border: `${W * 0.003}px solid ${NB_BLACK}`,
  boxShadow: `${W * 0.004}px ${W * 0.004}px 0 ${NB_BLACK}`,
  borderRadius: 0,
  ...extra,
});

const syne = (size: number, weight: 700 | 800 = 700): React.CSSProperties => ({
  fontFamily: "var(--font-syne), sans-serif",
  fontWeight: weight,
  fontSize: size,
  lineHeight: 1.0,
  letterSpacing: "-0.01em",
});

const inter = (size: number, weight: 400 | 600 = 400): React.CSSProperties => ({
  fontFamily: "var(--font-inter), sans-serif",
  fontWeight: weight,
  fontSize: size,
  lineHeight: 1.3,
});

// ─── Phone component ──────────────────────────────────────────────────────────
function Phone({ src, alt, style }: { src: string; alt: string; style?: React.CSSProperties }) {
  return (
    <div style={{ position: "relative", aspectRatio: `${MK_W}/${MK_H}`, ...style }}>
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img src="/mockup.png" alt="" style={{ display: "block", width: "100%", height: "100%" }} draggable={false} />
      <div style={{
        position: "absolute", zIndex: 10, overflow: "hidden",
        left: `${SC_L}%`, top: `${SC_T}%`, width: `${SC_W}%`, height: `${SC_H}%`,
        borderRadius: `${SC_RX}% / ${SC_RY}%`,
      }}>
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src={src} alt={alt} style={{ display: "block", width: "100%", height: "100%", objectFit: "cover", objectPosition: "top" }} draggable={false} />
      </div>
    </div>
  );
}

// ─── Caption ──────────────────────────────────────────────────────────────────
function Caption({ label, headline, dark = false }: {
  label: string; headline: React.ReactNode; dark?: boolean;
}) {
  return (
    <div>
      <div style={{
        display: "inline-block",
        background: dark ? NB_WHITE : NB_BLACK,
        color: dark ? NB_BLACK : NB_WHITE,
        ...syne(W * 0.022),
        letterSpacing: "0.12em",
        padding: `${W * 0.012}px ${W * 0.022}px`,
        marginBottom: W * 0.04,
        textTransform: "uppercase" as const,
      }}>
        {label}
      </div>
      <div style={{ color: dark ? NB_WHITE : NB_BLACK, ...syne(W * 0.095, 800) }}>
        {headline}
      </div>
    </div>
  );
}

// ─── Diagonal stripe ─────────────────────────────────────────────────────────
function Stripes({ light = false, style }: { light?: boolean; style?: React.CSSProperties }) {
  const color = light ? "rgba(255,255,255,0.07)" : "rgba(0,71,255,0.1)";
  return (
    <div style={{
      background: `repeating-linear-gradient(45deg, transparent, transparent 20px, ${color} 20px, ${color} 40px)`,
      ...style,
    }} />
  );
}

// ─── Feature pill ─────────────────────────────────────────────────────────────
function Pill({ label, accent = false }: { label: string; accent?: boolean }) {
  return (
    <div style={{
      display: "inline-flex", alignItems: "center",
      background: accent ? NB_BLUE : NB_WHITE,
      color: accent ? NB_WHITE : NB_BLACK,
      ...inter(W * 0.032, 600),
      padding: `${W * 0.018}px ${W * 0.032}px`,
      ...nb(), whiteSpace: "nowrap" as const,
    }}>
      {label}
    </div>
  );
}

// ─── Slide wrapper ────────────────────────────────────────────────────────────
function Slide({ bg, children, style }: { bg: string; children: React.ReactNode; style?: React.CSSProperties }) {
  return (
    <div style={{ width: W, height: H, background: bg, position: "relative", overflow: "hidden", fontFamily: "var(--font-syne)", ...style }}>
      {children}
    </div>
  );
}

// ═════════════════════════════════ SLIDES ════════════════════════════════════

function Slide1({ src }: { src: string }) {
  return (
    <Slide bg={NB_BG}>
      <div style={{ position: "absolute", top: 0, left: 0, right: 0, height: H * 0.006, background: NB_BLUE }} />
      <div style={{ position: "absolute", left: 0, top: 0, bottom: 0, width: W * 0.018, background: NB_BLUE }} />

      {/* App icon row */}
      <div style={{ position: "absolute", top: H * 0.055, left: W * 0.08, display: "flex", alignItems: "center", gap: W * 0.04 }}>
        <div style={{ ...nb({ borderRadius: W * 0.045 }), overflow: "hidden", flexShrink: 0 }}>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/app-icon.png" alt="Bsky Dreams" style={{ display: "block", width: W * 0.16, height: W * 0.16 }} draggable={false} />
        </div>
        <div>
          <div style={{ ...syne(W * 0.048, 800), color: NB_BLACK, textTransform: "uppercase" as const, letterSpacing: "0.04em" }}>BSKY DREAMS</div>
          <div style={{ ...inter(W * 0.028, 400), color: NB_BLACK, opacity: 0.5, marginTop: W * 0.006 }}>bskydreams.com</div>
        </div>
      </div>

      {/* Headline below icon row */}
      <div style={{ position: "absolute", top: H * 0.19, left: W * 0.08, right: W * 0.07 }}>
        <Caption label="Bluesky, redesigned" headline={<>A Different<br />Bluesky<br />Experience.</>} />
      </div>

      <Phone src={src} alt="Home feed" style={{ position: "absolute", bottom: 0, left: "50%", transform: "translateX(-50%) translateY(22%)", width: "84%" }} />
      <div style={{ position: "absolute", bottom: 0, left: 0, right: 0, height: H * 0.004, background: NB_BLACK }} />
    </Slide>
  );
}

function Slide2({ src }: { src: string }) {
  return (
    <Slide bg={NB_BLUE}>
      <Stripes light style={{ position: "absolute", inset: 0 }} />
      <div style={{ position: "absolute", top: H * 0.06, left: W * 0.08, right: W * 0.08 }}>
        <Caption label="Gallery view" headline={<>Every<br />image,<br />surfaced.</>} dark />
      </div>
      <Phone src={src} alt="Gallery" style={{ position: "absolute", bottom: 0, left: "50%", transform: "translateX(-50%) translateY(12%)", width: "84%" }} />
      <div style={{
        position: "absolute", bottom: H * 0.05, right: W * 0.06,
        width: W * 0.22, background: NB_LIME, ...nb(),
        padding: `${W * 0.018}px ${W * 0.022}px`,
        ...inter(W * 0.028, 600), color: NB_BLACK,
        textTransform: "uppercase" as const, letterSpacing: "0.08em",
      }}>Alt text<br />included</div>
    </Slide>
  );
}

function Slide3({ src }: { src: string }) {
  return (
    <Slide bg={NB_BLACK}>
      <div style={{ position: "absolute", top: 0, left: 0, right: 0, height: H * 0.008, background: NB_CORAL }} />
      <div style={{ position: "absolute", top: H * 0.06, left: W * 0.08, right: W * 0.08 }}>
        <Caption label="Bsky Dreams TV" headline={<>Scroll<br />videos.<br />Just<br />watch.</>} dark />
      </div>
      <Phone src={src} alt="TV" style={{ position: "absolute", bottom: 0, left: "50%", transform: "translateX(-50%) translateY(12%)", width: "84%" }} />
      <div style={{
        position: "absolute", bottom: H * 0.06, right: W * 0.05,
        background: NB_CORAL, ...inter(W * 0.028, 600), color: NB_WHITE,
        padding: `${W * 0.018}px ${W * 0.028}px`, textTransform: "uppercase" as const,
        letterSpacing: "0.1em", ...nb({ border: `${W * 0.003}px solid ${NB_WHITE}` }),
      }}>2× speed on hold</div>
    </Slide>
  );
}

function Slide4({ src }: { src: string }) {
  return (
    <Slide bg={NB_BG}>
      <div style={{ position: "absolute", left: 0, top: 0, bottom: 0, width: W * 0.018, background: NB_LIME }} />
      <div style={{ position: "absolute", top: H * 0.06, left: W * 0.08, right: W * 0.08 }}>
        <Caption label="Reader mode" headline={<>Articles,<br />actually<br />readable.</>} />
        <div style={{ ...inter(W * 0.034, 400), color: NB_BLACK, opacity: 0.5, marginTop: W * 0.04 }}>
          Direct · Readable · Archive
        </div>
      </div>
      <Phone src={src} alt="Reader" style={{ position: "absolute", bottom: 0, left: "50%", transform: "translateX(-50%) translateY(12%)", width: "84%" }} />
    </Slide>
  );
}

function Slide5({ src }: { src: string }) {
  return (
    <Slide bg={NB_BG}>
      <div style={{ position: "absolute", top: 0, left: 0, right: 0, height: H * 0.012, background: NB_BLACK }} />
      <div style={{ position: "absolute", top: H * 0.07, left: W * 0.08, right: W * 0.08 }}>
        <Caption label="Conversations" headline={<>Reply<br />without<br />losing<br />the thread.</>} />
      </div>
      <div style={{ position: "absolute", top: H * 0.06, right: W * 0.06, width: W * 0.1, height: W * 0.1, background: NB_BLUE, ...nb() }} />
      <Phone src={src} alt="Conversations" style={{ position: "absolute", bottom: 0, right: "-4%", transform: "translateY(16%)", width: "84%" }} />
    </Slide>
  );
}

function Slide6({ src }: { src: string }) {
  return (
    <Slide bg="#F0F4FF" style={{ background: "linear-gradient(160deg, #E8EDFF 0%, #F5F8FF 60%, #FFFDF8 100%)" }}>
      <div style={{ position: "absolute", top: H * 0.06, left: W * 0.08, right: W * 0.08 }}>
        <Caption label="Timeline view" headline={<>See posts<br />when they<br />happened.</>} />
      </div>
      <Phone src={src} alt="Timeline" style={{ position: "absolute", bottom: 0, left: "50%", transform: "translateX(-50%) translateY(12%)", width: "84%" }} />
      <Stripes style={{ position: "absolute", bottom: 0, left: 0, right: 0, height: H * 0.007 }} />
    </Slide>
  );
}

function Slide7({ src }: { src: string }) {
  return (
    <Slide bg={NB_BLACK}>
      <div style={{
        position: "absolute", top: H * 0.04, left: "50%", transform: "translateX(-50%)",
        width: W * 1.2, height: W * 1.2, borderRadius: "50%",
        background: "radial-gradient(circle, rgba(0,71,255,0.28) 0%, transparent 70%)",
        pointerEvents: "none",
      }} />
      <div style={{ position: "absolute", top: H * 0.06, left: W * 0.08, right: W * 0.08 }}>
        <Caption label="Constellation" headline={<>Map your<br />community.</>} dark />
        <div style={{ ...inter(W * 0.034, 400), color: NB_WHITE, opacity: 0.45, marginTop: W * 0.04 }}>
          Visualize who's connected
        </div>
      </div>
      <Phone src={src} alt="Constellation" style={{ position: "absolute", bottom: 0, left: "50%", transform: "translateX(-50%) translateY(12%)", width: "84%" }} />
    </Slide>
  );
}

function Slide8({ src }: { src: string }) {
  return (
    <Slide bg={NB_BG}>
      <div style={{ position: "absolute", right: 0, top: 0, bottom: 0, width: W * 0.018, background: NB_CORAL }} />
      <div style={{ position: "absolute", top: H * 0.06, left: W * 0.08, right: W * 0.1 }}>
        <Caption label="Analytics" headline={<>Know<br />your<br />reach.</>} />
      </div>
      <Phone src={src} alt="Analytics" style={{ position: "absolute", bottom: 0, left: "-4%", transform: "translateY(12%)", width: "84%" }} />
    </Slide>
  );
}

function Slide9({ src }: { src: string }) {
  return (
    <Slide bg={NB_BLUE}>
      <Stripes light style={{ position: "absolute", inset: 0 }} />
      <div style={{ position: "absolute", top: H * 0.06, left: W * 0.08, right: W * 0.08 }}>
        <Caption label="Search channels" headline={<>Save<br />searches<br />as channels.</>} dark />
      </div>
      <Phone src={src} alt="Search" style={{ position: "absolute", bottom: 0, left: "50%", transform: "translateX(-50%) translateY(12%)", width: "84%" }} />
      <div style={{
        position: "absolute", bottom: H * 0.05, left: W * 0.06,
        background: NB_LIME, color: NB_BLACK, ...inter(W * 0.028, 600),
        padding: `${W * 0.018}px ${W * 0.028}px`, textTransform: "uppercase" as const,
        letterSpacing: "0.08em", ...nb(),
      }}># saved forever</div>
    </Slide>
  );
}

function Slide10() {
  const features = [
    "Gallery view", "Bsky Dreams TV", "Reader mode",
    "Inline replies", "Conversation view", "Timeline scrubber",
    "Network constellation", "Analytics dashboard", "Search channels",
    "Direct messages", "Post composer", "GIF support",
    "Link previews", "Image lightbox", "Seen-post tracking",
  ];
  return (
    <Slide bg={NB_BLACK}>
      <div style={{ position: "absolute", top: 0, left: 0, right: 0, height: H * 0.008, background: NB_CORAL }} />
      <div style={{
        position: "absolute", top: H * 0.1, left: "50%", transform: "translateX(-50%)",
        ...nb({ borderRadius: W * 0.045, border: `${W * 0.004}px solid ${NB_WHITE}`, boxShadow: `${W * 0.006}px ${W * 0.006}px 0 ${NB_WHITE}` }),
        overflow: "hidden",
      }}>
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src="/app-icon.png" alt="Bsky Dreams" style={{ display: "block", width: W * 0.22, height: W * 0.22 }} draggable={false} />
      </div>
      <div style={{ position: "absolute", top: H * 0.33, left: W * 0.08, right: W * 0.08, textAlign: "center", ...syne(W * 0.095, 800), color: NB_WHITE }}>
        And so<br />much more.
      </div>
      <div style={{
        position: "absolute", top: H * 0.54, left: W * 0.06, right: W * 0.06,
        display: "flex", flexWrap: "wrap" as const, gap: W * 0.022, justifyContent: "center",
      }}>
        {features.map((f, i) => <Pill key={f} label={f} accent={i < 3} />)}
      </div>
      <div style={{
        position: "absolute", bottom: H * 0.06, left: 0, right: 0, textAlign: "center",
        ...inter(W * 0.032, 600), color: NB_WHITE, opacity: 0.35,
        letterSpacing: "0.1em", textTransform: "uppercase" as const,
      }}>Free to download</div>
    </Slide>
  );
}

// ─── Slide registry ────────────────────────────────────────────────────────────
type SlideEntry =
  | { id: string; label: string; Component: React.ComponentType<{ src: string }>; srcKey: string }
  | { id: string; label: string; Component: null; srcKey: null };

const SLIDES: SlideEntry[] = [
  { id: "01-hero",          label: "Hero",          Component: Slide1, srcKey: "home" },
  { id: "02-gallery",       label: "Gallery",       Component: Slide2, srcKey: "gallery" },
  { id: "03-tv",            label: "TV",            Component: Slide3, srcKey: "tv" },
  { id: "04-reader",        label: "Reader",        Component: Slide4, srcKey: "reader" },
  { id: "05-conversations", label: "Conversations", Component: Slide5, srcKey: "conversations" },
  { id: "06-timeline",      label: "Timeline",      Component: Slide6, srcKey: "timeline" },
  { id: "07-constellation", label: "Constellation", Component: Slide7, srcKey: "constellation" },
  { id: "08-analytics",     label: "Analytics",     Component: Slide8, srcKey: "analytics" },
  { id: "09-channels",      label: "Channels",      Component: Slide9, srcKey: "search" },
  { id: "10-more",          label: "More",          Component: null,   srcKey: null },
];

type ExportSize = { label: string; w: number; h: number };
const EXPORT_SIZES: ExportSize[] = [
  { label: '6.9"', w: 1320, h: 2868 },
  { label: '6.5"', w: 1284, h: 2778 },
  { label: '6.3"', w: 1206, h: 2622 },
  { label: '6.1"', w: 1125, h: 2436 },
];

// ─── Preview card ─────────────────────────────────────────────────────────────
function ScreenshotPreview({ id, children, onExport }: {
  id: string; children: React.ReactNode; onExport: (id: string) => void;
}) {
  const containerRef = useRef<HTMLDivElement>(null);
  const [scale, setScale] = useState(1);

  useEffect(() => {
    if (!containerRef.current) return;
    const ro = new ResizeObserver((entries) => {
      setScale(entries[0].contentRect.width / W);
    });
    ro.observe(containerRef.current);
    return () => ro.disconnect();
  }, []);

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
      <div
        ref={containerRef}
        onClick={() => onExport(id)}
        title="Click to export"
        style={{ width: "100%", aspectRatio: `${W}/${H}`, position: "relative", overflow: "hidden", border: "2px solid #ccc", cursor: "pointer" }}
      >
        <div style={{ position: "absolute", top: 0, left: 0, width: W, height: H, transformOrigin: "top left", transform: `scale(${scale})` }}>
          {children}
        </div>
      </div>
      <button
        onClick={() => onExport(id)}
        style={{ fontFamily: "var(--font-syne)", fontWeight: 700, fontSize: 12, textTransform: "uppercase", letterSpacing: "0.08em", padding: "8px", background: NB_BLACK, color: NB_WHITE, border: "none", cursor: "pointer" }}
      >
        Export
      </button>
    </div>
  );
}

// ─── Main page ─────────────────────────────────────────────────────────────────
export default function ScreenshotsPage() {
  const [size, setSize] = useState<ExportSize>(EXPORT_SIZES[0]);
  const [exporting, setExporting] = useState(false);
  const offscreenRefs = useRef<Map<string, HTMLDivElement>>(new Map());

  const renderSlide = (slide: SlideEntry) => {
    if (slide.Component === null) return <Slide10 />;
    const src = `/screenshots/${slide.srcKey}.png`;
    return <slide.Component src={src} />;
  };

  const captureSlide = useCallback(async (el: HTMLDivElement, filename: string) => {
    el.style.left = "0px";
    el.style.opacity = "1";
    el.style.zIndex = "1";

    const opts = { width: W, height: H, pixelRatio: 1, cacheBust: true };
    await toPng(el, opts); // warm-up
    const dataUrl = await toPng(el, opts);

    el.style.left = "-9999px";
    el.style.opacity = "0";
    el.style.zIndex = "-1";

    const img = new window.Image();
    img.src = dataUrl;
    await new Promise<void>((r) => { img.onload = () => r(); });

    const canvas = document.createElement("canvas");
    canvas.width  = size.w;
    canvas.height = size.h;
    canvas.getContext("2d")!.drawImage(img, 0, 0, size.w, size.h);

    const a = document.createElement("a");
    a.href = canvas.toDataURL("image/png");
    a.download = filename;
    a.click();
  }, [size]);

  const handleExport = useCallback(async (slideId: string) => {
    const el = offscreenRefs.current.get(slideId);
    if (!el) return;
    setExporting(true);
    try { await captureSlide(el, `${slideId}-${size.w}x${size.h}.png`); }
    finally { setExporting(false); }
  }, [captureSlide, size]);

  const handleExportAll = useCallback(async () => {
    setExporting(true);
    try {
      for (const slide of SLIDES) {
        const el = offscreenRefs.current.get(slide.id);
        if (!el) continue;
        await captureSlide(el, `${slide.id}-${size.w}x${size.h}.png`);
        await new Promise((r) => setTimeout(r, 300));
      }
    } finally { setExporting(false); }
  }, [captureSlide, size]);

  return (
    <div style={{ background: "#F0F0F0", minHeight: "100vh", padding: 24 }}>
      {/* Toolbar */}
      <div style={{ display: "flex", alignItems: "center", gap: 16, marginBottom: 20, background: NB_WHITE, border: `2px solid ${NB_BLACK}`, padding: "12px 16px" }}>
        <span style={{ fontFamily: "var(--font-syne)", fontWeight: 700, fontSize: 14, textTransform: "uppercase", letterSpacing: "0.08em" }}>
          Bsky Dreams Screenshots
        </span>
        <select
          value={size.label}
          onChange={(e) => setSize(EXPORT_SIZES.find((s) => s.label === e.target.value) ?? EXPORT_SIZES[0])}
          style={{ fontFamily: "var(--font-inter)", fontSize: 13, padding: "6px 10px", border: `2px solid ${NB_BLACK}`, borderRadius: 0 }}
        >
          {EXPORT_SIZES.map((s) => (
            <option key={s.label} value={s.label}>{s.label} — {s.w}×{s.h}</option>
          ))}
        </select>
        <button
          onClick={handleExportAll}
          disabled={exporting}
          style={{ fontFamily: "var(--font-syne)", fontWeight: 700, fontSize: 12, textTransform: "uppercase", letterSpacing: "0.08em", padding: "8px 20px", background: exporting ? "#999" : NB_BLUE, color: NB_WHITE, border: `2px solid ${NB_BLACK}`, cursor: exporting ? "wait" : "pointer", boxShadow: `3px 3px 0 ${NB_BLACK}` }}
        >
          {exporting ? "Exporting…" : "Export All"}
        </button>
        <span style={{ fontFamily: "var(--font-inter)", fontSize: 12, color: "#666" }}>
          Click any slide to export individually
        </span>
      </div>

      {/* Screenshot placement guide */}
      <div style={{ background: NB_LIME, border: `2px solid ${NB_BLACK}`, padding: "10px 16px", marginBottom: 24, fontFamily: "var(--font-inter)", fontSize: 13, color: NB_BLACK, lineHeight: 1.6 }}>
        <strong>Add your screenshots:</strong> Drop PNGs into <code style={{ background: "rgba(0,0,0,0.1)", padding: "1px 5px" }}>public/screenshots/</code> named:{" "}
        {["home", "gallery", "tv", "reader", "conversations", "timeline", "constellation", "analytics", "search"].map((n) => (
          <code key={n} style={{ background: "rgba(0,0,0,0.1)", padding: "1px 5px", marginRight: 4 }}>{n}.png</code>
        ))}
      </div>

      {/* Grid */}
      <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(220px, 1fr))", gap: 20 }}>
        {SLIDES.map((slide) => (
          <div key={slide.id}>
            <div style={{ fontFamily: "var(--font-syne)", fontWeight: 700, fontSize: 11, textTransform: "uppercase", letterSpacing: "0.1em", marginBottom: 6, color: "#444" }}>
              {slide.id.split("-")[0]}. {slide.label}
            </div>
            <ScreenshotPreview id={slide.id} onExport={handleExport}>
              {renderSlide(slide)}
            </ScreenshotPreview>
          </div>
        ))}
      </div>

      {/* Offscreen export containers */}
      <div style={{ position: "fixed", top: 0, left: "-9999px", opacity: 0, pointerEvents: "none" }}>
        {SLIDES.map((slide) => (
          <div
            key={slide.id}
            ref={(el) => { if (el) offscreenRefs.current.set(slide.id, el); }}
            style={{ width: W, height: H, position: "absolute", left: "-9999px", top: 0, fontFamily: "var(--font-syne), sans-serif" }}
          >
            {renderSlide(slide)}
          </div>
        ))}
      </div>
    </div>
  );
}
