appDir: "."
baseUrl: "."
dir: "../resource.opt"
mainConfigFile: "main.js"
stubModules: ["cs"]
modules: [
  {
    name: "main"
    exclude: ["coffee-script"]
  }
]
optimize: "none"
#optimize: "uglify2"
preserveLicenseComments: false
generateSourceMaps: true
#useSourceUrl: true
# vim:ft=coffee
