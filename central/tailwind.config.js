/** @type {import('tailwindcss').Config} */
// ดีไซน์เว็บส่วนกลาง (แบบ A: ขาวเรียบ) — สีหลักคือ brand (ม่วงคราม) ตัวอักษร ink
export default {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      fontFamily: {
        sans: ['"Noto Sans Thai"', 'system-ui', 'sans-serif'],
        // ตัวอย่างเอกสารราชการ (หัวใบลา) — ตรงกับแบบฟอร์มจริง
        doc: ['Sarabun', '"TH Sarabun New"', 'Tahoma', 'sans-serif'],
      },
      colors: {
        brand: {
          50: '#eef2ff',
          100: '#e0e7ff',
          200: '#c7d2fe',
          500: '#6366f1',
          600: '#4f46e5',
          700: '#4338ca',
        },
        ink: '#0f172a',
        canvas: '#f7f8fa',
        line: '#eceef2',
      },
      boxShadow: {
        card: '0 1px 2px rgba(15, 23, 42, 0.04)',
      },
    },
  },
  plugins: [],
};
