//
//  SQWorkoutRouteMapView.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 1/3/26.
//

import SwiftUI
import MapKit
import CoreLocation

struct SQWorkoutRouteMapView: View {
    let isLoading: Bool
    let locations: [CLLocation]
    let errorMessage: String?
    let mapHeight: CGFloat = 220

    @State private var cameraPosition: MapCameraPosition = .automatic

    private var cleanedLocations: [CLLocation] {
        locations
            .filter {
                let lat = $0.coordinate.latitude
                let lon = $0.coordinate.longitude
                return lat.isFinite && lon.isFinite && abs(lat) <= 90 && abs(lon) <= 180
            }
            .sorted { $0.timestamp < $1.timestamp }
    }

    private var polyline: MKPolyline? {
        guard cleanedLocations.count >= 2 else { return nil }
        let coords = cleanedLocations.map { $0.coordinate }
        return MKPolyline(coordinates: coords, count: coords.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .SQSpace.s) {
            if isLoading {
                VStack {
                    Spacer()
                    
                    ProgressView()
                        .scaleEffect(0.9)
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    Spacer()
                }
                .frame(height: mapHeight)
            } else {
                if let errorMessage {
                    Text("Couldn’t load route: \(errorMessage)")
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.textSecondary)
                } else if let polyline {
                    Map(position: $cameraPosition) {
                        MapPolyline(polyline)
                            .stroke(SQColor.accent(1).color.opacity(0.25), lineWidth: 10)

                        MapPolyline(polyline)
                            .stroke(SQColor.accent(1).color, lineWidth: 4)

                        if let first = cleanedLocations.first?.coordinate {
                            Marker("Start", coordinate: first)
                        }
                        if let last = cleanedLocations.last?.coordinate {
                            Marker("End", coordinate: last)
                        }
                    }
                    .frame(height: mapHeight)
                    .clipShape(RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous))
                    .onAppear {
                        cameraPosition = .rect(padded(polyline.boundingMapRect))
                    }
                } else if !isLoading {
                    Text("No route recorded for this workout.")
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.textSecondary)
                }
            }
        }
    }

    private func padded(_ rect: MKMapRect) -> MKMapRect {
        let dx = rect.size.width * 0.2
        let dy = rect.size.height * 0.2
        return rect.insetBy(dx: -dx, dy: -dy)
    }
}
