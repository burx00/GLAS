import SwiftUI
import UIKit
import Foundation
import MapKit
import PhotosUI
import CoreLocation
import AVFoundation
import Observation

// MARK: - Palette
// Taken from the ГЛАС logo: warm cream paper, deep teal ink, soft matte "clay" surfaces.
//   Cream  #E5E2D3   Teal  #39585A   Clay surface #F1EFE5
// Every color has a light and a dark value, so the app follows the phone's appearance.

private extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(UIColor { trait in
            let hex = trait.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}

private enum Theme {
    // Surfaces
    static let background    = Color(light: 0xE5E2D3, dark: 0x182224)   // cream paper
    static let surface       = Color(light: 0xF1EFE5, dark: 0x243133)   // raised clay
    static let surfaceDeep   = Color(light: 0xDAD6C4, dark: 0x1B2628)   // pressed / selected

    // Text
    static let textPrimary   = Color(light: 0x24393B, dark: 0xEDEBDD)
    static let textSecondary = Color(light: 0x5F7577, dark: 0xA9B9BA)
    static let onAccent      = Color(light: 0xFBF9F1, dark: 0xFBF9F1)

    // Brand teal (from the logo)
    static let teal          = Color(light: 0x39585A, dark: 0x4F7F82)   // fills
    static let tealText      = Color(light: 0x39585A, dark: 0x9CC3C5)   // icons/text on surfaces

    // Meaning colors
    static let alert         = Color(light: 0xBD623A, dark: 0xCC6F45)   // warm terracotta
    static let sos           = Color(light: 0xB3261E, dark: 0xC9433A)   // urgent red
}

// MARK: - Logo (vector, drawn from the supplied artwork)

private struct GlasLogo: Shape {
    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let ox = rect.midX - side / 2
        let oy = rect.midY - side / 2
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: ox + x * side, y: oy + y * side) }

        let cx: CGFloat = 0.4525, cy: CGFloat = 0.4485, r: CGFloat = 0.39
        var path = Path()
        var angle: CGFloat = -39
        var isFirst = true
        while angle >= -270 {
            let t = angle * .pi / 180
            let point = p(cx + r * cos(t), cy + r * sin(t))
            if isFirst { path.move(to: point); isFirst = false } else { path.addLine(to: point) }
            angle -= 2
        }
        path.addLine(to: p(cx, cy + r))
        path.addLine(to: p(0.4525, 0.9825))                              // speech-bubble tail
        path.addLine(to: p(0.785, 0.67))
        path.addQuadCurve(to: p(0.85, 0.505), control: p(0.86, 0.615))
        path.addLine(to: p(0.4575, 0.505))                               // the bar of the "G"
        return path
    }
}

private struct LogoMark: View {
    var size: CGFloat
    var color: Color = Theme.teal

    var body: some View {
        GlasLogo()
            .stroke(color, style: StrokeStyle(lineWidth: size * 0.09, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

// MARK: - Clay surface (soft matte card with a light and a dark shadow)

private struct ClayModifier<S: Shape>: ViewModifier {
    let shape: S
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content.background {
            shape
                .fill(Theme.surface)
                .shadow(color: scheme == .dark ? .black.opacity(0.45) : Color(red: 0.35, green: 0.32, blue: 0.22).opacity(0.22),
                        radius: 10, x: 5, y: 7)
                .shadow(color: scheme == .dark ? .white.opacity(0.03) : .white.opacity(0.75),
                        radius: 8, x: -5, y: -5)
        }
    }
}

private extension View {
    func clay<S: Shape>(_ shape: S) -> some View { modifier(ClayModifier(shape: shape)) }
}

// MARK: - Model

private enum MapMode: CaseIterable {
    case alerts, stations

    var title: String        { self == .alerts ? "Сигнали" : "Станици" }
    var summaryLabel: String { self == .alerts ? "Пријавени сигнали" : "Полициски станици" }
    var tabIcon: String      { self == .alerts ? "exclamationmark.triangle.fill" : "shield.lefthalf.filled" }
    var markerIcon: String   { self == .alerts ? "exclamationmark" : "shield.fill" }
    var color: Color         { self == .alerts ? Theme.alert : Theme.teal }          // fills
    var tint: Color          { self == .alerts ? Theme.alert : Theme.tealText }      // on surfaces
}

private struct MapSpot: Identifiable {
    let id: String
    let kind: MapMode
    let coordinate: CLLocationCoordinate2D
    let area: String
    let time: String?

    var title: String    { kind == .alerts ? "Пријавен сигнал" : "Полициска станица" }
    var subtitle: String { time.map { "\(area) • \($0)" } ?? area }

    // Fictional demo data.
    static let all: [MapSpot] = [
        MapSpot(id: "a1", kind: .alerts,   coordinate: .init(latitude: 42.009, longitude: 21.400), area: "Карпош",      time: "21:47"),
        MapSpot(id: "a2", kind: .alerts,   coordinate: .init(latitude: 42.001, longitude: 21.441), area: "Чаир",        time: "20:14"),
        MapSpot(id: "a3", kind: .alerts,   coordinate: .init(latitude: 41.987, longitude: 21.424), area: "Центар",      time: "18:03"),
        MapSpot(id: "s1", kind: .stations, coordinate: .init(latitude: 41.996, longitude: 21.433), area: "Центар",      time: nil),
        MapSpot(id: "s2", kind: .stations, coordinate: .init(latitude: 42.008, longitude: 21.412), area: "Карпош",      time: nil),
        MapSpot(id: "s3", kind: .stations, coordinate: .init(latitude: 41.983, longitude: 21.443), area: "Кисела Вода", time: nil)
    ]
}

// MARK: - Three-second audible SOS alarm
// Synthesized in memory: no external audio asset is required.
private final class SOSAlarm {
    static let shared = SOSAlarm()
    private var player: AVAudioPlayer?

    func play() {
        player?.stop()
        let sampleRate = 22_050
        let seconds = 3
        let count = sampleRate * seconds
        var pcm = Data(capacity: count * 2)
        for i in 0..<count {
            let t = Double(i) / Double(sampleRate)
            let frequency = (Int(t * 4) % 2 == 0) ? 880.0 : 1175.0
            let envelope = min(1.0, t * 35.0, (3.0 - t) * 35.0)
            let value = Int16(0.42 * max(0, envelope) * sin(2.0 * .pi * frequency * t) * Double(Int16.max))
            var little = value.littleEndian
            withUnsafeBytes(of: &little) { pcm.append(contentsOf: $0) }
        }
        var wav = Data()
        func u16(_ n: UInt16) { var v = n.littleEndian; withUnsafeBytes(of: &v) { wav.append(contentsOf: $0) } }
        func u32(_ n: UInt32) { var v = n.littleEndian; withUnsafeBytes(of: &v) { wav.append(contentsOf: $0) } }
        wav.append(contentsOf: "RIFF".utf8)
        u32(UInt32(36 + pcm.count))
        wav.append(contentsOf: "WAVEfmt ".utf8)
        u32(16); u16(1); u16(1)
        u32(UInt32(sampleRate)); u32(UInt32(sampleRate * 2))
        u16(2); u16(16)
        wav.append(contentsOf: "data".utf8)
        u32(UInt32(pcm.count))
        wav.append(pcm)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(data: wav)
            player?.prepareToPlay()
            player?.play()
        } catch {
            print("SOS alarm could not play: \(error)")
        }
    }
}


// MARK: - Main screen

struct ContentView: View {
    @State private var mode: MapMode = .alerts
    @State private var selectedID: String?
    @State private var showSOS = false
    @State private var showAlertList = false
    @State private var showReport = false
    @State private var showProfile = false
    @AppStorage("profileName") private var profileName = ""
    @State private var stationDirections = NearestStationDirections()
    @State private var showDirectionsError = false
    @State private var search = ""
    @State private var camera: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 41.9981, longitude: 21.4254),
            span: MKCoordinateSpan(latitudeDelta: 0.075, longitudeDelta: 0.085)
        )
    )

    private var visibleSpots: [MapSpot] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return MapSpot.all.filter { spot in
            spot.kind == mode && (query.isEmpty || spot.area.localizedCaseInsensitiveContains(query))
        }
    }

    private var selectedSpot: MapSpot? {
        visibleSpots.first { $0.id == selectedID }
    }

    var body: some View {
        ZStack {
            mapLayer.ignoresSafeArea()

            VStack(spacing: 14) {
                header
                searchBar
                Spacer()
                if let spot = selectedSpot {
                    SpotCard(spot: spot) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { selectedID = nil }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                bottomBar
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 8)
        }
        .fontDesign(.rounded)
        .foregroundStyle(Theme.textPrimary)
        .sheet(isPresented: $showSOS) {
            SOSSheet()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.background)
        }
        .sheet(isPresented: $showAlertList) {
            AlertHistorySheet(spots: MapSpot.all.filter { $0.kind == .alerts }) { spot in
                showAlertList = false
                mode = .alerts
                select(spot)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Theme.background)
        }
        .sheet(isPresented: $showReport) {
            PrivateReportSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.background)
        }
        .sheet(isPresented: $showProfile) {
            ProfileSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.background)
        }
        .alert("Не може да се најде станица", isPresented: $showDirectionsError) {
            Button("Во ред", role: .cancel) { }
        } message: {
            Text(stationDirections.errorMessage ?? "Обидете се повторно.")
        }
        .onChange(of: stationDirections.errorMessage) { _, message in
            if message != nil { showDirectionsError = true }
        }
        .sensoryFeedback(.selection, trigger: mode)
        .sensoryFeedback(.impact, trigger: showSOS)
    }

    // MARK: Map

    private var mapLayer: some View {
        Map(position: $camera) {
            ForEach(visibleSpots) { spot in
                Annotation(spot.title, coordinate: spot.coordinate, anchor: .center) {
                    Button {
                        select(spot)
                    } label: {
                        MarkerView(spot: spot, isSelected: spot.id == selectedID)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(spot.title), \(spot.subtitle)")
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: false))
        // A soft cream wash so the map sits in the same palette as the app.
        .overlay {
            Theme.background.opacity(0.22).allowsHitTesting(false)
        }
    }

    private func select(_ spot: MapSpot) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            selectedID = spot.id
            camera = .region(
                MKCoordinateRegion(
                    center: spot.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.045)
                )
            )
        }
    }

    // MARK: Top area

    private var header: some View {
        HStack {
            HStack(spacing: 10) {
                LogoMark(size: 28)
                Text("ГЛАС")
                    .font(.title3.weight(.semibold))
                    .tracking(2)
                    .foregroundStyle(Theme.tealText)
            }
            .padding(.horizontal, 18)
            .frame(height: 48)
            .clay(Capsule())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("ГЛАС")

            Spacer()

            Button {
                showProfile = true
            } label: {
                Group {
                    if profileInitials(profileName).isEmpty {
                        Image(systemName: "person.fill").font(.headline)
                    } else {
                        Text(profileInitials(profileName)).font(.subheadline.weight(.bold))
                    }
                }
                .foregroundStyle(Theme.tealText)
                .frame(width: 48, height: 48)
                .clay(Circle())
            }
            .accessibilityLabel("Профил")
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.textSecondary)
            TextField("Пребарај по населба", text: $search)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !search.isEmpty {
                Button {
                    search = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.textSecondary)
                }
                .accessibilityLabel("Исчисти пребарување")
            }
        }
        .padding(.horizontal, 18)
        .frame(minHeight: 50)
        .clay(Capsule())
    }

    // MARK: Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 12) {
            HStack {
                Text(visibleSpots.isEmpty ? "Нема резултати" : "\(mode.summaryLabel): \(visibleSpots.count)")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("Демо податоци")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Theme.surfaceDeep, in: Capsule())
            }
            .padding(.horizontal, 4)

            HStack(spacing: 8) {
                tabButton(.alerts)
                sosButton
                tabButton(.stations)
            }

            Button {
                stationDirections.findAndOpenNearestStation()
            } label: {
                HStack(spacing: 8) {
                    if stationDirections.isSearching {
                        ProgressView().tint(Theme.onAccent)
                    } else {
                        Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                    }
                    Text(stationDirections.isSearching ? "Се бара најблиска станица..." : "Насоки до најблиска полициска станица")
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.onAccent)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Theme.teal, in: RoundedRectangle(cornerRadius: 16))
            }
            .disabled(stationDirections.isSearching)
            .accessibilityHint("Пребарува вистински полициски станици во Apple Maps и отвора насоки.")

            HStack(spacing: 10) {
                Button { showAlertList = true } label: {
                    Label("Листа", systemImage: "list.bullet.rectangle")
                        .frame(maxWidth: .infinity)
                }
                Button { showReport = true } label: {
                    Label("Пријави", systemImage: "square.and.pencil")
                        .frame(maxWidth: .infinity)
                }
            }
            .font(.footnote.weight(.semibold))
            .buttonStyle(.bordered)
            .tint(Theme.teal)
        }
        .padding(14)
        .clay(RoundedRectangle(cornerRadius: 30, style: .continuous))
    }

    private func tabButton(_ option: MapMode) -> some View {
        let isOn = mode == option
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                mode = option
                selectedID = nil
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: option.tabIcon)
                    .font(.title3)
                Text(option.title)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(isOn ? option.tint : Theme.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(
                isOn ? Theme.surfaceDeep : Color.clear,
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.title)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private var sosButton: some View {
        Button {
            SOSAlarm.shared.play()
            showSOS = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "phone.fill")
                Text("SOS")
                    .font(.headline.weight(.heavy))
            }
            .foregroundStyle(Theme.onAccent)
            .padding(.horizontal, 20)
            .frame(minHeight: 58)
            .background(Theme.sos, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Theme.sos.opacity(0.35), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("SOS, итен повик, демо")
    }
}

// MARK: - Map marker

private struct MarkerView: View {
    let spot: MapSpot
    let isSelected: Bool

    var body: some View {
        let size: CGFloat = isSelected ? 46 : 36
        ZStack {
            Circle().fill(spot.kind.color)
            Image(systemName: spot.kind.markerIcon)
                .font(.system(size: isSelected ? 20 : 16, weight: .bold))
                .foregroundStyle(Theme.onAccent)
        }
        .frame(width: size, height: size)
        .overlay(Circle().stroke(Theme.surface, lineWidth: 3))
        .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Selected place card

private struct SpotCard: View {
    let spot: MapSpot
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: spot.kind.markerIcon)
                .font(.headline)
                .foregroundStyle(Theme.onAccent)
                .frame(width: 46, height: 46)
                .background(spot.kind.color, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(spot.title)
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Text(spot.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer(minLength: 8)

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.textSecondary)
            }
            .accessibilityLabel("Затвори")
        }
        .padding(14)
        .clay(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

// MARK: - SOS demo sheet

private struct SOSSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "phone.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Theme.onAccent)
                .frame(width: 72, height: 72)
                .background(Theme.sos, in: Circle())
                .padding(.top, 24)

            Text("SOS • Демо")
                .font(.title2.bold())
                .foregroundStyle(Theme.textPrimary)

            Text("Ова е прототип. Не е испратен сигнал до полиција или служби за итни случаи.")
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)

            Label("Во вистинска опасност повикајте 112", systemImage: "exclamationmark.shield.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.sos)
                .multilineTextAlignment(.center)

            Spacer(minLength: 0)

            Button {
                dismiss()
            } label: {
                Text("Во ред")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 28)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(Theme.teal)
        }
        .fontDesign(.rounded)
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }
}

// MARK: - Profile (saved on this iPhone only)

private func profileInitials(_ name: String) -> String {
    let letters = name
        .split(whereSeparator: { $0.isWhitespace })
        .prefix(2)
        .compactMap { $0.first }
    return String(letters).uppercased()
}

private struct ProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @AppStorage("profileName") private var name = ""
    @AppStorage("profileArea") private var area = ""
    @AppStorage("profileContactName") private var contactName = ""
    @AppStorage("profileContactPhone") private var contactPhone = ""
    @State private var showClearConfirm = false

    private var dialableContact: String {
        contactPhone.filter { $0.isNumber || $0 == "+" }
    }

    private func call(_ number: String) {
        guard !number.isEmpty, let url = URL(string: "tel:\(number)") else { return }
        openURL(url)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        ZStack {
                            Circle().fill(Theme.teal)
                            if profileInitials(name).isEmpty {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 34, weight: .semibold))
                            } else {
                                Text(profileInitials(name))
                                    .font(.system(size: 34, weight: .bold, design: .rounded))
                            }
                        }
                        .foregroundStyle(Theme.onAccent)
                        .frame(width: 84, height: 84)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                Section("Лични податоци") {
                    TextField("Име и презиме", text: $name)
                        .textContentType(.name)
                    TextField("Населба", text: $area)
                }
                .listRowBackground(Theme.surface)

                Section {
                    TextField("Име на контакт", text: $contactName)
                        .textContentType(.name)
                    TextField("Телефонски број", text: $contactPhone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                    Button {
                        call(dialableContact)
                    } label: {
                        Label(contactName.isEmpty ? "Повикај контакт" : "Повикај \(contactName)",
                              systemImage: "phone.fill")
                    }
                    .disabled(dialableContact.isEmpty)
                } header: {
                    Text("Контакт за итни случаи")
                } footer: {
                    Text("Контактот е само зачуван на овој телефон. Апликацијата не испраќа пораки до него.")
                }
                .listRowBackground(Theme.surface)

                Section {
                    Button(role: .destructive) {
                        call("112")
                    } label: {
                        Label("Повикај 112", systemImage: "exclamationmark.shield.fill")
                    }
                } footer: {
                    Text("Во вистинска опасност веднаш повикајте 112.")
                }
                .listRowBackground(Theme.surface)

                Section {
                    Button("Избриши ги моите податоци", role: .destructive) {
                        showClearConfirm = true
                    }
                } footer: {
                    Text("Сите податоци се чуваат само на овој iPhone, не на сервер.")
                }
                .listRowBackground(Theme.surface)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Профил")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
            .confirmationDialog("Да се избришат ли сите профилни податоци?",
                                isPresented: $showClearConfirm,
                                titleVisibility: .visible) {
                Button("Избриши", role: .destructive) {
                    name = ""
                    area = ""
                    contactName = ""
                    contactPhone = ""
                }
                Button("Откажи", role: .cancel) { }
            }
        }
        .fontDesign(.rounded)
        .foregroundStyle(Theme.textPrimary)
    }
}

#Preview {
    ContentView()
}


// MARK: - Alert history (illustrative demo records)

private struct AlertHistorySheet: View {
    let spots: [MapSpot]
    let onSelect: (MapSpot) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(spots) { spot in
                        Button { onSelect(spot) } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(Theme.alert)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(spot.area).font(.headline)
                                    Text("Пријавен сигнал • \(spot.time ?? "Непознато")")
                                        .font(.subheadline)
                                        .foregroundStyle(Theme.textSecondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            .padding(.vertical, 5)
                        }
                        .listRowBackground(Theme.surface)
                    }
                } header: {
                    Text("Каде и кога")
                } footer: {
                    Text("Овие сигнали се измислени примери за демонстрација, не вистински инциденти.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Историја на сигнали")
            .navigationBarTitleDisplayMode(.inline)
        }
        .fontDesign(.rounded)
        .foregroundStyle(Theme.textPrimary)
    }
}

// MARK: - Private evidence attachment prototype
// Photos are kept locally in memory in this demo. Never publish a person's photo
// or accuse an identifiable individual publicly without safeguards and review.

private struct PrivateReportSheet: View {
    @State private var chosenPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var details = ""
    @State private var area = ""
    @State private var incidentDate = Date()
    @State private var showConfirmation = false

    private var photoButtonTitle: String {
        photoData == nil ? "Избери фотографија" : "Промени фотографија"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Поднесете доверлива пријава. Фотографијата е приватен доказ, не јавна објава.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
                Section("Информации за настанот") {
                    TextField("Локација / населба", text: $area)
                    DatePicker("Датум и време", selection: $incidentDate, in: ...Date())
                    TextField("Што се случи?", text: $details, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section("Фотографија (опционално)") {
                    PhotosPicker(selection: $chosenPhoto, matching: .images) {
                        Label(photoButtonTitle, systemImage: "photo.on.rectangle.angled")
                    }
                    if let photoData, let image = UIImage(data: photoData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 190)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .accessibilityLabel("Преглед на избраната фотографија")
                        Button("Отстрани фотографија", role: .destructive) {
                            self.photoData = nil
                            chosenPhoto = nil
                        }
                    }
                }
                Section {
                    Text("Во оваа демо верзија ништо не се испраќа, зачувува на сервер или објавува. За вистинска пријава се потребни согласност, безбедно чување и модерација.")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                    Button("Прегледај пријава") {
                        showConfirmation = true
                    }
                    .disabled(area.trimmingCharacters(in: .whitespaces).isEmpty ||
                              details.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .listRowBackground(Theme.surface)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Нова пријава")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: chosenPhoto) { _, newValue in
                Task {
                    guard let newValue else { photoData = nil; return }
                    photoData = try? await newValue.loadTransferable(type: Data.self)
                }
            }
            .alert("Демо преглед", isPresented: $showConfirmation) {
                Button("Во ред", role: .cancel) { }
            } message: {
                Text("Пријавата е пополнета, но не е испратена. Фотографијата останува само во овој преглед.")
            }
        }
        .fontDesign(.rounded)
        .foregroundStyle(Theme.textPrimary)
    }
}


// MARK: - Nearest police station directions (Swift 6 safe delegate)

@Observable
@MainActor
private final class NearestStationDirections: NSObject {
    var isSearching = false
    var errorMessage: String?

    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var locationDelegate: StationLocationDelegate?

    override init() {
        super.init()

        let delegate = StationLocationDelegate(
            onAuthorization: { [weak self] in
                Task { @MainActor [weak self] in
                    self?.authorizationChanged()
                }
            },
            onLocation: { [weak self] latitude, longitude in
                Task { @MainActor [weak self] in
                    await self?.searchAndOpen(
                        near: CLLocation(latitude: latitude, longitude: longitude)
                    )
                }
            },
            onError: { [weak self] message in
                Task { @MainActor [weak self] in
                    self?.isSearching = false
                    self?.errorMessage = message
                }
            }
        )
        locationDelegate = delegate
        manager.delegate = delegate
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func findAndOpenNearestStation() {
        errorMessage = nil
        isSearching = true
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied, .restricted:
            isSearching = false
            errorMessage = "Дозволете пристап до локацијата во Settings."
        @unknown default:
            isSearching = false
            errorMessage = "Локацијата не е достапна."
        }
    }

    private func authorizationChanged() {
        guard isSearching else { return }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied, .restricted:
            isSearching = false
            errorMessage = "Пристапот до локацијата не е дозволен."
        default:
            break
        }
    }

    private func searchAndOpen(near location: CLLocation) async {
        let queries = ["police station", "полициска станица", "police", "полиција"]
        var found: [MKMapItem] = []
        var lastError: Error?

        for query in queries {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            request.region = MKCoordinateRegion(
                center: location.coordinate,
                latitudinalMeters: 30000,
                longitudinalMeters: 30000
            )
            do {
                let response = try await MKLocalSearch(request: request).start()
                found.append(contentsOf: response.mapItems)
                if !found.isEmpty { break }
            } catch {
                lastError = error
            }
        }

        let closest = found
            .compactMap { item -> (MKMapItem, CLLocationDistance)? in
                guard let loc = item.placemark.location else { return nil }
                return (item, loc.distance(from: location))
            }
            .min { $0.1 < $1.1 }?.0

        isSearching = false
        if let closest {
            _ = MKMapItem.openMaps(with: [closest], launchOptions: [
                MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
            ])
        } else if let lastError {
            errorMessage = "Неуспешно пребарување: \(lastError.localizedDescription)"
        } else {
            errorMessage = "Не е пронајдена полициска станица во близина. Во итен случај повикајте 112."
        }
    }
}

// The Core Location delegate is NOT main-actor isolated.
// Only primitive Sendable values cross into main-actor tasks.
private final class StationLocationDelegate: NSObject, CLLocationManagerDelegate {
    private let onAuthorization: @Sendable () -> Void
    private let onLocation: @Sendable (Double, Double) -> Void
    private let onError: @Sendable (String) -> Void

    init(
        onAuthorization: @escaping @Sendable () -> Void,
        onLocation: @escaping @Sendable (Double, Double) -> Void,
        onError: @escaping @Sendable (String) -> Void
    ) {
        self.onAuthorization = onAuthorization
        self.onLocation = onLocation
        self.onError = onError
        super.init()
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        onAuthorization()
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let location = locations.last else {
            onError("Не може да се прочита вашата локација.")
            return
        }
        onLocation(location.coordinate.latitude, location.coordinate.longitude)
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        onError(error.localizedDescription)
    }
}
