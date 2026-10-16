// tailwindcss/nesting: CSS เดิม (legacy.css) ห่อไว้ใต้ .legacy แบบซ้อน — คอมไพล์เป็น
// ตัวเลือกธรรมดาให้เบราว์เซอร์รุ่นเก่าอ่านได้
export default {
  plugins: {
    'tailwindcss/nesting': {},
    tailwindcss: {},
    autoprefixer: {},
  },
};
