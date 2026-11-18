-- Standalone tests follow the exact .toc order with the same addon namespace
-- that WoW passes to each Lua file. A missing/reordered module fails here.
return function()
    local namespace = {}
    local toc = assert(io.open("QuestItemTracker/QuestItemTracker.toc", "r"))
    local count = 0
    local last
    for line in toc:lines() do
        local path = line:match("^%s*(.-)%s*$")
        if path:match("%.lua$") then
            local filename = "QuestItemTracker/" .. path:gsub("\\", "/")
            assert(loadfile(filename), "Cannot load TOC Lua module: " .. filename)
                ("QuestItemTracker", namespace)
            count = count + 1
            last = path
        end
    end
    toc:close()
    assert(count >= 10 and last == "QuestItemTracker.lua",
        "Modules must load before QuestItemTracker.lua bootstrap")
    return namespace
end
