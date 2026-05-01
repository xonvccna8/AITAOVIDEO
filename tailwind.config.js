/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      fontFamily: {
        sans: [
          "Inter",
          "ui-sans-serif",
          "system-ui",
          "Segoe UI",
          "Roboto",
          "Arial",
          "sans-serif",
        ],
      },
      backgroundImage: {
        mesh:
          "radial-gradient(circle at 12% 12%, rgba(45, 212, 191, 0.35), transparent 30%), radial-gradient(circle at 82% 8%, rgba(251, 113, 133, 0.28), transparent 32%), radial-gradient(circle at 88% 78%, rgba(251, 191, 36, 0.24), transparent 30%), linear-gradient(135deg, #06111f 0%, #0d1b2a 42%, #102a43 100%)",
      },
      boxShadow: {
        glass: "0 20px 70px rgba(2, 8, 23, 0.32)",
        glow: "0 18px 50px rgba(45, 212, 191, 0.2)",
      },
    },
  },
  plugins: [],
};
