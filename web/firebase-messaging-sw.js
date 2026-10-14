// Service worker de notificaciones push para la versión web.
// Debe vivir en la raíz del sitio (web/) con este nombre exacto.
importScripts("https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyAv4NTSMLxVFjCkhMIadMMcMFTxf9SYPVc",
  authDomain: "bidstream-656cf.firebaseapp.com",
  projectId: "bidstream-656cf",
  storageBucket: "bidstream-656cf.firebasestorage.app",
  messagingSenderId: "454079777397",
  appId: "1:454079777397:web:551228d3b459e34e21463c",
});

// Con la pestaña cerrada o en segundo plano, Firebase muestra la
// notificación automáticamente con el título/cuerpo enviados por el servidor.
firebase.messaging();
