import MapKit
import SwiftUI

struct DestinationSearchView: View {
    let locationService: LocationService
    let onRouteReady: (RouteSketch) -> Void

    @State private var query = ""
    @State private var candidates: [DestinationCandidate] = []
    @State private var suggestionService = DestinationSuggestionService()
    @State private var workLabel: String?
    @State private var workTask: Task<Void, Never>?
    @State private var requestID = UUID()
    @State private var activeQuery = ""
    @State private var selectedMode: TransportMode?
    @State private var hasSearched = false
    @Environment(\.openURL) private var openURL

    private var isSearching: Bool { workLabel != nil }
    @State private var isShowingAlternatives = false
    @State private var selectedDestination: PlaceReference?
    @State private var errorMessage: String?
    @State private var searchRadius = 30_000.0
    @State private var picker: MapPickerRequest?
    @State private var showsAbout = false
    @FocusState private var isQueryFocused: Bool

    private let routeService = MapRouteService()

    var body: some View {
        ZStack {
            AtlasPaperBackground()
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        introduction
                        if (!candidates.isEmpty || selectedDestination != nil) && !isQueryFocused {
                            HStack {
                                Text(query.isEmpty ? "地图选点" : query)
                                    .font(.subheadline)
                                    .lineLimit(2)
                                Spacer()
                                Button("重新搜索") {
                                    selectedDestination = nil
                                    candidates = []
                                    hasSearched = false
                                    errorMessage = nil
                                    cancelWork()
                                    isQueryFocused = true
                                }
                                .frame(minHeight: 44)
                            }
                        } else {
                            searchForm.id("searchForm")
                        }
                        errorNotice
                        suggestionList
                        results
                            .disabled(isSearching)
                            .id("results")
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 56)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: candidates.count) { _, count in
                    if count > 0 { scrollProxy.scrollTo("results", anchor: .top) }
                }
                .onChange(of: errorMessage) { _, message in
                    if message != nil { scrollProxy.scrollTo("errorNotice", anchor: .top) }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom) {
            if let workLabel {
                HStack(spacing: 12) {
                    ProgressView()
                    Text(workLabel).font(.subheadline)
                    Spacer()
                    Button("取消") { cancelWork() }
                        .frame(minWidth: 44, minHeight: 44)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(TurnCueTheme.surface)
            } else if let selectedDestination, !isQueryFocused {
                routeConfirmation(for: selectedDestination)
            }
        }
        .onDisappear { cancelWork() }
        .onChange(of: query) { _, newValue in
            if newValue != activeQuery { cancelWork() }
            errorMessage = nil
            hasSearched = false
            searchRadius = 30_000
            candidates = []
            selectedDestination = nil
            isShowingAlternatives = false
            suggestionService.update(query: newValue, near: locationService.latestLocation?.coordinate)
        }
        .sheet(item: $picker) { request in
            MapPointPickerView(initial: request.initial) { place in
                selectedDestination = place
                candidates = []
                errorMessage = nil
            }
        }
        .sheet(isPresented: $showsAbout) {
            AboutView(locationService: locationService)
        }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                BrandLogoView()
                Spacer(minLength: 8)
                Button {
                    isQueryFocused = false
                    cancelWork()
                    showsAbout = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("关于与帮助")
                .accessibilityHint("查看使用说明、隐私政策与定位设置")
            }
            .padding(.bottom, 4)
            if !isQueryFocused && candidates.isEmpty && selectedDestination == nil {
                Rectangle()
                    .fill(TurnCueTheme.accent)
                    .frame(width: 44, height: 3)
                Text("先认方向，再找地标。")
                    .font(TurnCueTheme.atlasTitle(30))
                    .tracking(-0.5)
                    .foregroundStyle(TurnCueTheme.ink)
                Text("从当前位置出发，把路线记成几个关键节点。")
                    .font(.body)
                    .lineSpacing(4)
                    .foregroundStyle(TurnCueTheme.secondaryInk)
                    .frame(maxWidth: 330, alignment: .leading)
            }
        }
    }

    private var searchForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("你想去哪里？")
                .font(TurnCueTheme.atlasTitle(24))
            TextField("例如：次渠锦园北区北门", text: $query)
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .focused($isQueryFocused)
                .onSubmit { search(radius: searchRadius) }
                .padding(.leading, 16)
                .padding(.trailing, 50)
                .frame(minHeight: 58)
                .overlay(alignment: .trailing) {
                    if !query.isEmpty {
                        Button { query = ""; isQueryFocused = true } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(TurnCueTheme.secondaryInk)
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("清除目的地")
                    }
                }
                .background(TurnCueTheme.surface)
                .overlay { Rectangle().stroke(TurnCueTheme.connector, lineWidth: 1) }
                .overlay(alignment: .bottom) { Rectangle().fill(isQueryFocused ? TurnCueTheme.accent : TurnCueTheme.ink).frame(height: isQueryFocused ? 3 : 1) }
                .accessibilityLabel("目的地")
                .accessibilityHint("输入地点、城区、道路或建筑名称")

            Button { search(radius: searchRadius) } label: {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .font(.body.weight(.semibold))
                    Text("查找目的地")
                        .font(.headline)
                    Spacer()

                }
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity, minHeight: 56)
                .foregroundStyle(.white)
                .background(TurnCueTheme.ink)
            }
            .buttonStyle(PressButtonStyle())
            .disabled(isSearching || query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Text("从当前位置出发，查找时需要定位。")
                .font(.footnote)
                .foregroundStyle(TurnCueTheme.secondaryInk)
        }
    }

    @ViewBuilder
    private var errorNotice: some View {
        if let errorMessage {
            VStack(alignment: .leading, spacing: 8) {
                Label(errorMessage, systemImage: "exclamationmark.circle")
                    .font(.footnote)
                if locationService.authorizationStatus == .denied {
                    Button("打开定位设置") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                    .frame(minHeight: 44)
                }
            }
            .foregroundStyle(TurnCueTheme.ink)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(TurnCueTheme.surface)
            .id("errorNotice")
            .accessibilityLabel("错误：\(errorMessage)")
        }
    }

    private func routeConfirmation(for place: PlaceReference) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("前往 \(place.name)")
                .font(.footnote)
                .foregroundStyle(TurnCueTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)
            HStack {
                Text("出行方式").font(.subheadline)
                Spacer()
                Picker("出行方式", selection: $selectedMode) {
                    Text("按距离推荐").tag(TransportMode?.none)
                    ForEach(TransportMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(TransportMode?.some(mode))
                    }
                }
                .pickerStyle(.menu)
                .frame(minHeight: 44)
            }
            Button { makeRoute(to: place) } label: {
                Label("查看路线", systemImage: "arrow.right")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .foregroundStyle(.white)
                    .background(TurnCueTheme.ink)
            }
            .buttonStyle(PressButtonStyle())
            .accessibilityHint("生成前往\(place.name)的路线草图")
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .background(TurnCueTheme.surface)
    }

    @ViewBuilder
    private var suggestionList: some View {
        if !isSearching, !hasSearched, isQueryFocused, candidates.isEmpty, !query.isEmpty, !suggestionService.suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text("搜索建议").font(.subheadline.weight(.semibold))
                    .padding(.bottom, 8)
                ForEach(Array(suggestionService.suggestions.enumerated()), id: \.element.id) { index, suggestion in
                    Button {
                        query = suggestion.query
                        search(radius: searchRadius)
                    } label: {
                        HStack(spacing: 12) {
                            Text(String(format: "%02d", index + 1))
                                .font(.caption.monospacedDigit().weight(.bold))
                                .foregroundStyle(TurnCueTheme.accent)
                                .frame(width: 26, alignment: .leading)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(suggestion.title).font(.body.weight(.semibold)).foregroundStyle(TurnCueTheme.ink)
                                if !suggestion.subtitle.isEmpty { Text(suggestion.subtitle).font(.caption).foregroundStyle(TurnCueTheme.secondaryInk).lineLimit(1) }
                            }
                            Spacer(minLength: 8)
                            Image(systemName: "arrow.up.left").font(.caption.weight(.semibold)).foregroundStyle(TurnCueTheme.secondaryInk)
                        }
                        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                        .overlay(alignment: .bottom) { Rectangle().fill(TurnCueTheme.connector).frame(height: 1) }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var results: some View {
        if !isQueryFocused {
            if let first = candidates.first {
                VStack(alignment: .leading, spacing: 12) {
                    Text("选择目的地")
                        .font(TurnCueTheme.atlasTitle(24))
                    Text("核对地址，选好后查看路线。")
                        .font(.footnote)
                        .foregroundStyle(TurnCueTheme.secondaryInk)
                    candidateRow(first)
                    if candidates.count > 1 {
                        DisclosureGroup("其他 \(candidates.count - 1) 个地点", isExpanded: $isShowingAlternatives) {
                            VStack(spacing: 10) {
                                ForEach(candidates.dropFirst()) { candidate in candidateRow(candidate) }
                            }
                            .padding(.top, 10)
                        }
                        .font(.subheadline)
                        .padding(.vertical, 8)
                    }
                    searchAlternatives
                }
            } else if let place = selectedDestination {
                VStack(alignment: .leading, spacing: 8) {
                    Label("已选择地图位置", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                    Text(place.address).font(.subheadline)
                    Button("重新选点") { openMapPicker() }.frame(minHeight: 44)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(TurnCueTheme.surface)
            } else if !isSearching {
                if hasSearched { searchAlternatives }
                else {
                    Button("在地图上选点", systemImage: "map") { openMapPicker() }
                        .font(.subheadline)
                        .frame(minHeight: 44)
                }
            }
        }
    }

    private func candidateRow(_ candidate: DestinationCandidate) -> some View {
        CandidateButton(candidate: candidate, isSelected: selectedDestination == candidate.place) {
            selectedDestination = candidate.place
            errorMessage = nil
        }
    }

    private var searchAlternatives: some View {
        Menu {
            Button("扩大范围查找", systemImage: "magnifyingglass") { search(radius: 100_000) }
            Button("在地图上选点", systemImage: "map") { openMapPicker() }
        } label: {
            Label("没找到要去的地点？", systemImage: "ellipsis.circle")
                .font(.subheadline)
                .frame(minHeight: 44)
        }
    }

    private func search(radius: Double) {
        guard !isSearching else { return }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { isQueryFocused = true; return }
        isQueryFocused = false
        candidates = []
        selectedDestination = nil
        searchRadius = radius
        activeQuery = query
        beginWork("正在查找目的地…") {
            let location = try await locationService.currentLocation()
            try Task.checkCancellation()
            let found = try await routeService.search(query: trimmed, near: location, radiusMeters: radius)
            try Task.checkCancellation()
            candidates = found
            hasSearched = true
        }
    }

    private func makeRoute(to place: PlaceReference) {
        guard !isSearching else { return }
        isQueryFocused = false
        beginWork("正在整理路线与关键节点…") {
            let location = try await locationService.currentLocation()
            try Task.checkCancellation()
            let distance = GeoMath.distanceMeters(from: GeoPoint(location.coordinate), to: place.coordinate)
            let route = try await routeService.route(from: location, to: place, mode: selectedMode ?? .recommended(forStraightLineDistance: distance))
            try Task.checkCancellation()
            onRouteReady(route)
        }
    }

    private func openMapPicker() {
        guard !isSearching else { return }
        isQueryFocused = false
        beginWork("正在确定当前位置…") {
            let location = try await locationService.currentLocation()
            try Task.checkCancellation()
            picker = MapPickerRequest(initial: GeoPoint(location.coordinate))
        }
    }

    private func beginWork(_ label: String, action: @escaping @MainActor () async throws -> Void) {
        cancelWork()
        let id = UUID()
        requestID = id
        workLabel = label
        errorMessage = nil
        workTask = Task { @MainActor in
            defer {
                if requestID == id {
                    workLabel = nil
                    workTask = nil
                }
            }
            do { try await action() }
            catch {
                guard requestID == id, !Task.isCancelled else { return }
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "暂时无法连接地图服务。请检查网络后重试。"
                hasSearched = true
            }
        }
    }

    private func cancelWork() {
        requestID = UUID()
        workTask?.cancel()
        workTask = nil
        locationService.cancelCurrentRequest()
        workLabel = nil
    }

}

private struct CandidateButton: View {
    let candidate: DestinationCandidate
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? TurnCueTheme.accent : TurnCueTheme.secondaryInk)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(candidate.place.name)
                        .font(TurnCueTheme.atlasTitle(21))
                        .foregroundStyle(TurnCueTheme.ink)
                    Text(candidate.place.address)
                        .font(.footnote)
                        .lineSpacing(2)
                        .foregroundStyle(TurnCueTheme.secondaryInk)
                        .lineLimit(2)
                    Text("\(candidate.direction.title)  ·  直线\(candidate.distanceText)")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(TurnCueTheme.accent)
                }
                Spacer(minLength: 8)

            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(TurnCueTheme.surface)
            .overlay { Rectangle().stroke(TurnCueTheme.connector, lineWidth: 1) }
            .overlay(alignment: .leading) { if isSelected { Rectangle().fill(TurnCueTheme.accent).frame(width: 4) } }
        }
        .buttonStyle(PressButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint("选择此地点，再点查看路线")
    }
}

private struct MapPickerRequest: Identifiable { let id = UUID(); let initial: GeoPoint }

private struct MapPointPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let initial: GeoPoint
    let onConfirm: (PlaceReference) -> Void
    @State private var position: MapCameraPosition
    @State private var selected: GeoPoint?

    init(initial: GeoPoint, onConfirm: @escaping (PlaceReference) -> Void) {
        self.initial = initial; self.onConfirm = onConfirm
        _position = State(initialValue: .region(MKCoordinateRegion(center: initial.coordinate, latitudinalMeters: 4_000, longitudinalMeters: 4_000)))
    }

    var body: some View {
        NavigationStack {
            MapReader { proxy in
                Map(position: $position) {
                    UserAnnotation()
                    if let selected { Marker("选择的位置", coordinate: selected.coordinate) }
                }
                .onTapGesture { point in if let coordinate = proxy.convert(point, from: .local) { selected = GeoPoint(coordinate) } }
            }
            .navigationTitle("在地图上选点").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 12) {
                    Text(selected == nil ? "轻点地图标记目的地" : "已标记目的地，可再次轻点调整。")
                        .font(.footnote)
                        .foregroundStyle(TurnCueTheme.secondaryInk)
                    Button {
                        guard let selected else { return }
                        onConfirm(PlaceReference(name: "选定的目的地", address: "地图上标记的位置", coordinate: selected))
                        dismiss()
                    } label: {
                        Text("确认目的地")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .foregroundStyle(.white)
                            .background(TurnCueTheme.ink)
                    }
                    .buttonStyle(PressButtonStyle())
                    .disabled(selected == nil)
                }
                .padding(20)
                .background(TurnCueTheme.surface)
            }
        }
    }
}

#Preview { NavigationStack { DestinationSearchView(locationService: LocationService()) { _ in } } }
