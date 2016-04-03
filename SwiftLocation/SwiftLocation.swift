//
//  SwiftLocation.swift
//  SwiftLocation
//
//  Created by Jonathan Sahoo on 4/2/16.
//  Copyright © 2016 Jonathan Sahoo. All rights reserved.
//

import CoreLocation

// MARK: Errors
let SwiftLocationErrorDomain = "SwiftLocationErrorDomain"
let LocationAuthorizationCouldNotBeDetermined = 99
let FailedToGetLocationAuthorization = 100
let FailedToDetermineLocation = 101

// MARK: - SwiftLocationDelegate
@objc public protocol SwiftLocationDelegate {
    func locationDidUpdate(location: CLLocation)
    func locationUpdateFailedWithError(error: NSError)
}

// MARK: - SwiftLocation
public class SwiftLocation: NSObject {
    
    private static let locMan = LocationManager.sharedInstance
    private static var delegates = [SwiftLocationDelegate]()
    private static var continuousLocationMonitoringIsWaitingForAuthorization = false
    private static var oneTimeLocationRequestIsWaitingForAuthorization = false
    private static var pauseContinuousLocationMonitoringWhileFetchingOneTimeLocationUpate = false
    private static var isEnabled = false
    
    /// `SwiftLocation` automatically determines which location authorization should be used depending on which location usage key is used in Info.plist. However, if both `NSLocationWhenInUseUsageDescription` and `NSLocationAlwaysUsageDescription` are present, you must explicitly tell `SwiftFile` which authorization to use with this property.
    public static var desiredLocationAuthorization: CLAuthorizationStatus?
    /// The last reported location.
    public static var lastReportedLocation: CLLocation?
    
    /// The location authorization being used by `SwiftFile`, or `nil` if it can't be determined.
    public static var locationAuthorization: CLAuthorizationStatus? {
        get {
            let whenInUse = NSBundle.mainBundle().infoDictionary?["NSLocationWhenInUseUsageDescription"]
            let always = NSBundle.mainBundle().infoDictionary?["NSLocationAlwaysUsageDescription"]
            
            if let desiredLocationAuthorization = desiredLocationAuthorization { return desiredLocationAuthorization }
            else if let _ = whenInUse, let _ = always {
                notifyDelegatesOfError(domain: SwiftLocationErrorDomain, code: LocationAuthorizationCouldNotBeDetermined, description: "Because both 'NSLocationWhenInUseUsageDescription' and 'NSLocationAlwaysUsageDescription' are specified in your Info.plist, you must explicitly declare which location authorization to use with SwiftLocation.desiredLocationAuthorization.")
                return nil
            }
            else if let _ = whenInUse { return CLAuthorizationStatus.AuthorizedWhenInUse }
            else if let _ = always { return CLAuthorizationStatus.AuthorizedAlways }
            else {
                notifyDelegatesOfError(domain: SwiftLocationErrorDomain, code: LocationAuthorizationCouldNotBeDetermined, description: "Please include either 'NSLocationWhenInUseUsageDescription' or 'NSLocationAlwaysUsageDescription' in your Info.plist. Location services will be disabled until one of these keys is present.")
                return nil
            }
        }
    }
    /// The minimum distance that must be traveled (in meters) before a new location is sent to the delegate(s). By default (`kCLDistanceFilterNone`) all updates are sent to the delegate(s). ( See [`CLLocationManager`'s `distanceFilter`](https://developer.apple.com/library/ios/documentation/CoreLocation/Reference/CLLocationManager_Class/#//apple_ref/occ/instp/CLLocationManager/distanceFilter) for more information.
    public static var desiredDistanceFilter: CLLocationDistance {
        get { return locMan.locationManager.distanceFilter }
        set { locMan.locationManager.distanceFilter = newValue }
    }
    /// The radius (in meters) for which the location will be accurate to. For example, a value of 100 results in location data accurate to 100 meters. See [`CLLocationManager`'s `desiredAccuracy`](https://developer.apple.com/library/ios/documentation/CoreLocation/Reference/CLLocationManager_Class/#//apple_ref/occ/instp/CLLocationManager/desiredAccuracy) for more information.
    public static var desiredLocationAccuracy: CLLocationAccuracy {
        get { return locMan.locationManager.desiredAccuracy }
        set { locMan.locationManager.desiredAccuracy = newValue }
    }
    /**
     A Boolean indicating whether or not the app should continue monitoring and receiving location updates in the background.
     
     - note: Requires iOS 9 or greater.
    */
    public static var enableBackgroundLocationUpdates: Bool {
        get { if #available(iOS 9.0, *) { return locMan.locationManager.allowsBackgroundLocationUpdates } else { return false } }
        set { if #available(iOS 9.0, *) { locMan.locationManager.allowsBackgroundLocationUpdates = newValue } }
    }

    
    /**
     Add a delegate object that will receive location updates.
     
     - parameter delegate: The delegate object.
     */
    public static func addDelegate(delegate: SwiftLocationDelegate) {
        delegates.append(delegate)
    }
    /**
     Remove a delegate object from the list of delegates that receive location updates.
     
     - parameter delegate: The delegate object.
     */
    public static func removeDelegate(delegate: SwiftLocationDelegate) {
        if let index = delegates.indexOf({ $0 === delegate }) {
            delegates.removeAtIndex(index)
        }
    }
    
    /// Start monitoring the user's location and reports changes to the delegates' `locationDidUpdate:` method.
    public static func startUpdatingLocation() {
        
        if !isEnabled  {
            guard let locationAuthorization = locationAuthorization else {
                notifyDelegatesOfError(domain: SwiftLocationErrorDomain, code: LocationAuthorizationCouldNotBeDetermined, description: "Could not start updating location because a location authorization could not be determined. Please ensure that one has been set in your Info.plist")
                return
            }
            locMan.locationManager.stopUpdatingLocation()
            
            if !isAuthorizedForLocationMonitoring() {
                continuousLocationMonitoringIsWaitingForAuthorization = true
                requestLocationAuthorization(locationAuthorization)
            }
            else {
                isEnabled = true
                locMan.locationManager.startUpdatingLocation()
            }
        }
    }
    
    /// Stops monitoring location and the delivery of location updates to the delegate.
    public static func stopUpdatingLocation() {
        isEnabled = false
        locMan.locationManager.stopUpdatingLocation()
    }
    
    /// Request the current location (delivered once per call) using the highest accuracy.
    @available(iOS 9.0, *) public static func requestCurrentLocation() {
        guard let locationAuthorization = locationAuthorization else {
            notifyDelegatesOfError(domain: SwiftLocationErrorDomain, code: LocationAuthorizationCouldNotBeDetermined, description: "Could not start updating location because a location authorization could not be determined. Please ensure that one has been set in your Info.plist")
            return
        }
        
        locMan.locationManager.stopUpdatingLocation()
        pauseContinuousLocationMonitoringWhileFetchingOneTimeLocationUpate = isEnabled // If continuous location monitoring is currently active, temporarily stop it and restart it after receiving one-time location update
        locMan.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        if !isAuthorizedForLocationMonitoring() {
            oneTimeLocationRequestIsWaitingForAuthorization = true
            requestLocationAuthorization(locationAuthorization)
        }
        else { locMan.locationManager.requestLocation() }
    }
    
    /// Request the current location (delivered once per call) with a desired accuracy. If none is supplied, the current `desiredLocationAccuracy` will be used.
    @available(iOS 9.0, *) public static func requestCurrentLocationWithAccuracy(accuracy: CLLocationAccuracy?) {
        guard let locationAuthorization = locationAuthorization else {
            notifyDelegatesOfError(domain: SwiftLocationErrorDomain, code: LocationAuthorizationCouldNotBeDetermined, description: "Could not start updating location because a location authorization could not be determined. Please ensure that one has been set in your Info.plist")
            return
        }
        
        locMan.locationManager.stopUpdatingLocation()
        pauseContinuousLocationMonitoringWhileFetchingOneTimeLocationUpate = isEnabled // If continuous location monitoring is currently active, temporarily stop it and restart it after receiving one-time location update
        if let accuracy = accuracy { locMan.locationManager.desiredAccuracy = accuracy }
        
        if !isAuthorizedForLocationMonitoring() {
            oneTimeLocationRequestIsWaitingForAuthorization = true
            requestLocationAuthorization(locationAuthorization)
        }
        else { locMan.locationManager.requestLocation() }
    }
    
    /**
     Check whether or not authorization has been granted for location monitoring.
     
     - returns: A Boolean indicating whether or not authorization has been granted for location monitoring.
     */
    public static func isAuthorizedForLocationMonitoring() -> Bool {
        guard let desiredLocationAuthorization = locationAuthorization else {
            notifyDelegatesOfError(domain: SwiftLocationErrorDomain, code: LocationAuthorizationCouldNotBeDetermined, description: "Could not start updating location because a location authorization could not be determined. Please ensure that one has been set in your Info.plist")
            return false
        }
        if CLLocationManager.authorizationStatus() == desiredLocationAuthorization { return true }
        return false
    }
    
    /// Request location authorization.
    private static func requestLocationAuthorization(desiredAuthorization: CLAuthorizationStatus) {
        if desiredAuthorization == .AuthorizedWhenInUse { locMan.locationManager.requestWhenInUseAuthorization() }
        else if desiredAuthorization == .AuthorizedAlways { locMan.locationManager.requestAlwaysAuthorization() }
    }
    
    /// Notify all delegates of updated location.
    private static func notifyDelegatesOfNewLocation(location: CLLocation) {
        for delegate in delegates { delegate.locationDidUpdate(location) }
    }
    
    /// Notify all delegates of an error.
    private static func notifyDelegatesOfError(domain domain: String, code: Int, description: String) {
        for delegate in delegates { delegate.locationUpdateFailedWithError(NSError(domain: domain, code: code, userInfo: [NSLocalizedDescriptionKey: description])) }
    }
}

// MARK: - CLLocationManager Backend
class LocationManager: NSObject, CLLocationManagerDelegate {

    private static let sharedInstance = LocationManager()
    private let locationManager = CLLocationManager()
    
    override init() {
        super.init()
        locationManager.delegate = self
    }

    func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        guard let locationAuthorization = SwiftLocation.locationAuthorization else {return}
        if CLLocationManager.authorizationStatus() != locationAuthorization && CLLocationManager.authorizationStatus() != CLAuthorizationStatus.NotDetermined {
            SwiftLocation.notifyDelegatesOfError(domain: SwiftLocationErrorDomain, code: FailedToGetLocationAuthorization, description: "Failed to get location authorization.")
            return
        }
        
        // Start location monitoring (or get one-time location) as soon as authorization is received
        if SwiftLocation.continuousLocationMonitoringIsWaitingForAuthorization {
            if CLLocationManager.authorizationStatus() == locationAuthorization {
                SwiftLocation.isEnabled = true
                locationManager.startUpdatingLocation()
                SwiftLocation.continuousLocationMonitoringIsWaitingForAuthorization = false
            }
        }
        if SwiftLocation.oneTimeLocationRequestIsWaitingForAuthorization {
            if CLLocationManager.authorizationStatus() == locationAuthorization {
                if #available(iOS 9.0, *) { locationManager.requestLocation() }
                SwiftLocation.oneTimeLocationRequestIsWaitingForAuthorization = false
            }
        }
    }
    
    func locationManager(manager: CLLocationManager, didFailWithError error: NSError) {
        SwiftLocation.notifyDelegatesOfError(domain: error.domain, code: error.code, description: error.localizedDescription)
    }
    
    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let currentLocation = locations.last else {return}
        SwiftLocation.lastReportedLocation = currentLocation
        SwiftLocation.notifyDelegatesOfNewLocation(currentLocation)
        if locationManager.desiredAccuracy != SwiftLocation.desiredLocationAccuracy { locationManager.desiredAccuracy = SwiftLocation.desiredLocationAccuracy } // If the accuracy was changed for a one-time location update, revert it back
        if SwiftLocation.pauseContinuousLocationMonitoringWhileFetchingOneTimeLocationUpate { locationManager.startUpdatingLocation() } // If continuous location monitoring was active when a one-time location was requested, restart it
    }

}
