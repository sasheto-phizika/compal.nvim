local M = {}
M.cmd = {
        c = { normal = {cd = "cd %g;", cmd = "make"}, interactive = { repl = nil, title = "", cmd = "", in_shell = false}},
        rust = { normal = {cd = "cd %g;", cmd = "cargo run"}, interactive = { repl = nil, title = "", cmd = "", in_shell = false}},
        cpp = { normal = {cd = "cd %g;", cmd = "make"}, interactive = { repl = nil, title = "", cmd = "", in_shell = false}},
        julia = { normal = {cd = "", cmd = "julia %f"}, interactive = { repl = "julia", title = "julia", cmd = 'include("%f")', in_shell = false}},
        python = { normal = {cd = "", cmd = "python %f"}, interactive = { repl = "ipython", title = "python", cmd = "%run %f", in_shell = nil}},
        sh = { normal = {cd = "", cmd = "bash %f"}, interactive = { repl = nil, title = "", cmd = "", in_shell = false}},
        cs = { normal = {cd = "cd %g;", cmd = "dotnet run"}, interactive = { repl = nil, title = "", cmd = "", in_shell = false}},
        php = { normal = {cd = "", cmd = "php %f"}, interactive = { repl = nil, title = "", cmd = "", in_shell = false}},
        haskell = { normal = {cd = "cd %g", cmd = "cabal run"}, interactive = { repl = "ghci", title = "ghc", cmd = ":l %f", in_shell = false}},
        lua = { normal = {cd = "", cmd = "lua %f"}, interactive = { repl = "lua", title = "lua", cmd = "dofile(\"%f\")", in_shell = true}},
        java = { normal = {cd = "", cmd = "javac %f"}, interactive = { repl = nil, title = "", cmd = "", in_shell = false}},
        javascript = { normal = {cd = "", cmd = "node %f"}, interactive = { repl = nil, title = "", cmd = "", in_shell = false}},
        ruby = { normal = {cd = "", cmd = "ruby %f"}, interactive = { repl = "irb", title = "irb", cmd = 'require "%f"', in_shell = false}},
        tex = { normal = {cd = "", cmd = "pdflatex %f"}, interactive = { repl = nil, title = "", cmd = "", in_shell = false}},
        kotlin = { normal = {cd = "", cmd = "kotlinc %f"}, interactive = { repl = nil, title = "", cmd = "", in_shell = false}},
        zig = { normal = {cd = "cd %g;", cmd = "zig build run"}, interactive = { repl = nil, title = "", cmd = "", in_shell = false}},
        typescript = { normal = {cd = "", cmd = "npx tsc %f"}, interactive = { repl = nil, title = "", cmd = "", in_shell = false}},
        elixir = { normal = {cd = "cd %g;", cmd = "mix compile"}, interactive = { repl = "iex -S mix", title = "beam.smp", cmd = "recompile()", in_shell = false}},
        ocaml = { normal = {cd = "cd %g;", cmd = "dune build;dune exec $(basename %g)"}, interactive = {repl = "dune utop", title = "utop", cmd = "", in_shell = true}},
        clojure = { normal = {cd = "", cmd = "clj -M %f"}, interactive = { repl = "clj", title = "rlwrap", cmd = '(load-file "%f")', in_shell = false}},
        go = { normal = {cd = "cd %g;", cmd = "go run ."}, interactive = { repl = nil, title = "", cmd = "", in_shell = false}},
        dart = { normal = {cd = "cd %g;", cmd = "dart run"}, interactive = { repl = nil, title = "", cmd = "", in_shell = false}},
    split = "tmux split -v",
    save = true,
    focus_shell = true,
    focus_repl = true,
    override_shell = true
}

local function parse_wildcards(str)
    local parsed_command = str:gsub("%%f", vim.fn.expand("%:p")):gsub("%%s", vim.fn.expand("%:p:r")):gsub("%%h", vim.fn.expand("%:p:h"))
    local git_root = vim.fn.system("git rev-parse --show-toplevel"):sub(0, -2)

    if git_root:gmatch("fatal:")() == nil then
        parsed_command = parsed_command:gsub("%%g", git_root)
    else
        if parsed_command:gmatch("%%g")() then
            error("File is not in a git repository but '%g' was used in the command!!")
        end
    end

    return parsed_command
end

M.compile_vim = function(args)
    args = args or ""

    if M.cmd.save then
        vim.cmd("w")
    end

   vim.cmd("!" .. parse_wildcards(M.cmd[vim.bo.filetype].normal.cd .. M.cmd[vim.bo.filetype].normal.cmd) .. args)
end

M.compile_normal = function(args)
    args = args or ""

    if M.cmd.save then
        vim.cmd("w")
    end

    if os.getenv("TMUX") then
        local ft = vim.bo.filetype
        local sh_pane = vim.fn.system("tmux list-panes -F '#{pane_index} #{pane_current_command}' | grep sh")
        local pane_index

        if sh_pane == "" then
            pane_index = tonumber(vim.fn.system("tmux display-message -p '#{pane_index}'")) + 1
            vim.fn.system(M.cmd.split)
        else
            pane_index = sh_pane:gmatch("%w+")()
            vim.fn.system("tmux select-pane -t " .. pane_index)
        end

        vim.fn.system(string.format("tmux send-keys C-z C-u '%s' Enter", parse_wildcards(M.cmd[ft].normal.cd .. M.cmd[ft].normal.cmd) .. args))

        if M.cmd.focus_shell == false then
            vim.fn.system("tmux select-pane -t " .. tonumber(pane_index) - 1)
    	end
    end
end

local function handle_interactive_split(ft)
    if M.cmd[ft].interactive.in_shell then
        vim.fn.system(M.cmd.split)
        vim.fn.system(string.format("tmux send-key '%s' Enter" , M.cmd[ft].interactive.repl))
    else
        vim.fn.system(M.cmd.split .. " " .. M.cmd[ft].interactive.repl)
    end
end

M.compile_interactive = function(args)
    args = args or ""

    if M.cmd.save then
        vim.cmd("w")
    end

    if os.getenv("TMUX") then
        local ft = vim.bo.filetype
        local repl_pane = vim.fn.system("tmux list-panes -F '#{pane_index} #{pane_current_command}' | grep " .. M.cmd[ft].interactive.title)
        local pane_index

        if repl_pane ~= "" then
            pane_index = repl_pane:gmatch("%w+")()
            vim.fn.system("tmux select-pane -t " .. pane_index)
        else
            if M.cmd.override_shell then
                local sh_pane = vim.fn.system("tmux list-panes -F '#{pane_index} #{pane_current_command}' | grep sh")

                if sh_pane ~= "" then
                    pane_index = sh_pane:gmatch("%w+")()
                    vim.fn.system("tmux select-pane -t " .. pane_index)
                    vim.fn.system(string.format("tmux send-keys C-z C-u '%s' Enter", M.cmd[ft].interactive.repl))
                else
                    pane_index = tonumber(vim.fn.system("tmux display-message -p '#{pane_index}'")) + 1
                    handle_interactive_split(ft)
                end
            else
                pane_index = tonumber(vim.fn.system("tmux display-message -p '#{pane_index}'")) + 1
                handle_interactive_split(ft)
            end
        end

        vim.fn.system(string.format("tmux send-keys C-u '%s' Enter", parse_wildcards(M.cmd[ft].interactive.cmd) .. args))

        if M.cmd.focus_repl == false then
            vim.fn.system("tmux select-pane -t" .. tonumber(pane_index) - 1)
    	end
    end
end

M.compile_smart = function(args)
    if os.getenv("TMUX") then
        if M.cmd[vim.bo.filetype].interactive.repl then
            M.compile_interactive(args)
        else
            M.compile_normal(args)
        end
    else
        M.compile_vim(args)
    end
end

M.setup = function(opts)
    if opts then M.cmd = vim.tbl_deep_extend("force", M.cmd, opts) end

    local function concat_args(argv)
        local res = " "
        for i=2,#argv do
            res = res .. argv[i] .. " "
        end
        return res
    end

    vim.api.nvim_create_user_command("Compal", function(opt)
        M["compile_" .. opt.fargs[1]](concat_args(opt.fargs))
    end,
        {nargs = "*",
        complete = function()
      return { "smart", "interactive", "vim", "normal" }
    end,
    })

    return M
end

return M
