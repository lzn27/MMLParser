MMLParser = class("MMLParser", MVCView)
local M = MMLParser
local NOTE_TO_NUMBER = {
    ["c"] = 1,
    ["d"] = 2,
    ["e"] = 3,
    ["f"] = 4,
    ["g"] = 5,
    ["a"] = 6,
    ["b"] = 7,
}

local LONG_NOTE_LENGTH = 1
local INSTRUMENT = 0

local MML_EXAMPLE = "t130o3b8b8b16a16r16b16r16o4d16r16o3b16r16f+16a8b8b8b16a16r16b16r16o4f16r16e16r16d16o3a8t130o3b8b8b16a16r16b16r16o4d16r16o3b16r16f+16a8b8b8b16a16r16b16r16o4f16r16e16r16d16o3a8b8b8b16a16r16b16r16o4d16r16o3b16r16f+16a8b8b8b8a16b16r2o5f+4.d4.r8d16e16f8.e8.d8c+8.d8.e8f+4.b4.o4b8o5c+8d8.e8.d8c+8.a8.g8f+4.:o4b4o5f4.:o4b4r8o5d16e16c+8.:f8e8.d8o4o5c+8.:o4a+8o5d8.e8f+4.:o4b4o5f4.:b4b8o6c+8o5b8.:o6d8e8.o5g8f+8.o6d8.e8o5f+4.:o4b4b4.:o5f4r8d16e16f8.:o4b8o5e8.d8o4g8.:o5c+8d8.e8o4b4.:o5f+4c+4.:b4o4b8o5c+8d8.e8.d8c+8.a8.g8f+4.:o4b4b4.:o5f4r8d16e16d4.:f+4f4.:b4o4b8o5c+8d8.g8.f+8f8.o6d8.o5a+8b4"

M.timeEvents = {
    {
        name = "PlayNoteTimer_old",
        interval = 0,
        callback = function(self)
            if self.Play_old then
                if self.Index_old < #self.result then
                    if self.NoteTime_old < self.result[self.Index_old].second then
                        if self.NoteTime_old == 0 then
                            if self.result[self.Index_old].second < LONG_NOTE_LENGTH then --当成短音
                                for i=1, #self.result[self.Index_old].note do
                                    MusicalModel:PlayToneSound(self.result[self.Index_old].note[i], INS.MainPlayer.gameObject, INSTRUMENT, false, 0)
                                end
                            else--当成长音
                                for i=1, #self.result[self.Index_old].note do
                                    MusicalModel:PlayToneSound(self.result[self.Index_old].note[i], INS.MainPlayer.gameObject, INSTRUMENT, false, 1)
                                end
                            end
                        end
                        self.NoteTime_old = self.NoteTime_old + CS.UnityEngine.Time.deltaTime
                    else
                        if self.result[self.Index_old].second >= LONG_NOTE_LENGTH then --如果是长音。那么停止这个音
                            for i=1, #self.result[self.Index_old].note do
                                MusicalModel:StopToneSound(self.result[self.Index_old].note[i], INS.MainPlayer.gameObject, INSTRUMENT, false, 1)
                            end
                        end
                        self.Index_old = self.Index_old +1
                        self.NoteTime_old = 0
                    end
                else
                    self.Play_old = false
                end
            end
        end
    },
}

M.children = {
    {
        name = "CloseBtn",
        type = "Button",
        onClick = function(self)
            UI.ClosePanel(self.mono)
        end
    },
    {
        name = "InputField",
        type = "QSTMPInputField",
    },
    {
        name = "GuZhengBtn",
        type = "Button",
        onClick = function(self)
            local mml = self.InputField.text
            self:ParseMML(mml)
            local txt = ""
            for i=1, #self.result do
                local item= self.result[i]
                local notes = table.concat(item.note,",")
                notes=notes.." "..tostring(item.second).."秒".."    "
                txt = txt..notes
            end
            self.OutPut.text = txt
            INSTRUMENT = 1
            self:Play_OldSystem()
        end
    },
    {
        name = "ZhuDiBtn",
        type = "Button",
        onClick = function(self)
            local mml = self.InputField.text
            self:ParseMML(mml)
            local txt = ""
            for i=1, #self.result do
                local item= self.result[i]
                local notes = table.concat(item.note,",")
                notes=notes.." "..tostring(item.second).."秒".."    "
                txt = txt..notes
            end
            self.OutPut.text = txt
            INSTRUMENT = 0
            self:Play_OldSystem()
        end
    },
    {
        name = "OutPut",
        type = "Text",
    }

}

function M:awake()
    self.result = {}
    self.OCTAVE, self.TEMPO, self.VOLUME, self.LENGTH, self.METRE = 4, 60, 12, 4, "44"
end

function M:init()
    self.InputField:SetBaseOnValidateInput()
    self.InputField.text = MML_EXAMPLE
end

function M:ProcessNote(n, offset, length, halfDot)
    if offset == "#" then
        offset = "+"
    end
    if n == "r" or n == "p" then
        n = "r"
    else
        n = offset .. n .. self.OCTAVE
    end
    local beats = tonumber(string.sub(self.METRE, 1, 1)) / (tonumber(length) or self.LENGTH)
    if type(halfDot) == "string" and string.len(halfDot) > 0 then
        beats = beats + beats / 2
    end
    local second = 60 / self.TEMPO * beats
    return n, second, self.VOLUME
end

function M:ProcessOctaveChange(octave)
    local add = 0
    for i = 1, string.len(octave) do
        if string.sub(octave, i, i) == "<" then
            add = add - 1
        end
        if string.sub(octave, i, i) == ">" then
            add = add + 1
        end
    end
    self.OCTAVE = self.OCTAVE + add
end

function M:ProcessTVOLM(tvolm)
    --TODO:--增加错误校验
    local prefix = string.sub(tvolm, 1, 1)
    if prefix == "t" then
        --增加校验
        self.TEMPO = tonumber(string.sub(tvolm, 2))
    elseif prefix == "v" then
        --增加校验
        self.VOLUME = tonumber(string.sub(tvolm, 2))
    elseif prefix == "o" then
        --增加校验
        local octave = tonumber(string.sub(tvolm, 2))
        if octave > 0 and octave < 9 then
            self.OCTAVE = octave
        end
    elseif prefix == "l" then
        --增加校验
        self.LENGTH = tonumber(string.sub(tvolm, 2))
    elseif prefix == "m" then
        --增加校验
        if string.sub(tvolm, 2, 2) == "4" or string.sub(tvolm, 2, 2) == "8" then
            --目前仅支持以4分音符或8分音符为一拍
            self.METRE = string.sub(tvolm, 2)
        end
    end
end

function M:ParseMML(mml)
    self.result = {}

    local NOTE_PATTERN = "([a-grp])([#,+,-]?)([%d]*)([%.]?)"
    local OctaveChange_PATTERN = "[<, >]+"
    local TVOLM_PATTERN = "[t,v,o,l,m][%d]+"
    local BarLine_Blank_PATTEN = "[\r,\n,%s,|]+"

    mml = string.lower(string.gsub(mml, BarLine_Blank_PATTEN, ""))
    local note_B, note_E, noteOriginal, offset, length, dotted = string.find(mml, NOTE_PATTERN, 1)
    local octave_B, octave_E = string.find(mml, OctaveChange_PATTERN, 1)
    local tvol_B, tvol_E = string.find(mml, TVOLM_PATTERN, 1)
    local trickBox = {
        ["note"] = { B = note_B, E = note_E, func = self.ProcessNote, pattern = NOTE_PATTERN },
        ["octave"] = { B = octave_B, E = octave_E, func = self.ProcessOctaveChange, pattern = OctaveChange_PATTERN },
        ["tvol"] = { B = tvol_B, E = tvol_E, func = self.ProcessTVOLM, pattern = TVOLM_PATTERN },
    }
    local IsTrickBoxOK = function(box)
        if not box.note.B then
            print("The End")
            return false
        end
        return true
    end

    local MMLLen = string.len(mml)
    if not note_E then
        return
    end
    local lastNoteEnd = note_E + 1
    while IsTrickBoxOK(trickBox) do
        local minItem = { B = MMLLen + 1 }
        for _, item in pairs(trickBox) do
            if item and item.B and item.B < minItem.B then
                minItem = item
            end
        end
        local word = string.sub(mml, minItem.B, minItem.E)
        if minItem.pattern == OctaveChange_PATTERN or minItem.pattern == TVOLM_PATTERN then
            minItem.func(self, word)
            minItem.B, minItem.E = string.find(mml, minItem.pattern, minItem.E + 1)
        elseif minItem.pattern == NOTE_PATTERN then
            local note, sec, vol = minItem.func(self, noteOriginal, offset, length, dotted)
            local note_Interval_Str = string.sub(mml, lastNoteEnd, minItem.B)
            local note_link_symbol = string.match(note_Interval_Str, "[:,&]")
            if note_link_symbol == ":" and #self.result > 0 then
                --chords和弦
                table.insert(self.result[#self.result].note, note)
            elseif note_link_symbol == "&" and #self.result > 0 then
                --legato连音
                if not (#self.result[#self.result].note > 1) then
                    --上一个音不是和弦
                    self.result[#self.result].second = self.result[#self.result].second + sec
                end
            else
                --新的音符
                table.insert(self.result, { note = { note }, second = sec, volume = vol })
            end
            lastNoteEnd = minItem.E + 1
            minItem.B, minItem.E, noteOriginal, offset, length, dotted = string.find(mml, minItem.pattern, minItem.E + 1)
        end
    end
end

function M:ConvertResultT_oOldSystemType()
    for i =1 ,#self.result do
        local notes = {}
        for j=1, #self.result[i].note do
            local cate = tonumber(string.match(self.result[i].note[j],"[%d]") or 0)
            cate = cate - 1
            if cate<1 then
                cate = 1
            end
            if cate>3 then
                cate = 3
            end
            local n = string.match(self.result[i].note[j],"[a-gr]")
            if not n then
                break
            end
            if n~="r" then
                local tbID = cate * 100 + NOTE_TO_NUMBER[n]
                table.insert(notes, tbID)
            end
        end
        self.result[i].note = notes
    end
end

function M:Play_OldSystem()
    self:ConvertResultT_oOldSystemType()
    self.Index_old=1
    self.NoteTime_old=0
    self.Play_old = true
end