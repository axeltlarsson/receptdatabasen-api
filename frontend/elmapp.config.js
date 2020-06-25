const { createProxyMiddleware } = require("http-proxy-middleware");

module.exports = {
  configureWebpack: (config, env) => {
    // Manipulate the config object and return it.
    return config;
  },
  setupProxy: function (app) {
    app.use(
      ["/rest", "/images"],
      createProxyMiddleware({ target: "http://localhost:8080/" })
    );
  },
};
