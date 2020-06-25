module.exports = {
  configureWebpack: (config, env) => {
    // Manipulate the config object and return it.
    return config;
  },
  proxy: "http://localhost:8080"
}
