# Leaderboard of Opportunity

## Setup

  * Copy `config.yml.template` to `config.yml` and edit as required
  * ???
  * Profit!!

## Usage 
The options are as follows:

```bash
Usage: opportunity.rb [options]
        --file FILE                  Pull exeception data from a file
    -v, --verbose                    Increase verbosity
        --pages PAGES                Specify the number of Airbrake error pages to parse (default: 2)
    -r, --reverse                    Reverse sorting order - lower rankings displayed first (default: off)
        --top NUMBER                 Display the top <NUMBER> of results (default: all)
    -p, --presenter                  Enable presenter mode. Users must hit a keyboard key between printing each item (default: off)
```

The default mode of running Opportunity should be sufficient for most cases:

    ./opportunity.rb

If you want to replicate the way in which Opportunity is run during the Engineering meetings, use the following:

    ./opportunity.rb -v --top 5 -r --presenter
