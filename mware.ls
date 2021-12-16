require! {
	https
	url
}

module.exports = (req, res, next) !->
	{pathname, query} = url.parse req.url, yes
	if pathname is \/api/mware
		if q = query.q
			q = decodeURIComponent q
			q = "https://junmeitu.com/#q"
			https.get q, (resp) !~>
				data = ""
				resp.on \data (chunk) !~>
					data += chunk
				resp.on \end !~>
					res.end data
		else
			next!
	else
		next!

process.on \uncaughtException (err) !->
	console.log err.message
