import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// เว็บนี้ถูกวางไว้ใต้แอป Flutter บน GitHub Pages: omkub.github.io/koragoch/central/
// (ดูขั้นตอน "Build เว็บผู้ดูแลส่วนกลาง" ใน .github/workflows/deploy-pages.yml)
export default defineConfig({
  base: '/koragoch/central/',
  plugins: [react()],
});
