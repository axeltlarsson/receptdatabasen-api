import './main.css';
import './hourglass_loader.css';
import './fonts.css';
import * as EasyMDE from 'easymde';
import { Elm } from './Main.elm';

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

const getPasskey = (options) => navigator.credentials.get({
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

const getBrowserInfo = () => {
  const { userAgent, vendor } = navigator;
  let browser = '';

  // Detecting browser name
  if (userAgent.includes('Firefox')) {
    browser = 'Mozilla Firefox';
  } else if (userAgent.includes('Opera') || userAgent.includes('OPR')) {
    browser = 'Opera';
  } else if (userAgent.includes('Chrome')) {
    browser = vendor.includes('Google') ? 'Google Chrome' : 'Not Chrome';
  } else if (userAgent.includes('Safari')) {
    browser = 'Safari';
  } else if (userAgent.includes('MSIE') || userAgent.includes('Trident/')) {
    browser = 'Internet Explorer';
  } else {
    browser = 'Unknown';
  }

  // OS Detection
  let osVersion = '';
  let os = '';
  if (userAgent.includes('Win')) {
    os = 'Windows';
    const match = userAgent.match(/Windows NT (\d+\.\d+)/);
    osVersion = match ? ` NT ${match[1]}` : '';
  } else if (userAgent.includes('Mac')) {
    os = 'MacOS';
    const match = userAgent.match(/Mac OS X (\d+[._\d]+)/);
    osVersion = match ? ` ${match[1].replace(/_/g, '.')}` : '';
  } else if (userAgent.includes('X11')) {
    os = 'UNIX';
  } else if (userAgent.includes('Linux')) {
    os = 'Linux';
  } else {
    os = 'Unknown OS';
  }

  return `${browser}, ${os}${osVersion}`;
};

const encodeOptions = (options) => {
  const opts = options;
  // passkeycreation requires user.id and challenge to be in buffers
  // the server base64url encodes the user.id and challenge
  if (options.user) {
    opts.user.id = base64urlToBuffer(opts.user.id);
  }
  opts.challenge = base64urlToBuffer(opts.challenge);
  if (opts.excludeCredentials) {
    for (let i = 0; i < opts.excludeCredentials.length; i++) {
      opts.excludeCredentials[i].id = base64urlToBuffer(opts.excludeCredentials[i].id);
    }
  }

  return opts;
};
const serializePasskey = (credential) => ({
  authenticatorAttachment: credential.authenticatorAttachment,
  id: credential.id,
  rawId: bufferToBase64url(credential.rawId),
  response: {
    authenticatorData: bufferToBase64url(credential.response.authenticatorData),
    clientDataJSON: bufferToBase64url(credential.response.clientDataJSON),
    signature: bufferToBase64url(credential.response.signature),
    userHandle: bufferToBase64url(credential.response.userHandle),
  },
  type: credential.type,
});

let abortController;

app.ports.passkeyPortSender.subscribe((message) => {
  console.log('port message recevied in js land', message);
  switch (message.type) {
    case 'checkPasskeySupport': {
      passkeySupport().then((passkeySupported) => {
        app.ports.passkeyPortReceiver.send({ type: 'passkeySupported', passkeySupport: passkeySupported });
      });
      break;
    }
    case 'createPasskey': {
      const { options } = message;

      const opts = encodeOptions(options);

      createPasskey(opts).then((credential) => {
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

        app.ports.passkeyPortReceiver.send({ type: 'passkeyCreated', passkey: serialized, name: getBrowserInfo() });
      }).catch((err) => {
        console.error(err);
        app.ports.passkeyPortReceiver.send({ type: 'errorCreatingPasskey', error: err.toString() });
      });
      break;
    }

    case 'getPasskey': {
      const { options } = message;
      // passkeycreation requires user.id and challenge to be in buffers
      // the server base64url encodes the user.id and challenge
      options.challenge = base64urlToBuffer(options.challenge);
      if (options.allowCredentials) {
        for (let i = 0; i < options.allowCredentials.length; i++) {
          options.allowCredentials[i].id = base64urlToBuffer(options.allowCredentials[i].id);
        }
      }
      getPasskey(options).then((credential) => {
        const serialized = serializePasskey(credential);
        app.ports.passkeyPortReceiver.send({ type: 'passkeyRetrieved', passkey: serialized });
      }).catch((err) => {
        console.error(err);
        app.ports.passkeyPortReceiver.send({ type: 'errorRetrievingPasskey', error: err.toString() });
      });
      break;
    }

    case 'getPasskeyConditional': {
      if (window.PublicKeyCredential
        && window.PublicKeyCredential.isConditionalMediationAvailable) {
        // Check if conditional mediation is available.
        window.PublicKeyCredential.isConditionalMediationAvailable().then((isCMA) => {
          if (isCMA) {
            // Call WebAuthn authentication
            const opts = encodeOptions(message.options);
            abortController = new AbortController();
            navigator.credentials.get({
              publicKey: opts,
              mediation: 'conditional',
              signal: abortController.signal,
            }).then((credential) => {
              const serialized = serializePasskey(credential);
              app.ports.passkeyPortReceiver.send({ type: 'passkeyRetrieved', passkey: serialized });
            }).catch((err) => {
              if (!abortController.signal.aborted) {
                console.error(err);
                app.ports.passkeyPortReceiver.send({ type: 'errorRetrievingPasskey', error: err.toString() });
              }
            });
          } else {
            console.warn('Passkeys are not available in this browser');
            app.ports.passkeyPortReceiver.send({ type: 'passkeySupported', passkeySupport: false });
          }
        });
      } else {
        console.warn('Passkeys are not supported in this browser');
        app.ports.passkeyPortReceiver.send({ type: 'passkeySupported', passkeySupport: false });
      }
      break;
    }

    case 'abortCMA': {
      if (abortController) {
        abortController.abort();
      }
      break;
    }

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
