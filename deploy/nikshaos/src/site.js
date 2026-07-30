/**
 * nikshaos.in — motion layer.
 *
 * ★ WHY THERE IS NO GSAP HERE
 *   The proposal budgeted GSAP + ScrollTrigger (~50KB gz) because Acts I and II
 *   were pinned, scroll-scrubbed timelines. Those two acts are exactly the ones
 *   omitted for missing captures (Student 360, AI Copilot). What remains —
 *   a header state toggle, an entrance reveal, and a pointer/scroll parallax —
 *   needs no timeline engine, so v1 ships this file instead: no dependency, no
 *   build step, and ~2KB where 50KB was budgeted.
 *
 *   If Act I or Act III is ever built, they need real scrubbed timelines and
 *   GSAP + ScrollTrigger should be vendored then. Do NOT hand-roll pinning.
 *
 * ★ RULES THIS FILE OBEYS (proposal §8.2)
 *   - ZERO `scroll` listeners. IntersectionObserver only.
 *   - ONE requestAnimationFrame loop for the whole page, and it does not run
 *     when nothing needs it.
 *   - Only `transform` and `opacity` are written.
 *   - `will-change` is set on enter and REMOVED on leave. Leaving it on is the
 *     most common cause of the jank this design risks.
 *   - Nothing here is required for the page to be complete. The DOM is already
 *     in its final composed state; this only adds movement.
 *
 * ★ REDUCED MOTION
 *   `prefers-reduced-motion: reduce` REMOVES motion rather than reducing it
 *   (§9.1). Checked before anything is built, and re-checked on change.
 */
(function () {
  'use strict';

  var reduceMQ = window.matchMedia('(prefers-reduced-motion: reduce)');
  var fineMQ = window.matchMedia('(pointer: fine)');
  var desktopMQ = window.matchMedia('(min-width: 768px)');

  var teardown = [];
  var rafId = 0;

  /* ------------------------------------------------------------------ rAF *
   * One loop, shared. Tasks register themselves; the loop stops when the last
   * one goes idle, so an off-screen scene costs nothing.
   * ------------------------------------------------------------------ */
  var tasks = [];
  function tick() {
    rafId = 0;
    var alive = false;
    for (var i = 0; i < tasks.length; i++) {
      if (tasks[i]()) alive = true;
    }
    if (alive) rafId = requestAnimationFrame(tick);
  }
  function wake() {
    if (!rafId) rafId = requestAnimationFrame(tick);
  }

  /* ------------------------------------------------------------- header *
   * A sentinel just below the fold toggles the stuck state. This is the
   * documented alternative to a scroll listener (§5 Header).
   * ------------------------------------------------------------------ */
  function initHeader() {
    var header = document.querySelector('[data-header]');
    var sentinel = document.querySelector('[data-header-sentinel]');
    if (!header || !sentinel || !('IntersectionObserver' in window)) return;

    var io = new IntersectionObserver(
      function (entries) {
        header.classList.toggle('is-stuck', !entries[0].isIntersecting);
      },
      { threshold: 0 }
    );
    io.observe(sentinel);
    teardown.push(function () {
      io.disconnect();
      header.classList.remove('is-stuck');
    });
  }

  /* ------------------------------------------------------------- reveal *
   * The resting state in CSS is "visible". We arm the hidden state only here,
   * after confirming motion is allowed — so with JS off, or under reduced
   * motion, the content is simply already there.
   * ------------------------------------------------------------------ */
  function initReveal() {
    var items = document.querySelectorAll('[data-reveal]');
    if (!items.length || !('IntersectionObserver' in window)) return;

    document.documentElement.classList.add('motion-ok');
    for (var i = 0; i < items.length; i++) items[i].classList.add('reveal-armed');

    var io = new IntersectionObserver(
      function (entries) {
        for (var i = 0; i < entries.length; i++) {
          var e = entries[i];
          if (!e.isIntersecting) continue;
          var el = e.target;
          /* 60ms stagger among siblings revealed together (§5 Act IV). */
          var siblings = el.parentNode ? el.parentNode.querySelectorAll('[data-reveal]') : [el];
          var idx = Array.prototype.indexOf.call(siblings, el);
          el.style.transitionDelay = Math.max(0, idx) * 60 + 'ms';
          el.classList.remove('reveal-armed');
          el.classList.add('reveal-in');
          io.unobserve(el);
        }
      },
      { rootMargin: '0px 0px -12% 0px', threshold: 0.06 }
    );
    for (var j = 0; j < items.length; j++) io.observe(items[j]);

    teardown.push(function () {
      io.disconnect();
      document.documentElement.classList.remove('motion-ok');
      for (var k = 0; k < items.length; k++) {
        items[k].classList.remove('reveal-armed', 'reveal-in');
        items[k].style.transitionDelay = '';
        items[k].style.transform = '';
      }
    });
  }

  /* -------------------------------------------------------------- scene *
   * Pointer parallax + a scroll dolly on the Act 0 depth scene.
   *
   * Targets are lerped at 0.08 toward the pointer inside the shared rAF loop —
   * ONE loop, ONE pointermove listener on the container, never per element
   * (§5 Act 0.2). The loop is only awake while the scene is on screen.
   * ------------------------------------------------------------------ */
  function initScene() {
    var stage = document.querySelector('[data-scene]');
    if (!stage || !('IntersectionObserver' in window)) return;

    var layers = stage.querySelectorAll('.layer');
    if (!layers.length) return;

    var depths = [];
    for (var i = 0; i < layers.length; i++) {
      depths.push(parseFloat(layers[i].getAttribute('data-depth')) || 0);
    }

    var tx = 0, ty = 0;      /* target, normalised -1..1 */
    var cx = 0, cy = 0;      /* current */
    var visible = false;
    var pointer = false;

    function onMove(ev) {
      var r = stage.getBoundingClientRect();
      tx = ((ev.clientX - r.left) / r.width - 0.5) * 2;
      ty = ((ev.clientY - r.top) / r.height - 0.5) * 2;
      wake();
    }
    function onLeave() {
      tx = 0; ty = 0;
      wake();
    }

    function apply() {
      /* rotateY ±6deg, rotateX ∓4deg on the scene container (§5 Act 0.2). */
      stage.style.transform =
        'perspective(1400px) rotateY(' + (cx * 6).toFixed(3) + 'deg) rotateX(' + (-cy * 4).toFixed(3) + 'deg)';
      for (var i = 0; i < layers.length; i++) {
        /* Each layer additionally translates by x · depth · 14px. The z-depth
           itself stays in CSS so the composition is correct without JS. */
        var dx = (cx * depths[i] * 14).toFixed(2);
        var dy = (cy * depths[i] * 6).toFixed(2);
        layers[i].style.setProperty('--px', dx + 'px');
        layers[i].style.setProperty('--py', dy + 'px');
        layers[i].style.transform =
          'translate3d(' + dx + 'px,' + dy + 'px,0) ' + layerZ(i);
      }
    }

    /* The CSS z-depth per breakpoint has to be preserved when JS takes over the
       transform, or the scene flattens the moment the pointer moves. Read once
       from the computed style at init and re-read on resize. */
    var zCache = [];
    function readZ() {
      zCache = [];
      for (var i = 0; i < layers.length; i++) {
        var t = window.getComputedStyle(layers[i]).transform;
        var m = t && t !== 'none' ? t.match(/matrix3d\(([^)]+)\)/) : null;
        var z = 0;
        if (m) {
          var v = m[1].split(',');
          z = parseFloat(v[14]) || 0;
        }
        zCache.push(z);
      }
    }
    function layerZ(i) {
      return 'translateZ(' + zCache[i] + 'px)';
    }

    function step() {
      if (!visible) return false;
      var dx = tx - cx, dy = ty - cy;
      if (Math.abs(dx) < 0.0005 && Math.abs(dy) < 0.0005) {
        if (cx !== tx || cy !== ty) { cx = tx; cy = ty; apply(); }
        return false;                       /* settled — let the loop stop */
      }
      cx += dx * 0.08;                      /* lerp 0.08 (§5 Act 0.2) */
      cy += dy * 0.08;
      apply();
      return true;
    }
    tasks.push(step);

    function attachPointer() {
      if (pointer || !fineMQ.matches || !desktopMQ.matches) return;
      stage.addEventListener('pointermove', onMove, { passive: true });
      stage.addEventListener('pointerleave', onLeave, { passive: true });
      pointer = true;
    }
    function detachPointer() {
      if (!pointer) return;
      stage.removeEventListener('pointermove', onMove);
      stage.removeEventListener('pointerleave', onLeave);
      pointer = false;
      tx = 0; ty = 0;
      wake();
    }

    var io = new IntersectionObserver(
      function (entries) {
        visible = entries[0].isIntersecting;
        if (visible) {
          readZ();
          /* will-change ON enter … */
          for (var i = 0; i < layers.length; i++) layers[i].style.willChange = 'transform';
          attachPointer();
          wake();
        } else {
          detachPointer();
          /* … and REMOVED on leave (§8.2 rule 2). */
          for (var j = 0; j < layers.length; j++) layers[j].style.willChange = '';
        }
      },
      { threshold: 0 }
    );
    io.observe(stage);

    var onResize = function () {
      readZ();
      detachPointer();
      attachPointer();
    };
    window.addEventListener('resize', onResize, { passive: true });

    teardown.push(function () {
      io.disconnect();
      detachPointer();
      window.removeEventListener('resize', onResize);
      stage.style.transform = '';
      for (var i = 0; i < layers.length; i++) {
        layers[i].style.transform = '';
        layers[i].style.willChange = '';
      }
    });
  }

  /* ---------------------------------------------------- blueprint parallax *
   * Decorative planes drift on scroll. Driven by the rAF loop while the plane
   * is on screen — never by a scroll listener.
   * ------------------------------------------------------------------ */
  function initParallax() {
    var planes = document.querySelectorAll('[data-parallax]');
    if (!planes.length || !('IntersectionObserver' in window)) return;

    var active = [];

    function step() {
      if (!active.length) return false;
      var vh = window.innerHeight || 1;
      for (var i = 0; i < active.length; i++) {
        var el = active[i];
        var rate = parseFloat(el.getAttribute('data-parallax')) || 0;
        var r = el.getBoundingClientRect();
        /* -1 above the viewport … +1 below it. */
        var p = (r.top + r.height / 2 - vh / 2) / vh;
        el.style.transform = 'translate3d(0,' + (p * rate * vh).toFixed(1) + 'px,0)';
      }
      return true;                          /* keep running while any is visible */
    }
    tasks.push(step);

    var io = new IntersectionObserver(
      function (entries) {
        for (var i = 0; i < entries.length; i++) {
          var el = entries[i].target;
          var at = active.indexOf(el);
          if (entries[i].isIntersecting) {
            if (at === -1) active.push(el);
            el.style.willChange = 'transform';
          } else {
            if (at !== -1) active.splice(at, 1);
            el.style.willChange = '';
          }
        }
        if (active.length) wake();
      },
      { threshold: 0 }
    );
    for (var i = 0; i < planes.length; i++) io.observe(planes[i]);

    teardown.push(function () {
      io.disconnect();
      active.length = 0;
      for (var j = 0; j < planes.length; j++) {
        planes[j].style.transform = '';
        planes[j].style.willChange = '';
      }
    });
  }

  /* ------------------------------------------------------------------ boot */
  function start() {
    initHeader();          /* not motion — the header state is useful regardless */
    if (reduceMQ.matches) return;
    initReveal();
    initScene();
    initParallax();
  }

  function stop() {
    if (rafId) { cancelAnimationFrame(rafId); rafId = 0; }
    tasks.length = 0;
    for (var i = teardown.length - 1; i >= 0; i--) teardown[i]();
    teardown.length = 0;
  }

  start();

  /* Re-check on change, per §9.1. Someone who turns reduced motion on mid-visit
     gets the static page immediately, without a reload. */
  var onPrefChange = function () {
    stop();
    start();
  };
  if (reduceMQ.addEventListener) reduceMQ.addEventListener('change', onPrefChange);
  else if (reduceMQ.addListener) reduceMQ.addListener(onPrefChange);
})();
