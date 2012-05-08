# Intro
This is a simple script that parses exception logs from Airbrake, figures out the most likely offending line in the app that caused the exception based on the Airbrake backtrace, and then uses a local copy of the app (and Git blame) to figure out who wrote that line.

It then ranks developers using a scoring algorithm that biases towards high exception rates for individual exceptions, and also a high number of different types of exceptions.

In short: it's probably best not to be at the top of this leaderboard!

# Setup

  * `git clone git@github.com:warpdude/opportunity-leaderboard.git`
  * Copy `config.yml.template` to `config.yml` and edit as required
  * `bundle install`
  * ???
  * Profit!

# Usage 
The options are as follows:

```bash
Usage: opportunity.rb [options]
        --file FILE                  Pull exeception data from a file
    -v, --verbose                    Increase verbosity
        --pages PAGES                Specify the number of Airbrake error pages to parse (default: 2)
    -r, --reverse                    Reverse sorting order - lower rankings displayed first (default: off)
        --top NUMBER                 Display the top <NUMBER> of results (default: all)
    -p, --presenter                  Enable presenter mode. Users must hit a keyboard key between printing each item (default: off)
        --debug                      Enable debugging output
```

The default mode of running Opportunity should be sufficient for most cases:

    ./opportunity.rb

If you want to replicate the way in which Opportunity is run during the Engineering meetings, use the following:

    ./opportunity.rb --top 5 -r --presenter

# In Summary

![so fierce](http://cdn.memegenerator.net/instances/400x/20148185.jpg)
