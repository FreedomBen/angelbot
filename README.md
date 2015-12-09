# Angel Bot

## What does Angel Bot do?

Currently Angel Bot has the following skills:

1. Looking up words in the dictionary (Merriam-Webster.  Requires API key)
1. Providing links to Blue Jeans conference rooms
1. Translating Jira numbers to Jira ticket links
1. Translating gerrit notation to gerrit links
1. Conducting raffles

## How do I start up Angel Bot?

* Add your slack token to `slackbot-frd.conf` in the provided spot.  For more information see [the slackbot_frd documentation](https://github.com/FreedomBen/slackbot_frd#prestantious--eximious--how-do-i-start)
* Add your Merriam Webster dictionary keys to `slackbot-frd.conf` if you want to use the dictionary bot
* run `bundle install`
* run `slackbot-frd start` from the top-level directory

## Can I send pull requests?

Please do!

## What framework does this use?

Angel bot uses [slackbot_frd](https://github.com/FreedomBen/slackbot_frd)
