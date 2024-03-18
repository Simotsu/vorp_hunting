fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
--dont touch
version '1.0.0'
author 'Simotsu - Bobby O\'Shea'
description 'A Much Improved Hunting script for VORPCore framework'
lua54 'yes'

client_script {
    'config.lua',
    'client/client.lua',
    'client/main.js'
}
server_script {
    
    '@oxmysql/lib/MySQL.lua',
    'config.lua',
    'server/server.lua'
}

exports {
    'DataViewNativeGetEventData'
}


