local GSSE = GSSE
local GNOME = GSStaticSourceTransmission
local GSStaticPrefix = "GS-E"
local GSEVersion = GetAddOnMetadata("GS-Core", "Version")
local GSold = false
local L = LibStub("AceLocale-3.0"):GetLocale("GS-SE")
local ldb = LibStub:GetLibrary("LibDataBroker-1.1")
local AceGUI = LibStub("AceGUI-3.0")
local Completing = LibStub("AceGUI-3.0-Completing-EditBox")
local libS = LibStub:GetLibrary("AceSerializer-3.0")
local libC = LibStub:GetLibrary("LibCompress")
local libCE = libC:GetAddonEncodeTable()

local dataobj = ldb:NewDataObject(L["GnomeSequencer-Enhanced"], {type = "data source", text = "/gsse"})

local transauthor = GetUnitName("player", true) .. '@' .. GetRealmName()
local transauthorlen = string.len(transauthor)

Completing:Register ("ExampleAll", AUTOCOMPLETE_LIST.WHISPER)


GSPrintDebugMessage("GS-Core Version " .. GSEVersion, GNOME)

StaticPopupDialogs['GSE_UPDATE_AVAILABLE'] = {
	text = L["GS-E is out of date. You can download the newest version from https://mods.curse.com/addons/wow/gnomesequencer-enhanced."],
	hasEditBox = 1,
	OnShow = function(self)
		self.editBox:SetAutoFocus(false)
		self.editBox.width = self.editBox:GetWidth()
		self.editBox:Width(220)
		self.editBox:SetText("https://mods.curse.com/addons/wow/gnomesequencer-enhanced")
		self.editBox:HighlightText()
		ChatEdit_FocusActiveWindow();
	end,
	OnHide = function(self)
		self.editBox:Width(self.editBox.width or 50)
		self.editBox.width = nil
	end,
	hideOnEscape = 1,
	button1 = OKAY,
	EditBoxOnEnterPressed = function(self)
		ChatEdit_FocusActiveWindow();
		self:GetParent():Hide();
	end,
	EditBoxOnEscapePressed = function(self)
		ChatEdit_FocusActiveWindow();
		self:GetParent():Hide();
	end,
	EditBoxOnTextChanged = function(self)
		if(self:GetText() ~= "https://mods.curse.com/addons/wow/gnomesequencer-enhanced") then
			self:SetText("https://mods.curse.com/addons/wow/gnomesequencer-enhanced")
		end
		self:HighlightText()
		self:ClearFocus()
		ChatEdit_FocusActiveWindow();
	end,
	OnEditFocusGained = function(self)
		self:HighlightText()
	end,
	showAlert = 1,
}

local function GSSendMessage(tab, channel, target)
  local _, instanceType = IsInInstance()
	local transmission = GSEncodeMessage(tab)
	GSPrintDebugMessage(transmission, GNOME)
	if GSisEmpty(channel) then
		if IsInRaid() then
			channel = (not IsInRaid(LE_PARTY_CATEGORY_HOME) and IsInRaid(LE_PARTY_CATEGORY_INSTANCE)) and "INSTANCE_CHAT" or "RAID"
		else
		  channel = (not IsInGroup(LE_PARTY_CATEGORY_HOME) and IsInGroup(LE_PARTY_CATEGORY_INSTANCE)) and "INSTANCE_CHAT" or "PARTY"
		end
  end
	GSSE:SendCommMessage(GSStaticPrefix, transmission, channel, target)

end

local function performVersionCheck(version)
	if(tonumber(version) ~= nil and tonumber(version) > tonumber(GSEVersion)) then
		if not GSold then
		  GSPrint(L["GS-E is out of date. You can download the newest version from https://mods.curse.com/addons/wow/gnomesequencer-enhanced."], GSStaticSourceTransmission)
		  GSold = true
		  if((tonumber(message) - tonumber(version)) >= 0.05) then
			  StaticPopup_Show('GSE_UPDATE_AVAILABLE')
		  end
		end
	end
end

function GSEncodeMessage(Sequence)
  --clean sequence
  eSequence = GSTRUnEscapeSequence(Sequence)
  --remove version and source
  eSequence.version = nil
  eSequence.source = GSStaticSourceTransmission
  eSequence.authorversion = nil


  local one = libS:Serialize(eSequence)
  local two = libC:CompressHuffman(one)
  local final = libCE:Encode(two)
  return final
end

function GSDecodeMessage(data)
  -- Decode the compressed data
  local one = libCE:Decode(data)

  --Decompress the decoded data
  local two, message = libC:Decompress(one)
  if(not two) then
  	GSPrintDebugMessage ("YourAddon: error decompressing: " .. message, "GS-Transmission")
  	return
  end

  -- Deserialize the decompressed data
  local success, final = libS:Deserialize(two)
  if (not success) then
  	GSPrintDebugMessage ("YourAddon: error deserializing " .. final, "GS-Transmission")
  	return
  end

  GSPrintDebugMessage ("Data Finalised", "GS-Transmission")
  return success, final
end

function GSTransmitSequence(SequenceName, channel, target)
  local t = {}
	t.Command = "GS-E_TRANSMITSEQUENCE"
	t.SequenceName = SequenceName
	t.Sequence = GSMasterOptions.SequenceLibrary[SequenceName][GSGetActiveSequenceVersion(SequenceName)]
	GSSendMessage(t, channel, target)
end

local function ReceiveSequence(SequenceName, Sequence, sender)
  local version = GSGetNextSequenceVersion(SequenceName)
	Sequence.version = version
	Sequence.source = GSStaticSourceTransmission
	GSAddSequenceToCollection(SequenceName, Sequence, version)
	GSPrint(L["Received Sequence "] .. SequenceName .. L[" from "] .. sender ..  L[" saved as version "] .. version)
end


function GSSE:OnCommReceived(prefix, message, distribution, sender)
  GSPrintDebugMessage("GSSE:onCommReceived", GNOME)
  GSPrintDebugMessage(prefix .. " " .. message .. " " .. distribution .. " " .. sender, GNOME)
  local success, t = GSDecodeMessage(message)
  if success then
		if t.Command == "GS-E_VERSIONCHK" then
	    if not GSold then
				performVersionCheck(t.Version)
			end
	  elseif t.Command == "GS-E_TRANSMITSEQUENCE" then
			if sender ~= GetUnitName("player", true) then
        ReceiveSequence(t.SequenceName, t.Sequence, sender)
			else
        GSPrintDebugMessage("Ignoring Sequence from me.", GNOME)
			end
    end
	end
end


local function sendVersionCheck()
  if not GSold then
		local _, instanceType = IsInInstance()
	  local t = {}
	  t.Command = "GS-E_VERSIONCHK"
	  t.Version = GSEVersion
	  GSSendMessage(t)
	end
end

function GSSE:GROUP_ROSTER_UPDATE(...)
	sendVersionCheck()
end


GSSE:RegisterComm("GS-E")
GSSE:RegisterEvent("GROUP_ROSTER_UPDATE")


function dataobj:OnEnter()

end

function dataobj:OnLeave()

end

function dataobj:OnTooltipShow()
	self:AddLine(L["GS-E: Left Click to open the Sequence Editor"])
	self:AddLine(L["GS-E: Right Click to open the Sequence Debugger"])
end

function dataobj:OnClick(button)
	if button == "LeftButton" then
    GSGuiShowViewer()
	elseif button == "MiddleButton" then
    GSShowTransmissionGui()
	elseif button == "RightButton" then
    GSDebugFrame:Show()
	end
end

local transSequencevalue = ""

local tranmissionFrame = AceGUI:Create("Frame")
tranmissionFrame:SetTitle(L["Send To"])
tranmissionFrame:SetCallback("OnClose", function(widget) tranmissionFrame:Hide() end)
tranmissionFrame:SetLayout("List")
tranmissionFrame:SetWidth(290)
tranmissionFrame:SetHeight(190)
tranmissionFrame:Hide()

local SequenceListbox = AceGUI:Create("Dropdown")
SequenceListbox:SetLabel(L["Load Sequence"])
SequenceListbox:SetWidth(250)
SequenceListbox:SetCallback("OnValueChanged", function (obj,event,key) transSequencevalue = key end)
tranmissionFrame:AddChild(SequenceListbox)

local playereditbox = AceGUI:Create("EditBoxExampleAll")
playereditbox:SetLabel(L["Send To"])
playereditbox:SetWidth(250)
playereditbox:DisableButton(true)
tranmissionFrame:AddChild(playereditbox)

local sendbutton = AceGUI:Create("Button")
sendbutton:SetText(L["Send"])
sendbutton:SetWidth(250)
sendbutton:SetCallback("OnClick", function() GSTransmitSequence(transSequencevalue, "WHISPER", playereditbox:GetText()) end)
tranmissionFrame:AddChild(sendbutton)

GSSE.transmissionframe = tranmissionFrame

function GSShowTransmissionGui(SequenceName)
  if GSSE.viewframe:IsVisible() then
    local point, relativeTo, relativePoint, xOfs, yOfs = GSSE.viewframe:GetPoint()
	--	GSSE.transmissionframe:SetPoint("CENTRE" , (left/2)+(width/2), bottom )
		GSSE.transmissionframe:SetPoint(point, xOfs + 500, yOfs + 155)

	end
	if GSSE.editframe:IsVisible() then
		local point, relativeTo, relativePoint, xOfs, yOfs = GSSE.editframe:GetPoint()
	--	GSSE.transmissionframe:SetPoint("CENTRE" , (left/2)+(width/2), bottom )
		GSSE.transmissionframe:SetPoint(point, xOfs + 500, yOfs + 155)

	end

	local names = GSSE:getSequenceNames()
	SequenceListbox:SetList(names)
  if not GSisEmpty(SequenceName) then
		SequenceListbox:SetValue(SequenceName)
		transSequencevalue = SequenceName
	end
	tranmissionFrame:Show()
end
