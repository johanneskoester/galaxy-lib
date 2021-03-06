-- http://stackoverflow.com/questions/19262761/lua-need-to-split-at-comma/19263313#19263313
function string:split( inSplitPattern, outResults )
  if not outResults then
    outResults = { }
  end
  local theStart = 1
  local theSplitStart, theSplitEnd = string.find( self, inSplitPattern, theStart )
  while theSplitStart do
    table.insert( outResults, string.sub( self, theStart, theSplitStart-1 ) )
    theStart = theSplitEnd + 1
    theSplitStart, theSplitEnd = string.find( self, inSplitPattern, theStart )
  end
  table.insert( outResults, string.sub( self, theStart ) )
  return outResults
end

local repo = VAR.REPO

local channel_args = ''
local channels = VAR.CHANNELS:split(",")
for i = 1, #channels do
    channel_args = channel_args .. " -c " .. channels[i]
end

local target_args = ''
local targets = VAR.TARGETS:split(",")
for i = 1, #targets do
    target_args = target_args .. " " .. targets[i]
end

local bind_args = {}
local binds_table = VAR.BINDS:split(",")
for i = 1, #binds_table do
    table.insert(bind_args, binds_table[i])
end

local test_bind_args = {}
local test_binds_table = VAR.TEST_BINDS:split(",")
for i = 1, #test_binds_table do
    table.insert(test_bind_args, test_binds_table[i])
end

local conda_image = VAR.CONDA_IMAGE
if conda_image == '' then
    conda_image = 'continuumio/miniconda:latest'
end

local destination_base_image = VAR.DEST_BASE_IMAGE
if destination_base_image == '' then
    destination_base_image = 'bgruening/busybox-bash:0.1'
end

local verbose = VAR.VERBOSE
if verbose == '' then
    verbose = '--quiet'
else
    verbose = '--verbose'
end

local preinstall = VAR.PREINSTALL
if preinstall ~= '' then
    preinstall = preinstall .. ' && '
end

local postinstall = VAR.POSTINSTALL
if postinstall ~= '' then
    postinstall = '&&' .. postinstall
end

inv.task('build')
    .using(conda_image)
        .withHostConfig({binds = {"build:/data"}})
        .run('rm', '-rf', '/data/dist')
    .using(conda_image)
        .withHostConfig({binds = bind_args})
        .run('/bin/sh', '-c', preinstall
            .. 'conda install '
            .. channel_args .. ' '
            .. target_args
            .. ' -p /usr/local --copy --yes '
            .. verbose
            .. postinstall)
    .wrap('build/dist')
        .at('/usr/local')
        .inImage(destination_base_image)
        .as(repo)
    .using(conda_image)
        .withHostConfig({binds = {"build:/data"}})
        .run('rm', '-rf', '/data/dist')

if VAR.TEST_BINDS == '' then
    inv.task('test')
        .using(repo)
        .withConfig({entrypoint = {'/bin/sh', '-c'}})
        .run(VAR.TEST)
else
    inv.task('test')
        .using(repo)
        .withHostConfig({binds = test_bind_args})
        .withConfig({entrypoint = {'/bin/sh', '-c'}})
        .run(VAR.TEST)
end

inv.task('push')
    .push(repo)

inv.task('build-and-test')
    .runTask('build')
    .runTask('test')

inv.task('all')
    .runTask('build')
    .runTask('test')
    .runTask('push')
