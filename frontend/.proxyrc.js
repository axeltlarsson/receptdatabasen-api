const { createProxyMiddleware } = require("http-proxy-middleware");

module.exports = function (app) {
  app.use('/rest',
    createProxyMiddleware( {
      target: "http://localhost:8080/",
    })
  );
  app.use('/images',
    createProxyMiddleware( {
      target: "http://localhost:8080/",
    })
  );
  app.use('/export_to_list',
    createProxyMiddleware( {
      target: "http://localhost:8080/",
    })
  );
};
