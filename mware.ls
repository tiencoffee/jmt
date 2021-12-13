require! {
	https
}

module.exports = (req, res, next) !->
	if ma = /^\/api\/(.+)$/exec req.url
		url = "https://junmeitu.com/#{ma.1}"
		https.get url, (resp) !~>
			data = ""
			resp.on \data (chunk) !~>
				data += chunk
			resp.on \end !~>
				res.end data
	else
		next!

process.on \uncaughtException (err) !->
	console.log err.message
