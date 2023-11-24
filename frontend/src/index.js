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

const bufferToBase64url = (buffer) => {
  // modified from https://github.com/github/webauthn-json/blob/main/src/webauthn-json/base64url.ts

  const byteView = new Uint8Array(buffer);
  let str = '';
  for (const charCode of byteView) {
    str += String.fromCharCode(charCode);
  }

  // Binary string to base64
  const base64String = btoa(str);

  // Base64 to base64url
  // We assume that the base64url string is well-formed.
  const base64urlString = base64String.replace(/\+/g, '-').replace(
    /\//g,
    '_',
  ).replace(/=/g, '');

  return base64urlString;
};

const base64urlToBuffer = (baseurl64String) => {
  // Base64url to Base64
  const padding = '=='.slice(0, (4 - (baseurl64String.length % 4)) % 4);
  const base64String = baseurl64String.replace(/-/g, '+').replace(/_/g, '/') + padding;

  // Base64 to binary string
  const str = atob(base64String);

  // Binary string to buffer
  const buffer = new ArrayBuffer(str.length);
  const byteView = new Uint8Array(buffer);
  for (let i = 0; i < str.length; i++) {
    byteView[i] = str.charCodeAt(i);
  }
  return buffer;
};

app.ports.passkeyPortSender.subscribe((message) => {
  console.log('port message recevied in js land', message);
  switch (message.type) {
    case 'checkPasskeySupport':
      passkeySupport().then((passkeySupported) => {
        app.ports.passkeyPortReceiver.send({ type: 'passkeySupported', passkeySupport: passkeySupported });
      });
      break;
    case 'createPasskey':
      const { options } = message;

      // passkeycreation requires user.id and challenge to be in buffers
      // the server base64url encodes the user.id and challenge
      options.user.id = base64urlToBuffer(options.user.id);
      options.challenge = base64urlToBuffer(options.challenge);
      if (options.excludeCredentials) {
        for (let i = 0; i < options.excludeCredentials.length; i++) {
          options.excludeCredentials[i].id = base64urlToBuffer(options.excludeCredentials[i].id);
        }
      }

      // TODO: exclude credentials already existing on the server
      // if (options.excludeCredentials) {
      // for (let cred of options.excludeCredentials) {
      // cred.id = base64url.decode(cred.id);
      // }
      // }
      createPasskey(options).then((credential) => {
        console.log(credential);
        const serialized = {
          authenticatorAttachment: credential.authenticatorAttachment,
          id: credential.id,
          rawId: bufferToBase64url(credential.rawId),
          response: {
            attestationObject: bufferToBase64url(credential.response.attestationObject),
            clientDataJSON: bufferToBase64url(credential.response.clientDataJSON),
          },
          type: credential.type,
        };

        console.log(serialized);

        app.ports.passkeyPortReceiver.send({ type: 'passkeyCreated', passkey: serialized });
      }).catch((err) => {
        console.error(err);
        app.ports.passkeyPortReceiver.send({ type: 'error', error: err.toString() });
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
