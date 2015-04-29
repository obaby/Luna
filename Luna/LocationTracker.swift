//
//  LocationTracker.swift
//  Luna
//
//  Created by Andrew Shepard on 1/21/15.
//  Copyright (c) 2015 Andrew Shepard. All rights reserved.
//

import Foundation
import CoreLocation
import UIKit

public typealias LocationResult = Result<Location>
public typealias Observer = (location: LocationResult) -> ()

public class LocationTracker: NSObject, CLLocationManagerDelegate {
    
    private var lastResult: LocationResult = .Failure(.NoData)
    private var observers: [Observer] = []
    
    private let locationManager: CLLocationManager
    
    var currentLocation: LocationResult {
        return self.lastResult
    }
    
    init(locationManager:CLLocationManager = CLLocationManager()) {
        self.locationManager = locationManager
        super.init()
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        
        self.locationManager.startUpdatingLocation()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "handleBackgroundNotification:", name: UIApplicationWillResignActiveNotification, object: nil)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "handleForegroundNotification:", name: UIApplicationDidBecomeActiveNotification, object: nil)
    }
    
    // MARK: - Public
    
    func addLocationChangeObserver(observer: Observer) -> Void {
        observers.append(observer)
    }
    
    // MARK: - CLLocationManagerDelegate
    
    public func locationManager(manager: CLLocationManager!, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        #if os(iOS)
            switch status {
            case .AuthorizedWhenInUse:
                locationManager.startUpdatingLocation()
            default:
                locationManager.requestWhenInUseAuthorization()
            }
        #elseif os(OSX)
            locationManager.startUpdatingLocation()
        #endif
    }
    
    public func locationManager(manager: CLLocationManager!, didFailWithError error: NSError!) {
        let result = LocationResult.Failure(Reason.Other(error))
        self.publishChangeWithResult(result)
        self.lastResult = result
    }
    
    public func locationManager(manager: CLLocationManager!, didUpdateLocations locations: [AnyObject]!) {
        if let currentLocation = locations.first as? CLLocation {
            if shouldUpdateWithLocation(currentLocation) {
                CLGeocoder().reverseGeocodeLocation(currentLocation, completionHandler: { (placemarks, error) -> Void in
                    if let placemark = placemarks?.first as? CLPlacemark,
                        let city = placemark.locality,
                        let state = placemark.administrativeArea,
                        let neighborhood = placemark.subLocality {
                            
                            if self.shouldUpdateWithLocation(currentLocation) {
                                let location = Location(location: currentLocation, city: city, state: state, neighborhood: neighborhood)
                                
                                let result = LocationResult.Success(Box(location))
                                self.publishChangeWithResult(result)
                                self.lastResult = result
                            }
                    }
                    else {
                        let result = LocationResult.Failure(Reason.Other(error))
                        self.publishChangeWithResult(result)
                        self.lastResult = result
                    }
                })
            }
            
            // location hasn't changed significantly
        }
    }
    
    // MARK: - Private
    
    func handleBackgroundNotification(notification: NSNotification) {
        self.locationManager.stopUpdatingLocation()
    }
    
    func handleForegroundNotification(notification: NSNotification) {
        self.locationManager.startUpdatingLocation()
    }
    
    private func publishChangeWithResult(result: LocationResult) {
        if self.shouldUpdateWithResult(result) {
            observers.map { (observer) -> Void in
                observer(location: result)
            }
        }
    }
    
    private func shouldUpdateWithLocation(location: CLLocation) -> Bool {
        switch lastResult {
        case .Success(let box):
            return location.distanceFromLocation(box.unbox.physical) > 100
        case .Failure:
            return true
        }
    }
    
    private func shouldUpdateWithResult(result: LocationResult) -> Bool {
        switch lastResult {
        case .Success(let box):
            let location = box.unbox.physical
            return self.shouldUpdateWithLocation(location)
        case .Failure:
            return true
        }
    }
}

public struct Location: Equatable {
    let physical: CLLocation
    let city: String
    let state: String
    let neighborhood: String
    
    init(location physical: CLLocation, city: String, state: String, neighborhood: String) {
        self.physical = physical
        self.city = city
        self.state = state
        self.neighborhood = neighborhood
    }
}

public func ==(lhs: Location, rhs: Location) -> Bool {
    return lhs.physical == rhs.physical
}
