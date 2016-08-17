#!/usr/bin/env bash
. <(aescrypt -d angelbot.aes -o -) || echo 'Doh password was wrong'
slackbot-frd start
