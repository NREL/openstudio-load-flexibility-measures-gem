# Openstudio Load Flexibility Measures Gem

This gem contains measures for thermal energy storage for building cooling and domestic hot water heating.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'openstudio-load-flexibility-measures'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install 'openstudio-load-flexibility-measures'

## Usage

The '''openstudio-load-flexibility-measures''' gem contains measures to apply thermal load flexibility to a building model. The current version contains the following:
* Add Central HPWH for Load Flexibility
* Add Distributed Ice Storage to Air Loop for Load Flexibility
* Add Ice Storage to Plant Loop for Load Flexibility

Detailed instructions for usage are included in each measure's respective README.md and docs folder. 

# Releasing

* Update CHANGELOG.md
* Run rake rubocop:auto_correct
* Update version in `/lib/openstudio/openstudio-load-flexibility-measures/version.rb`
* Create PR to master, after tests and reviews complete, then merge
* Locally - from the master branch, run rake release
* Release via github
* On GitHub, go to the releases page and update the latest release tag. Name it “Version x.y.z” and copy the CHANGELOG entry into the description box.

## TODO

- [ ] Update measures to code standards (get rubocop.yml from other OS gems)
- [ ] Update usage with links to respective measure documentation
