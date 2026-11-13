/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      fontFamily: {
        sans: ['Sarabun', 'system-ui', 'sans-serif'],
      },
      colors: {
        brand: {
          50: '#eef1f8',
          100: '#e1e6f1',
          200: '#c3cde4',
          500: '#2a4a9c',
          600: '#1e3a8a',
          700: '#172e6e',
        },
        ink: '#0f172a',
        canvas: '#f7f8fa',
        line: '#e6e8ee',
      },
      boxShadow: {
        card: '0 1px 2px rgba(15, 23, 42, 0.04)',
      },
    },
  },
  plugins: [],
};
