local class = rawget(_G, 'class')
local l_BaseScreen = rawget(_G, 'l_BaseScreen')
local CreateTextEntity = rawget(_G, 'CreateTextEntity')
local AttachInPlace = rawget(_G, 'AttachInPlace')
local CreateAnimation = rawget(_G, 'CreateAnimation')
local ReloadTestScreen = rawget(_G, 'ReloadTestScreen')
local COMICS_FONT = rawget(_G, 'COMICS_FONT')
local HGETEXT_CENTER = rawget(_G, 'HGETEXT_CENTER')
local HGETEXT_MIDDLE = rawget(_G, 'HGETEXT_MIDDLE')

class 'TestScreen' (l_BaseScreen)

function TestScreen:__init(name, screen)
	l_BaseScreen.__init(self, name, screen)
	self:CreateReloadLogic()
	self:CreateMinesweeper()
end

function TestScreen:CreateMinesweeper()
	self.rows = 8
	self.columns = 15
	self.total_mines = 20
	self.mines_count = self.total_mines
	self.opened_count = 0
	self.is_game_over = false
	self.is_first_click = true
	self.map = {}

	local tile_size = 42
	local start_x = 218
	local start_y = 225

	self.status_text = self:CreateCustomText({
		x = 512,
		y = 160,
		z = 230,
		string = 'Mines: ' .. self.mines_count,
		text_name = 'status_text',
		color = '0xFFFFFFFF',
		scale = 0.7
	})

	for row = 1, self.rows do
		self.map[row] = {}
		for column = 1, self.columns do
			local x = start_x + (column - 1) * tile_size
			local y = start_y + (row - 1) * tile_size
			local name = 'tile_' .. row .. '_' .. column

			self:CreateCustomObject({
				obj_name = name .. '_bg',
				x = x, y = y, z = 190,
				scale_x = 0.62, scale_y = 0.62,
				color = '0xFFB0B0B0',
				anim_texture = 'Data/Textures/General/area_square.png'
			})

			self:CreateCustomObject({
				obj_name = name,
				x = x, y = y, z = 210,
				scale_x = 0.62, scale_y = 0.62,
				color = '0xFF008080',
				anim_texture = 'Data/Textures/General/area_square.png'
			})

			local number_text = self:CreateCustomText({
				x = x, y = y, z = 225,
				string = '',
				text_name = name .. '_text',
				color = '0xFF000000',
				scale = 0.6
			})
			number_text:Hide()

			local flag_text = self:CreateCustomText({
				x = x, y = y, z = 235,
				string = 'F',
				text_name = name .. '_flag',
				color = '0xFFFFFF00',
				scale = 0.6
			})
			flag_text:Hide()

			self.map[row][column] = {
				row = row,
				column = column,
				obj_name = name,
				text = number_text,
				flag_text = flag_text,
				has_mine = false,
				near_mines = 0,
				is_open = false,
				is_flagged = false
			}

			local tile_row = row
			local tile_column = column
			self:RegisterActiveObject(name, function(clicked_obj_name, key)
				self:OnTileClick(tile_row, tile_column, key)
			end)
			self:RegisterActiveObject(name .. '_bg', function(clicked_obj_name, key)
				self:OnTileClick(tile_row, tile_column, key)
			end)
		end
	end
end

function TestScreen:IsRightMouseButton(key)
	return key == 2 or key == '2'
end

function TestScreen:OnTileClick(row, column, key)
	if self.is_game_over then return end

	local tile = self.map[row][column]

	if self:IsRightMouseButton(key) then
		self:ToggleFlag(tile)
		return
	end

	if tile.is_flagged or tile.is_open then return end

	if self.is_first_click then
		self.is_first_click = false
		self:PutMines(row, column)
		self:CountNearMines()
	end

	if tile.has_mine then
		self:LoseGame(tile)
	else
		self:OpenTiles(tile)
		self:CheckWin()
	end
end

function TestScreen:ToggleFlag(tile)
	if tile.is_open then return end

	tile.is_flagged = not tile.is_flagged
	if tile.is_flagged then
		tile.flag_text:Show()
		self.mines_count = self.mines_count - 1
	else
		tile.flag_text:Hide()
		self.mines_count = self.mines_count + 1
	end
	self.status_text:SetText('Mines: ' .. self.mines_count)
end

function TestScreen:PutMines(first_row, first_column)
	local mines_left = self.total_mines
	while mines_left > 0 do
		local row = math.random(1, self.rows)
		local column = math.random(1, self.columns)
		local tile = self.map[row][column]
		if not tile.has_mine and not (row == first_row and column == first_column) then
			tile.has_mine = true
			mines_left = mines_left - 1
		end
	end
end

function TestScreen:CountNearMines()
	for row = 1, self.rows do
		for column = 1, self.columns do
			local tile = self.map[row][column]
			tile.near_mines = 0
			for near_row = row - 1, row + 1 do
				for near_column = column - 1, column + 1 do
					if self:IsInsideMap(near_row, near_column) and self.map[near_row][near_column].has_mine then
						tile.near_mines = tile.near_mines + 1
					end
				end
			end
		end
	end
end

function TestScreen:IsInsideMap(row, column)
	return row >= 1 and row <= self.rows and column >= 1 and column <= self.columns
end

function TestScreen:OpenTiles(start_tile)
	local queue = { start_tile }
	local head = 1

	while head <= #queue do
		local tile = queue[head]
		head = head + 1

		if not tile.is_open and not tile.is_flagged then
			tile.is_open = true
			self.opened_count = self.opened_count + 1
			self:GetObject(tile.obj_name):Hide()
			tile.flag_text:Hide()

			if tile.near_mines > 0 then
				tile.text:SetText(tostring(tile.near_mines))
				tile.text:SetColor(self:GetNumberColor(tile.near_mines))
				tile.text:Show()
			else
				for near_row = tile.row - 1, tile.row + 1 do
					for near_column = tile.column - 1, tile.column + 1 do
						if self:IsInsideMap(near_row, near_column) then
							local neighbour = self.map[near_row][near_column]
							if not neighbour.is_open and not neighbour.is_flagged and not neighbour.has_mine then
								queue[#queue + 1] = neighbour
							end
						end
					end
				end
			end
		end
	end
end

function TestScreen:GetNumberColor(number)
	local colors = {
		'0xFF0000FF',
		'0xFF008000',
		'0xFFFF0000',
		'0xFF000080',
		'0xFF800000',
		'0xFF008080',
		'0xFF000000',
		'0xFF808080'
	}
	return colors[number] or '0xFF000000'
end

function TestScreen:LoseGame(clicked_tile)
	self.is_game_over = true
	self.status_text:SetText('Game over')

	for row = 1, self.rows do
		for column = 1, self.columns do
			local tile = self.map[row][column]
			if tile.has_mine then
				self:GetObject(tile.obj_name):Hide()
				tile.flag_text:Hide()
				tile.text:SetText('*')
				tile.text:SetColor('0xFFFF0000')
				tile.text:Show()
			end
		end
	end

	clicked_tile.text:SetColor('0xFFFFFF00')
end

function TestScreen:CheckWin()
	if self.opened_count < self.rows * self.columns - self.total_mines then
		return
	end

	self.is_game_over = true
	self.status_text:SetText('You win!')

	for row = 1, self.rows do
		for column = 1, self.columns do
			local tile = self.map[row][column]
			if tile.has_mine and not tile.is_flagged then
				tile.is_flagged = true
				tile.flag_text:Show()
			end
		end
	end
end

function TestScreen:CreateCustomText(info)
	local text_scale = info.scale or 0.7
	local text_spacing = info.spacing or 0.9
	local text_color = info.color or '0xFFFFFFFF'
	local text_z = info.z or 150
	local text_x = info.x or 512
	local text_y = info.y or 384
	local text_string = info.string or 'EMPTY'
	local text_name = info.text_name

	local text_entity = nil
	text_entity = CreateTextEntity(COMICS_FONT, 'EMPTY')
	if text_name then
		text_entity:SetName(text_name)
	end
	text_entity:SetXY(text_x, text_y)
	text_entity:SetZ(text_z)
	text_entity:SetScale(text_scale)
	text_entity:SetSpacing(text_spacing)
	text_entity:SetTextAlignment(HGETEXT_CENTER + HGETEXT_MIDDLE)
	text_entity:SetColor(text_color)
	text_entity:SetText(text_string)
	if info.parent_object then
		AttachInPlace(text_entity, info.parent_object)
	else
		AttachInPlace(text_entity, self.screen)
	end
	if text_name then
		self.screen:RegisterGUIControl(text_entity)
	end
	return text_entity
end

function TestScreen:CreateCustomObject(info)
	local anim_texture = info.anim_texture or 'Data/Textures/General/area_square.png'
	local anim_w = info.anim_w or 64
	local anim_h = info.anim_h or 64
	local anim_hot_w = info.anim_hot_w or math.floor(anim_w / 2)
	local anim_hot_h = info.anim_hot_w or math.floor(anim_h / 2)
	local obj_name = info.obj_name
	local color = info.color or '0xFFFFFFFF'
	assert(obj_name, 'no obj_name for new object')

	local x = info.x or 512
	local y = info.y or 384
	local z = info.z or 200
	local angle = info.angle or 0
	local scale_x = info.scale_x or 1
	local scale_y = info.scale_y or 1

	local anim = CreateAnimation(anim_texture, 0, 0, anim_w, anim_h, 1, 0)
	anim:SetHotSpot(anim_hot_w, anim_hot_h)
	anim:SetColor(color)
	local obj = self.screen:CreateObject(obj_name, anim, x, y, z, angle, scale_x, scale_y)
	return obj
end

function TestScreen:CreateReloadLogic()
	self:CreateCustomObject({
		obj_name = 'area_reload',
		x = 512, y = 95, z = 200,
		scale_x = 2.2, scale_y = 0.7,
		color = '0xFF606060'
	})
	self:CreateCustomText({
		x = 512, y = 95, z = 230,
		string = 'Restart',
		text_name = 'reload_text',
		color = '0xFFFFFFFF',
		scale = 0.65
	})
	local function ClickReload(clicked_obj_name)
		Console:Log('ClickReload ' .. tostring(clicked_obj_name))
		ReloadTestScreen()
	end
	self:RegisterActiveObject('area_reload', ClickReload)
end

function TestScreen:OnObjectMouseDown(object, key)
	l_BaseScreen.OnObjectMouseDown(self, object, key)
	if object then
		if self.active_objects and self.active_objects[object:GetName()] then
			self.active_objects[object:GetName()](object:GetName(), key)
		end
	end
end

function TestScreen:RegisterActiveObject(objName, callback)
	if not self.active_objects then
		self.active_objects = {}
	end
	self.active_objects[objName] = callback
end