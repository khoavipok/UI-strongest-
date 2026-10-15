--[[
	khanhlyHUB • Dynamic Island (GUI kaitun khanhly) — V5.1
	LocalScript -> StarterPlayerScripts, chạy trực tiếp, hoặc dùng như thư viện:
	    local khanhly_v5 = loadstring(game:HttpGet("URL_RAW"))()
	    khanhly_v5.new({ Title = "khanhly", Description = "ok", Logo = "rbxassetid://..." })
	Chỉ là UI: không gọi remote, không tự động hoá gameplay.

	V5.1 SỬA GÌ SO VỚI V5
	  ÁNH SÁNG
	    * Toàn bộ lớp sáng nằm trong một container "Light" bên trong CanvasGroup của island.
	      CanvasGroup tự cắt theo góc bo, nên ánh sáng LUÔN khớp hình pill / tròn / card ở mọi kích cỡ
	      (không còn thanh sheen 12px bo góc riêng nằm lệch hình).
	    * Vệt sáng quét (sweep) là dải chéo nằm DƯỚI chữ, không phủ lên nội dung.
	    * Cường độ sáng đi theo thanh trượt GLASS; mỗi theme có tông kính riêng.
	  KHUNG ẢNH
	    * Một hàm avatar() duy nhất: khung tròn/bo góc + viền mảnh + ảnh Crop + chữ dự phòng
	      (cả khi ảnh load lỗi). Huy hiệu loại thông báo nằm đúng trên mép vòng tròn logo.
	  PC / MOBILE
	    * Scale tính theo chiều cao, chiều rộng VÀ chiều cao card lớn nhất, nên card không tràn
	      điện thoại ngang, không quá nhỏ trên màn 4K.
	    * Né tai thỏ / vùng an toàn (ScreenInsets = DeviceSafeInsets).
	    * Nút tròn và thanh trượt có vùng chạm 40px / 28px (trước đó chỉ 30px / 6px).
	  LOGIC
	    * Chạm pill đúng lúc thông báo sắp hiện không còn làm mất thông báo.
	    * Intro không ghi đè island đang phát thông báo.
	    * Đổi theme cập nhật MỌI chỗ dùng màu accent (trước chỉ vài chỗ).
	    * Chiều cao nội dung chi tiết tính cả LineHeight, chữ dài bị cắt "…" thay vì tràn.
	    * Đếm ngược của card chi tiết tạm dừng khi bạn rê / giữ ngón tay để đọc.
	    * Bỏ Lighting blur mặc định (GlassBlur = true nếu thật sự muốn).
	    * Chạy trực tiếp file là hiện GUI (tắt: getgenv().KhanhlyV5_AutoStart = false).
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ContentProvider = game:GetService("ContentProvider")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

------------------------------------------------------------------------
-- PHẦN 1: CORE LIBRARY
------------------------------------------------------------------------
local KhanhlyV5 = {}
KhanhlyV5.__index = KhanhlyV5
KhanhlyV5.Version = "5.1.0"

local globalEnv = (typeof(getgenv) == "function" and getgenv()) or _G
globalEnv.__KhanhlyV5_RunCount = tonumber(globalEnv.__KhanhlyV5_RunCount) or 0
globalEnv.__KhanhlyV5_StartClock = globalEnv.__KhanhlyV5_StartClock or os.clock()

local createdByUser = false

local THEME_PRESETS = {
	LiquidGlass = {
		Label = "LIQUID",
		Bg = Color3.fromRGB(14, 16, 22),
		GlassTransparency = 0.16,
		Tint = Color3.fromRGB(200, 225, 255),
		BlurSize = 8,
		Accent = Color3.fromRGB(46, 230, 120),
		Accent2 = Color3.fromRGB(56, 189, 248),
	},
	CrystalClear = {
		Label = "CRYSTAL",
		Bg = Color3.fromRGB(18, 22, 32),
		GlassTransparency = 0.32,
		Tint = Color3.fromRGB(186, 214, 255),
		BlurSize = 12,
		Accent = Color3.fromRGB(56, 189, 248),
		Accent2 = Color3.fromRGB(168, 85, 247),
	},
	ObsidianDark = {
		Label = "OBSIDIAN",
		Bg = Color3.fromRGB(8, 8, 10),
		GlassTransparency = 0.03,
		Tint = Color3.fromRGB(190, 192, 205),
		BlurSize = 0,
		Accent = Color3.fromRGB(46, 230, 120),
		Accent2 = Color3.fromRGB(56, 189, 248),
	},
	PurpleNebula = {
		Label = "NEBULA",
		Bg = Color3.fromRGB(16, 12, 26),
		GlassTransparency = 0.18,
		Tint = Color3.fromRGB(226, 200, 255),
		BlurSize = 10,
		Accent = Color3.fromRGB(192, 132, 252),
		Accent2 = Color3.fromRGB(244, 114, 182),
	},
}

local THEME_ORDER = { "LiquidGlass", "CrystalClear", "ObsidianDark", "PurpleNebula" }

local function parseBool(val, defaultVal)
	if val == nil then
		return defaultVal
	end
	if type(val) == "boolean" then
		return val
	end
	if type(val) == "string" then
		local lower = string.lower(val)
		if lower == "true" or lower == "1" or lower == "yes" or lower == "on" then
			return true
		elseif lower == "false" or lower == "0" or lower == "no" or lower == "off" then
			return false
		end
	end
	return defaultVal
end

function KhanhlyV5.new(userConfig)
	createdByUser = true
	userConfig = type(userConfig) == "table" and userConfig or {}

	globalEnv.__KhanhlyV5_RunCount = globalEnv.__KhanhlyV5_RunCount + 1
	local sessionUses = globalEnv.__KhanhlyV5_RunCount

	local rawThemeName = tostring(userConfig.Theme or "")
	if rawThemeName == "" or not THEME_PRESETS[rawThemeName] then
		rawThemeName = "LiquidGlass"
	end
	local activePreset = THEME_PRESETS[rawThemeName]

	------------------------------------------------------------------------
	-- 1. CONFIG
	------------------------------------------------------------------------
	local logoId = userConfig.Logo or userConfig.LeftImage or "rbxassetid://111673746737789"
	local CONFIG = {
		GuiName = userConfig.GuiName or "KHANHLYHUB",
		Title = userConfig.Title or "khanhlyHUB",
		Message = userConfig.Description or userConfig.Message or "copy bé nai kaitun nofi siếu cấp vip pru",
		Logo = logoId,
		LeftImage = logoId,
		Theme = rawThemeName,
		Folder = userConfig.Folder or "khanhly_v5",

		Intro = parseBool(userConfig.Intro, true),
		startintro_size = tonumber(userConfig.startintro_size) or 80,
		squareintro_time = tonumber(userConfig.squareintro_time) or 1.2,

		GlassTransparency = tonumber(userConfig.GlassTransparency) or activePreset.GlassTransparency,
		GlassBlur = parseBool(userConfig.GlassBlur, false),

		discord_link = userConfig.discord_link or "discord.gg/yourc",
		CardTags = userConfig.CardTags or "MainBF  •  MainV3  •  Kaitun",
		CardSince = userConfig.CardSince or ("Dùng từ " .. os.date("%d/%m/%Y")),
		DefaultKicker = userConfig.DefaultKicker or "ĐẦU TIÊN TRONG SCRIPT ROBLOX",

		BossTitle = userConfig.BossTitle or userConfig.Title or "kaitun katakury",
		BossLines = userConfig.BossLines or {
			"kaitun katakury: Đang kiểm tra trạng thái...",
			"kaitun katakury: Tối ưu hoá tốc độ farm",
			"kaitun katakury: Liquid Glass V5 hoàn tất",
		},
		RouteLabel = userConfig.RouteLabel or "LOCAL PREVIEW • UI V5",
		ProgressLabel = userConfig.ProgressLabel or "DEMO PROGRESS",
		ProgressPercent = tonumber(userConfig.ProgressPercent) or 68,
		StatusLabel = userConfig.StatusLabel or "SYSTEM ONLINE",

		Accent = userConfig.Accent or activePreset.Accent,
		Accent2 = userConfig.Accent2 or activePreset.Accent2,

		NotifyDuration = tonumber(userConfig.NotifyDuration) or 4.0,
		DetailDuration = tonumber(userConfig.DetailDuration) or 6.0,
		WelcomeNotify = parseBool(userConfig.WelcomeNotify, true),
		WelcomeKicker = userConfig.WelcomeKicker or "ĐẦU TIÊN TRONG SCRIPT ROBLOX",
		WelcomeTitle = userConfig.WelcomeTitle or "Dynamic Island, dùng thật.",
		WelcomeMessage = userConfig.WelcomeMessage
			or "Khanhly Hub V5 đưa Dynamic Island chuẩn Liquid Glass vào script Roblox — chạm vào thông báo để mở bảng chi tiết sống động.",

		ClosedWidth = math.clamp(tonumber(userConfig.ClosedWidth) or 268, 220, 340),
		ClosedHeight = math.clamp(tonumber(userConfig.ClosedHeight) or 40, 34, 56),
		OpenWidth = math.clamp(tonumber(userConfig.OpenWidth) or 360, 320, 460),
		NotifCardWidth = math.clamp(tonumber(userConfig.NotifCardWidth) or 360, 320, 460),
		NotifCardHeight = math.clamp(tonumber(userConfig.NotifCardHeight) or 160, 140, 260), -- chiều cao TỐI THIỂU
		TopMargin = tonumber(userConfig.TopMargin) or 8,
		ToggleKey = userConfig.ToggleKey or Enum.KeyCode.RightShift,
		MaxVisibleLines = tonumber(userConfig.MaxVisibleLines) or 3,
	}

	local previous = PlayerGui:FindFirstChild(CONFIG.GuiName)
	if previous then
		previous:Destroy()
	end
	local oldBlur = Lighting:FindFirstChild("KhanhlyV5_GlassBlur")
	if oldBlur then
		oldBlur:Destroy()
	end

	------------------------------------------------------------------------
	-- 2. THEME + HELPER
	------------------------------------------------------------------------
	local C = {
		Bg = activePreset.Bg,
		White = Color3.fromRGB(255, 255, 255),
		Text = Color3.fromRGB(246, 248, 252),
		Body = Color3.fromRGB(214, 220, 232),
		Sub = Color3.fromRGB(148, 156, 172),
		Kicker = Color3.fromRGB(94, 234, 212),
		GlyphDark = Color3.fromRGB(10, 14, 22),
	}

	local KIND_COLORS = {
		info = CONFIG.Accent2,
		blue = Color3.fromRGB(56, 189, 248),
		xanh = Color3.fromRGB(56, 189, 248),
		xanh_duong = Color3.fromRGB(56, 189, 248),

		success = Color3.fromRGB(52, 211, 153),
		green = Color3.fromRGB(46, 230, 120),
		xanh_la = Color3.fromRGB(46, 230, 120),

		warn = Color3.fromRGB(251, 191, 36),
		yellow = Color3.fromRGB(250, 204, 21),
		vang = Color3.fromRGB(250, 204, 21),

		error = Color3.fromRGB(248, 113, 113),
		red = Color3.fromRGB(244, 63, 94),
		["do"] = Color3.fromRGB(244, 63, 94),

		purple = Color3.fromRGB(192, 132, 252),
		tim = Color3.fromRGB(192, 132, 252),
		violet = Color3.fromRGB(168, 85, 247),

		pink = Color3.fromRGB(244, 114, 182),
		hong = Color3.fromRGB(244, 114, 182),

		orange = Color3.fromRGB(251, 146, 60),
		cam = Color3.fromRGB(251, 146, 60),

		cyan = Color3.fromRGB(45, 212, 191),
		ngoc = Color3.fromRGB(45, 212, 191),
	}

	local KIND_NAMES = {
		info = "THÔNG TIN • LIVE ISLAND",
		blue = "XANH DƯƠNG • LIVE ISLAND",
		xanh = "XANH DƯƠNG • LIVE ISLAND",
		xanh_duong = "XANH DƯƠNG • LIVE ISLAND",
		success = "HOÀN TẤT • LIVE ISLAND",
		green = "XANH LÁ • LIVE ISLAND",
		xanh_la = "XANH LÁ • LIVE ISLAND",
		warn = "CẢNH BÁO • LIVE ISLAND",
		yellow = "CẢNH BÁO VÀNG • LIVE ISLAND",
		vang = "CẢNH BÁO VÀNG • LIVE ISLAND",
		error = "BÁO LỖI • LIVE ISLAND",
		red = "CẢNH BÁO ĐỎ • LIVE ISLAND",
		["do"] = "CẢNH BÁO ĐỎ • LIVE ISLAND",
		purple = "TÍM ĐẶC BIỆT • LIVE ISLAND",
		tim = "TÍM ĐẶC BIỆT • LIVE ISLAND",
		violet = "TÍM ĐẶC BIỆT • LIVE ISLAND",
		pink = "HỒNG • LIVE ISLAND",
		hong = "HỒNG • LIVE ISLAND",
		orange = "CAM • LIVE ISLAND",
		cam = "CAM • LIVE ISLAND",
		cyan = "NGỌC BÍCH • LIVE ISLAND",
		ngoc = "NGỌC BÍCH • LIVE ISLAND",
	}

	local function normalizeKind(kind)
		if type(kind) == "string" then
			local k = string.lower(kind)
			if KIND_COLORS[k] then
				return k
			end
		end
		return "info"
	end

	local function resolveGlyphShape(kind)
		if kind == "success" or kind == "green" or kind == "xanh_la" then
			return "check"
		elseif kind == "error" or kind == "red" or kind == "do" then
			return "cross"
		elseif kind == "warn" or kind == "yellow" or kind == "vang" or kind == "orange" or kind == "cam" then
			return "warn"
		elseif kind == "purple" or kind == "tim" or kind == "violet" or kind == "pink" or kind == "hong" then
			return "spark"
		elseif kind == "cyan" or kind == "ngoc" then
			return "bolt"
		end
		return "info"
	end

	local function itemColor(item)
		return item.customColor or KIND_COLORS[item.kind] or CONFIG.Accent2
	end

	local EASE = Enum.EasingStyle
	local DIR = Enum.EasingDirection
	local kp = NumberSequenceKeypoint.new

	local alive = true
	local conns = {}
	local ambient = {}
	local live = setmetatable({}, { __mode = "k" })

	local function bind(signal, fn)
		local c = signal:Connect(fn)
		conns[#conns + 1] = c
		return c
	end

	-- Tween có huỷ tween cũ cùng property -> bấm nhanh liên tục vẫn mượt.
	local function tween(obj, time, props, style, dir, delayTime)
		if not alive or not obj or not obj.Parent then
			return nil
		end
		local slot = live[obj]
		if not slot then
			slot = {}
			live[obj] = slot
		end
		for prop in pairs(props) do
			local old = slot[prop]
			if old then
				old:Cancel()
			end
		end
		local tw = TweenService:Create(
			obj,
			TweenInfo.new(time, style or EASE.Quint, dir or DIR.Out, 0, false, delayTime or 0),
			props
		)
		for prop in pairs(props) do
			slot[prop] = tw
		end
		tw:Play()
		return tw
	end

	local function after(tw, fn)
		if tw then
			tw.Completed:Once(function(state)
				if alive and state == Enum.PlaybackState.Completed then
					fn()
				end
			end)
		end
	end

	local function new(className, props, parent)
		local o = Instance.new(className)
		for k, v in pairs(props) do
			o[k] = v
		end
		o.Parent = parent
		return o
	end

	local function corner(parent, r)
		return new("UICorner", { CornerRadius = r and UDim.new(0, r) or UDim.new(1, 0) }, parent)
	end

	-- Viền kính: sáng ở trên, mờ ở giữa, nhẹ ở dưới.
	local function glassStroke(parent, color, base)
		local s = new("UIStroke", {
			Color = color or C.White,
			Transparency = base or 0.55,
			Thickness = 1.15,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}, parent)
		new("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({ kp(0, 0.2), kp(0.5, 0.78), kp(1, 0.42) }),
		}, s)
		return s
	end

	local function label(parent, props)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.BorderSizePixel = 0
		l.Font = Enum.Font.GothamMedium
		l.TextSize = 12
		l.TextColor3 = C.Text
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.TextYAlignment = Enum.TextYAlignment.Center
		l.TextTruncate = Enum.TextTruncate.AtEnd
		for k, v in pairs(props) do
			l[k] = v
		end
		l.Parent = parent
		return l
	end

	local function textWidth(text, size, font)
		local ok, value = pcall(function()
			return TextService:GetTextSize(text, size, font, Vector2.new(1200, 100)).X
		end)
		if ok and value then
			return value
		end
		return (utf8.len(text) or #text) * size * 0.56
	end

	local function isPointer(input)
		return input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
	end

	-- Đăng ký màu theo accent để đổi theme là đổi hết, không sót chỗ nào.
	local themed = {}
	local themeFns = {}
	local function colorFor(key)
		if key == "Accent" then
			return CONFIG.Accent
		elseif key == "Accent2" then
			return CONFIG.Accent2
		end
		return C.Bg
	end
	local function bindTheme(inst, prop, key)
		themed[#themed + 1] = { inst = inst, prop = prop, key = key }
		inst[prop] = colorFor(key)
		return inst
	end
	local function refreshThemeColors()
		for _, t in ipairs(themed) do
			if t.inst and t.inst.Parent then
				t.inst[t.prop] = colorFor(t.key)
			end
		end
		for _, fn in ipairs(themeFns) do
			fn()
		end
	end

	-- KHUNG ẢNH: tròn/bo góc + viền mảnh + ảnh Crop + chữ dự phòng (cả khi ảnh lỗi).
	local logoImages = {}
	local function avatar(parent, props, radius, fallbackText, fallbackSize)
		local z = props.ZIndex or 2
		local box = new("Frame", {
			Name = "Avatar",
			BackgroundColor3 = C.White,
			BackgroundTransparency = 0.9,
			BorderSizePixel = 0,
			AnchorPoint = props.AnchorPoint or Vector2.zero,
			Position = props.Position or UDim2.new(),
			Size = props.Size,
			ZIndex = z,
		}, parent)
		corner(box, radius)
		new("UIStroke", {
			Color = C.White,
			Transparency = 0.82,
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}, box)
		local img = new("ImageLabel", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			Image = CONFIG.LeftImage,
			ScaleType = Enum.ScaleType.Crop,
			ZIndex = z + 1,
		}, box)
		corner(img, radius)
		local fb = label(box, {
			Size = UDim2.fromScale(1, 1),
			Text = fallbackText,
			TextSize = fallbackSize,
			Font = Enum.Font.GothamBold,
			TextXAlignment = Enum.TextXAlignment.Center,
			Visible = true,
			ZIndex = z + 2,
		})
		local failed = false
		local function refresh()
			fb.Visible = failed or not (img.IsLoaded and img.Image ~= "")
		end
		refresh()
		bind(img:GetPropertyChangedSignal("IsLoaded"), refresh)
		bind(img:GetPropertyChangedSignal("Image"), function()
			failed = false
			refresh()
		end)
		task.spawn(function()
			pcall(function()
				ContentProvider:PreloadAsync({ img }, function(_, status)
					if status ~= Enum.AssetFetchStatus.Success then
						failed = true
					end
				end)
			end)
			if alive and img.Parent then
				refresh()
			end
		end)
		logoImages[#logoImages + 1] = img
		return box, img
	end

	-- Icon vẽ bằng đoạn thẳng đầu tròn. Toạ độ tính từ TÂM của holder (px).
	local function segment(parent, x1, y1, x2, y2, thick, color, z)
		local dx, dy = x2 - x1, y2 - y1
		local len = math.sqrt(dx * dx + dy * dy)
		local f = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, (x1 + x2) / 2, 0.5, (y1 + y2) / 2),
			Size = UDim2.fromOffset(len + thick, thick),
			Rotation = math.deg(math.atan2(dy, dx)),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = z or 2,
		}, parent)
		corner(f)
		return f
	end

	local function dot(parent, x, y, d, color, z)
		local f = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, x, 0.5, y),
			Size = UDim2.fromOffset(d, d),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = z or 2,
		}, parent)
		corner(f)
		return f
	end

	local function clearChildren(holder)
		for _, child in ipairs(holder:GetChildren()) do
			child:Destroy()
		end
	end

	local function drawGlyph(holder, kind, color, k, customIconId)
		clearChildren(holder)
		k = k or 1
		if type(customIconId) == "string" and customIconId ~= "" then
			new("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(math.floor(18 * k), math.floor(18 * k)),
				BackgroundTransparency = 1,
				Image = customIconId,
				ImageColor3 = color,
				ZIndex = 4,
			}, holder)
			return
		end
		local shape = resolveGlyphShape(kind)
		local t = 2.4 * k
		if shape == "check" then
			segment(holder, -5 * k, 0.5 * k, -1.5 * k, 4 * k, t, color, 3)
			segment(holder, -1.5 * k, 4 * k, 5.5 * k, -4 * k, t, color, 3)
		elseif shape == "cross" then
			segment(holder, -4.5 * k, -4.5 * k, 4.5 * k, 4.5 * k, t, color, 3)
			segment(holder, 4.5 * k, -4.5 * k, -4.5 * k, 4.5 * k, t, color, 3)
		elseif shape == "warn" then
			segment(holder, 0, -6 * k, 0, 1.5 * k, t, color, 3)
			dot(holder, 0, 5.8 * k, 3.2 * k, color, 3)
		elseif shape == "spark" then
			segment(holder, 0, -6 * k, 0, 6 * k, t * 0.9, color, 3)
			segment(holder, -6 * k, 0, 6 * k, 0, t * 0.9, color, 3)
			segment(holder, -3.5 * k, -3.5 * k, 3.5 * k, 3.5 * k, t * 0.75, color, 3)
			segment(holder, 3.5 * k, -3.5 * k, -3.5 * k, 3.5 * k, t * 0.75, color, 3)
		elseif shape == "bolt" then
			segment(holder, 1.5 * k, -6 * k, -3.5 * k, 0.5 * k, t * 0.9, color, 3)
			segment(holder, -3.5 * k, 0.5 * k, 3.5 * k, -0.5 * k, t * 0.85, color, 3)
			segment(holder, 3.5 * k, -0.5 * k, -1.5 * k, 6 * k, t * 0.9, color, 3)
		else
			dot(holder, 0, -5.6 * k, 3.2 * k, color, 3)
			segment(holder, 0, -1.6 * k, 0, 5.8 * k, t, color, 3)
		end
	end

	local function drawClose(holder, color)
		segment(holder, -4, -4, 4, 4, 2, color, 3)
		segment(holder, 4, -4, -4, 4, 2, color, 3)
	end

	local function drawSkip(holder, color)
		for _, ox in ipairs({ -4.5, 0.5 }) do
			segment(holder, ox, -4, ox + 4, 0, 2, color, 3)
			segment(holder, ox + 4, 0, ox, 4, 2, color, 3)
		end
	end

	-- Vòng sóng lan ra quanh chấm trạng thái (kiểu "live activity").
	local function pulse(dotFrame, key, maxSize)
		local ring = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = dotFrame.Size,
			BackgroundTransparency = 0.55,
			BorderSizePixel = 0,
		}, dotFrame)
		bindTheme(ring, "BackgroundColor3", key)
		corner(ring)
		local tw = TweenService:Create(
			ring,
			TweenInfo.new(1.6, EASE.Quad, DIR.Out, -1, false, 0),
			{ Size = UDim2.fromOffset(maxSize, maxSize), BackgroundTransparency = 1 }
		)
		ambient[#ambient + 1] = tw
		tw:Play()
		return ring
	end

	------------------------------------------------------------------------
	-- 3. NÚT TRÒN LIQUID GLASS
	--    Nút ngoài (trong suốt) là VÙNG CHẠM 40px; thân kính bên trong giữ nguyên kích thước thiết kế.
	--    Position là TÂM của nút.
	------------------------------------------------------------------------
	local function glassCircle(parent, size, props)
		local hit = math.max(size, props.Hit or 40)
		local btn = new("TextButton", {
			Name = props.Name or "Glass",
			Text = "",
			AutoButtonColor = false,
			Active = true,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = props.Position or UDim2.new(),
			Size = UDim2.fromOffset(hit, hit),
			ZIndex = props.ZIndex or 5,
		}, parent)

		local body = new("Frame", {
			Name = "Body",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(size, size),
			BackgroundColor3 = C.White,
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			ZIndex = 1,
		}, btn)
		corner(body)
		new("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({ kp(0, 0.78), kp(1, 0.93) }),
		}, body)
		local stroke = new("UIStroke", {
			Color = C.White,
			Thickness = 1,
			Transparency = 0,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}, body)
		new("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({ kp(0, 0.2), kp(0.45, 0.8), kp(1, 0.55) }),
		}, stroke)

		local scale = new("UIScale", { Scale = 1 }, body)

		local hover = new("Frame", {
			Name = "Hover",
			BackgroundColor3 = C.White,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 1,
		}, body)
		corner(hover)

		local cap = new("Frame", {
			Name = "Gloss",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.07),
			Size = UDim2.fromScale(0.62, 0.34),
			BackgroundColor3 = C.White,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, body)
		corner(cap)
		new("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({ kp(0, 0.5), kp(1, 1) }),
		}, cap)

		local under = new("Frame", {
			Name = "Reflect",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 0.94),
			Size = UDim2.fromScale(0.48, 0.14),
			BackgroundColor3 = C.White,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, body)
		corner(under)
		new("UIGradient", {
			Rotation = 270,
			Transparency = NumberSequence.new({ kp(0, 0.82), kp(1, 1) }),
		}, under)

		local icon = new("Frame", {
			Name = "Icon",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 3,
		}, body)

		return { btn = btn, body = body, scale = scale, hover = hover, icon = icon }
	end

	local function wireGlass(g, mode)
		local hovering = false
		bind(g.btn.MouseEnter, function()
			hovering = true
			tween(g.scale, 0.28, { Scale = 1.08 }, EASE.Quint, DIR.Out)
			tween(g.hover, 0.22, { BackgroundTransparency = 0.86 }, EASE.Quad, DIR.Out)
			if mode == "spin" then
				tween(g.icon, 0.4, { Rotation = 90 }, EASE.Back, DIR.Out)
			elseif mode == "nudge" then
				tween(g.icon, 0.3, { Position = UDim2.fromOffset(2, 0) }, EASE.Quint, DIR.Out)
			end
		end)
		bind(g.btn.MouseLeave, function()
			hovering = false
			tween(g.scale, 0.3, { Scale = 1 }, EASE.Back, DIR.Out)
			tween(g.hover, 0.25, { BackgroundTransparency = 1 }, EASE.Quad, DIR.Out)
			if mode == "spin" then
				tween(g.icon, 0.35, { Rotation = 0 }, EASE.Quint, DIR.Out)
			elseif mode == "nudge" then
				tween(g.icon, 0.3, { Position = UDim2.fromOffset(0, 0) }, EASE.Quint, DIR.Out)
			end
		end)
		bind(g.btn.InputBegan, function(input)
			if isPointer(input) then
				tween(g.scale, 0.08, { Scale = 0.88 }, EASE.Quad, DIR.Out)
				tween(g.hover, 0.08, { BackgroundTransparency = 0.78 }, EASE.Quad, DIR.Out)
			end
		end)
		bind(g.btn.InputEnded, function(input)
			if isPointer(input) then
				tween(g.scale, 0.35, { Scale = hovering and 1.08 or 1 }, EASE.Back, DIR.Out)
				tween(g.hover, 0.2, { BackgroundTransparency = hovering and 0.86 or 1 }, EASE.Quad, DIR.Out)
			end
		end)
	end

	------------------------------------------------------------------------
	-- 4. SPRING
	------------------------------------------------------------------------
	local Spring = {}
	Spring.__index = Spring

	function Spring.new(x, k, d, eps)
		return setmetatable({ x = x, v = 0, t = x, k = k, d = d, e = eps or 0.05 }, Spring)
	end

	function Spring:step(dt)
		local n = math.max(1, math.ceil(dt / (1 / 90)))
		local h = dt / n
		for _ = 1, n do
			local a = self.k * (self.t - self.x) - self.d * self.v
			self.v = self.v + a * h
			self.x = self.x + self.v * h
		end
	end

	function Spring:atRest()
		return math.abs(self.t - self.x) < self.e and math.abs(self.v) < self.e * 10
	end

	------------------------------------------------------------------------
	-- 5. LAYOUT (đơn vị thiết kế; UIScale co giãn theo màn hình)
	------------------------------------------------------------------------
	local PAD = 16
	local OPEN_W = CONFIG.OpenWidth
	local CLOSED_W, CLOSED_H = CONFIG.ClosedWidth, CONFIG.ClosedHeight
	local CIRCLE, NOTIF_H = 44, 44

	local DETAIL_W = CONFIG.NotifCardWidth
	local DETAIL_MIN_H = CONFIG.NotifCardHeight
	local DETAIL_BODY_MAX = 150
	local DETAIL_TOP = 68 -- y bắt đầu phần nội dung
	local DETAIL_CHROME = 54 -- chiều cao phần chân (tag + thanh đếm ngược) dưới nội dung
	local DETAIL_RADIUS = 28
	local DETAIL_MAX_H = DETAIL_TOP + DETAIL_BODY_MAX + DETAIL_CHROME

	local ROW_H = 22
	local rowCount = math.clamp(#CONFIG.BossLines, 1, CONFIG.MaxVisibleLines)
	local INFO_TOP = 66
	local INFO_H = 78
	local IMG = INFO_H -- ảnh vuông cao đúng bằng card thông tin -> thẳng hàng tuyệt đối
	local PROG_Y = INFO_TOP + INFO_H + 12
	local GLASS_Y = PROG_Y + 22 + 10
	local GLASS_H = 28
	local FOOT_Y = GLASS_Y + GLASS_H + 10
	local OPEN_H = FOOT_Y + 26 + 16
	local OPEN_RADIUS = 32
	local GLOSS_H = 20
	local HINT_DEFAULT = "TAP OUTSIDE OR SWIPE UP"

	------------------------------------------------------------------------
	-- 6. CÂY GUI
	------------------------------------------------------------------------
	local Gui = new("ScreenGui", {
		Name = CONFIG.GuiName,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 100,
	}, PlayerGui)
	-- Né tai thỏ / camera cutout trên điện thoại (không có thuộc tính này thì bỏ qua).
	pcall(function()
		Gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	end)

	local Dim = new("TextButton", {
		Name = "Dim",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 1,
	}, Gui)

	-- Holder 0x0 giữa-trên màn hình: UIScale không làm lệch tâm.
	local Scaler = new("Frame", {
		Name = "Scaler",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.fromOffset(0, 0),
		ZIndex = 2,
	}, Gui)
	local FitScale = new("UIScale", { Scale = 1 }, Scaler)

	local initGlass = math.clamp(CONFIG.GlassTransparency, 0, 0.85)
	local Island = new("CanvasGroup", {
		Name = "Island",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(0, -60),
		Size = UDim2.fromOffset(CLOSED_W, CLOSED_H),
		BackgroundColor3 = C.Bg,
		BackgroundTransparency = initGlass,
		BorderSizePixel = 0,
	}, Scaler)
	local IslandCorner = corner(Island, CLOSED_H / 2)
	local IslandStroke = glassStroke(Island, C.White, 0.45)
	local PressScale = new("UIScale", { Scale = 0.75 }, Island)

	-- ÁNH SÁNG: mọi lớp sáng nằm trong "Light" (full-size, ZIndex 0, dưới nội dung).
	-- CanvasGroup cắt theo góc bo của island nên ánh sáng luôn ôm đúng hình pill / tròn / card.
	local Light = new("Frame", {
		Name = "Light",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 0,
	}, Island)

	local Frost = new("Frame", {
		Name = "Frost",
		BackgroundColor3 = C.White,
		BackgroundTransparency = 0.84,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
	}, Light)
	local FrostGradient = new("UIGradient", {
		Rotation = 115,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, C.White),
			ColorSequenceKeypoint.new(0.45, activePreset.Tint),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 140, 180)),
		}),
		Transparency = NumberSequence.new({ kp(0, 0.25), kp(0.38, 0.82), kp(0.75, 0.92), kp(1, 0.55) }),
	}, Frost)

	local GlossTop = new("Frame", {
		Name = "GlossTop",
		BackgroundColor3 = C.White,
		BackgroundTransparency = 0.72,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, GLOSS_H),
		ZIndex = 2,
	}, Light)
	new("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({ kp(0, 0.12), kp(0.4, 0.6), kp(1, 1) }),
	}, GlossTop)

	local GlossBottom = new("Frame", {
		Name = "GlossBottom",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = C.White,
		BackgroundTransparency = 0.84,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 10),
		ZIndex = 2,
	}, Light)
	new("UIGradient", {
		Rotation = 270,
		Transparency = NumberSequence.new({ kp(0, 0.45), kp(1, 1) }),
	}, GlossBottom)

	local IslandButton = new("TextButton", {
		Name = "IslandButton",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
	}, Island)

	-- 6a. PILL + mini timer/usage ------------------------------------------------
	local CompactGroup = new("CanvasGroup", {
		Name = "Compact",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.fromOffset(CLOSED_W, CLOSED_H),
		GroupTransparency = 1,
		ZIndex = 2,
	}, Island)

	local LOGO_S = 26
	avatar(CompactGroup, {
		Position = UDim2.fromOffset(7, (CLOSED_H - LOGO_S) / 2),
		Size = UDim2.fromOffset(LOGO_S, LOGO_S),
	}, nil, "K", 13)

	local MiniLeftTimerPill = new("Frame", {
		Name = "MiniTimerBadge",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 7 + LOGO_S + 4, 0.5, 0),
		Size = UDim2.fromOffset(58, 24),
		BackgroundColor3 = C.White,
		BackgroundTransparency = 0.9,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, CompactGroup)
	corner(MiniLeftTimerPill, 12)
	local MiniTimerStroke = new("UIStroke", { Transparency = 0.55, Thickness = 1 }, MiniLeftTimerPill)
	bindTheme(MiniTimerStroke, "Color", "Accent")

	local MiniTimerDot = new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 6, 0, 8),
		Size = UDim2.fromOffset(5, 5),
		BorderSizePixel = 0,
		ZIndex = 4,
	}, MiniLeftTimerPill)
	bindTheme(MiniTimerDot, "BackgroundColor3", "Accent")
	corner(MiniTimerDot)

	local MiniUseCountLabel = label(MiniLeftTimerPill, {
		Text = string.format("#%d", sessionUses),
		Font = Enum.Font.GothamBold,
		TextSize = 8,
		Position = UDim2.fromOffset(14, 2),
		Size = UDim2.new(1, -16, 0, 10),
		ZIndex = 4,
	})
	bindTheme(MiniUseCountLabel, "TextColor3", "Accent")

	local MiniTimeSecLabel = label(MiniLeftTimerPill, {
		Text = "00:00s",
		Font = Enum.Font.GothamBold,
		TextSize = 9,
		TextColor3 = C.Text,
		Position = UDim2.fromOffset(6, 12),
		Size = UDim2.new(1, -8, 0, 10),
		ZIndex = 4,
	})

	local compactTextX = 7 + LOGO_S + 4 + 58 + 8
	local compactTextW = CLOSED_W - compactTextX - 28
	local CompactTitle = label(CompactGroup, {
		Text = CONFIG.Title,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		Position = UDim2.fromOffset(compactTextX, 5),
		Size = UDim2.fromOffset(compactTextW, 15),
	})
	local CompactMessage = label(CompactGroup, {
		Text = CONFIG.Message,
		TextSize = 10,
		TextColor3 = C.Sub,
		Position = UDim2.fromOffset(compactTextX, 20),
		Size = UDim2.fromOffset(compactTextW, 13),
	})
	local CompactDot = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(8, 8),
		BorderSizePixel = 0,
		ZIndex = 2,
	}, CompactGroup)
	bindTheme(CompactDot, "BackgroundColor3", "Accent")
	corner(CompactDot)
	pulse(CompactDot, "Accent", 22)

	-- 6b. THÔNG BÁO THU GỌN / MỞ NGANG -------------------------------------------
	local NotifGroup = new("CanvasGroup", {
		Name = "Notif",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		GroupTransparency = 1,
		Visible = false,
		ZIndex = 3,
	}, Island)

	-- Nút chạm toàn thông báo nằm DƯỚI nội dung để nút Skip ăn click trước.
	local NotifTap = new("TextButton", {
		Name = "TapDetail",
		Text = "",
		AutoButtonColor = false,
		Active = true,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
	}, NotifGroup)

	local NotifIcon = new("Frame", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, NOTIF_H / 2, 0.5, 0),
		Size = UDim2.fromOffset(30, 30),
		BackgroundColor3 = CONFIG.Accent2,
		BorderSizePixel = 0,
		ZIndex = 4,
	}, NotifGroup)
	corner(NotifIcon)
	local NotifIconScale = new("UIScale", { Scale = 1 }, NotifIcon)
	local NotifGlyph = new("Frame", {
		Name = "Glyph",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 5,
	}, NotifIcon)

	local NotifText = new("CanvasGroup", {
		Name = "Text",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(300, NOTIF_H),
		GroupTransparency = 1,
		Visible = false,
		ZIndex = 5,
	}, NotifGroup)
	local NotifTitle = label(NotifText, {
		Text = "",
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		Position = UDim2.fromOffset(46, 5),
		Size = UDim2.new(1, -90, 0, 16),
	})
	local NotifMessage = label(NotifText, {
		Text = "",
		TextSize = 10,
		TextColor3 = C.Sub,
		Position = UDim2.fromOffset(46, 21),
		Size = UDim2.new(1, -90, 0, 13),
	})
	local NotifTimerTrack = new("Frame", {
		Name = "TimerTrack",
		Position = UDim2.fromOffset(46, 37),
		Size = UDim2.new(1, -90, 0, 2),
		BackgroundColor3 = C.White,
		BackgroundTransparency = 0.86,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, NotifText)
	corner(NotifTimerTrack)
	local NotifTimerFill = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = CONFIG.Accent2,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, NotifTimerTrack)
	corner(NotifTimerFill)

	local SkipGlass = glassCircle(NotifText, 30, {
		Name = "Skip",
		Position = UDim2.new(1, -22, 0.5, 0),
		ZIndex = 6,
	})
	drawSkip(SkipGlass.icon, C.Text)

	-- 6c. BẢNG THÔNG BÁO CHI TIẾT ------------------------------------------------
	local NotifDetailGroup = new("CanvasGroup", {
		Name = "NotifDetail",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.fromOffset(DETAIL_W, DETAIL_MIN_H),
		GroupTransparency = 1,
		Visible = false,
		ZIndex = 4,
	}, Island)

	local DETAIL_LOGO = 40
	local DetailLogoBox = avatar(NotifDetailGroup, {
		Position = UDim2.fromOffset(20, 18),
		Size = UDim2.fromOffset(DETAIL_LOGO, DETAIL_LOGO),
		ZIndex = 5,
	}, nil, "KH", 16)

	-- Huy hiệu loại thông báo: tâm nằm đúng trên mép vòng tròn logo ở góc 45° (0.5 + 0.3536 = 0.8536).
	local badgeCenter = math.floor(DETAIL_LOGO * 0.8536 + 0.5)
	local DetailKindDot = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(badgeCenter, badgeCenter),
		Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = CONFIG.Accent2,
		BorderSizePixel = 0,
		ZIndex = 9,
	}, DetailLogoBox)
	corner(DetailKindDot)
	local DetailKindStroke = new("UIStroke", { Thickness = 2 }, DetailKindDot)
	bindTheme(DetailKindStroke, "Color", "Bg")
	local DetailKindMiniGlyph = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 10,
	}, DetailKindDot)

	local DETAIL_TEXT_X = 20 + DETAIL_LOGO + 12
	local DETAIL_TEXT_W = DETAIL_W - DETAIL_TEXT_X - 20 - 28 - 10 -- chừa chỗ nút đóng bên phải

	local DetailKicker = label(NotifDetailGroup, {
		Text = CONFIG.DefaultKicker,
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		TextColor3 = C.Kicker,
		Position = UDim2.fromOffset(DETAIL_TEXT_X, 19),
		Size = UDim2.fromOffset(DETAIL_TEXT_W, 14),
		ZIndex = 5,
	})
	local DetailHeadline = label(NotifDetailGroup, {
		Text = "",
		Font = Enum.Font.GothamBold,
		TextSize = 17,
		TextColor3 = C.White,
		Position = UDim2.fromOffset(DETAIL_TEXT_X, 34),
		Size = UDim2.fromOffset(DETAIL_TEXT_W, 24),
		ZIndex = 5,
	})

	local DetailClose = glassCircle(NotifDetailGroup, 28, {
		Name = "DetailClose",
		Position = UDim2.new(1, -34, 0, 32),
		ZIndex = 7,
	})
	drawClose(DetailClose.icon, C.Text)

	local DetailBody = label(NotifDetailGroup, {
		Text = "",
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextColor3 = C.Body,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		LineHeight = 1.24,
		Position = UDim2.fromOffset(20, DETAIL_TOP),
		Size = UDim2.new(1, -40, 0, 40),
		ZIndex = 5,
	})

	-- Chân card neo theo ĐÁY nên luôn đúng chỗ dù nội dung dài hay ngắn.
	local DetailFooterLeft = label(NotifDetailGroup, {
		Text = CONFIG.CardSince,
		TextSize = 10,
		TextColor3 = C.Sub,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 20, 1, -30),
		Size = UDim2.fromOffset(150, 16),
		ZIndex = 5,
	})
	local DetailFooterRight = label(NotifDetailGroup, {
		Text = CONFIG.CardTags,
		TextSize = 10,
		TextColor3 = C.Sub,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -20, 1, -30),
		Size = UDim2.new(1, -20 - 20 - 158, 0, 16),
		ZIndex = 5,
	})

	local DetailProgressTrack = new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 20, 1, -14),
		Size = UDim2.new(1, -40 - 48, 0, 3),
		BackgroundColor3 = C.White,
		BackgroundTransparency = 0.88,
		BorderSizePixel = 0,
		ZIndex = 5,
	}, NotifDetailGroup)
	corner(DetailProgressTrack)
	local DetailProgressFill = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = CONFIG.Accent2,
		BorderSizePixel = 0,
		ZIndex = 6,
	}, DetailProgressTrack)
	corner(DetailProgressFill)
	local DetailTimerLabel = label(NotifDetailGroup, {
		Text = "0.0s",
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		TextColor3 = C.Body,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -20, 1, -8),
		Size = UDim2.fromOffset(40, 16),
		ZIndex = 5,
	})

	-- 6d. CARD CHÍNH -------------------------------------------------------------
	local ExpandedGroup = new("CanvasGroup", {
		Name = "Expanded",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.fromOffset(OPEN_W, OPEN_H),
		GroupTransparency = 1,
		Visible = false,
		ZIndex = 4,
	}, Island)

	local sections = {}
	local function section(x, y, w, h)
		local f = new("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(w, h),
		}, ExpandedGroup)
		sections[#sections + 1] = { frame = f, base = f.Position }
		return f
	end

	local innerW = OPEN_W - PAD * 2

	-- Header
	local Header = section(PAD, 14, innerW, 36)
	avatar(Header, { Position = UDim2.fromOffset(0, 1), Size = UDim2.fromOffset(34, 34) }, nil, "K", 16)

	local BADGE_W = 72
	local HEADER_TEXT_W = innerW - 44 - (30 + 6 + BADGE_W) - 8
	label(Header, {
		Text = CONFIG.BossTitle,
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		Position = UDim2.fromOffset(44, 2),
		Size = UDim2.fromOffset(HEADER_TEXT_W, 18),
	})
	label(Header, {
		Text = CONFIG.RouteLabel,
		TextSize = 10,
		TextColor3 = C.Sub,
		Position = UDim2.fromOffset(44, 20),
		Size = UDim2.fromOffset(HEADER_TEXT_W, 14),
	})

	local HeaderSessionBadge = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -(30 + 6), 0.5, 0),
		Size = UDim2.fromOffset(BADGE_W, 24),
		BackgroundColor3 = C.White,
		BackgroundTransparency = 0.9,
		BorderSizePixel = 0,
		ZIndex = 4,
	}, Header)
	corner(HeaderSessionBadge, 12)
	local HeaderBadgeStroke = new("UIStroke", { Transparency = 0.6, Thickness = 1 }, HeaderSessionBadge)
	bindTheme(HeaderBadgeStroke, "Color", "Accent2")
	local HeaderSessionText = label(HeaderSessionBadge, {
		Text = string.format("#%d • 00:00s", sessionUses),
		Font = Enum.Font.GothamBold,
		TextSize = 9,
		TextColor3 = C.Body,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 5,
	})

	local CloseGlass = glassCircle(Header, 30, {
		Name = "Close",
		Position = UDim2.new(1, -15, 0.5, 0),
		ZIndex = 5,
	})
	drawClose(CloseGlass.icon, C.Text)

	new("Frame", {
		BackgroundColor3 = C.White,
		BackgroundTransparency = 0.9,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(PAD, 56),
		Size = UDim2.fromOffset(innerW, 1),
	}, ExpandedGroup)

	-- Card thông tin + ảnh (cùng cao INFO_H, cách nhau 10px)
	local InfoCard = section(PAD, INFO_TOP, innerW - IMG - 10, INFO_H)
	InfoCard.BackgroundTransparency = 0.92
	InfoCard.BackgroundColor3 = C.White
	corner(InfoCard, 14)
	glassStroke(InfoCard, C.White, 0.78)

	local rowLabels = {}
	local rowsStart = (INFO_H - rowCount * ROW_H) / 2
	for i = 1, rowCount do
		local text = CONFIG.BossLines[i] or "STATUS: READY"
		local row = new("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(12, rowsStart + (i - 1) * ROW_H),
			Size = UDim2.new(1, -24, 0, ROW_H),
		}, InfoCard)
		local rowDot = new("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.fromOffset(6, 6),
			BorderSizePixel = 0,
		}, row)
		bindTheme(rowDot, "BackgroundColor3", i == 1 and "Accent" or "Accent2")
		corner(rowDot)
		rowLabels[i] = label(row, {
			Text = tostring(text),
			TextSize = 11,
			TextColor3 = C.Body,
			Position = UDim2.fromOffset(14, 0),
			Size = UDim2.new(1, -14, 1, 0),
		})
	end

	local ImageSec = section(OPEN_W - PAD - IMG, INFO_TOP, IMG, IMG)
	avatar(ImageSec, { Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(IMG, IMG) }, 16, "KH", 18)

	-- Progress
	local progress = math.clamp(tonumber(CONFIG.ProgressPercent) or 0, 0, 100)
	local ProgressSec = section(PAD, PROG_Y, innerW, 22)
	label(ProgressSec, {
		Text = CONFIG.ProgressLabel,
		Font = Enum.Font.GothamBold,
		TextSize = 9,
		TextColor3 = C.Sub,
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(0.7, 0, 0, 12),
	})
	local ProgressValue = label(ProgressSec, {
		Text = "0%",
		Font = Enum.Font.GothamBold,
		TextSize = 9,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(46, 12),
	})
	local Track = new("Frame", {
		BackgroundColor3 = C.White,
		BackgroundTransparency = 0.88,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 15),
		Size = UDim2.new(1, 0, 0, 6),
	}, ProgressSec)
	corner(Track)
	local Fill = new("Frame", {
		BackgroundColor3 = C.White,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
	}, Track)
	corner(Fill)
	local FillGradient = new("UIGradient", {}, Fill)
	themeFns[#themeFns + 1] = function()
		FillGradient.Color = ColorSequence.new(CONFIG.Accent, CONFIG.Accent2)
	end
	FillGradient.Color = ColorSequence.new(CONFIG.Accent, CONFIG.Accent2)

	local ProgressNum = new("NumberValue", { Value = 0 }, Gui)
	bind(ProgressNum.Changed, function(v)
		ProgressValue.Text = string.format("%d%%", math.floor(v + 0.5))
	end)

	-- Thanh Liquid Glass: vùng chạm cao 28px, đường ray thấy được chỉ 6px.
	local GlassSec = section(PAD, GLASS_Y, innerW, GLASS_H)
	local GlassBar = new("Frame", {
		BackgroundColor3 = C.White,
		BackgroundTransparency = 0.93,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	}, GlassSec)
	corner(GlassBar, 12)
	glassStroke(GlassBar, C.White, 0.82)

	local GlassTitleLbl = label(GlassBar, {
		Text = "GLASS 0%",
		Font = Enum.Font.GothamBold,
		TextSize = 9,
		TextColor3 = C.Kicker,
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.fromOffset(74, GLASS_H),
	})

	local THEME_BTN_W = 70
	local GlassSliderHit = new("TextButton", {
		Name = "GlassSlider",
		Text = "",
		AutoButtonColor = false,
		Active = true,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(92, 0),
		Size = UDim2.new(1, -(92 + THEME_BTN_W + 16), 1, 0),
		ZIndex = 2,
	}, GlassBar)
	local GlassTrack = new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.new(1, 0, 0, 6),
		BackgroundColor3 = C.White,
		BackgroundTransparency = 0.84,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, GlassSliderHit)
	corner(GlassTrack)
	local GlassSliderFill = new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BorderSizePixel = 0,
		ZIndex = 3,
	}, GlassTrack)
	bindTheme(GlassSliderFill, "BackgroundColor3", "Accent2")
	corner(GlassSliderFill)
	local GlassKnob = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = C.White,
		BorderSizePixel = 0,
		ZIndex = 4,
	}, GlassSliderHit)
	corner(GlassKnob)
	local GlassKnobScale = new("UIScale", { Scale = 1 }, GlassKnob)

	local ThemeCycleBtn = new("TextButton", {
		Name = "ThemeBtn",
		Text = activePreset.Label,
		AutoButtonColor = false,
		Font = Enum.Font.GothamBold,
		TextSize = 9,
		TextColor3 = C.Text,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -6, 0.5, 0),
		Size = UDim2.fromOffset(THEME_BTN_W, 22),
		BackgroundColor3 = C.White,
		BackgroundTransparency = 0.88,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, GlassBar)
	corner(ThemeCycleBtn, 11)

	-- Footer
	local Footer = section(PAD, FOOT_Y, innerW, 26)
	local Pill = new("Frame", {
		BackgroundColor3 = C.White,
		BackgroundTransparency = 0.92,
		BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 26),
	}, Footer)
	corner(Pill)
	local PillStroke = new("UIStroke", { Transparency = 0.65, Thickness = 1 }, Pill)
	bindTheme(PillStroke, "Color", "Accent")
	new("UIPadding", { PaddingLeft = UDim.new(0, 11), PaddingRight = UDim.new(0, 13) }, Pill)
	new("UISizeConstraint", { MaxSize = Vector2.new(170, 26) }, Pill)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
	}, Pill)
	local PillDot = new("Frame", {
		LayoutOrder = 1,
		Size = UDim2.fromOffset(7, 7),
		BorderSizePixel = 0,
	}, Pill)
	bindTheme(PillDot, "BackgroundColor3", "Accent")
	corner(PillDot)
	pulse(PillDot, "Accent", 18)
	local PillText = label(Pill, {
		LayoutOrder = 2,
		Text = CONFIG.StatusLabel,
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
	})
	new("UISizeConstraint", { MaxSize = Vector2.new(116, 26) }, PillText)

	local FooterHint = label(Footer, {
		Text = HINT_DEFAULT,
		Font = Enum.Font.Gotham,
		TextSize = 9,
		TextColor3 = C.Sub,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.new(1, -176, 1, 0),
	})

	------------------------------------------------------------------------
	-- 7. SPRING DRIVER
	------------------------------------------------------------------------
	local initSize = CONFIG.Intro and CONFIG.startintro_size or CLOSED_W
	local initH = CONFIG.Intro and CONFIG.startintro_size or CLOSED_H
	local springs = {
		w = Spring.new(initSize, 260, 21),
		h = Spring.new(initH, 260, 21),
		r = Spring.new(CONFIG.Intro and 22 or (CLOSED_H / 2), 280, 26),
		s = Spring.new(0.75, 300, 20, 0.0008),
		y = Spring.new(-(initH + 20), 170, 17),
	}

	local function apply()
		local w, h = springs.w.x, springs.h.x
		Island.Size = UDim2.fromOffset(w, h)
		IslandCorner.CornerRadius = UDim.new(0, math.max(0, math.min(springs.r.x, h / 2, w / 2)))
		PressScale.Scale = springs.s.x
		Island.Position = UDim2.fromOffset(0, springs.y.x)
	end

	local driver
	local function ensureDriver()
		if driver or not alive then
			return
		end
		driver = RunService.Heartbeat:Connect(function(dt)
			dt = math.min(dt, 1 / 20)
			local moving = false
			for _, sp in pairs(springs) do
				sp:step(dt)
				if sp:atRest() then
					sp.x, sp.v = sp.t, 0
				else
					moving = true
				end
			end
			apply()
			if not moving and driver then
				driver:Disconnect()
				driver = nil
			end
		end)
	end

	local function go(name, target, k, d)
		local sp = springs[name]
		sp.t = target
		if k then
			sp.k, sp.d = k, d
		end
		ensureDriver()
	end

	local function setIsland(w, h, r, k, d)
		go("w", w, k, d)
		go("h", h, k, d)
		go("r", r, k + 20, d + 4)
	end

	apply()

	------------------------------------------------------------------------
	-- 8. LIQUID GLASS + THEME + TIMER SỬ DỤNG
	------------------------------------------------------------------------
	local Mode = "idle" -- idle | open | detail
	local currentGlassTransparency = initGlass
	local currentThemeIndex = 1
	for i, name in ipairs(THEME_ORDER) do
		if name == CONFIG.Theme then
			currentThemeIndex = i
			break
		end
	end

	local WorldBlur
	local function syncWorldBlur(active)
		if not CONFIG.GlassBlur then
			if WorldBlur and WorldBlur.Parent then
				WorldBlur.Enabled = false
				WorldBlur.Size = 0
			end
			return
		end
		if not WorldBlur then
			WorldBlur = new("BlurEffect", { Name = "KhanhlyV5_GlassBlur", Size = 0, Enabled = false }, Lighting)
		end
		local preset = THEME_PRESETS[CONFIG.Theme] or THEME_PRESETS.LiquidGlass
		local target = (active and preset.BlurSize or 0) * (0.5 + currentGlassTransparency)
		if target > 0.5 then
			WorldBlur.Enabled = true
			tween(WorldBlur, 0.28, { Size = target }, EASE.Quad, DIR.Out)
		else
			after(tween(WorldBlur, 0.22, { Size = 0 }, EASE.Quad, DIR.Out), function()
				if Mode == "idle" and WorldBlur and WorldBlur.Parent then
					WorldBlur.Enabled = false
				end
			end)
		end
	end

	-- Một giá trị (độ trong suốt kính) điều khiển toàn bộ: nền, frost, 2 vệt sáng, viền.
	local function setGlassTransparency(val, instant)
		currentGlassTransparency = math.clamp(tonumber(val) or 0.16, 0, 0.85)
		CONFIG.GlassTransparency = currentGlassTransparency
		local ratio = math.clamp(currentGlassTransparency / 0.75, 0, 1)
		local frostT = math.clamp(0.92 - currentGlassTransparency * 0.38, 0.52, 0.96)
		local glossT = math.clamp(0.86 - currentGlassTransparency * 0.45, 0.35, 0.92)
		local glossBottomT = math.clamp(glossT + 0.12, 0.45, 0.97)
		local strokeT = math.clamp(0.65 - currentGlassTransparency * 0.50, 0.18, 0.78)

		GlassSliderFill.Size = UDim2.fromScale(ratio, 1)
		GlassKnob.Position = UDim2.new(ratio, 0, 0.5, 0)
		GlassTitleLbl.Text = string.format("GLASS %d%%", math.floor(ratio * 100 + 0.5))

		if instant then
			Island.BackgroundTransparency = currentGlassTransparency
			Frost.BackgroundTransparency = frostT
			GlossTop.BackgroundTransparency = glossT
			GlossBottom.BackgroundTransparency = glossBottomT
			IslandStroke.Transparency = strokeT
		else
			tween(Island, 0.22, { BackgroundTransparency = currentGlassTransparency }, EASE.Quad, DIR.Out)
			tween(Frost, 0.22, { BackgroundTransparency = frostT }, EASE.Quad, DIR.Out)
			tween(GlossTop, 0.22, { BackgroundTransparency = glossT }, EASE.Quad, DIR.Out)
			tween(GlossBottom, 0.22, { BackgroundTransparency = glossBottomT }, EASE.Quad, DIR.Out)
			tween(IslandStroke, 0.22, { Transparency = strokeT }, EASE.Quad, DIR.Out)
		end
		syncWorldBlur(Mode ~= "idle")
	end

	local function applyTheme(themeName)
		local preset = THEME_PRESETS[themeName]
		if not preset then
			return
		end
		CONFIG.Theme = themeName
		ThemeCycleBtn.Text = preset.Label
		C.Bg = preset.Bg
		CONFIG.Accent = preset.Accent
		CONFIG.Accent2 = preset.Accent2
		KIND_COLORS.info = CONFIG.Accent2
		FrostGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, C.White),
			ColorSequenceKeypoint.new(0.45, preset.Tint),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 140, 180)),
		})
		tween(Island, 0.28, { BackgroundColor3 = C.Bg }, EASE.Quad, DIR.Out)
		refreshThemeColors()
		setGlassTransparency(preset.GlassTransparency, false)
	end

	local function formatElapsedTime(sec)
		sec = math.max(0, math.floor(sec))
		local hrs = math.floor(sec / 3600)
		local mins = math.floor((sec % 3600) / 60)
		local s = sec % 60
		if hrs > 0 then
			return string.format("%d:%02d:%02d", hrs, mins, s)
		end
		return string.format("%02d:%02ds", mins, s)
	end

	local lastStamp = ""
	local function renderSession()
		local elapsed = os.clock() - globalEnv.__KhanhlyV5_StartClock
		local timeStr = formatElapsedTime(elapsed)
		local stamp = timeStr .. "|" .. tostring(sessionUses)
		if stamp == lastStamp then
			return
		end
		lastStamp = stamp
		MiniTimeSecLabel.Text = timeStr
		MiniUseCountLabel.Text = string.format("#%d", sessionUses)
		HeaderSessionText.Text = string.format("#%d • %s", sessionUses, timeStr)
	end

	local function bumpUsageCount(delta)
		sessionUses = sessionUses + (tonumber(delta) or 1)
		globalEnv.__KhanhlyV5_RunCount = sessionUses
		renderSession()
	end

	task.spawn(function()
		while alive do
			renderSession()
			task.wait(0.25)
		end
	end)

	------------------------------------------------------------------------
	-- 9. HIỆU ỨNG PHỤ
	------------------------------------------------------------------------
	-- Vệt sáng quét: dải chéo nằm TRONG lớp Light (dưới chữ), bị cắt theo góc bo của island.
	local function sweep()
		if not alive then
			return
		end
		local band = new("Frame", {
			Name = "SweepBand",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(-0.25, 0.5),
			Size = UDim2.fromScale(0.34, 2.4),
			Rotation = 16,
			BackgroundColor3 = C.White,
			BorderSizePixel = 0,
			ZIndex = 3,
		}, Light)
		new("UIGradient", {
			Transparency = NumberSequence.new({ kp(0, 1), kp(0.5, 0.84), kp(1, 1) }),
		}, band)
		tween(band, 0.95, { Position = UDim2.fromScale(1.25, 0.5) }, EASE.Quad, DIR.Out)
		task.delay(1.1, function()
			if band.Parent then
				band:Destroy()
			end
		end)
	end

	local function setProgress(p, instant, delayTime)
		progress = math.clamp(tonumber(p) or 0, 0, 100)
		if instant then
			ProgressNum.Value = progress
			Fill.Size = UDim2.fromScale(progress / 100, 1)
			return
		end
		tween(ProgressNum, 0.9, { Value = progress }, EASE.Quint, DIR.Out, delayTime)
		tween(Fill, 0.9, { Size = UDim2.fromScale(progress / 100, 1) }, EASE.Quint, DIR.Out, delayTime)
	end

	local function resetSections()
		for _, s in ipairs(sections) do
			s.frame.Position = s.base + UDim2.fromOffset(0, 10)
		end
	end

	------------------------------------------------------------------------
	-- 10. TRẠNG THÁI + THÔNG BÁO + CARD CHI TIẾT
	------------------------------------------------------------------------
	local phase = 0
	local detailToken = 0
	local introActive = CONFIG.Intro

	local Notif = {
		queue = {},
		running = false,
		token = 0,
		stage = "none", -- none | circle | wide
		current = nil,
		skip = false,
		hover = false,
		press = false,
	}
	local pointer = { hover = false, press = false } -- trên pill lúc đóng
	local islandHold = { hover = false, press = false } -- trên island lúc xem chi tiết (tạm dừng đếm ngược)

	local function refreshScale()
		local hover = pointer.hover or Notif.hover
		local press = pointer.press or Notif.press
		local t = 1
		if Mode == "idle" then
			if press then
				t = 0.96
			elseif hover then
				t = 1.03
			end
		end
		go("s", t, 420, 24)
	end

	local function updateHint()
		local pending = #Notif.queue
		if Mode == "open" and pending > 0 then
			FooterHint.Text = string.format("%d NEW • SWIPE UP", pending)
		else
			FooterHint.Text = HINT_DEFAULT
		end
	end

	local function measureNotification(item)
		local cam = Workspace.CurrentCamera
		local viewportX = cam and cam.ViewportSize.X or 800
		local available = viewportX / math.max(FitScale.Scale, 0.1) - 24
		local content = math.max(
			textWidth(item.title, 12, Enum.Font.GothamBold),
			textWidth(item.message, 10, Enum.Font.GothamMedium)
		)
		return math.clamp(content + 46 + 44 + 8, 210, math.max(210, math.min(420, available)))
	end

	local function setNotificationContent(item)
		item.width = measureNotification(item)
		local color = itemColor(item)
		NotifText.Size = UDim2.fromOffset(item.width, NOTIF_H)
		NotifTitle.Text = item.title
		NotifMessage.Text = item.message
		NotifIcon.BackgroundColor3 = color
		NotifTimerFill.BackgroundColor3 = color
		NotifTimerFill.Size = UDim2.fromScale(1, 1)
		drawGlyph(NotifGlyph, item.kind, C.GlyphDark, 1, item.icon)
	end

	local function holdNotification(item, token)
		local remaining = item.duration
		local last = os.clock()
		while true do
			RunService.Heartbeat:Wait()
			if not (alive and Notif.token == token and Mode == "idle") then
				return false
			end
			local now = os.clock()
			local dt = now - last
			last = now
			if Notif.skip then
				Notif.skip = false
				return true
			end
			if not (Notif.hover or Notif.press) then
				remaining = remaining - dt
			end
			NotifTimerFill.Size = UDim2.fromScale(math.clamp(remaining / item.duration, 0, 1), 1)
			if remaining <= 0 then
				return true
			end
		end
	end

	-- pill -> tròn -> bật icon -> mở ngang -> giữ (timer) -> tròn
	local function playNotification(item, token)
		local function valid()
			return alive and Notif.token == token and Mode == "idle"
		end
		local function pause(t)
			task.wait(t)
			return valid()
		end

		Notif.skip = false
		setNotificationContent(item)

		if Notif.stage == "none" then
			tween(CompactGroup, 0.12, { GroupTransparency = 1 }, EASE.Quad, DIR.In)
			NotifText.Visible = false
			NotifText.GroupTransparency = 1
			setIsland(CIRCLE, CIRCLE, CIRCLE / 2, 380, 24)
			if not pause(0.26) then
				return false
			end
			Notif.stage = "circle"
			CompactGroup.Visible = false
			NotifGroup.Visible = true
			NotifGroup.GroupTransparency = 1
			tween(NotifGroup, 0.15, { GroupTransparency = 0 }, EASE.Quad, DIR.Out)
		end

		NotifIconScale.Scale = 0.35
		tween(NotifIconScale, 0.40, { Scale = 1 }, EASE.Back, DIR.Out)
		if not pause(0.18) then
			return false
		end

		NotifText.GroupTransparency = 1
		NotifText.Position = UDim2.fromOffset(12, 0)
		NotifText.Visible = true
		setIsland(item.width, NOTIF_H, NOTIF_H / 2, 300, 22)
		if not pause(0.08) then
			return false
		end
		tween(NotifText, 0.32, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) }, EASE.Quint, DIR.Out)
		Notif.stage = "wide"

		if not holdNotification(item, token) then
			return false
		end

		tween(NotifText, 0.15, { GroupTransparency = 1 }, EASE.Quad, DIR.In)
		if not pause(0.1) then
			return false
		end
		NotifText.Visible = false
		setIsland(CIRCLE, CIRCLE, CIRCLE / 2, 380, 24)
		Notif.stage = "circle"
		return pause(0.24)
	end

	local function settleToIdle()
		Notif.stage = "none"
		Notif.current = nil
		tween(NotifGroup, 0.15, { GroupTransparency = 1 }, EASE.Quad, DIR.In)
		setIsland(CLOSED_W, CLOSED_H, CLOSED_H / 2, 280, 22)
		CompactGroup.Visible = true
		tween(CompactGroup, 0.25, { GroupTransparency = 0 }, EASE.Quad, DIR.Out, 0.08)
		task.delay(0.2, function()
			if alive and Notif.stage == "none" then
				NotifGroup.Visible = false
			end
		end)
	end

	local function pumpNotifications()
		if not alive or introActive or Notif.running or Mode ~= "idle" or #Notif.queue == 0 then
			return
		end
		Notif.running = true
		Notif.token = Notif.token + 1
		local token = Notif.token
		task.spawn(function()
			local completed = true
			while alive and Notif.token == token and Mode == "idle" and #Notif.queue > 0 do
				local item = table.remove(Notif.queue, 1)
				Notif.current = item
				updateHint()
				if not playNotification(item, token) then
					completed = false
					break
				end
				Notif.current = nil
			end
			if Notif.token ~= token then
				return -- đã bị huỷ/thay thế (abort tự dọn trạng thái)
			end
			Notif.running = false
			Notif.current = nil
			if alive and completed and Mode == "idle" and Notif.stage ~= "none" then
				settleToIdle()
			end
			if alive and Mode == "idle" and #Notif.queue > 0 then
				task.defer(pumpNotifications)
			end
		end)
	end

	local function abortNotification()
		Notif.token = Notif.token + 1
		Notif.running = false
		Notif.skip = false
		Notif.hover, Notif.press = false, false
		if Notif.stage ~= "none" then
			tween(NotifGroup, 0.14, { GroupTransparency = 1 }, EASE.Quad, DIR.In)
			task.delay(0.16, function()
				if alive and Notif.stage == "none" then
					NotifGroup.Visible = false
				end
			end)
		end
	end

	local function notify(title, message, duration, kind, extra)
		if not alive then
			return
		end
		local options = {}
		if type(duration) == "table" then
			for k, v in pairs(duration) do
				options[k] = v
			end
		elseif type(duration) == "string" then
			options.kind = duration
		else
			options.duration = duration
			options.kind = kind
		end
		if type(extra) == "table" then
			for k, v in pairs(extra) do
				options[k] = v
			end
		end

		local customColor = nil
		if typeof(options.color) == "Color3" then
			customColor = options.color
		elseif typeof(options.kind) == "Color3" then
			customColor = options.kind
		end
		local kindKey = options.kind
		if type(kindKey) ~= "string" then
			kindKey = options.color
		end

		Notif.queue[#Notif.queue + 1] = {
			title = tostring(title or CONFIG.Title),
			message = tostring(message or ""),
			detail = tostring(options.detail or message or ""),
			kicker = options.kicker,
			tags = options.tags or CONFIG.CardTags,
			since = options.since or CONFIG.CardSince,
			kind = normalizeKind(kindKey),
			customColor = customColor,
			icon = options.icon,
			duration = math.clamp(tonumber(options.duration) or CONFIG.NotifyDuration, 0.8, 30),
			detailDuration = tonumber(options.detailDuration) or CONFIG.DetailDuration,
			time = os.date("%H:%M"),
		}
		while #Notif.queue > 8 do
			table.remove(Notif.queue, 1)
		end
		updateHint()
		pumpNotifications()
	end

	-- Đo chiều cao nội dung có tính LineHeight; quá dài thì bị cắt "…" chứ không tràn.
	local function measureDetailBody(text)
		local h
		local ok, size = pcall(function()
			return TextService:GetTextSize(text, 13, Enum.Font.GothamMedium, Vector2.new(DETAIL_W - 40, 1000))
		end)
		if ok and size then
			h = size.Y * 1.24 + 8
		else
			local chars = utf8.len(text) or #text
			local perLine = math.max(1, math.floor((DETAIL_W - 40) / 7))
			h = math.ceil(chars / perLine) * 13 * 1.24 + 8
		end
		return math.clamp(math.ceil(h), 24, DETAIL_BODY_MAX)
	end

	local function fadeOut(group, my)
		after(tween(group, 0.14, { GroupTransparency = 1 }, EASE.Quad, DIR.In), function()
			if phase == my then
				group.Visible = false
			end
		end)
	end

	local close -- forward declaration

	local function openDetail(item)
		if not alive or not item then
			return
		end
		local fromMode = Mode
		bumpUsageCount(1)
		abortNotification()
		Mode = "detail"
		phase = phase + 1
		detailToken = detailToken + 1
		local myPhase, myToken = phase, detailToken
		Notif.stage = "none"
		Notif.current = nil
		pointer.hover, pointer.press = false, false

		local color = itemColor(item)
		DetailKicker.Text = tostring(item.kicker or KIND_NAMES[item.kind] or CONFIG.DefaultKicker)
		DetailKicker.TextColor3 = color
		DetailHeadline.Text = tostring(item.title or CONFIG.Title)
		DetailBody.Text = tostring(item.detail or item.message or "")
		DetailFooterLeft.Text = tostring(item.since or CONFIG.CardSince)
		DetailFooterRight.Text = tostring(item.tags or CONFIG.CardTags)
		DetailKindDot.BackgroundColor3 = color
		DetailProgressFill.BackgroundColor3 = color
		drawGlyph(DetailKindMiniGlyph, item.kind, C.GlyphDark, 0.45, item.icon)

		local bodyH = measureDetailBody(DetailBody.Text)
		DetailBody.Size = UDim2.new(1, -40, 0, bodyH)
		local cardH = math.max(DETAIL_MIN_H, DETAIL_TOP + bodyH + DETAIL_CHROME)
		NotifDetailGroup.Size = UDim2.fromOffset(DETAIL_W, cardH)

		go("w", DETAIL_W, 270, 22)
		go("h", cardH, 270, 22)
		go("r", DETAIL_RADIUS, 290, 26)
		refreshScale()
		syncWorldBlur(true)

		Dim.Visible = true
		tween(Dim, 0.30, { BackgroundTransparency = 0.55 }, EASE.Quad, DIR.Out)
		tween(CompactGroup, 0.12, { GroupTransparency = 1 }, EASE.Quad, DIR.In)
		NotifGroup.Visible = false
		if fromMode == "open" then
			fadeOut(ExpandedGroup, myPhase)
		else
			ExpandedGroup.Visible = false
		end

		NotifDetailGroup.Visible = true
		NotifDetailGroup.GroupTransparency = 1
		tween(NotifDetailGroup, 0.26, { GroupTransparency = 0 }, EASE.Quad, DIR.Out, 0.05)
		sweep()

		-- Đếm ngược tự thu gọn; tạm dừng khi đang rê/giữ để đọc.
		local totalWait = math.clamp(
			tonumber(item.detailDuration) or math.max((item.duration or 4) + 2, CONFIG.DetailDuration),
			2.5,
			30
		)
		local rem = totalWait
		DetailProgressFill.Size = UDim2.fromScale(1, 1)
		DetailTimerLabel.Text = string.format("%.1fs", rem)

		task.spawn(function()
			local last = os.clock()
			while alive and Mode == "detail" and phase == myPhase and detailToken == myToken do
				RunService.Heartbeat:Wait()
				local now = os.clock()
				local dt = now - last
				last = now
				if not (islandHold.hover or islandHold.press) then
					rem = rem - dt
				end
				DetailProgressFill.Size = UDim2.fromScale(math.clamp(rem / totalWait, 0, 1), 1)
				DetailTimerLabel.Text = string.format("%.1fs", math.max(0, rem))
				if rem <= 0 then
					close()
					break
				end
			end
		end)
	end

	local function openMain()
		if not alive or Mode == "open" then
			return
		end
		local fromMode = Mode
		if Notif.current then
			table.insert(Notif.queue, 1, Notif.current) -- không làm mất thông báo đang chờ
		end
		bumpUsageCount(1)
		abortNotification()
		Mode = "open"
		phase = phase + 1
		detailToken = detailToken + 1
		local myPhase = phase
		Notif.stage = "none"
		Notif.current = nil
		pointer.hover, pointer.press = false, false
		updateHint()

		go("w", OPEN_W, 260, 21)
		go("h", OPEN_H, 260, 21)
		go("r", OPEN_RADIUS, 280, 26)
		refreshScale()
		syncWorldBlur(true)

		Dim.Visible = true
		tween(Dim, 0.35, { BackgroundTransparency = 0.5 }, EASE.Quad, DIR.Out)
		tween(CompactGroup, 0.12, { GroupTransparency = 1 }, EASE.Quad, DIR.In)
		NotifGroup.Visible = false
		if fromMode == "detail" then
			fadeOut(NotifDetailGroup, myPhase)
		else
			NotifDetailGroup.Visible = false
			NotifDetailGroup.GroupTransparency = 1
		end

		ExpandedGroup.Visible = true
		ExpandedGroup.GroupTransparency = 1
		resetSections()
		ProgressNum.Value = 0
		Fill.Size = UDim2.fromScale(0, 1)
		tween(ExpandedGroup, 0.3, { GroupTransparency = 0 }, EASE.Quad, DIR.Out, 0.08)
		for i, s in ipairs(sections) do
			tween(s.frame, 0.55, { Position = s.base }, EASE.Quint, DIR.Out, 0.05 + (i - 1) * 0.04)
		end
		setProgress(progress, false, 0.3)
		sweep()
	end

	-- Mở thông minh: đang có thông báo thì mở chi tiết của nó, không thì mở card chính.
	local function openSmart()
		if Notif.current then
			openDetail(Notif.current)
		else
			openMain()
		end
	end

	close = function()
		if not alive or Mode == "idle" then
			return
		end
		Mode = "idle"
		phase = phase + 1
		detailToken = detailToken + 1
		local my = phase
		islandHold.hover, islandHold.press = false, false
		updateHint()

		go("w", CLOSED_W, 300, 28)
		go("h", CLOSED_H, 300, 28)
		go("r", CLOSED_H / 2, 300, 30)
		refreshScale()
		syncWorldBlur(false)

		NotifGroup.Visible = false
		NotifGroup.GroupTransparency = 1
		CompactGroup.Visible = true

		after(tween(Dim, 0.3, { BackgroundTransparency = 1 }, EASE.Quad, DIR.Out), function()
			if phase == my then
				Dim.Visible = false
			end
		end)
		fadeOut(ExpandedGroup, my)
		fadeOut(NotifDetailGroup, my)
		tween(CompactGroup, 0.22, { GroupTransparency = 0 }, EASE.Quad, DIR.Out, 0.12)

		task.delay(0.55, function()
			if alive and phase == my and Mode == "idle" then
				pumpNotifications()
			end
		end)
	end

	local function toggle()
		if Mode ~= "idle" then
			close()
		else
			openSmart()
		end
	end

	------------------------------------------------------------------------
	-- 11. INPUT
	------------------------------------------------------------------------
	bind(IslandButton.Activated, function()
		if Mode == "idle" then
			openSmart()
		end
	end)
	bind(Dim.Activated, function()
		close()
	end)
	bind(CloseGlass.btn.Activated, function()
		close()
	end)
	bind(DetailClose.btn.Activated, function()
		close()
	end)
	wireGlass(CloseGlass, "spin")
	wireGlass(DetailClose, "spin")

	bind(NotifTap.Activated, function()
		openSmart()
	end)
	bind(SkipGlass.btn.Activated, function()
		if Notif.stage ~= "none" then
			Notif.skip = true
		end
	end)
	wireGlass(SkipGlass, "nudge")

	-- Thanh trượt Liquid Glass + nút đổi theme
	local draggingGlass = false
	local function updateGlassFromInput(input)
		local absX = GlassSliderHit.AbsolutePosition.X
		local absW = math.max(1, GlassSliderHit.AbsoluteSize.X)
		local rel = math.clamp((input.Position.X - absX) / absW, 0, 1)
		setGlassTransparency(rel * 0.75, true)
	end
	bind(GlassSliderHit.InputBegan, function(input)
		if isPointer(input) then
			draggingGlass = true
			tween(GlassKnobScale, 0.12, { Scale = 1.2 }, EASE.Quad, DIR.Out)
			updateGlassFromInput(input)
		end
	end)
	bind(UserInputService.InputChanged, function(input)
		if
			draggingGlass
			and (
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			updateGlassFromInput(input)
		end
	end)
	bind(UserInputService.InputEnded, function(input)
		if isPointer(input) and draggingGlass then
			draggingGlass = false
			tween(GlassKnobScale, 0.2, { Scale = 1 }, EASE.Back, DIR.Out)
		end
	end)

	bind(ThemeCycleBtn.Activated, function()
		currentThemeIndex = (currentThemeIndex % #THEME_ORDER) + 1
		applyTheme(THEME_ORDER[currentThemeIndex])
	end)

	-- Hover/nhấn trên thông báo: phồng nhẹ + tạm dừng timer.
	bind(NotifTap.MouseEnter, function()
		Notif.hover = true
		refreshScale()
	end)
	bind(NotifTap.MouseLeave, function()
		Notif.hover, Notif.press = false, false
		refreshScale()
	end)
	bind(NotifTap.InputBegan, function(input)
		if isPointer(input) then
			Notif.press = true
			refreshScale()
		end
	end)
	bind(NotifTap.InputEnded, function(input)
		if isPointer(input) then
			Notif.press = false
			refreshScale()
		end
	end)

	-- Pill lúc đóng
	bind(IslandButton.MouseEnter, function()
		pointer.hover = true
		refreshScale()
	end)
	bind(IslandButton.MouseLeave, function()
		pointer.hover, pointer.press = false, false
		refreshScale()
	end)
	bind(IslandButton.InputBegan, function(input)
		if isPointer(input) then
			pointer.press = true
			refreshScale()
		end
	end)
	bind(IslandButton.InputEnded, function(input)
		if isPointer(input) then
			pointer.press = false
			refreshScale()
		end
	end)

	-- Island: tạm dừng đếm ngược card chi tiết khi đang đọc
	bind(Island.MouseEnter, function()
		islandHold.hover = true
	end)
	bind(Island.MouseLeave, function()
		islandHold.hover, islandHold.press = false, false
	end)
	local swipeInput, swipeStartY
	bind(Island.InputBegan, function(input)
		if isPointer(input) then
			islandHold.press = true
			if Mode ~= "idle" and not draggingGlass then
				swipeInput, swipeStartY = input, input.Position.Y
			end
		end
	end)

	-- Vuốt lên để đóng (theo dõi bằng UserInputService nên tay trượt ra ngoài island vẫn đúng).
	bind(UserInputService.InputChanged, function(input)
		if Mode == "idle" or not swipeInput or draggingGlass then
			return
		end
		local matches = (input == swipeInput)
			or (
				input.UserInputType == Enum.UserInputType.MouseMovement
				and swipeInput.UserInputType == Enum.UserInputType.MouseButton1
			)
		if matches and input.Position.Y - swipeStartY < -36 then
			swipeInput = nil
			close()
		end
	end)
	bind(UserInputService.InputEnded, function(input)
		if isPointer(input) then
			swipeInput = nil
			islandHold.press = false
		end
	end)

	bind(UserInputService.InputBegan, function(input, processed)
		if processed or input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		if input.KeyCode == CONFIG.ToggleKey then
			toggle()
		end
	end)

	------------------------------------------------------------------------
	-- 12. RESPONSIVE: PC / MOBILE
	------------------------------------------------------------------------
	local function updateFit()
		local vp = Gui.AbsoluteSize
		if vp.X <= 0 or vp.Y <= 0 then
			local cam = Workspace.CurrentCamera
			vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
		end
		local widest = math.max(OPEN_W, DETAIL_W)
		local tallest = math.max(OPEN_H, DETAIL_MAX_H)
		local f = math.clamp(vp.Y / 560, 0.85, 1.3) -- theo chiều cao màn hình
		f = math.min(f, (vp.X - 24) / widest) -- không tràn ngang (điện thoại dọc)
		f = math.min(f, (vp.Y - CONFIG.TopMargin - 16) / tallest) -- không tràn dọc (điện thoại ngang)
		FitScale.Scale = math.max(f, 0.5)
	end
	bind(Gui:GetPropertyChangedSignal("AbsoluteSize"), updateFit)
	updateFit()

	------------------------------------------------------------------------
	-- 13. API CÔNG KHAI
	------------------------------------------------------------------------
	local API = {}
	function API.Open() openMain() end
	function API.Close() close() end
	function API.Toggle() toggle() end
	function API.Notify(title, message, duration, kind, extra)
		notify(title, message, duration, kind, extra)
	end
	function API.NotifyDetail(opts)
		opts = type(opts) == "table" and opts or {}
		notify(
			opts.Title or opts.title or CONFIG.Title,
			opts.Message or opts.message or "",
			opts.Duration or opts.duration or CONFIG.NotifyDuration,
			opts.Kind or opts.kind or opts.Color or opts.color or "info",
			{
				kicker = opts.Kicker or opts.kicker,
				detail = opts.Detail or opts.detail or opts.Message or opts.message,
				tags = opts.Tags or opts.tags,
				since = opts.Since or opts.since,
				detailDuration = opts.DetailDuration or opts.detailDuration,
				icon = opts.Icon or opts.icon,
				color = opts.Color or opts.color,
			}
		)
	end
	function API.ShowDetailCard(opts)
		opts = type(opts) == "table" and opts or {}
		openDetail({
			title = opts.Title or opts.title or CONFIG.WelcomeTitle,
			message = opts.Message or opts.message or "",
			detail = opts.Detail or opts.detail or opts.Message or opts.message or "",
			kicker = opts.Kicker or opts.kicker or CONFIG.DefaultKicker,
			tags = opts.Tags or opts.tags or CONFIG.CardTags,
			since = opts.Since or opts.since or CONFIG.CardSince,
			kind = normalizeKind(opts.Kind or opts.kind or "info"),
			customColor = typeof(opts.Color) == "Color3" and opts.Color or nil,
			detailDuration = opts.Duration or opts.duration or CONFIG.DetailDuration,
		})
	end
	function API.Skip()
		if Notif.stage ~= "none" then
			Notif.skip = true
		end
	end
	function API.SetProgress(p) setProgress(p, Mode ~= "open") end
	function API.SetStatus(text) PillText.Text = tostring(text) end
	function API.SetMessage(text) CompactMessage.Text = tostring(text) end
	function API.SetTitle(text) CompactTitle.Text = tostring(text) end
	function API.SetLogo(assetId)
		CONFIG.LeftImage = tostring(assetId)
		for _, img in ipairs(logoImages) do
			if img and img.Parent then
				img.Image = CONFIG.LeftImage
			end
		end
	end
	function API.SetLines(lines)
		for i, l in ipairs(rowLabels) do
			l.Text = tostring(lines[i] or "")
		end
	end
	function API.SetGlass(transparency, blurEnabled)
		if blurEnabled ~= nil then
			CONFIG.GlassBlur = parseBool(blurEnabled, false)
		end
		setGlassTransparency(transparency, false)
	end
	function API.SetTheme(themeName)
		applyTheme(tostring(themeName))
		for i, name in ipairs(THEME_ORDER) do
			if name == CONFIG.Theme then
				currentThemeIndex = i
			end
		end
	end
	function API.IncrementUsage(delta)
		bumpUsageCount(delta or 1)
	end
	function API.Destroy()
		if Gui.Parent then
			Gui:Destroy()
		end
	end

	globalEnv.KhanhlyIsland = API

	local NotifyEvent = new("BindableEvent", { Name = "Notify" }, Gui)
	bind(NotifyEvent.Event, function(title, message, duration, kind, extra)
		notify(title, message, duration, kind, extra)
	end)
	local ProgressEvent = new("BindableEvent", { Name = "SetProgress" }, Gui)
	bind(ProgressEvent.Event, function(p)
		API.SetProgress(p)
	end)

	------------------------------------------------------------------------
	-- 14. CLEANUP
	------------------------------------------------------------------------
	local function cleanup()
		if not alive then
			return
		end
		alive = false
		Notif.token = Notif.token + 1
		detailToken = detailToken + 1
		if driver then
			driver:Disconnect()
			driver = nil
		end
		if WorldBlur and WorldBlur.Parent then
			WorldBlur:Destroy()
		end
		for _, c in ipairs(conns) do
			pcall(function()
				c:Disconnect()
			end)
		end
		for _, tw in ipairs(ambient) do
			pcall(function()
				tw:Cancel()
			end)
		end
		for _, slot in pairs(live) do
			for _, tw in pairs(slot) do
				pcall(function()
					tw:Cancel()
				end)
			end
		end
		if globalEnv.KhanhlyIsland == API then
			globalEnv.KhanhlyIsland = nil
		end
	end
	bind(Gui.Destroying, cleanup)

	------------------------------------------------------------------------
	-- 15. ENTRANCE
	------------------------------------------------------------------------
	setGlassTransparency(CONFIG.GlassTransparency, true)
	refreshThemeColors()
	renderSession()
	go("y", CONFIG.TopMargin, 170, 17)
	go("s", 1, 300, 20)

	local function finishIntro()
		introActive = false
		if not alive then
			return
		end
		if Mode == "idle" and Notif.stage == "none" then
			setIsland(CLOSED_W, CLOSED_H, CLOSED_H / 2, 260, 21)
			tween(CompactGroup, 0.36, { GroupTransparency = 0 }, EASE.Quad, DIR.Out, 0.08)
			task.delay(0.25, sweep)
		end
		pumpNotifications()
	end

	if CONFIG.Intro then
		local introSz = math.clamp(CONFIG.startintro_size, 48, 140)
		setIsland(introSz, introSz, 22, 260, 20)
		local IntroLogo = avatar(Island, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(math.floor(introSz * 0.56), math.floor(introSz * 0.56)),
			ZIndex = 10,
		}, 14, "KH", 18)
		task.delay(math.clamp(CONFIG.squareintro_time, 0.3, 4.0), function()
			if not alive then
				return
			end
			tween(IntroLogo, 0.18, { BackgroundTransparency = 1 }, EASE.Quad, DIR.In)
			for _, ch in ipairs(IntroLogo:GetChildren()) do
				if ch:IsA("ImageLabel") then
					tween(ch, 0.18, { ImageTransparency = 1 }, EASE.Quad, DIR.In)
				elseif ch:IsA("TextLabel") then
					tween(ch, 0.18, { TextTransparency = 1 }, EASE.Quad, DIR.In)
				elseif ch:IsA("UIStroke") then
					tween(ch, 0.18, { Transparency = 1 }, EASE.Quad, DIR.In)
				end
			end
			task.delay(0.2, function()
				if IntroLogo and IntroLogo.Parent then
					IntroLogo:Destroy()
				end
			end)
			finishIntro()
		end)
	else
		setIsland(CLOSED_W, CLOSED_H, CLOSED_H / 2, 260, 21)
		tween(CompactGroup, 0.4, { GroupTransparency = 0 }, EASE.Quad, DIR.Out, 0.1)
		task.delay(0.35, sweep)
	end

	if CONFIG.WelcomeNotify then
		local welcomeDelay = CONFIG.Intro and (CONFIG.squareintro_time + 1.1) or 1.6
		task.delay(welcomeDelay, function()
			if alive then
				notify(CONFIG.WelcomeTitle, CONFIG.WelcomeMessage, CONFIG.NotifyDuration, "cyan", {
					kicker = CONFIG.WelcomeKicker,
					detail = CONFIG.WelcomeMessage,
					tags = CONFIG.CardTags,
					since = CONFIG.CardSince,
					detailDuration = CONFIG.DetailDuration,
				})
			end
		end)
	end

	return API
end

-- Alias: khanhly_v5.new({...}) hoặc Ophyn.new({...})
globalEnv.khanhly_v5 = KhanhlyV5
globalEnv.Ophyn = KhanhlyV5

-- Chạy trực tiếp file thì hiện GUI mặc định. Nếu bạn gọi .new(...) ngay sau khi load thì bỏ qua bước này.
-- Tắt hẳn: getgenv().KhanhlyV5_AutoStart = false (đặt TRƯỚC khi load file).
if globalEnv.KhanhlyV5_AutoStart ~= false then
	task.defer(function()
		if not createdByUser then
			KhanhlyV5.new({})
		end
	end)
end

return KhanhlyV5
