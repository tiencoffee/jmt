app = void

function createComp props
	comp = ->
		vdom = {...props}
		vdom <<<
			checkAlive: !->
				unless @alived
					throw ""
			oninit: (vnode) !->
				for k, val of @
					@[k] = val.bind @ if typeof val is \function
				@alived = yes
				@attrs = vnode.attrs
				@children = vnode.children
				props.oninit?call @
			oncreate: (vnode) !->
				@dom = vnode.dom
				props.oncreate?call @
			onbeforeupdate: (vnode, old) ->
				@attrs = vnode.attrs
				@children = vnode.children
				props.onbeforeupdate?call @, old
			onupdate: (vnode) !->
				@dom = vnode.dom
				props.onupdate?call @
			onremove: !->
				@alived = no
				@dom = void
				props.onremove?call @
	comp

function createPage props
	vdom = {...props}
	vdom <<<
		oninit: !->
			@loading = yes
			@isOpenMenu = no
			@transparentMenu = no
			@aborters = []
			props.oninit?call @
		oncreate: !->
			@loading = void
			props.oncreate?call @
			m.redraw!
		load: (text) !->
			if text is yes
				text = "Đang tải..."
			@loading = text
			m.redraw!
		fetch: (url, opts = {}, type = \text) ->
			if typeof opts is \string
				type = opts
				opts = {}
			unless opts.signal
				aborter = new AbortController
				opts.signal = aborter.signal
				@aborters.push aborter
			fetch url, opts
				.then (res) ~>
					index = @aborters.indexOf aborter
					@aborters.splice index, 1
					res[type]!
		getDom: (path) ->
			query = encodeURIComponent path
			html = await @fetch "api/mware?q=#query" \text
			new DOMParser!parseFromString html, \text/html
		abort: !->
			for aborter in @aborters
				aborter.abort!
			@aborters = []
		closeMenu: !->
			@isOpenMenu = no
			m.redraw!
		onremove: !->
			@abort!
			props.onremove?call @
		view: ->
			m \.ful,
				m \.ful.ova,
					if @loading
						m \.ful.ccm,
							@loading
					else
						props.view.call @
				m \.ful.col.end.pen,
					if @isOpenMenu
						m \.c.col.end.rel.pea,
							key: \menu
							m \.ful.bg0.op50,
								ontouchmove: @closeMenu
								onclick: @closeMenu
							m \.pt3.bt3.bg0.z0,
								m \.rel,
									@menuView?!
					m \.row.fz3.tac.bg0.pea,
						key: \navbar
						class: app.class do
							"op0": @transparentMenu and not @isOpenMenu
						m \.c.py4.act,
							class: app.class do
								"toe": @isOpenMenu
							disabled:
								if @isOpenMenu
									app.index <= 0
								else
									@disabledPrev?!
							onclick: (event) !~>
								if @isOpenMenu
									app.back!
									@closeMenu!
								else
									@onclickPrev? event
							@isOpenMenu and "<--" or "<"
						m \.c.py4.act,
							ontouchstart: (event) !~>
								not= @isOpenMenu
							ontouchend: (event) !~>
								{clientX, clientY} = event.changedTouches.0
								if el = document.elementFromPoint clientX, clientY
									if el = el.closest \.toe
										app.mark el
										el.click!
							@navMenuView?! or "^"
						m \.c.py4.act,
							class: app.class do
								"toe": @isOpenMenu
							disabled:
								if @isOpenMenu
									app.index >= app.pages.length - 1
								else
									@disabledNext?!
							onclick: (event) !~>
								if @isOpenMenu
									app.forward!
									@closeMenu!
								else
									@onclickNext? event
							@isOpenMenu and "-->" or ">"
	createComp vdom

Album = createPage do
	oninit: !->
		@transparentMenu = yes
		@album = @attrs.album
		@hasGoto = no
		@willGoto = no
		@photoGoto = void
		@indexGoto = void
		@percGoto = void

	oncreate: !->
		await @loadDetails!
		@goto @album.index
		m.redraw!

	loadDetails: !->
		unless @album.total
			@load yes
			dom = await @getDom "beauty/#{@album.name}.html"
			@album.total = +(dom.querySelector \.pages .children[* - 2]innerText)
			els = dom.querySelectorAll \.picture-details>.special
			for a in els.0.querySelectorAll \a
				if name = /\/model\/(.+?)\.html/exec a.href ?.1
					unless model = app.models[name]
						model = app.createModel name
						if img = a.querySelector \img
							model.avatar = img.src
						app.models[name] = model
					@album.models.push model
			for script in dom.scripts
				text = script.text
				if text.includes "pc_cid = "
					@album.catid = +/pc_cid = (\w+)/exec text .1
					@album.conid = +/pc_id = (\w+)/exec text .1
					break
			els = dom.querySelectorAll \.picture-details>span
			for el in els
				text = el.innerText
				if text.startsWith \时间
					@album.time = text.substring 3 .split \- .reverse! .join \/
			for dd, i in dom.querySelectorAll \.relations>dd
				if i < 8
					a = dd.firstElementChild
					name = /\/beauty\/(.+?)\.html/exec a.href .1
					unless album = app.albums[name]
						thumb = a.firstElementChild.src
						album = app.createAlbum name, thumb
						app.albums[name] = album
					@album.others.push album
			@load!

	goto: (index) !->
		@album.index = index
		min = app.clamp index - 2 0 @album.total - 1
		max = app.clamp index + 2 0 @album.total - 1
		promises = []
		for let i from min to max
			if @album.photos[i] is void
				@album.photos[i] = no
				importance = i is index and \high or \low
				query = encodeURIComponent "ajax_beauty/#{@album.name}-#{i + 1}.html?ajax=1&catid=#{@album.catid}&conid=#{@album.conid}"
				url = "api/mware?q=#query"
				promise = @fetch url,
					importance: importance
					\json
				.then (data) !~>
					dom = new DOMParser!parseFromString data.pic, \text/html
					img = new Image
					img.src = dom.body.firstElementChild.src
					img.importance = importance
					img.onload = !~>
						photo = app.createPhoto img
						@album.photos[i] = photo
						m.redraw!
					img.onerror = !~>
						@album.photos[i] = 0
						m.redraw!
				.catch (err) !~>
					delete @album.photos[i]
				promises.push promise
		Promise.allSettled promises
		m.redraw!

	disabledPrev: ->
		@album.index <= 0

	disabledNext: ->
		@album.index >= @album.total - 1

	onclickPrev: !->
		@goto @album.index - 1

	onclickNext: !->
		@goto @album.index + 1

	onclickGoto: !->
		if index = await app.openInput "Nhập trang (#{@album.index + 1} / #{@album.total}):"
			index--
			if 0 <= index <= @album.total - 1
				@goto index
		@closeMenu!

	onclick: (event) !->
		{x, y} = event
		px = x / innerWidth
		py = y / innerHeight
		if px < 0.5
			if py < 0.25
				if photo = @album.photos[@album.index]
					not= photo.isScale
					app.mark 0 0 16 innerHeight / 4
			else if py < 0.5
				if photo = @album.photos[@album.index]
					not= photo.isRotate
					app.mark 0 innerHeight * 0.25 16 innerHeight / 4
			else if py < 0.75
				unless @disabledNext!
					@onclickNext!
					app.mark 0 innerHeight * 0.5 16 innerHeight / 4
			else
				unless @disabledPrev!
					@onclickPrev!
					app.mark 0 innerHeight * 0.75 16 innerHeight / 4

	onscrollViewer: (event) !->
		event.redraw = no
		unless @hasGoto
			if photo = @album.photos[@album.index]
				photo.scx = albumViewer.scrollLeft
				photo.scy = albumViewer.scrollTop

	onloadPhoto: (event) !->
		photo = @photoGoto or @album.photos[@album.index]
		if photo.scx?
			albumViewer.scrollLeft = photo.scx
			albumViewer.scrollTop = photo.scy
		else
			offset = albumViewer.scrollWidth - albumViewer.offsetWidth
			if offset > 0
				albumViewer.scrollLeft = Math.round offset / 2

	ontouchmoveGotoSlider: (event) !->
		event.redraw = no
		@hasGoto = yes
		{target} = event
		{clientX: x, clientY: y} = event.changedTouches.0
		frac = (y - target.offsetTop) / target.offsetHeight
		max = @album.total - 1
		indexGoto = Math.round app.clamp frac * max, 0 max
		if x < 80
			if not @willGoto or indexGoto isnt @indexGoto
				@willGoto = yes
				@photoGoto = @album.photos[indexGoto]
				@indexGoto = indexGoto
				@percGoto = indexGoto / max * 100
				m.redraw!
		else
			if @willGoto
				@willGoto = no
				m.redraw!

	ontouchendGotoSlider: (event) !->
		if @hasGoto
			if @willGoto
				@goto @indexGoto
			@hasGoto = no
			@willGoto = no
			@photoGoto = void
			@indexGoto = void
			@percGoto = void

	navMenuView: ->
		"#{@album.index + 1} / #{@album.total}"

	menuView: ->
		m \.col.gy3,
			m \.px2,
				@album.name
			m \.row.wra,
				@album.models.map (model) ~>
					m \.c6.col.mid.gy1.act,
						onclick: (event) !~>
							app.push Model,
								model: model
						m \img.obcv,
							src: model.avatar
							width: 64
							height: 64
						model.name
			m \.row.wra.g2.px2.co3,
				m \.c6,
					"Ngày: #{@album.time}"
			m \.row.wra,
				@album.others.map (album) ~>
					m \.c3.ar69,
						onclick: (event) !~>
							app.push Album,
								album: album
						m \img.w100.h100.obct,
							src: album.thumb
			m \.row.wra.tac,
				m \.c4
				m \.c4.py4.act.toe,
					onclick: @onclickGoto
					"Đến trang..."

	view: ->
		photo = if @hasGoto and @willGoto => @photoGoto else @album.photos[@album.index]
		m \.ful,
			onclick: @onclick
			m \.ful.ova#albumViewer,
				onscroll: @onscrollViewer
				if photo
					isRotate = (photo.width / photo.height > 1.2) - photo.isRotate
					if isRotate
						m \img.Album__photo.Album__photo--isRotate,
							class: app.class do
								"Album__photo--isScale": photo.isScale
							src: photo.src
							width: innerHeight
							onload: @onloadPhoto
					else
						m \img.Album__photo.Album__photo--noRotate,
							class: app.class do
								"Album__photo--isScale": photo.isScale
							src: photo.src
							onload: @onloadPhoto
				else if photo is 0
					m \.ful.ccm,
						"Ảnh lỗi!"
						m \.mt3.p3.act,
							onclick: (event) !~>
								event.stopPropagation!
								delete @album.photos[@album.index]
								@goto @album.index
							"Thử tải lại"
				else
					m \.ful.ccm,
						@hasGoto and "Chưa tải ảnh" or "Đang tải..."
			m \.gotoSlider,
				ontouchmove: @ontouchmoveGotoSlider
				ontouchend: @ontouchendGotoSlider
				if @willGoto
					m \.gotoSliderTooltip,
						style:
							top: @percGoto + \%
						m \.fz5.inb @indexGoto + 1
						m \.co3.inb.ml2 "/ #{@album.total}"
						m \.ml1 @album.index + 1

Models = createPage do
	oncreate: !->
		await @goto app.model.index
		m.redraw!

	goto: (index) !->
		@abort!
		app.model.index = index
		unless app.model.pages[index]
			@load yes
			dom = await @getDom "model/index-#{index + 1}.html"
			app.model.total or= +(dom.querySelector \.pages .children[* - 2]innerText)
			models = []
			for li in dom.querySelectorAll \#list>li
				a = li.firstElementChild
				name = /\/model\/(.+?)\.html/exec a.href .1
				model = app.createModel name
				if img = a.querySelector \img
					model.avatar = img.src
				app.models[name] = model
				models.push model
			app.model.pages[index] = models
		@load!
		m.redraw!

	disabledPrev: ->
		app.model.index <= 0

	disabledNext: ->
		app.model.index >= app.model.total - 1

	onclickPrev: !->
		@goto app.model.index - 1

	onclickNext: !->
		@goto app.model.index + 1

	navMenuView: ->
		"#{app.model.index + 1} / #{app.model.total}"

	menuView: ->
		m \.row.wra.tac,
			m \.c4.py4.act,
				onclick: !~>
					app.push Home
				"home"
			m \.c4.py4.act.toe,
				onclick: !~>
					if index = await app.openInput "Nhập trang (#{app.model.index + 1} / #{app.model.total}):"
						index--
						if 0 <= index <= app.model.total - 1
							@goto index
					@closeMenu!
				"Đến trang..."
			m \.c4.py4.act,
				onclick: !~>
					app.push Tags
				"tags"

	view: ->
		m \.row.wra.pt4.pb8.tac,
			app.model.pages[app.model.index].map (model) ~>
				m \.c3,
					onclick: (event) !~>
						app.push Model,
							model: model
					m \img.w100.ar89.obcv,
						src: model.avatar
					m \.py2.fz1,
						model.name

Model = createPage do
	oninit: !->
		@model = @attrs.model

	oncreate: !->
		await @loadDetails!
		await @goto @model.index
		m.redraw!

	loadDetails: !->
		unless @model.total
			@load yes
			dom = await @getDom "model/#{@model.name}.html"
			@model.total = 1
			if el = dom.querySelector \.pages
				if el .= children[* - 2]
					@model.total = +el.innerText
			for span in dom.querySelectorAll \.people-info>span
				text = span.innerText
				if text.startsWith \生日
					birthday = text.substring 3 .trim!
					if birthday is \0000-00-00
						birthday = void
					else
						birthday .= split \- .reverse!join \/
					@model.birthday = birthday
				else if text.startsWith \三围
					@model.body = text.substring 3 .trim!replace /[a-z]/gi "" .split \- .join " - "
				else if text.startsWith \身高
					@model.height = text.substring 3 .trim!replace /cm/i " cm"
				else if text.startsWith \体重
					@model.weight = text.substring 3 .trim!replace /kg/i " kg"
			@load!
			m.redraw!

	goto: (index) !->
		@abort!
		@model.index = index
		unless @model.pages[index]
			@load yes
			dom = await @getDom "model/#{@model.name}-#{index + 1}.html"
			window.a = dom
			albums = []
			for li in dom.querySelectorAll \.pic-list>.clearfix>li
				a = li.firstElementChild
				name = /\/beauty\/(.+?)\.html/exec a.href .1
				unless album = app.albums[name]
					thumb = a.firstElementChild.src
					album = app.createAlbum name, thumb
					app.albums[name] = album
				albums.push album
			@model.pages[index] = albums
		@load!
		m.redraw!

	disabledPrev: ->
		@model.index <= 0

	disabledNext: ->
		@model.index >= @model.total - 1

	onclickPrev: !->
		@goto @model.index - 1

	onclickNext: !->
		@goto @model.index + 1

	navMenuView: ->
		"#{@model.index + 1} / #{@model.total}"

	menuView: ->
		m \.row.wra.mid.gy3.pb3.px2,
			m \.c6,
				m \img.obcv,
					src: @model.avatar
					width: 64
					height: 64
			m \.c6.fz3,
				@model.name
			m \.c6,
				"Sinh nhật: #{@model.birthday or ""}"
			m \.c6,
				"Chiều cao: #{@model.height or ""}"
			m \.c6,
				"Ba vòng: #{@model.body or ""}"
			m \.c6,
				"Cân nặng: #{@model.weight or ""}"

	view: ->
		albums = @model.pages[@model.index]
		m \.col.mih100,
			m \.py2.tac "model"
			if albums.length
				m \.row.wra.pb8,
					albums.map (album) ~>
						m \.c3.ar69,
							onclick: (event) !~>
								app.push Album,
									album: album
							m \img.w100.h100.obct,
								src: album.thumb
			else
				m \.c.ccm,
					"Không có album nào"

Tags = createPage do
	oncreate: !->
		await @goto app.tag.index
		m.redraw!

	goto: (index) !->
		@abort!
		app.tag.index = index
		unless app.tag.pages[index]
			@load yes
			dom = await @getDom "tags/index-#{index + 1}.html"
			app.tag.total or= +(dom.querySelector \.pages .children[* - 2]innerText)
			tags = []
			for li in dom.querySelectorAll \#list>li
				a = li.firstElementChild
				name = /\/tags\/(.+?)\.html/exec a.href .1
				thumb = a.querySelector \img ?.src
				tag = app.createTag name, thumb
				app.tags[name] = tag
				tags.push tag
			app.tag.pages[index] = tags
		@load!
		m.redraw!

	disabledPrev: ->
		app.tag.index <= 0

	disabledNext: ->
		app.tag.index >= app.tag.total - 1

	onclickPrev: !->
		@goto app.tag.index - 1

	onclickNext: !->
		@goto app.tag.index + 1

	navMenuView: ->
		"#{app.tag.index + 1} / #{app.tag.total}"

	menuView: ->
		m \.row.wra.tac,
			m \.c4.py4.act,
				onclick: !~>
					app.push Home
				"home"
			m \.c4.py4.act.toe,
				onclick: !~>
					if index = await app.openInput "Nhập trang (#{app.tag.index + 1} / #{app.tag.total}):"
						index--
						if 0 <= index <= app.tag.total - 1
							@goto index
					@closeMenu!
				"Đến trang..."
			m \.c4.py4.act,
				onclick: !~>
					app.push Models
				"model"

	view: ->
		m \.row.wra.pt4.pb8.tac,
			app.tag.pages[app.tag.index].map (tag) ~>
				m \.c3,
					onclick: (event) !~>
						app.push Tag,
							tags: tag
					if tag.thumb
						m \img.w100.ar89.obcv,
							src: tag.thumb
					else
						m \.w100.ar89.bg1
					m \.py2.fz1,
						tag.text

Tags.infos = await (await fetch \tags.json)json!

Tag = createPage do
	oninit: !->
		@tag = @attrs.tags

	oncreate: !->
		await @loadDetails!
		await @goto @tag.index
		m.redraw!

	loadDetails: !->
		unless @tag.total
			@load yes
			dom = await @getDom "tags/#{@tag.name}.html"
			@tag.total = 1
			if el = dom.querySelector \.pages
				if el .= children[* - 2]
					@tag.total = +el.innerText
			@load!
			m.redraw!

	goto: (index) !->
		@abort!
		@tag.index = index
		unless @tag.pages[index]
			@load yes
			dom = await @getDom "tags/#{@tag.name}-#{index + 1}.html"
			window.a = dom
			albums = []
			for li in dom.querySelectorAll \.pic-list>.clearfix>li
				a = li.firstElementChild
				name = /\/beauty\/(.+?)\.html/exec a.href .1
				unless album = app.albums[name]
					thumb = a.firstElementChild.src
					album = app.createAlbum name, thumb
					app.albums[name] = album
				albums.push album
			@tag.pages[index] = albums
		@load!
		m.redraw!

	disabledPrev: ->
		@tag.index <= 0

	disabledNext: ->
		@tag.index >= @tag.total - 1

	onclickPrev: !->
		@goto @tag.index - 1

	onclickNext: !->
		@goto @tag.index + 1

	navMenuView: ->
		"#{@tag.index + 1} / #{@tag.total}"

	menuView: ->
		m \.row.wra.mid.gy3.pb3.px2,
			m \.c6,
				m \img.obcv,
					src: @tag.thumb
					width: 64
					height: 64
			m \.c6.fz3,
				@tag.name
			m \.c12,
				@tag.text

	view: ->
		albums = @tag.pages[@tag.index]
		m \.col.mih100,
			m \.py2.tac "tags"
			if albums.length
				m \.row.wra.pb8,
					albums.map (album) ~>
						m \.c3.ar69,
							onclick: (event) !~>
								app.push Album,
									album: album
							m \img.w100.h100.obct,
								src: album.thumb
			else
				m \.c.ccm,
					"Không có album nào"

Home = createPage do
	oncreate: !->
		await @goto app.home.index
		m.redraw!

	goto: (index) !->
		@abort!
		app.home.index = index
		unless app.home.pages[index]
			@load yes
			dom = await @getDom "beauty/index-#{index + 1}.html"
			app.home.total or= +(dom.querySelector \.pages .children[* - 2]innerText)
			albums = []
			for li in dom.querySelectorAll \#list>li
				a = li.firstElementChild
				name = /\/beauty\/(.+?)\.html/exec a.href .1
				unless album = app.albums[name]
					thumb = a.firstElementChild.src
					album = app.createAlbum name, thumb
					app.albums[name] = album
				albums.push album
			app.home.pages[index] = albums
		@load!
		m.redraw!

	disabledPrev: ->
		app.home.index <= 0

	disabledNext: ->
		app.home.index >= app.home.total - 1

	onclickPrev: !->
		@goto app.home.index - 1

	onclickNext: !->
		@goto app.home.index + 1

	navMenuView: ->
		"#{app.home.index + 1} / #{app.home.total}"

	menuView: ->
		m \.row.wra.tac,
			m \.c4.py4.act,
				onclick: !~>
					app.push Models
				"model"
			m \.c4.py4.act.toe,
				onclick: !~>
					if index = await app.openInput "Nhập trang (#{app.home.index + 1} / #{app.home.total}):"
						index--
						if 0 <= index <= app.home.total - 1
							@goto index
					@closeMenu!
				"Đến trang..."
			m \.c4.py4.act,
				onclick: !~>
					app.push Tags
				"tags"

	view: ->
		m \.row.wra.pt4.pb8,
			app.home.pages[app.home.index].map (album) ~>
				m \.c3.ar69,
					onclick: (event) !~>
						app.push Album,
							album: album
					m \img.w100.h100.obct,
						src: album.thumb

App = createComp do
	oninit: !->
		app := @
		@pages = []
		@page = void
		@index = -1
		@albums = {}
		@models = {}
		@tags = {}
		@input = void
		@home =
			pages: []
			index: 0
			total: 0
		@model =
			pages: []
			index: 0
			total: 0
		@tag =
			pages: []
			index: 0
			total: 0

	oncreate: !->
		addEventListener \pointerdown @ontouchstart
		addEventListener \contextmenu @oncontextmenu
		@push Home

	class: (...items) ->
		res = []
		for item in items
			if Array.isArray item
				res.push @class ...item
			else if item instanceof Object
				for k, val of item
					res.push k if val
			else
				res.push item
		res * " "

	uid: ->
		"" + performance.now! + Math.random!

	clamp: (num, min, max) ->
		num = min if num < min
		num = max if num > max
		num

	push: (comp, page = {}) !->
		page.comp = comp
		@pages.splice @index + 1 9e9 page
		@index = @pages.length - 1
		@page = page
		m.mount pageEl,
			view: ~>
				m comp, page
		m.redraw!

	back: !->
		if @index > 0
			@page = @pages[--@index]
			m.mount pageEl,
				view: ~>
					m @page.comp, @page
			m.redraw!

	forward: !->
		if @index < @pages.length - 1
			@page = @pages[++@index]
			m.mount pageEl,
				view: ~>
					m @page.comp, @page
			m.redraw!

	createAlbum: (name, thumb) ->
		name: name
		thumb: thumb
		photos: []
		models: []
		time: void
		index: 0
		total: 0
		catid: void
		conid: void
		others: []

	createModel: (name) ->
		name: name
		avatar: void
		birthday: void
		body: void
		height: void
		weight: void
		pages: []
		index: 0
		total: 0

	createTag: (name, thumb) ->
		info = Tags.infos[name]
		name: name
		thumb: thumb or info?1
		text: info?0
		pages: []
		index: 0
		total: 0

	createPhoto: (img) ->
		src: img.src
		width: img.naturalWidth
		height: img.naturalHeight
		scx: void
		scy: void
		isScale: no
		isRotate: no

	mark: (x, y, width, height) !->
		if x instanceof Element
			{x, y, width, height} = x.getBoundingClientRect!
		animEl = document.createElement \div
		animEl.className = \act2
		animEl.style <<<
			left: x + \px
			top: y + \px
			width: width + \px
			height: height + \px
		animEl.onanimationend = animEl~remove
		document.body.appendChild animEl

	openInput: (title = "") ->
		new Promise (resolve) !~>
			@input =
				title: title
				val: ""
				resolve: resolve
			m.redraw!

	closeInput: (val) !->
		@input.resolve val
		@input = void
		m.redraw!

	ontouchstart: (event) !->
		if el = event.target.closest \.act
			@mark el

	oncontextmenu: (event) !->
		if event.target.localName is \img
			event.preventDefault!

	view: ->
		m.fragment do
			m \#pageEl
			if @input
				m \.ful.fix.col.tac.bg0,
					m \.c.ccm.px4,
						onclick: (event) !~>
							@closeInput!
						m \div,
							@input.title
						m \.mt4.fz6,
							@input.val or \\xa0
					m \.row.wra.fz3,
						[7 8 9 4 5 6 1 2 3 0]map (num) ~>
							m \.c4.py4.act,
								onclick: !~>
									@input.val += num
								num
						m \.c4.py4.act,
							onclick: !~>
								@closeInput +@input.val
							"OK"
						m \.c4.py4.act,
							disabled: not @input.val
							onclick: !~>
								@input.val .= slice 0 -1
							"<=="

m.mount appEl, App
