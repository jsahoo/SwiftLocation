# SwiftLocation
SwiftLocation adds missing functionality to CoreLocation to make it smarter and easier to use.

## Features
* SwiftLocation provides class-level functions so that all of your classes can access location data without the need for multiple instances of a location manager and repetitive boilerplate code (I'm looking at you, CoreLocation)
* SwiftLocation automatically determines which type of location services to use (Always vs When In Use) depending on the key specified in the Info.plist so you'll never run into this issue:
<p align="center">
  <a target="_blank" href="http://stackoverflow.com/a/24063578"><img src="http://s29.postimg.org/qxqgozll3/Screen_Shot_2016_04_03_at_7_25_31_PM.png" alt="Stack Overflow Comment" title="Stack Overflow Comment"></a>
</p>
* Location monitoring begins _immediately_ after authorization has been granted, unlike CoreLocation. With CoreLocation, location monitoring will not begin unless `startUpdatingLocation()` is called _after_ authorization has been granted. Because these functions happen asynchronously, the developer has to take extra steps to ensure that location monitoring does in fact start when it's supposed to. SwiftLocation handles this automatically. Just call `startUpdatingLocation()` and SwiftLocation will automatically handle authorization requests and start the location monitoring as soon as authorization has been granted.
