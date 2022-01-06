require! {
	fs
	\terser
	\livescript2
	\js-yaml
	\live-server
}

code = fs.readFileSync \mware.ls \utf8
code = livescript2.compile code
code = (await terser.minify code)code
fs.writeFileSync \api/mware.js code

yaml = fs.readFileSync \tags.yaml \utf8
yaml .= replace /^\t/gm " "
yaml = jsYaml.load yaml
json = JSON.stringify yaml
fs.writeFileSync \tags.json json

mware = require \./api/mware.js

liveServer.start do
	port: 5500
	open: no
	logLevel: 0
	middleware: [mware]
