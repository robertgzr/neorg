--[[
    File: GTD-helpers
    Title: GTD Helpers module
    Summary: Nice helpers for GTD modules.
    Show: false.
    ---

This module is a set of public functions designed to ease GTD development.
--]]
require("neorg.modules.base")

local module = neorg.modules.create("core.gtd.helpers")

module.setup = function()
    return {
        success = true,
        requires = {
            "core.norg.dirman",
        },
    }
end

---@class core.gtd.helpers
module.public = {
    version = "0.0.9",

    --- Returns the list of every used file for GTD
    get_gtd_files = function(opts)
        opts = opts or {}
        local gtd_config = module.private.get_gtd_config()

        local ws = gtd_config.workspace
        local files = module.required["core.norg.dirman"].get_norg_files(ws)

        if vim.tbl_isempty(files) then
            log.error("No files found in " .. ws .. " workspace")
            log.error([[
            Please add at minima a index.norg file.
            ]])
            return
        end

        if opts.no_exclude then
            return files
        end

        local excluded_files = module.public.get_gtd_excluded_files()
        for _, excluded_file in pairs(excluded_files) do
            files = module.private.remove_from_table(files, excluded_file)
        end

        return files
    end,

    --- Returns the list of every excluded file in gtd
    --- @return table
    get_gtd_excluded_files = function()
        local gtd_config = module.private.get_gtd_config()
        local res = vim.deepcopy(gtd_config.exclude) or {}

        return res
    end,

    --- Checks if the data is processed or not.
    --- Check out :h neorg-gtd to know what is an unclarified task or project
    --- @param data core.gtd.queries.task|core.gtd.queries.project
    --- @param tasks core.gtd.queries.task[]?
    is_processed = function(data, tasks)
        return neorg.lib.match({
            data.type,
            ["task"] = function()
                return (
                        (
                            type(data.contexts) == "table" and not vim.tbl_isempty(data.contexts)
                            or (type(data["waiting.for"]) == "table" and not vim.tbl_isempty(data["waiting.for"]))
                        ) and not data.inbox
                    )
                    or (type(data["time.due"]) == "table" and not vim.tbl_isempty(data["time.due"]))
                    or (type(data["time.start"]) == "table" and not vim.tbl_isempty(data["time.start"]))
            end,
            ["project"] = function()
                if not tasks then
                    return
                end

                -- If the project is in someday, do not count it as unprocessed
                if
                    type(data.contexts) == "table"
                    and not vim.tbl_isempty(data.contexts)
                    and vim.tbl_contains(data.contexts, "someday")
                then
                    return true
                end

                -- All projects in inbox are unprocessed
                if data.inbox then
                    return false
                end

                local project_tasks = vim.tbl_filter(function(t)
                    return t.project_uuid == data.uuid
                end, tasks)

                -- Empty projects (without tasks) are unprocessed
                if vim.tbl_isempty(project_tasks) then
                    return false
                end

                -- Do not count done tasks for unprocessed projects
                project_tasks = vim.tbl_filter(function(t)
                    return t.state ~= "done"
                end, project_tasks)

                return not vim.tbl_isempty(project_tasks)
            end,
        })
    end,
}

module.private = {
    --- Convenience wrapper to set type for gtd_config
    --- @return core.gtd.base.config
    get_gtd_config = function()
        return neorg.modules.get_module_config("core.gtd.base")
    end,

    --- Remove `el` from table `t`
    --- @param t table
    --- @param el any
    --- @return table
    remove_from_table = function(t, el)
        vim.validate({ t = { t, "table" } })
        local result = {}

        -- This is possibly a directory, so we remove every file inside this directory
        if not vim.endswith(el, ".norg") then
            for _, v in ipairs(t) do
                if not vim.startswith(v, el) then
                    table.insert(result, v)
                end
            end
        else
            for _, v in ipairs(t) do
                if v ~= el then
                    table.insert(result, v)
                end
            end
        end

        return result
    end,
}

return module
