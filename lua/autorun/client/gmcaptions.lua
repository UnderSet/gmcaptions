-- fun fact: like 99% of this is from my MWII HUD which is GPL, but I wrote all of this stuff myself so
-- I can relicense it as I bloody please

local enable = CreateClientConVar("funnycaptions_enable", 1, true, false, "enable said funne captions")
local debugparsing = CreateClientConVar("funnycaptions_debugparse", 1, true, false, "enable dev debug parse text")
local showsfx = CreateClientConVar("funnycaptions_showsfx", 1, true, false, "show sfx in captions, requires setting Settings > Audio > Close Captions to Close Captions")

local captiondata = {}

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
                elseif string.StartsWith(actualtext[i], "sfx>") and showsfx:GetBool() then return
                else
                    local outtext = string.Explode(">", actualtext[i], false)[2]
                    outtable[i] = {outtext, color}
                end
            end
        end

        for i = #outtable, 1, -1 do
            if outtable[i][1] == "" or !outtable[i][1] then
                table.remove(outtable, i)
            end
        end

        captiondata[#captiondata + 1] = {outtable, CurTime() + duration}
    end
end

function DrawCaptions()
    surface.SetFont("DermaLarge")
    local h = select(2, surface.GetTextSize("TESTING"))
    if enable:GetBool() then
        local linecount = 0
        for i=1,#captiondata do
            if #captiondata[i][1] == 1 then
                local drawtxt = ""
                local drawtbl = {}
                local texttbl = string.Explode(" ", captiondata[i][1][1][1], false)

                for f=1,#texttbl do
                    if select(1, surface.GetTextSize(drawtxt .. " " .. texttbl[f])) < ScrW() * 0.6 then
                        drawtxt = drawtxt .. " " .. texttbl[f]
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
                    drawtxt = drawtxt .. drawtbl[f] .. "\n"
                end
                draw.DrawText(drawtxt, "DermaLarge", ScrW() * 0.5, ScrH() * 0.75 + h * linecount, captiondata[i][1][1][2] or color_white, TEXT_ALIGN_CENTER)
                linecount = linecount + #drawtbl
            else
                local drawtbl = {}
                drawtbl[1] = {} -- thanks lua
                local drawtbli = 1
                for e=1,#captiondata[i][1] do
                    surface.SetFont("DermaLarge")
                    local texttbl = string.Explode(" ", captiondata[i][1][e][1], false)
                    local teststring = ""

                    -- surface.GetTextSize() isn't cooperating with select() here so wasted memory :sadge:
                    for f=1,#texttbl do
                        if surface.GetTextSize(teststring .. " " .. texttbl[f]) < ScrW() * 0.6 then
                            teststring = teststring .. " " .. texttbl[f]
                            if f == #texttbl then
                                drawtbl[drawtbli][#drawtbl[drawtbli] + 1] = {teststring, captiondata[i][1][e][2], surface.GetTextSize(teststring)}    
                            end
                        else
                            drawtbl[drawtbli][#drawtbl[drawtbli] + 1] = {teststring, captiondata[i][1][e][2], surface.GetTextSize(teststring)}
                            teststring = texttbl[f]
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
                end
                linecount = linecount + #drawtbl
            end
        end

        for i = #captiondata, 1, -1 do
            if captiondata[i][2] < CurTime() then table.remove(captiondata, i) end
        end
    end
end

hook.Add("OnCloseCaptionEmit", "GMCaptionThingGrab", ParseCaption)
hook.Add("HUDPaint", "GMCaptionThingDraw", DrawCaptions)
hook.Add("HUDShouldDraw", "GMCaptionHideDefault", function(name) if name == "CHudCloseCaption" and enable:GetBool() then return false end end)
