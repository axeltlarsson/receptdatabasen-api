import './main.css';
import './hourglass_loader.css';
import './fonts.css';
import * as EasyMDE from 'easymde';
import { Elm } from './Main.elm';
import * as serviceWorker from './serviceWorker';

const flags = { width: window.innerWidth, height: window.innerHeight };
const app = Elm.Main.init({
  node: document.getElementById('root'),
  flags,
});

class EasyMDEditor extends HTMLElement {
  connectedCallback() {
    const textArea = document.createElement('textarea');
    this.appendChild(textArea);
    const id = this.getAttribute('id');

    let options = this.getAttribute('options');
    if (options) {
      options = JSON.parse(options);
    }

    const youtubeVideoId = (url) => {
      const re = /(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})/gi;
      const res = re.exec(url);
      if (!res) {
        return null;
      }
      return res[1];
    };

    // http://img.youtube.com/vi/[video-id]/[thumbnail-number].jpg
    const youtubeThumbnail = (videoId) => `https://img.youtube.com/vi/${videoId}/0.jpg`;

    const youtubeBtn = {
      name: 'add-youtube-video',
      action: (editor) => {
        const url = prompt('Klistra in Youtube URL', '');
        if (!url) {
          return false;
        }
        const videoId = youtubeVideoId(url);
        if (!videoId) {
          return false;
        }
        const thumb = youtubeThumbnail(videoId);
        editor.codemirror.replaceSelection(`<youtube url="https://www.youtube.com/embed/${videoId}" thumb="${thumb}"/>`);
        return true;
      },
      className: 'fa fa-youtube',
      title: 'Add Youtube video',
    };

    options = { toolbar: [...options.toolbar, youtubeBtn] };

    const easyMDE = new EasyMDE({
      element: textArea,
      toolbar: options.toolbar,
      spellChecker: false,
      placeholder: this.getAttribute('placeholder'),
      initialValue: this.getAttribute('initialValue'),
      promptURLs: true,
    });

    easyMDE.codemirror.on('change', () => {
      const msg = {
        type: 'change',
        id,
        value: easyMDE.value(),
      };
      app.ports.portReceiver.send(msg);
    });

    easyMDE.codemirror.on('blur', () => {
      const msg = {
        type: 'blur',
        id,
      };
      app.ports.portReceiver.send(msg);
    });
  }

  static get observedAttributes() {
    return ['initialValue'];
  }
}

customElements.define('easy-mde', EasyMDEditor);

// If you want your app to work offline and load faster, you can change
// unregister() to register() below. Note this comes with some pitfalls.
// Learn more about service workers: https://bit.ly/CRA-PWA
serviceWorker.register();
