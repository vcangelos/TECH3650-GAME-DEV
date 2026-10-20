-- CTFServer (ServerScriptService)
--
-- Capture the Flag round system for Red vs Blue.
-- Started from a HowToRoblox CTF tutorial for ideas, then rewrote it my own way and kept
-- it to one server script so it's easy to follow.
--
-- How a round goes:
--   1. Each team's flag spawns on one of its spot Parts, picked at random.
--   2. Touch the enemy flag to grab it. It gets stuck to your back.
--   3. Bring it to your own flag to score a capture.
--   4. Die or leave while carrying it and the flag goes back home.
--   5. First team to SCORE_TO_WIN wins, short break, new round with new flag spots.
--
-- Map setup: the spot Parts are placed by hand in Studio and named Red_Flag1, Red_Flag2,
-- Blue_Flag1, Blue_Flag2, and so on. I wanted the flag locations to change between rounds
-- so the map doesn't get stale. To add a spot, place a Part and give it the next number
-- (Red_Flag3). The numbers have to go 1, 2, 3... with no gaps.
--
-- Game state is stored as Attributes on the objects themselves, so I can watch the values
-- change in the Properties window while testing:
--   Team "Red"/"Blue"  -> Score       (captures this round)
--                      -> SpotNumber  (which spot the flag is on this round)
--   Player             -> CarryingFlag ("Red" or "Blue" while holding a flag)
--   Flag               -> Carried     (true while someone has it)

local Players = game:GetService("Players")
local Teams = game:GetService("Teams")

-- SETTINGS -------------------------------------------------------------------
-- Tweak the game here without touching the logic below

local SCORE_TO_WIN = 3
local INTERMISSION = 10 -- seconds of downtime between rounds
local ROUND_TIME = 300 -- 5  minutes
local winner = nil -- gets set to "Red" or "Blue" once a team hits SCORE_TO_WIN
local roundActive = false
-- FLAG SPOTS -----------------------------------------------------------------

-- Finds a spot Part by team and number, e.g. getSpot("Red", 2) finds Red_Flag2
local function getSpot(teamName, number)
	return workspace:FindFirstChild(teamName .. "_Flag" .. number, true) -- true = also look inside folders/models
end

-- Counts a team's spots by checking Red_Flag1, Red_Flag2, ... until one is missing
local function countSpots(teamName)
	local count = 0
	while getSpot(teamName, count + 1) do
		count += 1
	end
	return count
end

-- The spot Parts are only markers for where flags go; players shouldn't see or bump into them
local function hideSpots(teamName)
	for number = 1, countSpots(teamName) do
		local spot = getSpot(teamName, number)
		spot.Transparency = 1
		spot.CanCollide = false
		spot.CanTouch = false
	end

	-- Debug line I added while the flags weren't showing up; handy to keep
	print("CTF: found " .. countSpots(teamName) .. " " .. teamName .. " flag spot(s)")
end

hideSpots("Red")
hideSpots("Blue")

-- Picks a random spot for this round, but not the same one as last round, so it actually changes
local function pickSpotNumber(teamName)
	local team = Teams[teamName]
	local total = countSpots(teamName)
	assert(total > 0, "CTF: no flag spots found for team " .. teamName)

	local number
	repeat
		number = math.random(total)
	until number ~= team:GetAttribute("SpotNumber") or total == 1

	team:SetAttribute("SpotNumber", number)
end

-- HELPERS --------------------------------------------------------------------

-- The flag that's on the map for a team, e.g. getFlag("Red") finds "RedFlag"
local function getFlag(teamName)
	return workspace:FindFirstChild(teamName .. "Flag")
end

-- No on-screen text in this game, so feedback is just an explosion (boom + blast).
-- BlastPressure and DestroyJointRadiusPercent at 0 make it purely cosmetic: it can't
-- fling or kill anyone. Used for grabbing, losing, and capturing a flag.
local function playFlagEffect(position)
	local explosion = Instance.new("Explosion")
	explosion.Position = position
	explosion.BlastPressure = 0
	explosion.DestroyJointRadiusPercent = 0
	explosion.Parent = workspace
end

-- Weld the flag onto the player's back
local function pickUp(player, flagTeam)
	local flag = getFlag(flagTeam)
	local root = player.Character.HumanoidRootPart

	playFlagEffect(flag.Position) -- grabbed

	flag.Anchored = false
	flag.Massless = true -- otherwise the flag's weight slows the carrier down
	flag.CFrame = root.CFrame * CFrame.new(0, 1.5, 1) * CFrame.Angles(math.rad(20), 0, 0) -- on the back, tilted

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = flag
	weld.Parent = flag

	flag:SetAttribute("Carried", true)
	player:SetAttribute("CarryingFlag", flagTeam)
end

-- Sticks a piece (the pole or the cloth) onto the flag's invisible box so they move together.
-- Only the box detects touches; the visible pieces are just for looks.
local function attachToFlag(piece, flag)
	piece.Anchored = false
	piece.Massless = true
	piece.CanCollide = false
	piece.CanTouch = false

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = flag
	weld.Part1 = piece
	weld.Parent = piece

	piece.Parent = flag
end

-- spawnFlag and onFlagTouched need each other, so this is declared up here and filled in later
local onFlagTouched

-- Builds a new flag on the team's spot, deleting the old one first.
-- I rebuild the flag every time instead of moving it, because if a carrier falls off
-- the map, Roblox deletes the flag along with them. A fresh flag sidesteps that.
local function spawnFlag(teamName)
	local oldFlag = getFlag(teamName)
	if oldFlag then
		oldFlag:Destroy()
	end

	local spot = getSpot(teamName, Teams[teamName]:GetAttribute("SpotNumber"))

	-- The part players actually touch is an invisible 4x8x4 box. The pole alone was
	-- too thin to grab reliably, so the box makes pickups feel fair.
	local flag = Instance.new("Part")
	flag.Name = teamName .. "Flag"
	flag.Size = Vector3.new(4, 8, 4)
	flag.Transparency = 1
	flag.Anchored = true
	flag.CanCollide = false
	flag.Position = spot.Position + Vector3.new(0, spot.Size.Y / 2 + flag.Size.Y / 2, 0) -- sits on top of the spot

	-- What players see: a metal pole...
	local pole = Instance.new("Part")
	pole.Name = "Pole"
	pole.Size = Vector3.new(0.4, 8, 0.4)
	pole.Color = Color3.fromRGB(200, 200, 200)
	pole.Material = Enum.Material.Metal
	pole.CFrame = flag.CFrame
	attachToFlag(pole, flag)

	-- ...with a cloth in the team's color near the top...
	local cloth = Instance.new("Part")
	cloth.Name = "Cloth"
	cloth.Size = Vector3.new(0.2, 2.5, 3.5)
	cloth.BrickColor = Teams[teamName].TeamColor
	cloth.Material = Enum.Material.Fabric
	cloth.CFrame = flag.CFrame * CFrame.new(0, 2.75, 1.95)
	attachToFlag(cloth, flag)

	-- ...and a glow so you can spot it from across the map
	local light = Instance.new("PointLight")
	light.Color = cloth.Color
	light.Range = 12
	light.Parent = cloth

	flag.Parent = workspace

	flag.Touched:Connect(function(hit)
		onFlagTouched(teamName, hit)
	end)
end

-- Carrier died, respawned, or left: their flag goes back to its spot
local function sendHeldFlagHome(player)
	local flagTeam = player:GetAttribute("CarryingFlag")
	if not flagTeam then
		return -- they weren't holding anything
	end
	player:SetAttribute("CarryingFlag", nil)

	local flag = getFlag(flagTeam)
	if flag then -- (it's already gone if they fell off the map)
		playFlagEffect(flag.Position) -- lost
	end
	spawnFlag(flagTeam)
end

-- FORCEFIELD DURING INTERMISSION ----------------------------------------------
local intermissionActive = false

local function protectPlayer(player)
	local character = player.Character
	if character and not character:FindFirstChild("RoundForceField") then
		local field = Instance.new("ForceField")
		field.Name = "RoundForceField"
		field.Visible = true
		field.Parent = character
	end
end

local function removeProtection(player)
	local character = player.Character
	if character then
		local field = character:FindFirstChild("RoundForceField")
		if field then
			field:Destroy()
		end
	end
end

-- Activate protection as soon as the round finishes.
local function beginIntermission()
	if intermissionActive then return end
	roundActive = false
	intermissionActive = true
	for _, player in ipairs(Players:GetPlayers()) do
		protectPlayer(player)
	end
end

-- A capture: send the stolen flag home, add the points, check for a winner
local function score(player)
	local flagTeam = player:GetAttribute("CarryingFlag")
	player:SetAttribute("CarryingFlag", nil)

	playFlagEffect(getFlag(flagTeam).Position) -- captured
	spawnFlag(flagTeam)

	player.leaderstats.Captures.Value += 1

	local myTeam = player.Team
	myTeam:SetAttribute("Score", myTeam:GetAttribute("Score") + 1)

	if myTeam:GetAttribute("Score") >= SCORE_TO_WIN then
		winner = myTeam.Name
		beginIntermission() -- shield everyone immediately on the winning capture
	end
end

-- The main rules. Runs every time something touches a flag.
onFlagTouched = function(flagTeam, hit)
	if not roundActive or winner then
		return
	end

	-- Make sure it's a living player on a team (not a random part or a dead body)
	local character = hit.Parent
	local player = Players:GetPlayerFromCharacter(character)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not player or not player.Team or not humanoid or humanoid.Health <= 0 then
		return
	end

	-- Spectators were able to grab flags during testing. Only teams that have a flag
	-- on the map (Red and Blue) can play, so this blocks everyone else.
	local myTeam = player.Team.Name
	if not getFlag(myTeam) then
		return
	end

	if getFlag(flagTeam):GetAttribute("Carried") then
		return -- someone's already carrying this flag
	end

	if myTeam ~= flagTeam then
		-- Enemy flag: take it, as long as you aren't already holding one
		if not player:GetAttribute("CarryingFlag") then
			pickUp(player, flagTeam)
		end
	else
		-- Your own flag: if you're carrying the enemy's flag, that's a capture.
		-- (Your flag has to be home for this to happen, so you can't score while yours is stolen.)
		if player:GetAttribute("CarryingFlag") then
			score(player)
		end
	end
end

-- ROUNDS ---------------------------------------------------------------------

-- Gets one team ready for a new round: score back to 0, new spot, fresh flag
local function setUpTeam(teamName)
	Teams[teamName]:SetAttribute("Score", 0)
	pickSpotNumber(teamName)
	spawnFlag(teamName)
	print("CTF: " .. teamName .. " flag spawned at " .. teamName .. "_Flag" .. Teams[teamName]:GetAttribute("SpotNumber"))
end

-- New round: everyone's stats reset and they respawn, then both flags go to new spots
local function startRound()
	winner = nil
	roundActive = false

	-- Keep protection active until respawning and flag setup are finished.
	-- GetPlayers() gives back everyone in the game; this goes through them one at a time
	for _, player in ipairs(Players:GetPlayers()) do
		player:SetAttribute("CarryingFlag", nil)
		player.leaderstats.Captures.Value = 0
		player:LoadCharacter()
	end

	setUpTeam("Red")
	setUpTeam("Blue")
	intermissionActive = false
	for _, player in ipairs(Players:GetPlayers()) do
		removeProtection(player)
	end
	roundActive = true
end

-- PLAYERS --------------------------------------------------------------------

local function setupPlayer(player)
	-- A folder named "leaderstats" shows up on the player list automatically,
	-- and Roblox adds up each team's total for free
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local captures = Instance.new("IntValue")
	captures.Name = "Captures"
	captures.Parent = leaderstats

	local wins = Instance.new("IntValue")
	wins.Name = "Wins"
	wins.Value = 0
	wins.Parent = leaderstats

	local losses = Instance.new("IntValue")
	losses.Name = "Losses"
	losses.Value = 0
	losses.Parent = leaderstats

	-- If the carrier dies or respawns, the flag shouldn't stay stuck to their old body
	player.CharacterAdded:Connect(function(newCharacter)
		if intermissionActive then
			protectPlayer(player)
		end
		newCharacter:WaitForChild("Humanoid").Died:Connect(function()
			sendHeldFlagHome(player)
		end)
	end)
	player.CharacterRemoving:Connect(function()
		sendHeldFlagHome(player)
	end)
	if intermissionActive then
		protectPlayer(player)
	end
end

Players.PlayerAdded:Connect(setupPlayer)

-- In Studio I'd sometimes load in before this script started, so PlayerAdded never
-- fired for me and I had no leaderstats. This catches anyone who's already in the game.
for _, player in ipairs(Players:GetPlayers()) do
	setupPlayer(player)
end

Players.PlayerRemoving:Connect(sendHeldFlagHome)

-- GAME LOOP ------------------------------------------------------------------
-- The whole game in four lines: start a round, wait for a winner, take a break, repeat.


while true do

	-- Start a new round
	startRound()
	print("Round Started!")

	local timeLeft = ROUND_TIME

	-- Round continues until time runs out or a team wins
	while timeLeft > 0 and not winner do
		task.wait(1)
		timeLeft -= 1
	end
	beginIntermission() -- also shield everyone immediately when time runs out
	-- Determine winner if time runs out
	if not winner then
		local redScore = Teams.Red:GetAttribute("Score")
		local blueScore = Teams.Blue:GetAttribute("Score")

		if redScore > blueScore then
			winner = "Red"
		elseif blueScore > redScore then
			winner = "Blue"
		else
			winner = "Tie"
		end
	end

	-- Give a win to the winning team and a loss to the losing team.
	-- A tie does not change wins or losses.
	if winner ~= "Tie" then
		for _, player in ipairs(Players:GetPlayers()) do
			if player.Team and (player.Team.Name == "Red" or player.Team.Name == "Blue") then
				if player.Team.Name == winner then
					player.leaderstats.Wins.Value += 1
				else
					player.leaderstats.Losses.Value += 1
				end
			end
		end
	end

	print("Round Ended! Winner: " .. winner)

	-- ForceFields stay up for the entire intermission.
	task.wait(INTERMISSION)

end

