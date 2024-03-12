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

            if (page == "zacatek/instalace.md") {
                detectOSAndSetDownloadLink();
            }
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

    setTimeout(() => {
        openFolderAndHighlightPage('zacatek/instalace.md');
        changeContent('zacatek/instalace.md')
    }, 0);

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
    const defaultLink = document.querySelector('.navigation a[onclick*="${defaultPage}"]');
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
styleSheet.innerText = darkThemeStyles;
document.head.appendChild(styleSheet); updateSelectedLink('page1.md');

async function detectOSAndArchitecture() {
    let os = 'Unknown OS';
    let arch = 'Unknown Architecture';

    if (navigator.userAgentData) {
        try {
            const uaData = await navigator.userAgentData.getHighEntropyValues(['platform', 'architecture']);
            os = uaData.platform;
            arch = uaData.architecture;
        } catch (error) {
            console.error('Error fetching high entropy values:', error);
        }
    } else {
        const ua = navigator.userAgent.toLowerCase();

        if (/windows/.test(ua)) {
            os = 'Windows';
        } else if (/macintosh|mac os x/.test(ua)) {
            os = 'macOS';
        } else if (/linux/.test(ua)) {
            os = 'Linux';
        }

        if (/x86_64|win64|wow64|x64/.test(ua)) {
            arch = 'x86-64';
        } else if (/arm64|aarch64/.test(ua)) {
            arch = 'aarch64';
        } else if (/arm/.test(ua)) {
            arch = 'arm';
        }
    }

    return { os, arch };
}

async function getLatestReleaseDownloadUrl(owner, repo, os, arch) {
    const apiUrl = `https://api.github.com/repos/${owner}/${repo}/releases/latest`;

    try {
        const response = await fetch(apiUrl);
        const data = await response.json();
        const asset = data.assets.find(asset => asset.name.includes(os) && asset.name.includes(arch));
        return asset ? asset.browser_download_url : '';
    } catch (error) {
        console.error('Error fetching the latest release:', error);
        return '';
    }
}

async function detectOSAndSetDownloadLink() {
    const os = detectOSAndArchitecture().then(async obj => {
        const owner = 'SimonRalek';
        const repo = 'vyq';

        var downloadUrl = await getLatestReleaseDownloadUrl(owner, repo, obj.os, obj.arch);
        if (downloadUrl) {
            updateDownloadLink(downloadUrl);
        } else {
            console.log('No matching release asset found for the detected OS and architecture.');
        }
    });

}

function updateDownloadLink(downloadUrl) {
    const downloadLinkElement = document.querySelector('a[href="#downloadLink"]');

    if (downloadLinkElement) {
        downloadLinkElement.href = downloadUrl;
    }
}
