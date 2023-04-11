Config = {
  ensure_installed = {}
}

local image_name = "lsp-"..vim.fn.fnamemodify(vim.fn.getcwd(), ':t')

-- default command to run the lsp container
local default_cmd = function (runtime, workdir, image, network, docker_volume)
  if vim.loop.os_uname().sysname == "Windows_NT" then
    workdir = Dos2UnixSafePath(workdir)
  end

  local mnt_volume
  if docker_volume ~= nil then
    mnt_volume ="--volume="..docker_volume..":"..workdir..":z"
  else
    mnt_volume = "--volume="..workdir..":"..workdir..":z"
  end

  return {
    runtime,
    "container",
    "run",
    "--interactive",
    "--rm",
    "--network="..network,
    "--workdir="..workdir,
    mnt_volume,
    image
  }
end

local function command(server, user_opts)
  -- Start out with the default values:
  local opts =  {
    container_runtime = "docker",
    root_dir = vim.fn.getcwd(),
    cmd_builder = default_cmd,
    network = "none",
    image = image_name,
    docker_volume = nil,
  }

  -- If any opts were passed, those override the defaults:
  if user_opts ~= nil then
    opts = vim.tbl_extend("force", opts, user_opts)
  end

  if not opts.image then
    error(string.format("lspcontainers: no image specified for `%s`", server))
    return 1
  end

  return opts.cmd_builder(opts.container_runtime, opts.root_dir, opts.image, opts.network, opts.docker_volume)
end

Dos2UnixSafePath = function(workdir)
  workdir = string.gsub(workdir, ":", "")
  workdir = string.gsub(workdir, "\\", "/")
  workdir = "/" .. workdir
  return workdir
end

local function on_event(_, data, event)
  --if event == "stdout" or event == "stderr" then
  if event == "stdout" then
    if data then
      for _, v in pairs(data) do
        print(v)
      end
    end
  end
end


local function build_project_image()
  local container_runtime = "docker"
  local jobs = {}
  local job = vim.fn.jobstart(
    container_runtime.." build -f lsp.Dockerfile -t "..image_name..":latest .",
    {
      on_stderr = on_event,
      on_stdout = on_event,
      on_exit = on_event,
    }
  )
  table.insert(jobs, job)
  local job2 = vim.fn.jobstart(
    "ls -la",
    {
      on_stderr = on_event,
      on_stdout = on_event,
      on_exit = on_event,
    }
  )
  table.insert(jobs, job2)
  local _ = vim.fn.jobwait(jobs)
end

vim.api.nvim_create_user_command("LspImagesPull", images_pull, {})
vim.api.nvim_create_user_command("LspImagesRemove", images_remove, {})
vim.api.nvim_create_user_command("LspBuildImage", build_project_image, {})

local function setup(options)
  if options['ensure_installed'] then
    Config.ensure_installed = options['ensure_installed']
  end
end

return {
  command = command,
  setup = setup,
  build_project_image = build_project_image
}
