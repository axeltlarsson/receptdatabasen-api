const { createProxyMiddleware } = require("http-proxy-middleware");

module.exports = function (app) {
  app.use('/rest',
    createProxyMiddleware( {
      target: "http://localhost:80/",
    })
  );
  app.use('/images',
    createProxyMiddleware( {
      target: "http://localhost:80/",
    })
  );
};
