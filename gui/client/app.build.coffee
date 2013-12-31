appDir: "resource"
baseUrl: "."
dir: "resource.opt"
mainConfigFile: "resource/main.js"
modules: [
  {
    name: "main"
  }
]
#optimize: "none", useSourceUrl: true
optimize: "uglify2", preserveLicenseComments: false
generateSourceMaps: true
skipDirOptimize: true
# vim:ft=coffee
