window.addEventListener('DOMContentLoaded', event => {

  let mybutton = document.getElementById("btn-back-to-top");
  window.onscroll = function () {
    scrollFunction();
  };

  function scrollFunction() {
    if (
      document.body.scrollTop > 20 ||
      document.documentElement.scrollTop > 20
    ) {
      mybutton.style.display = "block";
    } else {
      mybutton.style.display = "none";
    }
  }

  mybutton.addEventListener("click", backToTop);

  function backToTop() {
    document.body.scrollTop = 0;
    document.documentElement.scrollTop = 0;
  }


  var navbarShrink = function () {
    const navbarCollapsible = document.body.querySelector('#mainNav');
    const top_icon = document.body.querySelector('#top-icon')

    if (!navbarCollapsible) {
      return;
    }
    if (window.scrollY === 0) {
      navbarCollapsible.classList.remove('navbar-shrink')
      top_icon.classList.remove('vis');
    } else {
      navbarCollapsible.classList.add('navbar-shrink')
      top_icon.classList.add('vis');
    }

  };

  navbarShrink();

  document.addEventListener('scroll', navbarShrink);


addObserver('animate-fadein-bottom', 'fadeInUp');
addObserver('animate-fadein-left', 'fadeInLeft');
addObserver('animate-fadein-right', 'fadeInRight');


function resizeElementToScreenHeight() {
  var element = document.getElementById('main-page');
  var screenHeight = window.innerHeight;
  element.style.height = screenHeight + 'px';
}

resizeElementToScreenHeight();

window.addEventListener('resize', resizeElementToScreenHeight);
});

function addObserver(animElement, animation) {
  const observer = new IntersectionObserver(entries => {
    entries.forEach(entry => {

      if (entry.isIntersecting) {
        entry.target.classList.add(animation);
      }

    });
  });

  document.querySelectorAll('.' + animElement).forEach((item) => {
    observer.observe(item);
  });
}
