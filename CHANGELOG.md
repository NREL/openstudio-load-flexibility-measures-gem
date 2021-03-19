# OpenStudio Load Flexibility Measures Gem

## Version 0.3.0
* Merged [#20](https://github.com/NREL/openstudio-load-flexibility-measures-gem/pull/20), 030 upgrade
  * Updated OS Extension dependency to 0.4.0
* Updated documentation for Add Packaged Ice Storage measure
* Corrected output variable in Add HPWH measure

## Version 0.2.1
* Updated dependency for OS Extension 0.3.2
* Removed extraneous delimiter argument from Add Packaged Ice Storage measure
  * Fixed [#18](https://github.com/NREL/openstudio-load-flexibility-measures-gem/issues/18), remove "delimiter" argument from add_packaged_ice_storage

## Version 0.2.0

* Updated dependencies for OS Version 3.1:
  * Merged [#15](https://github.com/NREL/openstudio-load-flexibility-measures-gem/pull/15), Os 3.1.0
  * OS Extension set to 0.3.1
  * OS Standards set to 0.2.12
* Updated measure names within documentation
* Updated documentation for Add Packaged Ice Storage measure

## Version 0.1.3

* Measures have been renamed and readme updated:
  * "Add Ice Storage to Plant Loop for Load Flexibility" is now "Add Central Ice Storage"
  * "Add Distributed Ice Storage to Air Loop for Load Flexibility" is now "Add Packaged Ice Storage"
  * "Add Central HPHW for Load Flexibility" is now "Add HPHW"
* Bug Fixes:
  * [#12](https://github.com/NREL/openstudio-load-flexibility-measures-gem/issues/12), File names become too long when using with URBANopt CLI

## Version 0.1.2

* Bug Fixes:
  * [#4](https://github.com/NREL/openstudio-load-flexibility-measures-gem/issues/4), use unix paths in 'add_distributed_ice_storage_to_air_loop_for_load_flexibility'
  * [#6](https://github.com/NREL/openstudio-load-flexibility-measures-gem/issues/6), code error in add_distributed measure
  * [#8](https://github.com/NREL/openstudio-load-flexibility-measures-gem/issues/8), EMS output variables cause measure failure
* Remove .DS_Store and exclude from future releases
* Code cleanup

## Version 0.1.1

* Initial release
