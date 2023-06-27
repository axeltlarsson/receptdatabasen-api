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

const passkeySupport = () => {
  // https://web.dev/passkey-registration/#feature-detection
  // Availability of `window.PublicKeyCredential` means WebAuthn is usable.
  // `isUserVerifyingPlatformAuthenticatorAvailable` means the feature detection is usable.
  // `isConditionalMediationAvailable` means the feature detection is usable.
  const pubkey = window.PublicKeyCredential;
  if (pubkey
    && pubkey.isUserVerifyingPlatformAuthenticatorAvailable
    && pubkey.isConditionalMediationAvailable) {
    // Check if user verifying platform authenticator is available.
    return Promise.all([
      pubkey.isUserVerifyingPlatformAuthenticatorAvailable(),
      pubkey.isConditionalMediationAvailable(),
    ]).then((results) => results.every((r) => r === true));
  }
  return Promise.resolve(false);
};

const createPasskey = (options) => navigator.credentials.create({
  publicKey: options,
});

app.ports.passkeyPortSender.subscribe((message) => {
  console.log('port message recevied in js land', message);
  switch (message.type) {
    case 'checkPasskeySupport':
      passkeySupport().then((passkeySupported) => {
        app.ports.passkeyPortReceiver.send({ type: 'passkeySupported', passkeySupport: passkeySupported });
      });
      break;
    case 'createPasskey':
      const options = {
        challenge: Uint8Array.from('MWoGDvsJpbAkI5s459o-rv_VKE3wN47tIqNqYaNAp1Ecghk7Myv0pGjd-BReBkucQdCxA0gJ8TyeUVyBfdx4RQ', (c) => c.charCodeAt(0)),
        rp: {
          name: 'localhost',
          id: 'localhost',
        },
        user: {
          id: Uint8Array.from('123', (c) => c.charCodeAt(0)),
          name: 'john78',
          displayName: 'John',
        },
        pubKeyCredParams: [{ alg: -7, type: 'public-key' }, { alg: -257, type: 'public-key' }],
        excludeCredentials: [{
          id: Uint8Array.from('923', (c) => c.charCodeAt(0)),
          type: 'public-key',
          transports: ['internal'],
        }],
        authenticatorSelection: {
          authenticatorAttachment: 'platform',
          requireResidentKey: true,
        },
      };
      createPasskey(options).then((credential) => {
        console.log('passkeyCreated', credential);
        app.ports.passkeyPortReceiver.send({ type: 'passkeyCreated', credential });
      });
      break;
    default:
      console.error('Unexpected message type %o', message.type);
  }
});

class EasyMDEditor extends HTMLElement {
  connectedCallback() {
    const textArea = document.createElement('textarea');
    this.appendChild(textArea);
    const id = this.getAttribute('id');
    const enableYoutube = this.getAttribute('youtube');

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

    if (enableYoutube) {
      options = { toolbar: [...options.toolbar, youtubeBtn] };
    } else {
      options = { toolbar: [...options.toolbar] };
    }

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
      app.ports.editorPortReceiver.send(msg);
    });

    easyMDE.codemirror.on('blur', () => {
      const msg = {
        type: 'blur',
        id,
      };
      app.ports.editorPortReceiver.send(msg);
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
