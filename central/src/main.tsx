import React from 'react';
import ReactDOM from 'react-dom/client';
import { HashRouter } from 'react-router-dom';
import App from './App';
import './index.css';
import { installSearchableSelectEnhancer } from './ui/searchableSelectEnhancer';

// เปิดใช้งานช่องค้นหาใน Dropdown (<select>) ทุกจุดทั่วทั้งระบบ
installSearchableSelectEnhancer();

// ใช้ HashRouter เพราะ GitHub Pages ไม่มี rewrite — เปิดลิงก์ย่อยตรง ๆ แล้วไม่ 404
ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <HashRouter>
      <App />
    </HashRouter>
  </React.StrictMode>,
);
