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

## Running in production

### Periodic Maintenance

#### Installing updates

If running on Amazon Linux, Red Hat, CentOS, or other related distro, use:

    sudo yum update

*NOTE:* **If the update installs a new docker engine (which it does from time to time), it will kill all running docker containers which includes angelbot, and she'll need to be restarted again**

#### Cleaning up docker artifacts

Periodically, after starting/stopping docker containers, you may want to clean up artifacts left by docker.  This will prevent the disk from filling up.  There are a few things you should do:

1.  Cleanup unlabeled images (often build artifacts)

```bash
docker rmi $(docker images | grep -iE '^<none>' | awk '{print $3}' | xargs)
```

1.  Cleanup old containers (angelbot containers shouldn't accumulate, but still good to check)

#### Scaling

_Note:  This is a glimpse into the distant future and isn't relevant now, but might be at some point, so I've included it here as part of my brain dump_

Currently a single angel bot instance more than meets the demand at Instructure.  In the future it's possible that this may change.  Due to underlying libraries, angel runs on a single thread, and there isn't really a vertical scaling option.  Fortunately I foresee a few strategies for scalining horizontally, which is the better way to scale anyway.

1.  Multiple instances of angelbot on the same EC2 instance
1.  Multiple EC2 instances running one or more instances of angelbot

The way it is currently, running _n_ instances of angel bot will result in _n_ responses to every trigger.  This is obviously terrible.  To correct this, there are a couple strategies to choose from (ordererd by what sound like the best options to me currently):

1.  Have each instance only answer some non-intersecting subset of channels:  E.g.:  Instance 0 is listening in channels a, b, and c (busy channels) while Instance 1 listens in all other channels
    - To accomplish this, you will need to modify the bot code to check for the appropriate channel.  There a couple of ways to do this.  See `greeting-bot.rb` for a good example (it uses slackbot_frd dto do the filtering rather than checking `channel == 'mychannel'`.  If using a subset tho, I don't think currently works with slackbot_frd so you might need to do something like `if %w[c1, c2].include?(channel)`
1.  Have each instance run a non-intersecting subset of bots.  E.g. Instance 0 runs the gerrit-jira translator (main source of traffic) and instance 1 runs all the others

