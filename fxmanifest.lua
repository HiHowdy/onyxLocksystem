fx_version 'adamant'

games { 'rdr2', 'gta5' }
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resource *will* become incompatible once RedM ships.'

server_scripts {
    'config.lua',
    'server/main.lua',
}

client_scripts {
    'config.lua',
    'client/main.lua',
}

export "givePlayerKeys"