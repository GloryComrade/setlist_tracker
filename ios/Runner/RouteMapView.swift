import Flutter
import MapKit
import UIKit

/// "setlist/route-map": a Show's GPS route on an Apple Map, shown on the
/// Show page on iPhone (lib/ui/live_show/route_map.dart). MapKit needs no
/// API key. Creation params: "segments", a list of flat [lat, lng, lat, lng,
/// ...] lists, one per stretch between pauses.
final class RouteMapFactory: NSObject, FlutterPlatformViewFactory {
  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    let params = args as? [String: Any] ?? [:]
    return RouteMapPlatformView(frame: frame, params: params)
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}

/// Fits the route once the view has a real size (it starts at zero).
private final class RouteMKMapView: MKMapView {
  var routeRect: MKMapRect?
  private var fittedSize: CGSize = .zero

  override func layoutSubviews() {
    super.layoutSubviews()
    guard let rect = routeRect, bounds.width > 0, bounds.height > 0,
      bounds.size != fittedSize
    else { return }
    fittedSize = bounds.size
    setVisibleMapRect(
      rect,
      edgePadding: UIEdgeInsets(top: 32, left: 32, bottom: 32, right: 32),
      animated: false
    )
  }
}

private final class RouteEnd: MKPointAnnotation {
  var isStart = false
}

final class RouteMapPlatformView: NSObject, FlutterPlatformView, MKMapViewDelegate {
  private let map: RouteMKMapView

  /// Neon Magenta (#FF4D9A), Marquee Amber (#FFB020) and Spotlight White
  /// (#F5F3FA) from the app's theme.
  private static let line = UIColor(red: 1, green: 0x4D / 255, blue: 0x9A / 255, alpha: 1)
  private static let amber = UIColor(red: 1, green: 0xB0 / 255, blue: 0x20 / 255, alpha: 1)
  private static let white = UIColor(
    red: 0xF5 / 255, green: 0xF3 / 255, blue: 0xFA / 255, alpha: 1)
  private static let stage = UIColor(
    red: 0x0B / 255, green: 0x0A / 255, blue: 0x12 / 255, alpha: 1)

  init(frame: CGRect, params: [String: Any]) {
    map = RouteMKMapView(frame: frame)
    super.init()
    map.delegate = self
    map.overrideUserInterfaceStyle = .dark
    map.pointOfInterestFilter = .excludingAll
    map.showsCompass = false
    map.showsScale = false
    map.isRotateEnabled = false
    map.isPitchEnabled = false
    map.accessibilityLabel = "Route map"

    var all: [CLLocationCoordinate2D] = []
    let segments = params["segments"] as? [Any] ?? []
    for raw in segments {
      let flat = (raw as? [NSNumber])?.map { $0.doubleValue } ?? []
      var coords: [CLLocationCoordinate2D] = []
      var i = 0
      while i + 1 < flat.count {
        coords.append(CLLocationCoordinate2D(latitude: flat[i], longitude: flat[i + 1]))
        i += 2
      }
      guard coords.count >= 2 else { continue }
      all.append(contentsOf: coords)
      map.addOverlay(MKPolyline(coordinates: coords, count: coords.count))
    }
    guard let first = all.first, let last = all.last else { return }

    let start = RouteEnd()
    start.coordinate = first
    start.isStart = true
    start.title = "Start"
    let finish = RouteEnd()
    finish.coordinate = last
    finish.title = "Finish"
    map.addAnnotations([start, finish])

    map.routeRect = MKPolyline(coordinates: all, count: all.count).boundingMapRect
  }

  func view() -> UIView { map }

  func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
    guard let polyline = overlay as? MKPolyline else {
      return MKOverlayRenderer(overlay: overlay)
    }
    let renderer = MKPolylineRenderer(polyline: polyline)
    renderer.strokeColor = Self.line
    renderer.lineWidth = 4
    renderer.lineCap = .round
    renderer.lineJoin = .round
    return renderer
  }

  /// Start: a white ring. Finish: an amber dot. Both edged in stage black.
  func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
    guard let end = annotation as? RouteEnd else { return nil }
    let view = MKAnnotationView(annotation: end, reuseIdentifier: nil)
    let size: CGFloat = 16
    view.frame = CGRect(x: 0, y: 0, width: size, height: size)
    view.layer.cornerRadius = size / 2
    if end.isStart {
      view.backgroundColor = Self.stage
      view.layer.borderColor = Self.white.cgColor
      view.layer.borderWidth = 3
    } else {
      view.backgroundColor = Self.amber
      view.layer.borderColor = Self.stage.cgColor
      view.layer.borderWidth = 3
    }
    view.canShowCallout = false
    view.isAccessibilityElement = false
    return view
  }
}
