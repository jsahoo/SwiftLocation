//
//  ViewController.swift
//  SwiftLocation
//
//  Created by Jonathan Sahoo on 4/2/16.
//  Copyright © 2016 Jonathan Sahoo. All rights reserved.
//

import UIKit
import CoreLocation

class ViewController: UIViewController, SwiftLocationDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()
        SwiftLocation.addDelegate(self)
        SwiftLocation.enableBackgroundLocationUpdates = true
        SwiftLocation.startUpdatingLocation()
    }
    
    func locationDidUpdate(location: CLLocation) {
        print("\(location.coordinate.latitude), \(location.coordinate.longitude)")
    }
    
    func locationUpdateFailedWithError(error: NSError) {
        print(error)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

