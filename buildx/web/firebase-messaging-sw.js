// Firebase Cloud Messaging service worker for Momentum web.
//
// Required for background push — i.e. when this tab isn't focused or the
// browser is fully closed. Must live at the web root
// (web/firebase-messaging-sw.js -> served as /firebase-messaging-sw.js) so
// it registers at scope "/". This runs in a separate worker context with no
// access to the rest of the app, so it re-initializes its own Firebase app
// using the same web config as lib/firebase_options.dart.

importScripts('https://www.gstatic.com/firebasejs/10.13.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.1/firebase-messaging-compat.js');

firebase.initializeApp({
    apiKey: 'AIzaSyAGzKf2uGgjdxDMOMwkigmxczQU8RQLWgE',
    appId: '1:213940967151:web:530f3e6d1ebcdb729fad1a',
    messagingSenderId: '213940967151',
    projectId: 'momentum-51138',
    authDomain: 'momentum-51138.firebaseapp.com',
    storageBucket: 'momentum-51138.firebasestorage.app',
});

const messaging = firebase.messaging();

// The backend always sends a `notification` payload (see
// backend/src/services/notificationService.ts), so the browser shows the
// system notification automatically with no code needed here. This handler
// is just for logging / future custom data-message handling.
messaging.onBackgroundMessage((payload) => {
    console.log('[firebase-messaging-sw.js] background message', payload);
});

// Focus (or open) the app when the user clicks a background notification.
self.addEventListener('notificationclick', (event) => {
    event.notification.close();
    event.waitUntil(
        clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windowClients) => {
            for (const client of windowClients) {
                if ('focus' in client) return client.focus();
            }
            if (clients.openWindow) return clients.openWindow('/');
        })
    );
});