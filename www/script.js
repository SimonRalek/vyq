const scrollTop = document.getElementById('return-to-top')
window.onscroll = () => {
  if (window.scrollY > 50) {
    scrollTop.style.visibility = "visible";
    scrollTop.style.opacity = 1;
  } else {
    scrollTop.style.visibility = "hidden";
    scrollTop.style.opacity = 0;
  }
};