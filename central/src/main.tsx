import React from 'react';
import ReactDOM from 'react-dom/client';
import { HashRouter } from 'react-router-dom';
import App from './App';
import './styles.css';

// ใช้ HashRouter เพราะ GitHub Pages ไม่มี rewrite — เปิดลิงก์ย่อยตรง ๆ แล้วไม่ 404
ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <HashRouter>
      <App />
    </HashRouter>
  </React.StrictMode>,
);
