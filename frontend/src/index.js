import "./main.css";
import "./hourglass_loader.css";
import "./fonts.css";
import { Elm } from "./Main.elm";
import * as EasyMDE from "easymde";
import * as serviceWorker from "./serviceWorker";

const flags = { width: window.innerWidth, height: window.innerHeight };
const app = Elm.Main.init({
  node: document.getElementById("root"),
  flags: flags,
});

class EasyMDEditor extends HTMLElement {
  constructor() {
    super();
  }

  connectedCallback() {
    console.log("connectedCallback", this.getAttribute("id"));

    const textArea = document.createElement("textarea");
    this.appendChild(textArea);
    const id = this.getAttribute("id");

    let options = this.getAttribute("options");
    if (options) {
      options = JSON.parse(options);
    }
    options = Object.assign({ toolbar: null }, options);

    const easyMDE = new EasyMDE({
      element: textArea,
      toolbar: options["toolbar"],
      spellChecker: false,
      placeholder: this.getAttribute("placeholder"),
      initialValue: this.getAttribute("initialValue"),
    });

    easyMDE.codemirror.on("change", () => {
      const msg = {
        type: "change",
        id: id,
        value: easyMDE.value(),
      };
      app.ports.portReceiver.send(msg);
    });

    easyMDE.codemirror.on("blur", () => {
      const msg = {
        type: "blur",
        id: id,
      };
      app.ports.portReceiver.send(msg);
    });
  }

  static get observedAttributes() {
    return ["initialValue"];
  }

  attributeChangedCallback(name, oldValue, newValue) {
    console.log("Custom element attributes changed.");
  }
}

customElements.define("easy-mde", EasyMDEditor);

app.ports.portSender.subscribe(function (elmValue) {
  console.log("elmValue", elmValue);
});

// If you want your app to work offline and load faster, you can change
// unregister() to register() below. Note this comes with some pitfalls.
// Learn more about service workers: https://bit.ly/CRA-PWA
serviceWorker.unregister();
