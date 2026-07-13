local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BuildController = require(script.Parent.BuildController)
local MapController = require(script.Parent.MapController)
local CutTreeController = require(script.Parent.CutTreeController)
local SelectionModeController = require(script.Parent.SelectionModeController)

local Spring = require(ReplicatedStorage.Common.Libraries.Spring)
local WorldMap = require(ReplicatedStorage.Common.WorldMap)

local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()

local SelectionBox = ReplicatedStorage.Assets.SelectionBox

local ScreenGui = Player.PlayerGui:WaitForChild("ScreenGui")
local HoveredTileLabel: TextLabel = ScreenGui:WaitForChild("HoveredTile")

local SelectionController = { isSelectingBox = false }

local selectionBox = SelectionBox:Clone()
local _, size = selectionBox:GetBoundingBox()
selectionBox.Parent = workspace

local spring = Spring.new(Vector3.zero)
spring.Speed = 12

local springBR = Spring.new(Vector3.zero)
springBR.Speed = 12
local springTL = Spring.new(Vector3.zero)
springTL.Speed = 12
local springTR = Spring.new(Vector3.zero)
springTR.Speed = 12
local springBL = Spring.new(Vector3.zero)
springBL.Speed = 12

local function updateSelectionBox(map: WorldMap.WorldMap)
	local startPos = map:WorldPosFromGridPos(map.selection.Start)
	local endPos = map:WorldPosFromGridPos(map.selection.End)

	local minX = math.min(startPos.X, endPos.X)
	local maxX = math.max(startPos.X, endPos.X)
	local minZ = math.min(startPos.Z, endPos.Z)
	local maxZ = math.max(startPos.Z, endPos.Z)

	springBR.Target = Vector3.new(maxX, 2 + size.Y / 2, maxZ)
	springTL.Target = Vector3.new(minX, 2 + size.Y / 2, minZ)
	springTR.Target = Vector3.new(maxX, 2 + size.Y / 2, minZ)
	springBL.Target = Vector3.new(minX, 2 + size.Y / 2, maxZ)
end

local function onMapCreated(map)
	RunService:BindToRenderStep("GetHoveredTile", 1, function(dt)
		local ray = workspace.CurrentCamera:ScreenPointToRay(Mouse.X, Mouse.Y)
		local raycastParams = RaycastParams.new()
		raycastParams.FilterDescendantsInstances = { workspace.Map.Tiles, workspace.Map.Ocean }
		raycastParams.FilterType = Enum.RaycastFilterType.Include
		local raycastResult = workspace:Raycast(ray.Origin, ray.Direction * 500, raycastParams)
		if not raycastResult then
			return
		end

		local hoveredTile = map:GridPosFromWorldPos(map:SnapToGrid(raycastResult.Position))
		local building = map.buildingMap:Get(hoveredTile.X, hoveredTile.Y)
		local feature = map.featureMap:Get(hoveredTile.X, hoveredTile.Y)
		local terrain = map.terrainMap:Get(hoveredTile.X, hoveredTile.Y)

		map.hoveredTile = hoveredTile
		HoveredTileLabel.Text =
			`Hovered Tile:  {map.hoveredTile}\n{building and building.Name or feature and feature.Name or "None"}`
		HoveredTileLabel.Position = UDim2.new(0.015, Mouse.X, -0.01, Mouse.Y)

		if not SelectionController.isSelectingBox then
			springBR.Target = map:WorldPosFromGridPos(hoveredTile) + Vector3.new(0, 1 + size.Y / 2, 0)
			if terrain == WorldMap.TerrainType.Ocean or terrain == WorldMap.TerrainType.Shore then
				springBR.Target -= Vector3.yAxis
			end

			springTL.Target = springBR.Target
			springTR.Target = springBR.Target
			springBL.Target = springBR.Target
		end

		springBR:TimeSkip(dt)
		springTL:TimeSkip(dt)
		springTR:TimeSkip(dt)
		springBL:TimeSkip(dt)

		selectionBox.BottomRight:PivotTo(CFrame.new(springBR.Position) * CFrame.Angles(0, math.rad(-180), 0))
		selectionBox.TopLeft:PivotTo(CFrame.new(springTL.Position))
		selectionBox.TopRight:PivotTo(CFrame.new(springTR.Position) * CFrame.Angles(0, 0, -math.rad(180)))
		selectionBox.BottomLeft:PivotTo(
			CFrame.new(springBL.Position) * CFrame.Angles(0, math.rad(-180), -math.rad(180))
		)
	end)

	ContextActionService:BindAction("SelectTile", function(_, state: Enum.UserInputState)
		if state == Enum.UserInputState.Begin then
			local hoveredTile = map.hoveredTile
			if not hoveredTile then
				return
			end

			map.selection = { Start = hoveredTile, End = hoveredTile }
			SelectionController.isSelectingBox = true

			RunService:BindToRenderStep("UpdateSelection", 2, function()
				hoveredTile = map.hoveredTile
				if not hoveredTile then
					return
				end

				map.selection.End = hoveredTile
				updateSelectionBox(map)
			end)
		elseif state == Enum.UserInputState.End then
			RunService:UnbindFromRenderStep("UpdateSelection")
			SelectionController.isSelectingBox = false
			local endPos = map:WorldPosFromGridPos(map.selection.End)

			if SelectionModeController.SelectionMode == "Build" then
				SelectionModeController.SelectionMode = "None"
				Mouse.Icon = "rbxasset://SystemCursors/Arrow"
				BuildController:Place(BuildController.PlannedBuilding, true)
				return
			end

			if SelectionModeController.SelectionMode == "CutTree" then
				local startPos = map:WorldPosFromGridPos(map.selection.Start)
				local minX = math.min(startPos.X, endPos.X)
				local maxX = math.max(startPos.X, endPos.X)
				local minZ = math.min(startPos.Z, endPos.Z)
				local maxZ = math.max(startPos.Z, endPos.Z)

				for x = minX, maxX do
					for z = minZ, maxZ do
						CutTreeController.AddCutTask(map, map:GridPosFromWorldPos(Vector3.new(x, 0, z)))
					end
				end
			end
		end
	end, false, Enum.UserInputType.MouseButton1)
end

onMapCreated(MapController:GetMap())

return SelectionController
