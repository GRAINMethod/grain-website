export default function NotFound() {
  return (
    <main style={{ minHeight: "100vh", display: "grid", placeItems: "center", padding: "2rem", textAlign: "center" }}>
      <div>
        <p style={{ fontFamily: "JetBrains Mono, monospace", fontSize: 12, letterSpacing: "0.18em", color: "#9AAF7A", textTransform: "uppercase" }}>404</p>
        <h1 style={{ fontSize: "clamp(2rem, 5vw, 3.5rem)", fontWeight: 800, letterSpacing: "-0.03em", margin: "0.5rem 0 1rem" }}>This page went unanswered.</h1>
        <p style={{ color: "rgba(240,236,223,0.7)", maxWidth: 420, margin: "0 auto 2rem" }}>The link may be old. Everything GRAIN does starts from the homepage.</p>
        <a href="/" style={{ display: "inline-block", background: "#9AAF7A", color: "#1C2420", padding: "14px 22px", fontWeight: 700, textDecoration: "none" }}>Go to grainmethod.com</a>
      </div>
    </main>
  );
}
