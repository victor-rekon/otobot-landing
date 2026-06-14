/* OTOBOT Indonesia — landing page interactions */
(function(){
  var reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  /* ---------- Nav ---------- */
  var navToggle = document.getElementById('navToggle');
  var navLinks = document.getElementById('navLinks');

  navToggle.addEventListener('click', function(){
    navLinks.classList.toggle('open');
  });
  navLinks.querySelectorAll('a').forEach(function(a){
    a.addEventListener('click', function(){ navLinks.classList.remove('open'); });
  });

  /* ---------- Reveal on scroll ---------- */
  var revealEls = document.querySelectorAll('.reveal');
  if ('IntersectionObserver' in window && !reduced){
    var io = new IntersectionObserver(function(entries){
      entries.forEach(function(entry){
        if (entry.isIntersecting){
          entry.target.classList.add('visible');
          io.unobserve(entry.target);
        }
      });
    }, { threshold: 0.15, rootMargin: '0px 0px -40px 0px' });
    revealEls.forEach(function(el){ io.observe(el); });
  } else {
    revealEls.forEach(function(el){ el.classList.add('visible'); });
  }

  /* ---------- Explode / teardown scroll animation ---------- */
  var explodeSection = document.getElementById('explode');
  var callouts = document.querySelectorAll('.callout');
  var dots = document.querySelectorAll('#explodeProgress i');
  var STEP_THRESHOLDS = [0.06, 0.24, 0.42, 0.60, 0.78]; // when each callout/step activates

  if (reduced || !explodeSection){
    // Static fallback: show a moderately exploded view + reveal all callouts
    document.documentElement.style.setProperty('--p', reduced ? 0.7 : 0);
    callouts.forEach(function(c){ c.classList.add('visible'); });
  } else {
    var ticking = false;

    function updateExplode(){
      var rect = explodeSection.getBoundingClientRect();
      var total = explodeSection.offsetHeight - window.innerHeight;
      var scrolled = -rect.top;
      var progress = total > 0 ? scrolled / total : 0;
      progress = Math.max(0, Math.min(1, progress));

      document.documentElement.style.setProperty('--p', progress.toFixed(4));

      var activeStep = -1;
      STEP_THRESHOLDS.forEach(function(t, i){
        if (progress >= t) activeStep = i;
      });

      callouts.forEach(function(c){
        var step = parseInt(c.getAttribute('data-step'), 10);
        c.classList.toggle('visible', step <= activeStep);
        c.classList.toggle('current', step === activeStep);
      });
      dots.forEach(function(d){
        var step = parseInt(d.getAttribute('data-step'), 10);
        d.classList.toggle('active', step <= activeStep);
      });

      ticking = false;
    }

    function onScroll(){
      if (!ticking){
        requestAnimationFrame(updateExplode);
        ticking = true;
      }
    }

    updateExplode();
    window.addEventListener('scroll', onScroll, { passive: true });
    window.addEventListener('resize', onScroll);
  }
})();
