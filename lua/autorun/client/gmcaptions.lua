-- fun fact: like 99% of this is from my MWII HUD which is GPL, but I wrote all of this stuff myself so
-- I can relicense it as I bloody please

local enable = CreateClientConVar("funnycaptions_enable", 1, true, false, "enable said funne captions")
local debugparsing = CreateClientConVar("funnycaptions_debugparse", 1, true, false, "enable dev debug parse text")
local showsfx = CreateClientConVar("funnycaptions_showsfx", 1, true, false, "show sfx in captions, requires setting Settings > Audio > Close Captions to Close Captions")

local expcaptionout = expcaptionout or {}

local lineadjust = lineadjust or 0
local totallines = 0

surface.CreateFont("CustomCaptionRenderFont", {
    font = "Roboto", -- Use the font-name which is shown to you by your operating system Font Viewer.
    extended = true,
	size = 30 * (ScrH() / 1080),
	weight = 300,
	antialias = true,
	shadow = false,
	additive = false,
	outline = true,
})

local function ParseCaption(soundscript, duration, fromplayer, text)
    -- beware: might induce sleep loss and insanity
    local outtable = {}
    local counter = 0
    local color = color_white
    
    if text != nil and enable:GetBool() then
        if GetConVar("developer"):GetBool() and debugparsing:GetBool() then 
            text = "<clr:128,255,127>HELLO THERE<clr:126,217,255>COLOR SWITCH<clr:255,255,255>really stupid long line why am I trying to fabricate a stupid long line what the hell is wrong with me why do I need such a long line, why do I still need a much longer line what is wrong with glua today" --forces line break on 16:9 too
        end

        if !string.match(text, "<.->") then
            outtable[1] = {text, color}
        else
            actualtext = string.Explode("<", text, false)
            for i=1,#actualtext do
                if string.StartsWith(actualtext[i], "clr:") then
                    local colorstr = string.Explode(">",string.Replace(actualtext[i], "clr:", ""))[1]
                    local outtext = string.Replace(actualtext[i], "clr:"..colorstr..">", "")
                    color = string.Explode(",", colorstr, false)
                    color = Color(color[1], color[2], color[3], 255) -- this is stupid

                    outtable[i] = {outtext, color}
                elseif string.StartsWith(actualtext[i], "sfx>") and !showsfx:GetBool() then
                else
                    local outtext = string.Explode(">", actualtext[i], false)[2]
                    outtable[i] = {outtext, color}
                end
            end
        end

        for i = #outtable, 1, -1 do
            if !outtable[i][1] then
                table.remove(outtable, i)
            end
        end

        -- now we parse (it was running EVERY FRAME previously lmfao)
        if #outtable == 1 then
            local drawtxt = ""
            local drawtbl = {}
            local texttbl = string.Explode(" ", outtable[1][1], false)
            surface.SetFont("CustomCaptionRenderFont")

            for f=1,#texttbl do
                if !texttbl[f] then
                elseif string.StartsWith(texttbl[f], "<cr>") then
                    drawtbl[#drawtbl + 1] = drawtxt
                    drawtxt = string.Right(texttbl[f], 3)
                elseif select(1, surface.GetTextSize(drawtxt .. (drawtxt == "" and "" or " ") .. texttbl[f])) < ScrW() * 0.65 then
                    drawtxt = drawtxt .. (drawtxt == "" and "" or " ") .. texttbl[f]
                    if f == #texttbl then
                        drawtbl[#drawtbl + 1] = drawtxt
                    end
                else
                    drawtbl[#drawtbl + 1] = drawtxt
                    drawtxt = texttbl[f]
                    if f == #texttbl then
                        drawtbl[#drawtbl + 1] = drawtxt
                    end
                end
            end

            expcaptionout[#expcaptionout + 1] = {drawtbl, CurTime() + duration, CurTime(), outtable[1][2] or color_white}
        else
            local drawtbl = {}
            drawtbl[1] = {} -- thanks lua
            local drawtbli = 1
            local teststringlen = 0
            surface.SetFont("CustomCaptionRenderFont")

            for e=1,#outtable do
                local texttbl = string.Explode(" ", outtable[e][1], false)
                local teststring = ""

                -- surface.GetTextSize() isn't cooperating with select() here so wasted memory :sadge:
                for f=1,#texttbl do
                    if string.StartsWith(texttbl[f], "<cr>") then -- force a line break
                        drawtbl[drawtbli][#drawtbl[drawtbli] + 1] = {teststring, outtable[e][2], surface.GetTextSize(teststring)}
                        teststring = string.Right(texttbl[f], string.len(texttbl[f]) - 4)
                        teststringlen = 0
                        drawtbl[#drawtbl + 1] = {}
                        drawtbli = #drawtbl
                    elseif (select(1, surface.GetTextSize(teststring .. (teststring == "" and "" or " ") .. texttbl[f])) + teststringlen) < ScrW() * 0.65 then
                        teststring = teststring .. (teststring == "" and "" or " ") .. texttbl[f]
                        if f == #texttbl then
                            teststringlen = teststringlen + select(1, surface.GetTextSize(teststring))
                            drawtbl[drawtbli][#drawtbl[drawtbli] + 1] = {teststring, outtable[e][2], surface.GetTextSize(teststring)}    
                        end
                    else
                        drawtbl[drawtbli][#drawtbl[drawtbli] + 1] = {teststring, outtable[e][2], surface.GetTextSize(teststring)}
                        drawtbl[#drawtbl + 1] = {}
                        drawtbli = #drawtbl
                        teststring = texttbl[f]
                        teststringlen = 0
                        if f == #texttbl then
                            teststringlen = 0
                            drawtbl[drawtbli][#drawtbl[drawtbli] + 1] = {teststring, outtable[e][2], surface.GetTextSize(teststring)}    
                        end
                    end
                end
            end
            
            expcaptionout[#expcaptionout + 1] = {drawtbl, CurTime() + duration, CurTime()}
        end
    end
end

local function DrawCaptions()
    surface.SetFont("CustomCaptionRenderFont")
    local h = select(2, surface.GetTextSize("TESTING"))
    if enable:GetBool() then
        local linecount = 0

        lineadjust = math.max(lineadjust - FrameTime() * 6, 0)

        -- DEPRECATED: Previous rendering implementation, PARSES ONCE EVERY FRAME
        --[[for i=1,#captiondata do
            if #captiondata[i][1] == 1 then
                local drawtxt = ""
                local drawtbl = {}
                local texttbl = string.Explode(" ", captiondata[i][1][1][1], false)

                for f=1,#texttbl do
                    if !texttbl[f] then
                    elseif string.StartsWith(texttbl[f], "<cr>") then
                        drawtbl[#drawtbl + 1] = drawtxt
                        drawtxt = string.Right(texttbl[f], 3)
                    elseif surface.GetTextSize(drawtxt .. (drawtxt == "" and "" or " ") .. texttbl[f]) < ScrW() * 0.6 then
                        drawtxt = drawtxt .. (drawtxt == "" and "" or " ") .. texttbl[f]
                        if f == #texttbl then
                            drawtbl[#drawtbl + 1] = drawtxt
                        end
                    else
                        drawtbl[#drawtbl + 1] = drawtxt
                        drawtxt = texttbl[f]
                    end
                end

                drawtxt = ""
                for f=1,#drawtbl do
                    drawtxt = drawtxt .. drawtbl[f] .. (#drawtbl >= 1 and "\n" or "")
                end
                draw.DrawText(drawtxt, "CustomCaptionRenderFont", ScrW() * 0.5, ScrH() * 0.75 + h * linecount, captiondata[i][1][1][2] or color_white, TEXT_ALIGN_CENTER)
                linecount = linecount + #drawtbl
            else
                local drawtbl = {}
                drawtbl[1] = {} -- thanks lua
                local drawtbli = 1
                local teststringlen = 0
                for e=1,#captiondata[i][1] do
                    surface.SetFont("CustomCaptionRenderFont")
                    local texttbl = string.Explode(" ", captiondata[i][1][e][1], false)
                    local teststring = ""

                    -- surface.GetTextSize() isn't cooperating with select() here so wasted memory :sadge:
                    for f=1,#texttbl do
                        if string.StartsWith(texttbl[f], "<cr>") then -- force a line break
                            drawtbl[drawtbli][#drawtbl[drawtbli] + 1] = {teststring, captiondata[i][1][e][2], surface.GetTextSize(teststring)}
                            teststring = string.Right(texttbl[f], string.len(texttbl[f]) - 4)
                            teststringlen = 0
                            drawtbl[#drawtbl + 1] = {}
                            drawtbli = #drawtbl
                        elseif (select(1, surface.GetTextSize(teststring .. (teststring == "" and "" or " ") .. texttbl[f])) + teststringlen) < ScrW() * 0.55 then
                            teststring = teststring .. (teststring == "" and "" or " ") .. texttbl[f]
                            if f == #texttbl then
                                teststringlen = teststringlen + select(1, surface.GetTextSize(teststring))
                                drawtbl[drawtbli][#drawtbl[drawtbli] + 1] = {teststring, captiondata[i][1][e][2], surface.GetTextSize(teststring)}    
                            end
                        else
                            drawtbl[drawtbli][#drawtbl[drawtbli] + 1] = {teststring, captiondata[i][1][e][2], surface.GetTextSize(teststring)}
                            teststring = texttbl[f]
                            teststringlen = 0
                            drawtbl[#drawtbl + 1] = {}
                            drawtbli = #drawtbl
                        end
                    end
                end
                
                for i=1,#drawtbl do
                    local linelen = 0
                    for e=1,#drawtbl[i] do
                        linelen = linelen + drawtbl[i][e][3]
                    end
                    surface.SetTextPos(ScrW() * 0.5 - linelen * 0.5, ScrH() * 0.75 + h * linecount)
                    for e=1,#drawtbl[i] do
                        surface.SetTextColor(drawtbl[i][e][2].r,drawtbl[i][e][2].g,drawtbl[i][e][2].b,255)
                        surface.DrawText(drawtbl[i][e][1])
                    end
                    linecount = linecount + 1
                end
            end
        end]]

        for i=1,#expcaptionout do
            if !expcaptionout[i][5] and #expcaptionout[i][1] >= 1 and totallines == 0 then
                totallines = totallines + #expcaptionout[i][1]
                lineadjust = lineadjust + #expcaptionout[i][1] - 1
                expcaptionout[i][5] = true
            elseif !expcaptionout[i][5] then
                totallines = totallines + #expcaptionout[i][1]
                lineadjust = lineadjust + #expcaptionout[i][1]
                expcaptionout[i][5] = true
            end
        end

        for i=1,#expcaptionout do
            if expcaptionout[i][4] then
                local drawtxt = ""
                for f=1,#expcaptionout[i][1] do
                    drawtxt = drawtxt .. expcaptionout[i][1][f] .. (f < #expcaptionout[i][1] and "\n" or "")
                end
                draw.DrawText(drawtxt, "CustomCaptionRenderFont", ScrW() * 0.5, ScrH() * 0.83 + h * linecount - h * totallines + h * lineadjust,
                    Color(expcaptionout[i][4].r,expcaptionout[i][4].g,expcaptionout[i][4].b,(math.min(CurTime() - expcaptionout[i][3], 1) - math.max(CurTime() - expcaptionout[i][2], 0)) * 1275)
                    or color_white, TEXT_ALIGN_CENTER)
                linecount = linecount + #expcaptionout[i][1]
            else
                for g=1,#expcaptionout[i][1] do
                    local linelen = 0
                    for e=1,#expcaptionout[i][1][g] do
                        linelen = linelen + expcaptionout[i][1][g][e][3]
                    end
                    surface.SetTextPos(ScrW() * 0.5 - linelen * 0.5, ScrH() * 0.83 + h * linecount - h * totallines + h * lineadjust)
                    for e=1,#expcaptionout[i][1][g] do
                        surface.SetTextColor(expcaptionout[i][1][g][e][2].r,expcaptionout[i][1][g][e][2].g,expcaptionout[i][1][g][e][2].b,(math.min(CurTime() - expcaptionout[i][3], 1) - math.max(CurTime() - expcaptionout[i][2], 0)) * 1275)
                        surface.DrawText(expcaptionout[i][1][g][e][1])
                    end
                    linecount = linecount + 1
                end
            end
        end

        -- DO NOT copy my nested if statements here
        if expcaptionout[1] then if expcaptionout[1][2] + 1 < CurTime() then
            --lineadjust = lineadjust + #expcaptionout[1][1]
            totallines = math.Approach(totallines, 0, #expcaptionout[1][1])
            table.remove(expcaptionout, 1)
        end end
    end
end

hook.Add("OnCloseCaptionEmit", "GMCaptionThingGrab", ParseCaption)
hook.Add("HUDPaint", "GMCaptionThingDraw", DrawCaptions)
hook.Add("HUDShouldDraw", "GMCaptionHideDefault", function(name) if name == "CHudCloseCaption" and enable:GetBool() then return false end end)
