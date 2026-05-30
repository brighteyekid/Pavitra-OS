/* main.js — Pavitra OS Website
   Lenis smooth scroll + GSAP ScrollTrigger animations
   Loader: canvas rings + logo reveal + title collapse
   Site:   hero stagger, line draws, counter, table/feat reveals
*/

gsap.registerPlugin(ScrollTrigger);

/* ── LENIS ──────────────────────────────────────────────────── */
const lenis = new Lenis({ lerp: 0.085, smoothWheel: true });
lenis.on('scroll', ScrollTrigger.update);
gsap.ticker.add((t) => lenis.raf(t * 1000));
gsap.ticker.lagSmoothing(0);

/* ── CANVAS LOADER ──────────────────────────────────────────── */
const canvas = document.getElementById('lc');
const ctx    = canvas.getContext('2d');
let   craf, T = 0;

function resizeCanvas() {
  canvas.width  = window.innerWidth;
  canvas.height = window.innerHeight;
}
resizeCanvas();
window.addEventListener('resize', resizeCanvas);

function drawLoader() {
  const W = canvas.width, H = canvas.height;
  const cx = W / 2, cy = H / 2;
  ctx.clearRect(0, 0, W, H);

  /* expanding rings */
  for (let i = 0; i < 5; i++) {
    const p = ((T * .009 + i * .2) % 1);
    const r = p * Math.min(W, H) * .52;
    ctx.beginPath();
    ctx.arc(cx, cy, r, 0, Math.PI * 2);
    ctx.strokeStyle = `rgba(0,210,255,${(1 - p) * .45})`;
    ctx.lineWidth   = 1;
    ctx.stroke();
  }

  /* inner glow dot */
  const pulse = .7 + .3 * Math.sin(T * .09);
  const grad  = ctx.createRadialGradient(cx, cy, 0, cx, cy, 70 * pulse);
  grad.addColorStop(0, 'rgba(0,210,255,.35)');
  grad.addColorStop(1, 'rgba(0,210,255,0)');
  ctx.beginPath();
  ctx.arc(cx, cy, 70 * pulse, 0, Math.PI * 2);
  ctx.fillStyle = grad;
  ctx.fill();

  /* core dot */
  ctx.beginPath();
  ctx.arc(cx, cy, 5, 0, Math.PI * 2);
  ctx.fillStyle = '#00D2FF';
  ctx.fill();

  T++;
  craf = requestAnimationFrame(drawLoader);
}
drawLoader();

/* ── LOADER TIMELINE ────────────────────────────────────────── */
const loaderTL = gsap.timeline({ onComplete: bootSite });

loaderTL
  /* progress bar fills */
  .to('#lbar',  { width: '100%', duration: 2.2, ease: 'power1.inOut' }, 0)
  /* logo fades in */
  .to('#llogo', { opacity: 1, duration: .8, ease: 'power2.out' }, .3)
  /* title lines slide up — letter-spacing collapses */
  .to('.lline span', {
    y: 0, duration: .9, stagger: .15, ease: 'power4.out'
  }, .7)
  /* subtitle fades */
  .to('#lsub', { opacity: 1, duration: .6, ease: 'power2.out' }, 1.4)
  /* hold, then exit */
  .to(['#loader-inner', '#lprogress'], {
    opacity: 0, y: -30, duration: .6, stagger: .08, ease: 'power3.in'
  }, 2.6)
  .to(canvas, {
    scale: 12, opacity: 0, duration: .9, ease: 'power4.in'
  }, 2.8)
  .to('#loader', { autoAlpha: 0, duration: .15 }, 3.4);

/* ── SITE BOOT ──────────────────────────────────────────────── */
function bootSite() {
  cancelAnimationFrame(craf);
  document.getElementById('loader').style.display = 'none';

  gsap.to('#site', { opacity: 1, duration: .5 });

  /* nav */
  gsap.from('#nav', { y: -50, opacity: 0, duration: .7, ease: 'power3.out', delay: .1 });

  /* hero */
  gsap.to('.eyebrow',   { opacity: 1, y: 0, duration: .7, ease: 'power3.out', delay: .25 });
  gsap.to('.li',        { y: '0%', duration: 1, stagger: .12, ease: 'power4.out', delay: .3 });
  gsap.to('#hero-desc', { opacity: 1, y: 0, duration: .8, ease: 'power3.out', delay: .7 });
  gsap.to('#hero-ctas', { opacity: 1, y: 0, duration: .7, ease: 'power3.out', delay: .85 });
  gsap.to('#scroll-hint', { opacity: 1, duration: .6, delay: 1.4 });

  /* parallax on hero bg */
  gsap.to('#hero-bg', {
    yPercent: 20,
    ease: 'none',
    scrollTrigger: { trigger: '#hero', start: 'top top', end: 'bottom top', scrub: true }
  });

  /* mouse parallax on hero bg */
  document.getElementById('hero').addEventListener('mousemove', (e) => {
    const { innerWidth: W, innerHeight: H } = window;
    const dx = (e.clientX / W - .5) * 20;
    const dy = (e.clientY / H - .5) * 10;
    gsap.to('#hero-bg', { x: dx, y: dy, duration: 1.5, ease: 'power2.out', overwrite: 'auto' });
  });

  /* nav scroll state */
  ScrollTrigger.create({
    start: 60,
    onEnter:    () => document.getElementById('nav').classList.add('scrolled'),
    onLeaveBack: () => document.getElementById('nav').classList.remove('scrolled'),
  });

  initScrollAnims();
}

/* ── SCROLL ANIMATIONS ──────────────────────────────────────── */
function initScrollAnims() {

  /* section labels */
  gsap.utils.toArray('[data-rl]').forEach(el => {
    gsap.to(el, {
      opacity: 1, y: 0, duration: .7, ease: 'power3.out',
      scrollTrigger: { trigger: el, start: 'top 88%' }
    });
  });

  /* body text reveals */
  gsap.utils.toArray('[data-sr]').forEach(el => {
    gsap.to(el, {
      opacity: 1, y: 0, duration: .9, ease: 'power3.out',
      scrollTrigger: { trigger: el, start: 'top 86%' }
    });
  });

  /* section titles — clip-path wipe */
  gsap.utils.toArray('.s-title').forEach(el => {
    gsap.from(el, {
      clipPath: 'inset(0 100% 0 0)',
      duration: 1, ease: 'power4.out',
      scrollTrigger: { trigger: el, start: 'top 85%' }
    });
  });

  /* horizontal dividers draw */
  gsap.utils.toArray('[data-lr],.div').forEach(el => {
    gsap.to(el, {
      scaleX: 1, duration: 1.2, ease: 'power4.inOut',
      scrollTrigger: { trigger: el, start: 'top 90%' }
    });
  });

  /* counters */
  gsap.utils.toArray('[data-count]').forEach(el => {
    const target = +el.dataset.count;
    const obj    = { val: 0 };
    gsap.to(obj, {
      val: target, duration: 1.5, ease: 'power2.out',
      onUpdate: () => { el.textContent = Math.round(obj.val); },
      scrollTrigger: { trigger: el, start: 'top 85%' }
    });
  });

  /* compat table rows stagger */
  gsap.utils.toArray('[data-tr]').forEach((row, i) => {
    gsap.to(row, {
      opacity: 1, x: 0, duration: .7, ease: 'power3.out',
      scrollTrigger: { trigger: row, start: 'top 88%' },
      delay: i * .08
    });
  });

  /* features grid items */
  gsap.utils.toArray('[data-fi]').forEach((el, i) => {
    gsap.to(el, {
      opacity: 1, y: 0, duration: .7, ease: 'power3.out',
      delay: (i % 2) * .12,
      scrollTrigger: { trigger: el, start: 'top 87%' }
    });
  });

  /* code window slide in */
  gsap.utils.toArray('[data-cr]').forEach(el => {
    gsap.to(el, {
      opacity: 1, x: 0, duration: .9, ease: 'power3.out',
      scrollTrigger: { trigger: el, start: 'top 82%' }
    });
  });
}
