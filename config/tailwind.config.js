// Design tokens live in app/assets/stylesheets/application.tailwind.css as CSS variables, so the
// whole app can switch between "Papier" (light) and "Nuit" (dark) without touching any markup.
const ramp = (name) =>
  Object.fromEntries(
    [50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 950].map((n) => [n, `rgb(var(--${name}-${n}) / <alpha-value>)`])
  )

module.exports = {
  darkMode: "class", // unused on purpose: themes are driven by the variables, not by `dark:` variants
  content: [
    "./app/views/**/*.{erb,html}",
    "./app/helpers/**/*.rb",
    "./app/javascript/**/*.{js,mjs,ts,tsx}"
  ],
  theme: {
    extend: {
      colors: {
        // neutral, warm ramp: page = ink-50, borders = ink-200, text = ink-900
        ink: ramp("ink"),
        accent: ramp("accent"), // the blue of the lettering on the paper calendar
        amber: ramp("amber"), //  month 1: yellow
        rose: ramp("rose"), //    month 2: pink
        sky: ramp("sky"), //      month 3: blue
        red: ramp("red"), //      danger
        paper: "rgb(var(--paper) / <alpha-value>)" // card / surface
      },
      fontFamily: {
        display: ['"Iowan Old Style"', '"Palatino Linotype"', '"Book Antiqua"', "Palatino", "Georgia", "serif"],
        sans: ['"Avenir Next"', '"Segoe UI"', "system-ui", "-apple-system", "Roboto", '"Helvetica Neue"', "sans-serif"]
      }
    }
  },
  safelist: [
    // built dynamically in app/helpers/episodes_helper.rb
    "bg-amber-100", "bg-amber-200", "bg-rose-100", "bg-rose-200", "bg-sky-100", "bg-sky-200",
    "border-amber-300", "border-rose-300", "border-sky-300",
    "text-amber-800", "text-rose-800", "text-sky-800",
    "opacity-40"
  ],
  plugins: []
}
