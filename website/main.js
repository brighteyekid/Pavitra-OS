// ============================================================
// INITIALIZATION
// ============================================================
gsap.registerPlugin(ScrollTrigger);

const lenis = new Lenis({
  duration: 1.6,
  easing: (t) => Math.min(1, 1.001 - Math.pow(2, -10 * t)),
  smoothWheel: true,
  smoothTouch: false,
  wheelMultiplier: 0.85,
  touchMultiplier: 1.5,
});

gsap.ticker.add((time) => { lenis.raf(time * 1000); });
gsap.ticker.lagSmoothing(0);
lenis.on('scroll', ScrollTrigger.update);
ScrollTrigger.defaults({ scroller: window });

// Scroll Progress Bar
const progressBar = document.getElementById('scroll-progress-bar');
lenis.on('scroll', (e) => {
  const progress = e.progress * 100;
  progressBar.style.height = `${progress}%`;
  
  // Hide scroll prompt in boot section when scrolling starts
  if (e.scroll > 50) {
    gsap.to('#boot-scroll', { opacity: 0, duration: 0.3 });
  } else {
    gsap.to('#boot-scroll', { opacity: 1, duration: 0.3 });
  }
});

// ============================================================
// CURSOR
// ============================================================
const cursor = document.getElementById('cursor');
const xTo = gsap.quickTo(cursor, "x", {duration: 0.08, ease: "power3"});
const yTo = gsap.quickTo(cursor, "y", {duration: 0.08, ease: "power3"});

window.addEventListener("mousemove", (e) => {
  xTo(e.clientX);
  yTo(e.clientY);
});

const interactiveElements = document.querySelectorAll('a, button, .btn');
interactiveElements.forEach(el => {
  el.addEventListener('mouseenter', () => {
    gsap.to(cursor, { scale: 1.8, opacity: 0.6, duration: 0.3 });
  });
  el.addEventListener('mouseleave', () => {
    gsap.to(cursor, { scale: 1, opacity: 1, duration: 0.3 });
  });
});

const logos = document.querySelectorAll('#boot-logo, #phil-logo-center');
logos.forEach(logo => {
  logo.addEventListener('mouseenter', () => {
    gsap.to(cursor, { rotation: 45, duration: 0.3 });
  });
  logo.addEventListener('mouseleave', () => {
    gsap.to(cursor, { rotation: 0, duration: 0.3 });
  });
});

// ============================================================
// CLOCK
// ============================================================
const clockEl = document.getElementById('clock');
function updateClock() {
  const now = new Date();
  const h = String(now.getHours()).padStart(2, '0');
  const m = String(now.getMinutes()).padStart(2, '0');
  const s = String(now.getSeconds()).padStart(2, '0');
  clockEl.textContent = `${h}:${m}:${s}`;
}
setInterval(updateClock, 1000);
updateClock();

// ============================================================
// SPLIT TEXT UTILITIES
// ============================================================
function splitTextByChar(element) {
  const text = element.innerText;
  element.innerHTML = '';
  return text.split('').map(char => {
    const span = document.createElement('span');
    span.className = 'char';
    if (char === ' ') {
      span.innerHTML = '&nbsp;';
    } else {
      span.innerText = char;
    }
    element.appendChild(span);
    return span;
  });
}

function splitTextByWord(element) {
  const text = element.innerText;
  element.innerHTML = '';
  return text.split(' ').map(word => {
    const wrap = document.createElement('span');
    wrap.className = 'word';
    const inner = document.createElement('span');
    inner.className = 'char'; // re-use char class for animations
    inner.innerText = word + ' ';
    wrap.appendChild(inner);
    element.appendChild(wrap);
    return inner;
  });
}

// ============================================================
// GLOBAL ANIMATIONS
// ============================================================
ScrollTrigger.batch(".reveal-section-label", {
  start: "top 80%",
  onEnter: (elements) => {
    elements.forEach(el => {
      const line = el.querySelector('.section-label-line');
      const text = el.querySelector('.section-label');
      
      const tl = gsap.timeline();
      tl.to(line, { width: 60, duration: 0.4, ease: "power2.out" })
        .to(text, { opacity: 1, duration: 0.2, ease: "power1.inOut" }, "-=0.1");
    });
  }
});

ScrollTrigger.batch(".reveal-line", {
  start: "top 80%",
  onEnter: (elements) => {
    gsap.to(elements, {
      y: 0,
      duration: 1,
      ease: "expo.out",
      stagger: 0.15
    });
  }
});

ScrollTrigger.batch(".reveal-fade", {
  start: "top 80%",
  onEnter: (elements) => {
    gsap.to(elements, {
      opacity: 1,
      y: 0,
      duration: 0.8,
      ease: "power2.out",
      stagger: 0.1
    });
  }
});

ScrollTrigger.batch(".line-draw", {
  start: "top 80%",
  onEnter: (elements) => {
    gsap.to(elements, {
      scaleX: 1,
      duration: 0.8,
      ease: "power3.out",
      stagger: 0.1
    });
  }
});

// Bouncing arrow
gsap.to('#boot-arrow', {
  y: 10,
  repeat: -1,
  yoyo: true,
  ease: "power1.inOut",
  duration: 0.8
});

// ============================================================
// SECTION 01 — BOOT
// ============================================================

function startBootAnimation() {
  const tl = gsap.timeline();

  // 1. Red progress bar
  tl.to('#boot-progress-bar', { width: '100%', duration: 2.2, ease: "power2.out" })
    .to('#boot-progress-bar', { opacity: 0, duration: 0.3 }, "+=0.2");

  // 2. SVG Logo drawing
  const svgPaths = document.querySelectorAll('#pavitra-logo-boot path, #pavitra-logo-boot circle, #pavitra-logo-boot polygon, #pavitra-logo-boot line');
  svgPaths.forEach(path => {
    const length = path.getTotalLength();
    path.style.strokeDasharray = length;
    path.style.strokeDashoffset = length;
  });

  tl.to(svgPaths, {
    strokeDashoffset: 0,
    duration: 2.5,
    ease: "power2.inOut",
    stagger: 0.12
  }, "-=1.5");



  // 6. Section label
  tl.to('#boot-label', { opacity: 1, duration: 0.6 }, "-=0.4");
}

// ============================================================
// BOOTSPLASH
// ============================================================
const bootLogs = [
  "[    0.000000] Linux version 6.1.0-48-amd64 (debian-kernel@lists.debian.org)",
  "[    0.000000] Command line: BOOT_IMAGE=/boot/vmlinuz-6.1.0-48-amd64 root=UUID=xxxx ro quiet splash",
  "[    0.021345] x86/cpu: Secure Memory Encryption (SME) configured",
  "[  <span class='bootsplash-ok'>OK</span>  ] Found device /dev/sda1.",
  "[  <span class='bootsplash-ok'>OK</span>  ] Mounted Root File System.",
  "[  <span class='bootsplash-ok'>OK</span>  ] Reached target Local File Systems.",
  "         Starting <span class='bootsplash-dim'>udev Kernel Device Manager</span>...",
  "[  <span class='bootsplash-ok'>OK</span>  ] Started <span class='bootsplash-dim'>udev Kernel Device Manager</span>.",
  "         Starting <span class='bootsplash-dim'>Network Time Synchronization</span>...",
  "[  <span class='bootsplash-ok'>OK</span>  ] Started <span class='bootsplash-dim'>Network Time Synchronization</span>.",
  "[  <span class='bootsplash-ok'>OK</span>  ] Reached target Network.",
  "         Starting <span class='bootsplash-dim'>Pavitra OS Core Services</span>...",
  "[  <span class='bootsplash-ok'>OK</span>  ] Started <span class='bootsplash-dim'>Waydroid Container Bridge</span>.",
  "[  <span class='bootsplash-ok'>OK</span>  ] Started <span class='bootsplash-dim'>Darling macOS Translation Layer</span>.",
  "[  <span class='bootsplash-ok'>OK</span>  ] Started <span class='bootsplash-dim'>Wine Windows Compatibility Layer</span>.",
  "[  <span class='bootsplash-ok'>OK</span>  ] Reached target <span class='bootsplash-ok'>Multi-Ecosystem Compatibility</span>.",
  "[  <span class='bootsplash-warn'>WARN</span> ] systemd-vconsole-setup.service failed.",
  "         Starting <span class='bootsplash-dim'>LightDM Display Manager</span>...",
  "[  <span class='bootsplash-ok'>OK</span>  ] Started <span class='bootsplash-dim'>LightDM Display Manager</span>.",
  "[  <span class='bootsplash-ok'>OK</span>  ] Reached target Graphical Interface.",
  "         Starting Pavitra OS User Session..."
];

window.addEventListener('load', () => {
  const bootsplashContent = document.getElementById('bootsplash-content');
  const bootsplash = document.getElementById('bootsplash');
  
  if (!bootsplash || !bootsplashContent) {
    startBootAnimation();
    return;
  }

  let logIndex = 0;

  function showNextLog() {
    if (logIndex >= bootLogs.length) {
      setTimeout(() => {
        gsap.to(bootsplash, { 
          opacity: 0, 
          duration: 0.8, 
          ease: "power2.inOut",
          onComplete: () => {
            bootsplash.remove();
            startBootAnimation();
          }
        });
      }, 600);
      return;
    }

    const div = document.createElement('div');
    div.className = 'bootsplash-line';
    div.innerHTML = bootLogs[logIndex];
    bootsplashContent.appendChild(div);
    
    if (bootsplashContent.children.length > 25) {
      bootsplashContent.removeChild(bootsplashContent.firstChild);
    }

    logIndex++;
    
    const delay = Math.random() * 60 + 10;
    
    if (bootLogs[logIndex - 1].includes("Starting")) {
      setTimeout(showNextLog, delay + 200);
    } else {
      setTimeout(showNextLog, delay);
    }
  }

  // Start sequence
  setTimeout(showNextLog, 300);
});

// Pin and fade out hero
ScrollTrigger.create({
  trigger: "#boot",
  start: "top top",
  end: "+=50%",
  pin: true,
  pinSpacing: false,
  animation: gsap.to('.boot-center', {
    scale: 0.4,
    opacity: 0,
    ease: "power1.inOut"
  }),
  scrub: true
});

// ============================================================
// SECTION 02 — MANIFESTO
// ============================================================
// Metrics reveal
ScrollTrigger.batch('.reveal-metric', {
  start: "top 75%",
  onEnter: (elements) => {
    elements.forEach((el, index) => {
      const line = el.querySelector('.metric-line-draw');
      const text = el.querySelector('.metric-text');
      
      const tl = gsap.timeline({ delay: index * 0.1 });
      tl.to(line, { width: '100%', duration: 0.5, ease: "power2.out" })
        .to(text, { opacity: 1, duration: 0.3 }, "-=0.2");
    });
  }
});

// ============================================================
// SECTION 03 — PHILOSOPHY
// ============================================================
const philSection = document.getElementById('philosophy');
const watermark = document.getElementById('logo-watermark');

// Setup philosophy connectors
gsap.set('.phil-connector--top', { height: 0, top: 'auto', bottom: -90 });
gsap.set('.phil-connector--bottom', { height: 0 });
gsap.set('.phil-connector--left', { width: 0, left: 'auto', right: -90 });
gsap.set('.phil-connector--right', { width: 0 });

const philTl = gsap.timeline({
  scrollTrigger: {
    trigger: "#philosophy",
    start: "top top",
    end: "+=250%", // reduced for better pacing and spacing
    pin: true,
    scrub: true
  }
});

// Ambient breathing effect for the logo (subtle scale)
gsap.to('.phil-logo-center', {
  scale: 1.05,
  repeat: -1,
  yoyo: true,
  ease: "sine.inOut",
  duration: 4
});

// Setup SVG paths for scroll-driven drawing
const philPaths = document.querySelectorAll('#pavitra-logo-phil path, #pavitra-logo-phil circle, #pavitra-logo-phil polygon, #pavitra-logo-phil line');
philPaths.forEach(path => {
  const length = path.getTotalLength();
  path.style.strokeDasharray = length;
  path.style.strokeDashoffset = length;
});

// Set initial offset for elegant sliding reveal
gsap.set('#phil-pure', { y: 20 });
gsap.set('#phil-sovereign', { y: -20 });
gsap.set('#phil-open', { x: 20 });
gsap.set('#phil-unified', { x: -20 });

// Draw the logo beautifully across the scroll sequence
philTl.to(philPaths, {
  strokeDashoffset: 0,
  duration: 0.8,
  ease: "none",
  stagger: 0.02
}, 0);

// Chapter 1: Top
philTl.to('#phil-pure', { opacity: 1, y: 0, duration: 0.15, ease: "power2.out" }, 0.1)
      .to('.phil-connector--top', { height: 40, duration: 0.15, ease: "power2.out" }, 0.1);

// Chapter 2: Right
philTl.to('#phil-unified', { opacity: 1, x: 0, duration: 0.15, ease: "power2.out" }, 0.3)
      .to('.phil-connector--right', { width: 40, duration: 0.15, ease: "power2.out" }, 0.3);

// Chapter 3: Bottom
philTl.to('#phil-sovereign', { opacity: 1, y: 0, duration: 0.15, ease: "power2.out" }, 0.5)
      .to('.phil-connector--bottom', { height: 40, duration: 0.15, ease: "power2.out" }, 0.5);

// Chapter 4: Left
philTl.to('#phil-open', { opacity: 1, x: 0, duration: 0.15, ease: "power2.out" }, 0.7)
      .to('.phil-connector--left', { width: 40, duration: 0.15, ease: "power2.out" }, 0.7);

// Chapter 5: Ethereal glow completion (no rotation)
philTl.to('.phil-logo-center', {
  filter: "drop-shadow(0px 0px 20px rgba(255,255,255,0.6))",
  duration: 0.1,
  ease: "power2.inOut"
}, 0.9);

// Watermark transition on exit
ScrollTrigger.create({
  trigger: "#philosophy",
  start: "bottom bottom",
  onEnter: () => {
    gsap.to(watermark, { opacity: 1, duration: 0.5 });
  },
  onLeaveBack: () => {
    gsap.to(watermark, { opacity: 0, duration: 0.5 });
  }
});


// ============================================================
// SECTION 04 — LAYERS
// ============================================================
const cards = document.querySelectorAll('.layer-card');
cards.forEach((card, i) => {
  const isEven = i % 2 !== 0;
  gsap.set(card, { x: isEven ? 80 : -80 });
  
  ScrollTrigger.create({
    trigger: card,
    start: "top 85%",
    onEnter: () => {
      gsap.to(card, {
        x: 0,
        opacity: 1,
        duration: 0.9,
        ease: "power3.out"
      });
    }
  });
});

// ============================================================
// SECTION 05 — ARCHITECTURE
// ============================================================
const archRows = gsap.utils.toArray('.arch-row');
archRows.reverse(); // Draw from bottom to top

ScrollTrigger.create({
  trigger: ".arch-diagram",
  start: "top 80%",
  onEnter: () => {
    archRows.forEach((row, i) => {
      const line = row.querySelector('.arch-row-line');
      
      const tl = gsap.timeline({ delay: i * 0.12 });
      tl.fromTo(row, { y: 30, opacity: 0 }, { y: 0, opacity: 1, duration: 0.8, ease: "power2.out" })
        .to(line, { width: '100%', duration: 0.6, ease: "power2.out" }, "-=0.6");
        
      // Annotation on row 5
      if (row.id === 'ar5') {
        const annText = row.querySelector('.arch-ann-text');
        const annLine = row.querySelector('.arch-ann-line');
        const annWrap = row.querySelector('.arch-annotation');
        
        tl.to(annWrap, { opacity: 1, duration: 0.1 }, "-=0.4")
          .fromTo(annLine, { scaleX: 0, transformOrigin: 'left' }, { scaleX: 1, duration: 0.5, ease: "power2.out" }, "-=0.4")
          .fromTo(annText, { opacity: 0, x: -10 }, { opacity: 1, x: 0, duration: 0.3 }, "-=0.1");
      }
    });
  }
});

// ============================================================
// SECTION 06 — TERMINAL
// ============================================================
const terminalLines = [
  "root@pavitra:~$ pavitra --version",
  "PAVITRA OS v1.0.0 — Debian 12 (Bookworm) x86_64\n",
  "root@pavitra:~$ pavitra launch photoshop.exe",
  "<span class='term-dim'>[■] Resolving compatibility layer... WINE</span>",
  "<span class='term-dim'>[■] Mounting virtual filesystem...</span>",
  "<span class='term-green'>[✓] Launching photoshop.exe</span>\n",
  "root@pavitra:~$ pavitra launch garageband.app",
  "<span class='term-dim'>[■] Resolving compatibility layer... DARLING</span>",
  "<span class='term-green'>[✓] Launching garageband.app</span>\n",
  "root@pavitra:~$ pavitra launch com.whatsapp.apk",
  "<span class='term-dim'>[■] Resolving compatibility layer... WAYDROID</span>",
  "<span class='term-green'>[✓] Launching com.whatsapp.apk</span>\n",
  "root@pavitra:~$ "
];

const terminalOutput = document.getElementById('terminal-output');
let terminalTyped = false;

ScrollTrigger.create({
  trigger: "#terminal-section",
  start: "top 70%",
  once: true,
  onEnter: () => {
    if (terminalTyped) return;
    terminalTyped = true;
    
    let currentLine = 0;
    
    function typeLine() {
      if (currentLine >= terminalLines.length) return;
      
      const lineStr = terminalLines[currentLine];
      let charIndex = 0;
      let isHTML = false;
      let currentHTML = "";
      
      const div = document.createElement('div');
      terminalOutput.appendChild(div);
      
      function typeChar() {
        if (charIndex >= lineStr.length) {
          currentLine++;
          setTimeout(typeLine, lineStr.endsWith('\n') ? 300 : 100);
          return;
        }
        
        const char = lineStr[charIndex];
        
        if (char === '<') isHTML = true;
        
        if (isHTML) {
          currentHTML += char;
          if (char === '>') {
            isHTML = false;
            // append whole html tag
            div.innerHTML = lineStr.substring(0, charIndex + 1);
          }
        } else {
          div.innerHTML = lineStr.substring(0, charIndex + 1);
        }
        
        charIndex++;
        setTimeout(typeChar, isHTML ? 0 : 30);
      }
      
      typeChar();
    }
    
    typeLine();
  }
});

// Blinking cursor
gsap.to('#terminal-cursor', {
  opacity: 0,
  duration: 0.35,
  repeat: -1,
  yoyo: true,
  ease: "steps(1)"
});


// ============================================================
// SECTION 07 — ACQUIRE
// ============================================================
const acqHeadline = document.getElementById('acquire-headline');
const acqChars = splitTextByChar(acqHeadline);

ScrollTrigger.create({
  trigger: "#acquire",
  start: "top 60%",
  onEnter: () => {
    const tl = gsap.timeline();
    tl.to(acqChars, {
      y: 0,
      opacity: 1,
      duration: 0.8,
      ease: "power3.out",
      stagger: 0.02
    });
    
    tl.fromTo('#acquire-buttons', 
      { y: -20, opacity: 0 }, 
      { y: 0, opacity: 1, duration: 0.8, ease: "power2.out" }, 
      "-=0.6"
    );
  }
});
