fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'kipchak_crimescene'
author 'Kipchak Studios'
description 'Kipchak Crime Scene - evidence markers, police tape and scene props'
version '1.0.0'

files {
    'textures/*.png'
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'locales/en.lua',
    'locales/tr.lua',
    'shared/util.lua',
    'bridge/init.lua'
}

server_scripts {
    'server/sv_config.lua',
    'bridge/framework/qbox.lua',
    'bridge/framework/qbcore.lua',
    'bridge/framework/esx.lua',
    'server/scene.lua',
    'server/main.lua'
}

client_scripts {
    'client/util.lua',
    'bridge/target/ox.lua',
    'bridge/target/qb.lua',
    'client/streaming.lua',
    'client/placement.lua',
    'client/tape.lua',
    'client/main.lua'
}

dependencies {
    'ox_lib'
}
