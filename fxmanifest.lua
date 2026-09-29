fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'SeaM_Tutorial'
author 'SeaM'
description 'First-time onboarding: a narrator, objectives around the map, and rewards at the end'
version '1.0.0'

shared_script 'config.lua'

client_scripts {
    'client/marker.lua',
    'client/main.lua',
}

server_script 'server/main.lua'

ui_page 'html/index.html'

files {
    'html/index.html',
}

dependency 'SeaM_Core'
