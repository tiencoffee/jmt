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
				name = /\/model\/(.+?)\.html/exec a.href .1
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
				unless model = app.models[name]
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
				unless tag = app.tags[name]
					tag = app.createTag name
					if img = a.querySelector \img
						tag.thumb = img.src
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
					m \img.w100.ar89.obcv,
						src: tag.thumb
					m \.py2.fz1,
						tag.text

Tags.texts =
	chunyufeng: "tinh khiết muốn gió"
	nvmishu: "nữ thư ký"
	siwafeitun: "mông mập mạp của vớ"
	dingjishaofu: "thiếu phụ hàng đầu"
	jiepaigaogen: "chụp ảnh gót chân trên đường phố"
	heisiyouhuo: "sự cám dỗ của lụa đen"
	qingchunhushizhifu: "đồng phục y tá tinh khiết"
	jurunvyou: "cự nhũ nữ ưu tú"
	siwashunv: "người phụ nữ quen thuộc với vớ"
	heisiluoli: "rose lori"
	fengsaoshaofu: "thiếu phụ phong tao"
	fengmanshaofu: "thiếu phụ đầy đặn"
	fengsao: "phong tao"
	xingganzuichun: "đôi môi gợi cảm"
	hongchun: "môi đỏ"
	tudian: "điểm lồi"
	rugou: "rãnh vú"
	wukelanmeinv: "người đẹp ukraine"
	wukelan: "ukraina"
	riben: "nhật bản"
	yuenan: "việt nam"
	eluosi: "nga"
	zhongguo: "trung quốc"
	renticaihui: "sơn cơ thể con người"
	hanguomeinv: "người đẹp hàn quốc"
	eluosimeinv: "người đẹp nga"
	meinvzhubo: "người đẹp dẫn chương trình"
	zhongguomote: "người mẫu trung quốc"
	meinvzipai: "người đẹp chụp ảnh tự sướng"
	yuenanmeinv: "người đẹp việt nam"
	ribenmeinv: "người đẹp nhật bản"
	yugang: "bồn tắm"
	meinvmishu: "thư ký xinh đẹp"
	mishu: "thư ký"
	zhixing: "tri thức"
	yongchi: "hồ bơi"
	shatan: "bãi biển đầy cát"
	gaogenxie: "giày cao gót"
	yundong: "thể thao"
	luoli: "lori"
	jiaoshi: "giáo viên"
	jinghua: "hoa cảnh sát"
	lolita: "lolita"
	jiepaishunv: "chụp ảnh người phụ nữ quen đường phố"
	chunjie: "lễ hội mùa xuân"
	shamo: "sa mạc"
	sifangzhao: "ảnh chụp phòng riêng"
	jiepaimeinv: "chụp ảnh người đẹp trên đường phố"
	jiepaibijini: "chụp ảnh bikini trên đường phố"
	jiepaichaodi: "đường phố chụp đáy"
	jiepaishaofu: "chụp ảnh thiếu phụ trên đường phố"
	zhanhuimote: "người mẫu triển lãm"
	jiepaijinshen: "chụp ảnh đường phố chặt chẽ"
	jiepainiuzi: "chụp cao bồi trên đường phố"
	jiepaireku: "chụp quần nóng trên đường phố"
	nvbing: "nữ binh sĩ"
	yanjingniang: "kính nương"
	ribenbijini: "bikini nhật bản"
	rougan: "cảm giác thịt"
	mengxi: "manh hệ"
	siwa: "vớ"
	jiaju: "nhà cửa"
	xinggan: "gợi cảm"
	yexing: "hoang dã"
	xiaomaise: "màu lúa mì"
	jiepaimeitun: "chụp ảnh đường phố đẹp"
	heisimeitui: "đôi chân đen xinh đẹp"
	botaoxiongyong: "sóng ngực dâng trào"
	neiyi: "đồ lót"
	nuannan: "người đàn ông ấm áp"
	oumeinanmo: "người mẫu nam châu âu và mỹ"
	oumeixiaoshuaige: "anh chàng đẹp trai châu âu và mỹ"
	jiroushuaige: "anh chàng đẹp trai cơ bắp"
	dashu: "chú"
	shuaigezhaopian: "hình ảnh của anh chàng đẹp trai"
	nvwangdiaojiao: "nữ hoàng dạy dỗ"
	changxuemeinv: "người đẹp giày cao gót"
	lianyiqun: "một chiếc váy"
	liguimeishu: "tủ đẹp bó hoa"
	zhengmei: "chính muội"
	rousiwa: "vớ thịt"
	yinv: "b nữ"
	jujiameinv: "người đẹp gia đình"
	jzhaobei: "J-7 CỐC"
	izhaobei: "CỐC I.I"
	jianshenmeinv: "người đẹp thể dục"
	mengnv: "manh nữ"
	hunxuemeinv: "người đẹp lai"
	chenshan: "áo sơ mi"
	haibianmeinv: "người đẹp bên bờ biển"
	yujie: "ngự tỷ"
	baoru: "bùng nổ sữa"
	gaogenmeitui: "đôi chân cao gót đẹp"
	smkunbang: "SM BÓ"
	wenshenmeinv: "người đẹp xăm hình"
	gudian: "cổ điển"
	ticaofu: "quần áo thể dục dụng cụ"
	jiepai: "chụp ảnh đường phố"
	shishangmeinv: "người đẹp thời trang"
	jiemeihua: "hoa chị em"
	diaodaisiwa: "vớ thắt lưng"
	hongsesiwa: "vớ đỏ"
	taiqiu: "bi-a"
	rouganmeinv: "người đẹp cảm giác thịt"
	wangwa: "vớ lưới"
	gaogui: "cao quý"
	huisi: "sợi xám"
	chuangshang: "trên giường"
	xiezhen: "viết sự thật"
	ruanmei: "em gái mềm mại"
	bainen: "trắng nõn"
	nenmo: "mô hình non"
	dingziku: "quần chữ đinh"
	shengdan: "giáng sinh"
	chuniang: "đầu bếp"
	quanjibaobei: "em bé boxing"
	kaibeimaoyi: "mở áo len ra"
	renjianxiongqi: "áo ngực trên trái đất"
	yubei: "ngọc lưng"
	yanjing: "kính mắt"
	hanfu: "hán phục"
	dudou: "yếm"
	wenquan: "suối nước nóng"
	xuedi: "tuyết"
	mitaotun: "mít"
	sheying: "nhiếp ảnh"
	gugan: "cảm giác xương"
	xinnian: "năm mới"
	cosplay: "COSPLAY"
	jiaosebanyan: "nhập vai"
	lanqiubaobei: "em bé bóng rổ"
	shatanmeinv: "vẻ đẹp bãi biển"
	nvjing: "nữ cảnh sát"
	liaokao: "xiềng xích"
	xingganshaonv: "cô gái gợi cảm"
	gaogenliangxie: "dép cao gót"
	kongjie: "tiếp viên hàng không"
	meihuomeinv: "quyến rũ người đẹp"
	weimei: "đẹp"
	hzhaobei: "CỐC H-7"
	neiyimeinv: "người đẹp nội y"
	fzhaobei: "CỐC F-7"
	maonvlang: "miêu nữ"
	qipao: "sườn xám"
	dadan: "táo bạo"
	zhifu: "đồng phục"
	daxiong: "ngực lớn"
	tongyanjuru: "đồng nhan cự nhũ"
	shaofu: "thiếu phụ"
	wumei: "quyến rũ"
	sifang: "phòng riêng"
	qingxin: "tươi mới"
	youwu: "vưu vật"
	qiaotun: "mông cong"
	dachidu: "quy mô lớn"
	rentiyishu: "nghệ thuật cơ thể con người"
	xingganmeinv: "người đẹp gợi cảm"
	lengyan: "lạnh lùng"
	toushimeinv: "phối cảnh người đẹp"
	yushi: "phòng tắm"
	jingyan: "tuyệt đẹp"
	bijini: "bikini"
	guganmeinv: "người đẹp xương"
	shishen: "ướt cơ thể"
	shuishoufu: "quần áo thủy thủ"
	fennen: "bột mềm"
	sikushui: "nước hồ chứa chết"
	gaochayongzhuang: "đồ bơi nĩa cao"
	beixin: "áo vest"
	baowenmeinv: "mỹ nữ báo hoa văn"
	qizhi: "khí chất"
	ezhaobei: "CỐC E.T"
	dzhaobeimeinv: "NGƯỜI ĐẸP CÚP D"
	youyameinv: "vẻ đẹp thanh lịch"
	wangyi: "quần áo lưới"
	jipin: "cực phẩm"
	yangguang: "ánh nắng mặt trời"
	shaonv: "thiếu nữ"
	heichangzhi: "màu đen dài và thẳng"
	baotunqunmeinv: "người đẹp mặc váy áo dài"
	laoshi: "giáo viên"
	zhiyezhuang: "trang phục công nghiệp"
	tunvlang: "cô gái thỏ"
	nvpu: "người giúp việc"
	jinshenku: "quần bó sát"
	hefu: "kimono"
	leisi: "ren"
	shuiyi: "đồ ngủ"
	pingxiong: "ngực phẳng"
	hushi: "y tá"
	qingchun: "thanh thuần"
	xizhuangmeinv: "người đẹp mặc vest"
	yundongzhuang: "quần áo thể thao"
	niuzi: "cao bồi"
	chaoduanqun: "váy siêu ngắn"
	gaogen: "gót chân cao gót"
	tianmei: "ngọt ngào"
	czhaobeimeinv: "NGƯỜI ĐẸP CÚP C"
	changfameinv: "người đẹp tóc dài"
	changtongwa: "vớ ống"
	changqun: "váy dài"
	siwameinv: "người đẹp vớ"
	gzhaobei: "CỐC G-7"
	bangongshi: "văn phòng"
	meitun: "mỹ"
	yisheng: "bác sĩ"
	saichenvlang: "cô gái đua xe"
	keai: "dễ thương"
	reku: "quần nóng"
	meiru: "làm đẹp sữa"
	hanguo: "hàn quốc"
	gothic_lolita: "gothlorita"
	classical_lolita: "lolita cổ điển"
	sweet_lolita: "lolita ngọt ngào"
	hanguomeinan: "mỹ nam hàn quốc"
	xiaopingtou: "đầu phẳng nhỏ"
	hejiudeshuaige: "anh chàng đẹp trai uống rượu"
	chaoshuaiqi: "siêu đẹp trai"
	badaozongcaifan: "tổng giám đốc bá đạo phạm"
	hanrimingxing: "ngôi sao hàn quốc và nhật bản"
	hongshufufu: "vợ chồng khoai lang"
	gaoqing: "hd"
	deguoshuaige: "anh chàng đẹp trai người đức"
	hanguoxiaoshuaige: "anh chàng đẹp trai hàn quốc"
	hanguonanmingxing: "ngôi sao nam hàn quốc"
	xiaoqingxin: "nhỏ tươi"
	mingxingbizhi: "hình nền ngôi sao"
	meihuo: "quyến rũ"
	guowaixiaonanhai: "cậu bé nước ngoài"
	jita: "guitar"
	hunxueer: "con lai"
	hanliumingxing: "ngôi sao hàn quốc"
	agenting: "argentina"
	xiaoshidai: "thời đại nhỏ bé"
	wangluogeshou: "ca sĩ mạng"
	kushuaixiezhen: "mát mẻ và thực tế"
	yinglun: "anh"
	huzhaxingnan: "người đàn ông cặn bã"
	gaoqingshuaige: "hd đẹp trai"
	danmai: "đan mạch"
	huameinan: "mỹ nam hoa"
	xibanya: "tây ban nha"
	zhengtainan: "chính thái nam"
	fengdu: "phong độ"
	shuaidailiao: "đẹp trai đến ngây người"
	alianqiumote: "người mẫu uae"
	mingxingshuaige: "anh chàng đẹp trai ngôi sao"
	oumeishuaige: "anh chàng đẹp trai châu âu và mỹ"
	shaoshuai: "thiếu tướng"
	pangke: "ponk"
	ku: "mát mẻ"
	renxiangsheying: "nhiếp ảnh chân dung"
	baxishuaige: "anh chàng đẹp trai brazil"
	lianhuaxiaowangzi: "hoàng tử nhỏ của hoa sen"
	faguoshuaige: "anh chàng đẹp trai người pháp"
	youyisi: "thật thú vị"
	oumeizhengtai: "châu âu và mỹ là quá"
	yaonan: "yêu nam"
	nanyiren: "nam nghệ sĩ"
	bashananshi: "người đàn ông barsha"
	shishanghan: "thời trang hàn quốc"
	zhiyuxi: "hệ thống chữa bệnh"
	xiuxianxiezhen: "giản dị viết sự thật"
	baxinanmo: "người mẫu nam brazil"
	meiguoshuaige: "anh chàng đẹp trai người mỹ"
	hongfaxixuegui: "ma cà rồng tóc đỏ"
	danmainanmo: "người mẫu nam đan mạch"
	hanxing: "sao hàn"
	zhennanren: "một người đàn ông thực sự"
	qiuxing: "ngôi sao bóng đá"
	faguoyanyuan: "diễn viên người pháp"
	miren: "quyến rũ"
	shishangzaoxing: "phong cách thời trang"
	zazhifengmian: "bìa tạp chí"
	jianshuo: "mạnh mẽ"
	shangganshuaige: "anh chàng đẹp trai buồn"
	youshang: "nỗi buồn"
	gediao: "phong cách"
	quanji: "boxing"
	gaoqingtupian: "hình ảnh hd"
	paiqiushuaige: "anh chàng đẹp trai bóng chuyền"
	shuaiqixiezhen: "đẹp trai là đúng sự thật"
	hunxue: "con lai"
	xiaosuihua: "những bông hoa nhỏ"
	tongxing: "ngôi sao nhí"
	jirouxiezhen: "cơ bắp là sự thật"
	nanrenwei: "hương vị nam tính"
	jianada: "ca-na-đa"
	wudamingxing: "ngôi sao võ thuật"
	gaoqingxiezhen: "độ nét cao thực tế"
	wangluohongren: "người nổi tiếng trên mạng"
	xiaocao: "cỏ trường học"
	baqiwailu: "khí phách lộ ra ngoài"
	meilinanren: "người đàn ông quyến rũ"
	gaofushuai: "cao phú soái"
	shuaiqixingnan: "người đàn ông đẹp trai"
	yanjingnan: "người đàn ông đeể"
	zaoxing: "tạo hình"
	haibian: "bên bờ biển"
	youyunan: "người đàn ông u sầu"
	yangguangnanhai: "cậu bé ánh nắng mặt trời"
	dashukong: "đại thúc khống chế"
	qiaopi: "vui tươi"
	changtui: "chân dài"
	dengshanke: "nhà leo núi"
	dongzhuang: "quần áo mùa đông"
	meili: "quyến rũ"
	faxing: "kiểu tóc"
	huzi: "râu"
	huzha: "râu cặn bã"
	guangbangzituoyi: "quang tanh cởi quần áo"
	mengwa: "manh oa"
	wangguan: "vương miện"
	quanjixiezhen: "boxing viết sự thật"
	oumeifan: "châu âu và mỹ phạm"
	gutongse: "màu đồng"
	meng: "manh"
	wenshen: "hình xăm"
	yijing: "ý cảnh"
	meitu: "meitu"
	yanshen: "ánh mắt"
	nanzhuchiren: "nam mc"
	nanhai: "cậu bé"
	wangluoshuaige: "anh chàng đẹp trai trên mạng"
	xiuxian: "giải trí"
	shaonan: "thiếu nam"
	xiaoxianrou: "thịt tươi nhỏ"
	mikafengshang: "mika phong thượng"
	banluo: "bán khỏa thân"
	yangguangshaonian: "thiếu niên ánh mặt trời"
	danyanpi: "mí mắt một mí"
	yingguoshuaige: "anh chàng đẹp trai người anh"
	zhenkong: "chân không"
	xizhuang: "bộ đồ"
	jiche: "đầu máy xe lửa"
	bizhitupian: "hình nền hình nền"
	tupiandaquan: "hình ảnh đầy đủ"
	haokandetupian: "hình ảnh đẹp"
	haokandebizhi: "hình nền đẹp"
	touxiangdaquan: "avatar là toàn diện"
	meinvtupiandaquan: "hình ảnh của người đẹp"
	beitou: "quay đầu lại"
	nanmingxing: "ngôi sao nam"
	zhinan: "người đàn ông thẳng"
	jianmei: "thể hình"
	duanfafaxingnan: "người đàn ông với mái tóc ngắn"
	dabeitou: "một cái đầu lớn"
	juanfa: "tóc xoăn"
	zhongduanfa: "tóc ngắn và trung bình"
	nanzhuchi: "nam mc"
	zhongchangfafaxing: "kiểu tóc dài trung bình"
	lvxingzhao: "ảnh du lịch"
	shifa: "tóc ướt"
	xiangshui: "nước hoa"
	feizhuliushuaige: "soái ca không chính thống"
	liuhaifaxing: "kiểu tóc tóc dài"
	mojing: "kính râm"
	guangtou: "đầu trực"
	gexingnansheng: "các chàng trai cá tính"
	lvsefaxing: "kiểu tóc màu xanh lá cây"
	oumeimingxing: "ngôi sao châu âu và mỹ"
	quanbailook: "tất cả đều trắng look"
	liuxingfaxing: "kiểu tóc phổ biến"
	shishangfaxing: "kiểu tóc thời trang"
	shuaigexiezhen: "anh chàng đẹp trai viết thật"
	jicheshuaige: "anh chàng đẹp trai đầu máy xe lửa"
	fugufeng: "phong cách retro"
	xihafeng: "phong cách hip-hop"
	youtou: "đầu dầu"
	nanshiduanfa: "tóc ngắn cho nam giới"
	yundongyuan: "vận động viên"
	xiaosheng: "tiểu sinh"
	yuanqi: "nguyên khí"
	gangfeng: "gió hồng kông"
	tuya: "graffiti"
	weijuanduanfa: "tóc ngắn xoăn nhẹ"
	shunan: "người đàn ông quen thuộc"
	geshou: "ca sĩ"
	zhuchiren: "người dẫn chương trình"
	malaixiyamingxing: "ngôi sao malaysia"
	hantuan: "đoàn hàn quốc"
	neidimingxing: "ngôi sao đại lục"
	niuziyi: "quần jean"
	xiaohuozi: "chàng trai trẻ"
	weijuanfaxing: "kiểu tóc xoăn nhẹ"
	mingxingfaxing: "kiểu tóc ngôi sao"
	chunzhuang: "trang phục mùa xuân"
	chunyi: "ý nghĩa mùa xuân"
	taqing: "đạp thanh"
	meiguomingxing: "ngôi sao người mỹ"
	zipai: "chụp ảnh tự sướng"
	gaoguai: "thật kỳ lạ"
	qinglv: "cặp đôi"
	enai: "ân ái"
	dachangtui: "chân dài"
	gufeng: "phong cách cổ xưa"
	xianqi: "tiên khí"
	gongzhuang: "quần áo công nhân"
	mire: "gạo nóng"
	jujiashuaige: "anh chàng đẹp trai ở nhà"
	chaoliu: "xu hướng"
	ganjingshuaige: "anh chàng đẹp trai sạch sẽ"
	mao: "mèo"
	dongbeishuaige: "anh chàng đẹp trai đông bắc"
	yinglang: "cứng rắn"
	piyinan: "người đàn ông mặc áo da"
	huachenyinan: "người đàn ông áo sơ mi hoa"
	hanguonanxing: "sao nam hàn quốc"
	niuziku: "quần jeans"
	fujinan: "người đàn ông cơ bụng"
	feizhuliu: "không chính thống"
	jinsefaxing: "kiểu tóc vàng"
	shuaigemingxing: "ngôi sao đẹp trai"
	shanxishuaige626: "anh chàng đẹp trai sơn tây"
	hunxuexiaoshuaige: "anh chàng đẹp trai lai"
	datouzhao: "ảnh chụp đầu to"
	ribenshuaige: "anh chàng đẹp trai nhật bản"
	ribenmingxing: "ngôi sao nhật bản"
	shenghuozhao: "ảnh cuộc sống"
	zhengtai: "chính quá"
	xiaozhengtai: "tiểu chính thái"
	tongmo: "mô hình trẻ em"
	mianjunan: "người đàn ông đeo mặt nạ"
	dongmanshuaige: "anh chàng đẹp trai anime"
	chengshu: "trưởng thành"
	nanmote: "người mẫu nam"
	youxing: "có loại"
	datoutie: "miếng dán đầu to"
	oumei: "châu âu và mỹ"
	jiangsushuaige: "anh chàng đẹp trai giang tô"
	qingshuangshuaige: "anh chàng đẹp trai sảng khoái"
	youting: "du thuyền"
	haishang: "trên biển"
	jilinshuaige: "anh chàng đẹp trai cát lâm"
	lvyou: "du lịch"
	jianzhu: "kiến trúc"
	malaixiyashuaige: "anh chàng đẹp trai malaysia"
	fengmian: "bìa"
	xiaogege: "anh trai nhỏ"
	juhua: "hoa cúc"
	changge: "hát đi"
	nanshifaxing: "kiểu tóc nam"
	nanshengfaxing: "kiểu tóc nam"
	linglei: "thay thế"
	junlangshuaige: "anh chàng đẹp trai"
	jianmeinan: "người đàn ông thể hình"
	zheyangpeng: "mái che"
	jianadashuaige: "anh chàng đẹp trai người canada"
	hanguonantuan: "nhóm ntm nam hàn quốc"
	zhuangyuan: "trang viên"
	niuzimaoshuaige: "anh chàng mũ cao bồi đẹp trai"
	xihageshou: "ca sĩ hip-hop"
	taiwanmingxing: "ngôi sao đài loan"
	heilongjiangshuaige: "soái ca hắc long giang"
	jiangxishuaige: "anh chàng đẹp trai giang tây"
	gougou: "chó"
	niuziyishuaige: "anh chàng đẹp trai với quần jean"
	keaishuaige: "anh chàng đẹp trai đáng yêu"
	shuaiqijiepai: "đẹp trai chụp ảnh đường phố"
	pishuainan: "một người đàn ông đàn ông"
	lengkushuaige: "anh chàng đẹp trai lạnh lùng"
	heibaixiezhen: "đen trắng và chân thực"
	dakuaitou: "một cái khổng lồ lớn"
	gongzhuangshuaige: "anh chàng đẹp trai trong trang phục công nhân"
	beijingshuaige: "anh chàng đẹp trai bắc kinh"
	niuzifushuaige: "chàng cao bồi đẹp trai"
	lengkubaqinan: "nam nhân khí phách lãnh khốc"
	helanshuaige: "anh chàng đẹp trai người hà lan"
	chaomo: "siêu mẫu"
	wutaizhao: "ảnh sân khấu"
	xiuxianzhuang: "quần áo giản dị"
	mingxingxinggan: "ngôi sao gợi cảm"
	simi: "riêng tư"
	dalumingxing: "ngôi sao châu lục"
	hangzhoushuaige: "anh chàng đẹp trai hàng châu"
	hanguonangeshou: "nam ca sĩ hàn quốc"
	weimeixiezhen: "đẹp để viết sự thật"
	hanguojirounan: "đàn ông cơ bắp hàn quốc"
	oumeinan: "đàn ông châu âu và mỹ"
	youyong: "bơi lội"
	xiongmao: "lông ngực"
	zhongqingshuaige: "anh chàng đẹp trai trùng khánh"
	hebeishuaige: "anh chàng đẹp trai hà bắc"
	xueyuanfengshuaige: "phong soái ca của học viện"
	lengku: "lạnh lùng"
	hubingshengao: "hồ binh cao lớn"
	shuaigejiepai: "chụp ảnh đường phố đẹp trai"
	zhejiangshuaige: "anh chàng đẹp trai chiết giang"
	junlang: "tuấn lãng"
	shuaiqixiaosheng: "đẹp trai tiểu sinh"
	chaoqipengbo: "sức sống mãnh liệt"
	renyuxian: "dòng người cá"
	qima: "cưỡi ngựa"
	shifafaxing: "kiểu tóc ướt"
	celianshuaige: "soái ca nghiêng mặt"
	gansushuaige: "anh chàng đẹp trai cam túc"
	shuaige: "anh chàng đẹp trai"
	mingxingjiepai: "chụp ảnh đường phố ngôi sao"
	nanshengcelian: "cậu bé nghiêng mặt"
	xihashuaige: "anh chàng hip hop đẹp trai"
	qizhinan: "người đàn ông khí chất"
	gexingnan: "đàn ông cá tính"
	zazhixiezhen: "tạp chí viết sự thật"
	mingxingdejirou: "cơ bắp của ngôi sao"
	yinglunfeng: "gió anh"
	wenyifan: "văn học nghệ thuật"
	nanmo: "người mẫu nam"
	oumeinanxiongji: "cơ ngực nam châu âu và mỹ"
	oumeirentiyishu: "nghệ thuật cơ thể con người châu âu và mỹ"
	shizhan: "thi triển"
	jietoufeng: "gió đường phố"
	"00hou": "sau 00"
	dashuaige: "anh chàng đẹp trai"
	gaogezishuaige: "cao lớn đẹp trai"
	hanguogeshou: "ca sĩ hàn quốc"
	nongmeishuaige: "anh chàng đẹp trai lông mày rậm"
	xiaoshuaige: "anh chàng đẹp trai"
	chaoyouxingnanren: "đàn ông siêu hữu hình"
	shishang: "thời trang"
	dianyinglianshuaige: "anh chàng đẹp trai với gương mặt điện ảnh"
	gaojilian: "khuôn mặt cao cấp"
	hanguoyanyuan: "diễn viên hàn quốc"
	tuifeinan: "người đàn ông suy đồi"
	shanggan: "buồn"
	chouyan: "hút thuốc"
	shuangyanpishuaige: "anh chàng đẹp trai với mí mắt hai mí"
	huwai: "ngoài trời"
	tuifeigan: "cảm giác suy đồi"
	jietoushaonv: "cô gái đường phố"
	gudan: "cô đơn"
	yigeren: "một người đàn ông"
	pishuai: "đẹp trai"
	beixinnan: "người đàn ông áo vest"
	beixinshuaige: "anh chàng đẹp trai áo vest"
	shuaiqixiaoge: "anh chàng đẹp trai"
	xiaoyanyuan: "diễn viên nhí"
	yinmidejiaoluo: "góc bí mật"
	wenjingshuaige: "anh chàng đẹp trai văn tĩnh"
	huwaisheying: "chụp ảnh ngoài trời"
	nantuan: "nhóm nam"
	wenshennan: "người đàn ông xăm mình"
	banluonan: "người đàn ông bán khỏa thân"
	chonglang: "lướt sóng"
	yundongshuaige: "anh chàng thể thao đẹp trai"
	banluoshuaige: "anh chàng đẹp trai bán khỏa thân"
	xiongji: "cơ ngực"
	baqi: "khí phách"
	henanshuaige: "soái ca hà nam"
	niuzikushuaige: "anh chàng đẹp trai với quần jeans"
	nansheng: "các chàng trai"
	zhengzhuangshuaige: "anh chàng đẹp trai đang giả vờ"
	chenshanshuaige: "anh chàng đẹp trai trong áo sơ mi"
	meizhuo: "bàn đẹp"
	shenghuoxinanshen: "cuộc sống là một nam thần"
	mingxingshenghuozhao: "ảnh cuộc sống của các ngôi sao"
	ranfafaxing: "tóc nhuộm tóc"
	jinfashuaige: "anh chàng tóc vàng đẹp trai"
	nanshengduanfa: "tóc ngắn của cậu bé"
	mingxinggaoqing: "ngôi sao hd"
	kuhei: "bóng tối"
	chenkaigeerzi: "con trai trần khải ca"
	meinanzi: "mỹ nam tử"
	xizhuangdayishuaige: "anh chàng đẹp trai trong bộ đồ"
	yanjingshuaige: "anh chàng đẹp trai với kính mắt"
	tingchechangshuaige: "anh chàng đẹp trai trong bãi đậu xe"
	xiaolianshuaige: "khuôn mặt nhỏ nhắn đẹp trai"
	lvpai: "chụp ảnh du lịch"
	chuanyidapei: "mặc quần áo phù hợp"
	duankushuaige: "quần short đẹp trai"
	mirenshuaige: "anh chàng đẹp trai quyến rũ"
	modengshaonv: "thiếu nữ moden"
	gexingshuaige: "anh chàng đẹp trai cá tính"
	xiazhiguang: "ánh sáng mùa hè"
	lilianggan: "cảm giác sức mạnh"
	xiantiaogan: "cảm giác đường nét"
	mengnan: "mãnh nam"
	piaoranfaxing: "nhuộm tóc"
	xuanhuanfeng: "huyền huyễn phong"
	heiseyumao: "lông màu đen"
	baowenzhuangshuaige: "báo hoa văn trang phục đẹp trai"
	anhuishuaige: "anh chàng đẹp trai an huy"
	xueyuanfeng: "phong cách học viện"
	meishaonian: "mỹ thiếu niên"
	xuguanghan: "hứa quang hán"
	ruya: "nho nhã"
	shenshifan: "quý ông phạm"
	dabeitoufaxing: "kiểu tóc lưng lớn"
	heibaida: "đen trắng"
	honghualvye: "hoa đỏ và lá xanh"
	senxixiezhen: "hệ sen viết thật"
	xiuxianzhuangshuaige: "anh chàng đẹp trai ăn mặc giản dị"
	zhongfenfaxing: "kiểu tóc trung bình"
	juanfafaxing: "kiểu tóc xoăn"
	shuaiqinanshifaxing: "kiểu tóc nam đẹp trai"
	chaoliushuaige: "soái ca trào lưu"
	yapi: "nhã lư"
	shenshi: "quý ông"
	zhiganshuaige: "kết cấu đẹp trai"
	lanselook: "màu xanh look"
	shishangshuaige: "thời trang đẹp trai"
	xuanchuanzhao: "ảnh tuyên truyền"
	shaonian: "thiếu niên"
	yangguangshuaige: "anh chàng đẹp trai ánh nắng mặt trời"
	gexing: "cá tính"
	nuannuan: "ấm áp"
	wenyiqingnian: "thanh niên văn nghệ"
	daotian: "cánh đồng lúa"
	xinjiangshuaige: "anh chàng đẹp trai tân cương"
	liaoningshuaige: "anh chàng đẹp trai liêu ninh"
	qingxinshuaige: "anh chàng đẹp trai tươi mới"
	yangyanshuaige: "đẹp trai đẹp mắt"
	shandongshuaige: "sơn đông đẹp trai"
	yonglan: "lười biếng"
	baishanshuaige: "anh chàng đẹp trai áo trắng"
	exochengyuan: "THÀNH VIÊN EXO"
	hanguomingxing: "ngôi sao hàn quốc"
	hanguoshuaige: "anh chàng đẹp trai hàn quốc"
	wenshenshuaige: "anh chàng đẹp trai xăm mình"
	nantiyishu: "nghệ thuật thể thao nam"
	heibai: "đen trắng"
	oumeitupian: "hình ảnh châu âu và mỹ"
	guangdongshuaige: "anh chàng đẹp trai quảng đông"
	taiwanshuaige: "anh chàng đẹp trai đài loan"
	fujianmingxing: "ngôi sao phúc kiến"
	fujianshuaige: "anh chàng đẹp trai phúc kiến"
	xiaogui: "tiểu quỷ"
	kuleng: "lạnh quá"
	meishaonan: "mỹ thiếu nam"
	xiarifeng: "gió mùa hè"
	chaonan: "người đàn ông thủy triều"
	hunanshuaige: "anh chàng đẹp trai hồ nam"
	shanghaishuaige: "anh chàng đẹp trai thượng hải"
	shuaiqibiren: "đẹp trai bức người"
	senxi: "hệ sen"
	huwaixiezhen: "viết sự thật ngoài trời"
	kushuai: "đẹp trai"
	fugu: "retro"
	meinan: "mỹ nam"
	xianggangmingxing: "ngôi sao hồng kông"
	jirounan: "người đàn ông cơ bắp"
	xianggangshuaige: "anh chàng đẹp trai hồng kông"
	fuji: "cơ bụng"
	liaorenshuaige: "trêu chọc soái ca"
	sichuanshuaige: "anh chàng đẹp trai tứ xuyên"
	nangeshou: "nam ca sĩ"
	changfashuaige: "anh chàng đẹp trai với mái tóc dài"
	bangfashuaige: "anh chàng đẹp trai bị trói tóc"
	hefuzhuang: "và quần áo"
	baiyishuaige: "anh chàng đẹp trai áo trắng"
	xizhuangshuaige: "anh chàng đẹp trai trong bộ đồ"
	dananhai: "cậu bé lớn"
	qizhishuaige: "khí chất đẹp trai"
	shuaiqi: "đẹp trai"
	xingnan: "loại nam"
	wenrouxingshuaige: "anh chàng đẹp trai dịu dàng"
	baiyishaonian: "thiếu niên áo trắng"
	shanxishuaige: "anh chàng đẹp trai thiểm tây"
	huzhanan: "người đàn ông cặn bã"
	nanyanyuan: "nam diễn viên"
	nanshen: "nam thần"
	waipai: "chụp bên ngoài"
	fuli: "phúc lợi"
	qingquneiyi: "đồ lót tình dục"
	meishaonv: "cô gái xinh đẹp"
	shuangmawei: "đuôi ngựa đôi"
	siwameitui: "vớ đẹp chân"
	youhuo: "cám dỗ"
	yongzhuang: "đồ bơi"
	meitui: "đôi chân đẹp"
	meixiong: "làm đẹp ngực"
	duanfa: "tóc ngắn"
	xiaofu: "đồng phục học sinh"
	ribenshaofu: "thiếu phụ nhật bản"
	baisi: "lụa trắng"
	nvshen: "nữ thần"
	juru: "sữa khổng lồ"
	changtuimeinv: "người đẹp chân dài"
	siwayouhuo: "vớ cám dỗ"
	meizi: "em gái"
	nvyou: "nữ ưu tú"
	ribennenmo: "mô hình non nhật bản"
	meijiao: "đôi chân đẹp"
	yuzu: "ngọc túc"
	naimuban46: "niki 46"
	zazhi: "tạp chí"
	qingqumaoyi: "áo len tình yêu"
	heisi: "sợi tơ đen"
	juruluoli: "đại nhũ loli"
	baisiluoli: "beth loli"
	luolikong: "lori kiểm soát"
	olmeinv: "OL BEAUTY"
	ribennvxing: "nữ diễn viên nhật bản"
	xueshengzhifu: "đồng phục học sinh"
	ribenzhifu: "đồng phục nhật bản"
	zhifumeishaonvtianguo: "chế ngự thiếu nữ xinh đẹp thiên quốc"
	oumeizhifu: "đồng phục châu âu và mỹ"
	zhifuyouhuo: "đồng phục cám dỗ"
	siwazhifu: "đồng phục vớ"
	heisizhifu: "đồng phục lụa đen"
	hushizhifu: "đồng phục y tá"
	qingquzhifu: "đồng phục tình dục"
	kongjiezhifu: "đồng phục tiếp viên hàng không"
	jkzhifu: "ĐỒNG PHỤC JK"
	xueshengzhuang: "trang phục học sinh"
	ribenmengmeizi: "em gái nhật bản manh"
	ribenshaonv: "thiếu nữ nhật bản"
	diaodai: "dây đeo"
	xinggannvlang: "cô gái gợi cảm"
	siwashaofu: "thiếu phụ vớ"
	jiepaisiwa: "chụp vớ trên đường phố"
	siwarenti: "vớ cơ thể con người"
	banluoyouwu: "vưu vật bán khỏa thân"
	sizuyouhuo: "chân tơ tằm cám dỗ"
	siwanvlang: "cô gái vớ"
	jiepaiheisi: "chụp ảnh lụa đen trên đường phố"
	buzhihuowucos: "KHÔNG BIẾT MÚA LỬA COS"
	jiepaimeitui: "chụp ảnh chân đẹp trên đường phố"
	qingshunv: "người phụ nữ quen thuộc"
	meinvgushi: "câu chuyện của người đẹp"
	leisiyouhuo: "ren quyến rũ"
	siwaduanqun: "váy ngắn vớ"
	jiepaiduanqun: "chụp ảnh đường phố cho một chiếc váy ngắn"
	bailingliren: "người đẹp cổ áo trắng"
	sizugaogen: "chân dài gót chân cao"
	yongzhuangshaonv: "cô gái mặc đồ bơi"
	rousimeitui: "thịt tơ đẹp chân"
	meitunshaofu: "thiếu phụ mỹ nhân"
	laladui: "đội lala"
	moxiong: "lau ngực"
	meisi: "meise"
	oumeidaxiongmeinv: "người đẹp ngực lớn ở châu âu và mỹ"
	fengman: "đầy đặn"
	kunbangshengyi: "nghệ thuật bó dây thừng"
	gouhunyouwu: "câu hồn vưu vật"
	siwameitun: "vớ đẹp"
	qingqupiyimeinv: "người đẹp áo da tình thú"
	nvyou235: "bạn gái"
	zhongguobijinimeinv: "người đẹp diện bikini trung quốc"
	miniqun: "váy ngắn"
	xiangchemeinv: "người đẹp xe hương"
	heiren: "người da đen"
	oumeishunv: "người phụ nữ quen thuộc ở châu âu và mỹ"
	jinfa: "tóc vàng"
	oumeisiwa: "vớ châu âu và mỹ"
	oumeijuru: "sữa khổng lồ châu âu và mỹ"
	gangguanwu: "múa ống thép"
	show_girl: "Show Girl"
	akb48: "AKB48"
	dudoumeinv: "người đẹp yếm"
	mingxing: "ngôi sao"
	yangyan: "đẹp mắt"
	laozhaopian: "hình ảnh cũ"
	quanjimeinv: "người đẹp quyền anh"
	wanghong: "net đỏ"
	shunv: "người phụ nữ quen thuộc"
	jiudianmeinv: "vẻ đẹp của khách sạn"
	zuqiubaobei: "em bé bóng đá"
	hunsha: "váy cưới"
	feitun: "mông béo"
	kzhaobei: "CỐC K-7"
	sizu: "chân tơ"
	meizu: "chân mỹ"
	huwaimeinv: "vẻ đẹp ngoài trời"
	chemo: "mô hình xe hơi"
	baoshameinv: "người đẹp lụa mỏng"
	tuimo: "mô hình chân"
	piyimeinv: "người đẹp áo da"
	qingchunshaonv: "thiếu nữ thanh thuần"
	qingqusiwa: "vớ tình yêu"
	90hou: "sau 90"
	lanqiu: "bóng rổ"
	meichuniang: "đầu bếp xinh đẹp"
	bzhaobeimeinv: "B NGƯỜI ĐẸP CÚP"

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
			tags = []
			for li in dom.querySelectorAll \.pic-list>.clearfix>li
				a = li.firstElementChild
				name = /\/beauty\/(.+?)\.html/exec a.href .1
				unless album = app.tags[name]
					thumb = a.firstElementChild.src
					album = app.createAlbum name, thumb
					app.tags[name] = album
				tags.push album
			@tag.pages[index] = tags
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
		name: name
		thumb: thumb
		text: Tags.texts[name]
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
