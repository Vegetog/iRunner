import SwiftUI
import MapKit
import CoreLocation

struct GCJ02Converter {
    static let a = 6378245.0
    static let ee = 0.00669342162296594323

    static func transform(latitude: Double, longitude: Double) -> CLLocationCoordinate2D {
        if isOutOfChina(latitude: latitude, longitude: longitude) {
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
        
        var dLat = transformLat(x: longitude - 105.0, y: latitude - 35.0)
        var dLon = transformLon(x: longitude - 105.0, y: latitude - 35.0)
        
        let radLat = latitude / 180.0 * Double.pi
        var magic = sin(radLat)
        magic = 1 - ee * magic * magic
        let sqrtMagic = sqrt(magic)
        
        dLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * Double.pi)
        dLon = (dLon * 180.0) / (a / sqrtMagic * cos(radLat) * Double.pi)
        
        let mgLat = latitude + dLat
        let mgLon = longitude + dLon
        
        return CLLocationCoordinate2D(latitude: mgLat, longitude: mgLon)
    }
    
    static func isOutOfChina(latitude: Double, longitude: Double) -> Bool {
        return longitude < 72.004 || longitude > 137.8347 || latitude < 0.8293 || latitude > 55.8271
    }
    
    static func transformLat(x: Double, y: Double) -> Double {
        var ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * Double.pi) + 20.0 * sin(2.0 * x * Double.pi)) * 2.0 / 3.0
        ret += (20.0 * sin(y * Double.pi) + 40.0 * sin(y / 3.0 * Double.pi)) * 2.0 / 3.0
        ret += (160.0 * sin(y / 12.0 * Double.pi) + 320 * sin(y * Double.pi / 30.0)) * 2.0 / 3.0
        return ret
    }
    
    static func transformLon(x: Double, y: Double) -> Double {
        var ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * Double.pi) + 20.0 * sin(2.0 * x * Double.pi)) * 2.0 / 3.0
        ret += (20.0 * sin(x * Double.pi) + 40.0 * sin(x / 3.0 * Double.pi)) * 2.0 / 3.0
        ret += (150.0 * sin(x / 12.0 * Double.pi) + 300.0 * sin(x / 30.0 * Double.pi)) * 2.0 / 3.0
        return ret
    }
}


struct ContentView: View {
    @State private var isRunning = false
    @State private var isPaused = false
    @State private var time = Date()
    @StateObject private var locationManager = LocationManager()
    
    @State private var timer: Timer?
    @State private var showingSummary = false


    var body: some View {
        VStack {
            // 状态栏部分
            HStack {
                Text("户外跑步 - \(currentMonth())")
                    .font(.headline)
                Spacer()
                Text("\(timeString(date: time))")
                    .font(.headline)
                    .onAppear {
                        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                            self.time = Date()
                        }
                        timer.fire()
                    }
            }
            .padding()
            .background(Color.gray.opacity(0.2))

            // 地图部分
            MapView(locationManager: locationManager)
                .frame(height: 500)
                .cornerRadius(10)
                .padding()

            // 底部控制栏
            VStack {
                Text("总距离: \(locationManager.totalDistance, specifier: "%.2f") 公里")
                Text("总时长: \(totalTimeString(seconds: locationManager.totalTime))")
                Text("实时配速: \(locationManager.currentPace, specifier: "%.2f") 分钟/公里")

                if !isRunning {
                    Button(action: {
                        startRunning()
                    }) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 50))
                            .frame(width: 200, height: 50)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                } else if isRunning && !isPaused {
                    Button(action: {
                        pauseRunning()
                    }) {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 40))
                            .frame(width: 200, height: 50)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                } else if isPaused {
                    HStack {
                        Button(action: {
                            endRunning()
                            showingSummary = true
                        }) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 33))
                                .frame(width: 100, height: 50)
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }

                        Button(action: {
                            continueRunning()
                        }) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 40))
                                .frame(width: 100, height: 50)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: 150)
            .background(Color.gray.opacity(0.1))
        }
        .sheet(isPresented: $showingSummary) {
            RunSummaryView(
                distance: locationManager.totalDistance,
                time: locationManager.totalTime,
                pace: locationManager.currentPace,
                isPresented: $showingSummary,
                onDismiss: {
                    // 重置数据
                    locationManager.routeSegments = [[]]
                    locationManager.totalDistance = 0
                    locationManager.totalTime = 0
                    locationManager.currentPace = 0
                }
            )
        }
    }
    
    
    func currentMonth() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "M"
        let month = dateFormatter.string(from: Date())
        return "\(month)月"
    }

    func timeString(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }

    func totalTimeString(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let seconds = (seconds % 3600) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    func startRunning() {
        isRunning = true
        isPaused = false
        locationManager.resetLocations()
        locationManager.startNewSegment()
        locationManager.startUpdatingLocation()
        startTimer()
    }

    func pauseRunning() {
        isPaused = true
        locationManager.pauseUpdatingLocation()
        stopTimer()
    }

    func continueRunning() {
        isPaused = false
        locationManager.continueUpdatingLocation()
        startTimer()
    }

    func endRunning() {
        isRunning = false
        isPaused = false
        locationManager.stopUpdatingLocation()
        stopTimer()
    }

    func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.locationManager.totalTime += 1
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }


}

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var routeSegments: [[CLLocationCoordinate2D]] = [[]]
    @Published var totalDistance: Double = 0
    @Published var totalTime: Int = 0
    @Published var currentPace: Double = 0
    
    private var lastLocation: CLLocation?
    private var pausedLocation: CLLocation?
    private let locationManager = CLLocationManager()
    
    private(set) var isRunning: Bool = false
    private var isPaused: Bool = false
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // 每10米更新一次位置
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startUpdatingLocation() {
        isRunning = true
        isPaused = false
        locationManager.startUpdatingLocation()
    }
    
    func stopUpdatingLocation() {
        isRunning = false
        isPaused = false
        locationManager.stopUpdatingLocation()
    }
    
    func startNewSegment() {
        routeSegments.append([])
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last, isRunning, !isPaused else { return }
        
        if newLocation.horizontalAccuracy <= 20 {
            // 转换坐标
            let gcjCoordinate = GCJ02Converter.transform(latitude: newLocation.coordinate.latitude,
                                                         longitude: newLocation.coordinate.longitude)
            let gcjLocation = CLLocation(latitude: gcjCoordinate.latitude, longitude: gcjCoordinate.longitude)
            
            if let lastLocation = lastLocation {
                let timeDiff = newLocation.timestamp.timeIntervalSince(lastLocation.timestamp)
                if timeDiff > 10 {
                    startNewSegment()
                } else {
                    let distance = gcjLocation.distance(from: lastLocation) / 1000 // 转换为公里
                    totalDistance += distance
                    
                    print("New location: \(gcjCoordinate.latitude), \(gcjCoordinate.longitude)")
                    print("Distance added: \(distance) km")
                    print("Total distance: \(totalDistance) km")
                    
                    if totalTime > 0 && totalDistance > 0 {
                        currentPace = (Double(totalTime) / 60) / totalDistance
                    }
                }
            }
            
            routeSegments[routeSegments.count - 1].append(gcjCoordinate)
            lastLocation = gcjLocation
            
            objectWillChange.send()
        }
    }

    func pauseUpdatingLocation() {
        isPaused = true
        pausedLocation = lastLocation
    }

    func continueUpdatingLocation() {
        isPaused = false
        if let pausedLocation = pausedLocation {
            lastLocation = pausedLocation
        }
        pausedLocation = nil
    }

    func resetLocations() {
        lastLocation = nil
        pausedLocation = nil
        routeSegments = [[]]
        totalDistance = 0
        totalTime = 0
        currentPace = 0
    }
}

struct MapView: UIViewRepresentable {
    @ObservedObject var locationManager: LocationManager
    @State private var showResetButton = false

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true

        let resetButton = MKUserTrackingButton(mapView: mapView)
        resetButton.layer.backgroundColor = UIColor(white: 1, alpha: 0.8).cgColor
        resetButton.layer.borderColor = UIColor.white.cgColor
        resetButton.layer.borderWidth = 1
        resetButton.layer.cornerRadius = 5
        resetButton.translatesAutoresizingMaskIntoConstraints = false

        mapView.addSubview(resetButton)

        NSLayoutConstraint.activate([
            resetButton.bottomAnchor.constraint(equalTo: mapView.bottomAnchor, constant: -20),
            resetButton.trailingAnchor.constraint(equalTo: mapView.trailingAnchor, constant: -20),
        ])

        return mapView
    }


    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.updatePolylines(mapView: mapView)
    }

    func makeCoordinator() -> MapViewCoordinator {
        MapViewCoordinator(self)
    }
}

class MapViewCoordinator: NSObject, MKMapViewDelegate {
    var parent: MapView
    var polylines: [MKPolyline] = []
    var lastRegion: MKCoordinateRegion?
    let regionChangeThreshold: CLLocationDegrees = 0.01

    init(_ parent: MapView) {
        self.parent = parent
    }

    func updatePolylines(mapView: MKMapView) {
        mapView.removeOverlays(polylines)
        polylines.removeAll()
        
        for segment in parent.locationManager.routeSegments {
            let polyline = MKPolyline(coordinates: segment, count: segment.count)
            polylines.append(polyline)
            mapView.addOverlay(polyline)
        }
        
        if let lastSegment = parent.locationManager.routeSegments.last, !lastSegment.isEmpty {
            updateMapRegionIfNeeded(mapView: mapView, coordinates: lastSegment)
        }
    }

    
    func updateMapRegionIfNeeded(mapView: MKMapView, coordinates: [CLLocationCoordinate2D]) {
        guard !coordinates.isEmpty else { return }

        let region = MKCoordinateRegion(coordinates)
        
        // 如果是第一次设置区域，或者区域变化超过阈值，才更新地图区域
        if lastRegion == nil || shouldUpdateRegion(oldRegion: lastRegion!, newRegion: region) {
            let span = MKCoordinateSpan(
                latitudeDelta: max(region.span.latitudeDelta, 0.005) * 1.5,
                longitudeDelta: max(region.span.longitudeDelta, 0.005) * 1.5
            )
            let adjustedRegion = MKCoordinateRegion(
                center: region.center,
                span: span
            )
            
            mapView.setRegion(adjustedRegion, animated: true)
            lastRegion = adjustedRegion
        }
    }

    func shouldUpdateRegion(oldRegion: MKCoordinateRegion, newRegion: MKCoordinateRegion) -> Bool {
        let latChange = abs(oldRegion.center.latitude - newRegion.center.latitude)
        let lonChange = abs(oldRegion.center.longitude - newRegion.center.longitude)
        return latChange > regionChangeThreshold || lonChange > regionChangeThreshold
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let polyline = overlay as? MKPolyline {
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = UIColor.blue
            renderer.lineWidth = 5
            return renderer
        }
        return MKOverlayRenderer(overlay: overlay)
    }
    
    func resetMapView(mapView: MKMapView) {
        if let userLocation = mapView.userLocation.location?.coordinate {
            let region = MKCoordinateRegion(center: userLocation, latitudinalMeters: 1000, longitudinalMeters: 1000)
            mapView.setRegion(region, animated: true)
        }
    }
}



extension MKCoordinateRegion {
    init(_ coordinates: [CLLocationCoordinate2D]) {
        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude

        for coordinate in coordinates {
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
        }

        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2,
                                            longitude: (minLon + maxLon) / 2)
        let span = MKCoordinateSpan(latitudeDelta: (maxLat - minLat) * 1.1,
                                    longitudeDelta: (maxLon - minLon) * 1.1)
        self.init(center: center, span: span)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
