// tailwindcss/nesting: designer.css (ตัวออกแบบแบบฟอร์ม) เขียนกฎแบบซ้อน — คอมไพล์เป็น
// ตัวเลือกธรรมดาให้เบราว์เซอร์รุ่นเก่าอ่านได้
export default {
  plugins: {
    'tailwindcss/nesting': {},
    tailwindcss: {},
    autoprefixer: {},
  },
};
