import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// เว็บนี้ถูกวางไว้ใต้แอป Flutter ที่ /central/ ของ hosting เดียวกัน
//   GitHub Pages:     omkub.github.io/koragoch/central/  (ค่านี้)
//   Firebase Hosting: rbp-chanikarnn.web.app/central/     (npm run build -- --base /central/)
// ดู .github/workflows/deploy-pages.yml และ deploy-firebase.yml
export default defineConfig({
  base: '/koragoch/central/',
  plugins: [react()],
});
