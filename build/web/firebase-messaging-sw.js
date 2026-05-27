importScripts("https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js");

firebase.initializeApp({
    apiKey: 'AIzaSyDCNlen91m6zNNU6rjPSj21_Xtt8XGcJ4A',
    appId: '1:157007901610:web:89175efb24b84106fd71d3',
    messagingSenderId: '157007901610',
    projectId: 'pivotal-racer-496313-v2',
    authDomain: 'pivotal-racer-496313-v2.firebaseapp.com',
    storageBucket: 'pivotal-racer-496313-v2.firebasestorage.app',
    measurementId: 'G-VP1D4JD8P0',
});

const messaging = firebase.messaging();