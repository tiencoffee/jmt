require! {
	fs
	\terser
	\livescript2
	\live-server
}

code = fs.readFileSync \mware.ls \utf8
code = livescript2.compile code
code = (await terser.minify code)code
fs.writeFileSync \api/mware.js code

mware = require \./api/mware.js

liveServer.start do
	port: 5500
	open: no
	logLevel: 0
	middleware: [mware]
