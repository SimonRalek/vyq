function changeContent(page) {
    fetch('pages/' + page)
        .then(response => response.text())
        .then(markdown => {
            const content = document.getElementById('content');
            content.innerHTML = marked(markdown);
            updateSelectedLink(page);

            content.scrollTop = 0;

            document.querySelector('.navigation').classList.remove('open');
            hljs.highlightAll();
        });
}
function updateSelectedLink(selectedPage) {
    document.querySelectorAll('.navigation a').forEach(link => {
        link.classList.remove('selected');
    });

    const links = document.querySelectorAll('.navigation a');
    links.forEach(link => {
        if (link.getAttribute('onclick').includes(selectedPage)) {
            link.classList.add('selected');
        }
    });
}

document.addEventListener('DOMContentLoaded', () => {
    document.querySelectorAll('.folder > .folder-text').forEach(folderText => {
        folderText.addEventListener('click', () => {
            const folder = folderText.parentElement;
            const nestedList = folder.querySelector('.nested');
            folder.classList.toggle('open');
            nestedList.classList.toggle('visible');
        });
    });

    setTimeout(() => { openFolderAndHighlightPage('zacatek/instalace.md'); changeContent('zacatek/instalace.md') }, 0); // Replace 'page1.md' with your actual default page

    document.getElementById('theme-toggle-btn').addEventListener('click', function () {
        const bodyClassList = document.body.classList;
        bodyClassList.toggle('dark-theme');

        const isDarkTheme = bodyClassList.contains('dark-theme');
        this.textContent = isDarkTheme ? '☀️' : '🌙';

        document.getElementById('light-theme-style').disabled = isDarkTheme;
        document.getElementById('dark-theme-style').disabled = !isDarkTheme;

        hljs.highlightAll();
    });

    const mobileMenuToggle = document.getElementById('mobile-menu-toggle');
    const navigation = document.querySelector('.navigation');

    mobileMenuToggle.addEventListener('click', (event) => {
        navigation.classList.toggle('open');
        event.stopPropagation();
    });

    navigation.addEventListener('click', (event) => {
        event.stopPropagation();
    });

    const navbarToggler = document.getElementById('navbarToggler');
    const navbarCollapse = document.getElementById('navbarResponsive');

    document.addEventListener('click', () => {
        if (!navbarCollapse.contains(event.target) && !navbarToggler.contains(event.target)) {
            navbarCollapse.classList.remove('show');
        }
        navigation.classList.remove('open');
    });
});

function openFolderAndHighlightPage(defaultPage) {
    const defaultLink = document.querySelector(`.navigation a[onclick*="${defaultPage}"]`);
    if (defaultLink) {
        const parentFolder = defaultLink.closest('.folder');
        if (parentFolder) {
            parentFolder.classList.add('open');
            const nestedList = parentFolder.querySelector('.nested');
            nestedList.classList.add('visible');
            defaultLink.classList.add('selected');
        }
    }
}

const darkThemeStyles = `
    body.dark-theme {
        background-color: #333;
        color: #fff;
    }

    body.dark-theme .contain {
        background-color: #424242;
    }

    body.dark-theme #mainNav {
        background-color: #424242;
        color: #fff;
        border-bottom: 1px solid #5d5d5d;
    }

    body.dark-theme #mainNav a {
        color: #fff;
    }

    body.dark-theme #mainNav a.active {
        border-bottom: 1px solid white;
    }

    body.dark-theme .navigation,
    body.dark-theme .content {
        background-color: #333;
        border-color: #424242;
    }

    body.dark-theme a {
        color: #adadad;
    }

    body.dark-theme .navigation ul .folder {
        background-color: #333;
    }

    body.dark-theme .quick-nav {
        background-color: #1e1e1e;
        border-bottom-color: #333;
    }

    body.dark-theme .navigation h2,
    body.dark-theme .navigation ul .folder a {
        color: #fff;
    }

    body.dark-theme #theme-toggle-btn {
        color: #fff;
    }

    body.dark-theme .navigation a.selected {
        background-color: #474747;
    }

    body.dark-theme .nested li a:hover {
        background-color: #404040;
    }


    body.dark-theme .folder>.folder-text:hover {
        background-color: #404040;
    }

    body.dark-theme .mobile-menu-toggle {
        background-color: #424242;
    }

    body.dark-theme #mainNav .navbar-collapse {
        background-color: #424242;
    }

    body.dark-theme pre {
        background-color: #2d2d2d;
        border-color: #444;
        color: #ccc;
    }

    body.dark-theme .hljs {
        background-color: #2d2d2d;
    }
`;

const styleSheet = document.createElement("style");
styleSheet.type = "text/css";
styleSheet.innerText = darkThemeStyles;
document.head.appendChild(styleSheet); updateSelectedLink('page1.md');