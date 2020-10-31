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

    const customBtn = {
      name: "timer",
      action: EasyMDE.drawImage,
      // action: (editor) => {
        // console.log("TIMER");
      // },
      className: "fa fa-star",
      title: "Timer"
    }

    options = { toolbar: [...options.toolbar, customBtn]};
    console.log("options:", options);

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
