/** @type {import('tailwindcss').Config} */
// ดีไซน์เว็บส่วนกลาง (แบบ A: ขาวเรียบ) — สีหลักคือ brand (ม่วงคราม) ตัวอักษร ink
export default {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      fontFamily: {
        sans: ['Sarabun', 'system-ui', 'sans-serif'],
        // ตัวอย่างเอกสารราชการ (หัวใบลา) — ตรงกับแบบฟอร์มจริง
        doc: ['Sarabun', '"TH Sarabun New"', 'Tahoma', 'sans-serif'],
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
        line: '#eceef2',
      },
      boxShadow: {
        card: '0 1px 2px rgba(15, 23, 42, 0.04)',
      },
    },
  },
  plugins: [],
};
