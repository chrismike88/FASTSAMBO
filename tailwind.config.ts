import type { Config } from "tailwindcss";

const config: Config = {
  content: ["./app/**/*.{ts,tsx}", "./components/**/*.{ts,tsx}", "./lib/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        navy: { 900: "#061A2E", 800: "#0B2E4F", 700: "#123E68", 600: "#17517F" },
        sky: { 500: "#1273B8", 400: "#24A5D9", 300: "#5BC0E8" },
        ok: "#16A34A",
        warn: "#F59E0B",
        late: "#EA7317",
        bad: "#DC2626",
      },
      fontFamily: {
        sans: ["var(--font-sans)", "system-ui", "sans-serif"],
      },
      boxShadow: {
        card: "0 1px 2px rgba(6,26,46,.06), 0 8px 24px -12px rgba(6,26,46,.22)",
      },
    },
  },
  plugins: [],
};
export default config;
