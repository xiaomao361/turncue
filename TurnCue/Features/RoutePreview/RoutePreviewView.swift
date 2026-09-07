import MapKit
import SwiftUI

struct RoutePreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var followPhase: FollowPhase = .overview
    @State private var isShowingRouteIndex = false
    @State private var detailScrollRequest = 0

    private var hasStarted: Bool { followPhase != .overview }
    private var isFollowing: Bool { followPhase == .following }
    private var isBrowsingAnotherNode: Bool {
        selectedLegID != nil && selectedLegID != progress.currentLeg.id
    }
    @State private var exportTask: Task<Void, Never>?
    let locationService: LocationService
    @State private var currentRoute: RouteSketch
    @State private var progress: RouteProgress
    @State private var errorMessage: String?
    @State private var mapPosition: MapCameraPosition
    @State private var selectedLegID: UUID?
    @State private var exportedImage: ExportedRouteImage?
    @State private var isExporting = false

    init(route: RouteSketch, locationService: LocationService) {
        self.locationService = locationService
        _currentRoute = State(initialValue: route)
        _progress = State(initialValue: RouteProgress(route: route))
        _mapPosition = State(initialValue: .region(Self.mapRegion(for: route)))
        _selectedLegID = State(initialValue: route.legs.first?.id)
    }

    var body: some View {
        ZStack {
            AtlasPaperBackground()
            ScrollViewReader { scrollProxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        atlasHeader
                        SimplifiedRouteMap(route: currentRoute, progress: progress, isFollowing: isFollowing, position: $mapPosition, selectedLegID: $selectedLegID)
                        if let selectedLeg {
                            SelectedNodeCard(
                                leg: selectedLeg,
                                context: nodeContext(for: selectedLeg)
                            )
                            .id("nodeDetail")
                        }
                        DisclosureGroup("全部 \(currentRoute.legs.count) 个节点", isExpanded: $isShowingRouteIndex) {
                            VStack(spacing: 0) {
                                ForEach(Array(currentRoute.legs.enumerated()), id: \.element.id) { index, leg in
                                    Button {
                                        selectedLegID = leg.id
                                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                                            scrollProxy.scrollTo("nodeDetail", anchor: .top)
                                        }
                                    } label: {
                                        RouteSketchRow(leg: leg, index: index, state: rowState(for: index), isSelected: selectedLegID == leg.id)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityAddTraits(selectedLegID == leg.id ? .isSelected : [])
                                    .accessibilityHint("查看说明，不会改变跟随进度")
                                }
                            }
                            .padding(.top, 8)
                        }
                        .font(.subheadline.weight(.semibold))
                        .padding(20)
                    }
                    .padding(.bottom, 24)
                }
                .onChange(of: detailScrollRequest) { _, _ in
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                        scrollProxy.scrollTo("nodeDetail", anchor: .top)
                    }
                }
            }
        }
        .toolbar(.visible, for: .navigationBar)
        .navigationTitle(progress.isComplete ? "已到达" : isFollowing ? "路线跟随" : "路线草图")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(TurnCueTheme.background, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("保存或分享路线图", systemImage: "square.and.arrow.up") { exportRouteImage() }
                        .disabled(isExporting)
                    Button("用 Apple 地图导航", systemImage: "map") { MapHandoffService.open(route: currentRoute) }
                    if isFollowing {
                        Button("暂停跟随", systemImage: "pause") { followPhase = .paused; locationService.stopNavigationUpdates() }
                    }
                    if progress.canGoBack {
                        Button(progress.isComplete ? "撤销到达" : "退回上一节点", systemImage: "arrow.uturn.backward") {
                            progress.goBack()
                            selectedLegID = progress.currentLeg.id
                            followPhase = .paused
                            detailScrollRequest += 1
                            locationService.stopNavigationUpdates()
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle").frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("路线操作")
            }
        }
        .safeAreaInset(edge: .bottom) { controls }
        .onChange(of: locationService.locationRevision) { _, _ in updateFromLocation() }
        .onDisappear {
            locationService.stopNavigationUpdates()
            exportTask?.cancel()
        }
        .onAppear { if isFollowing { locationService.startNavigationUpdates() } }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && isFollowing { locationService.startNavigationUpdates() }
            else { locationService.stopNavigationUpdates() }
        }
        .onChange(of: progress.currentIndex) { previousIndex, _ in
            if selectedLegID == currentRoute.legs[previousIndex].id {
                selectedLegID = progress.currentLeg.id
            }
        }
        .sensoryFeedback(.selection, trigger: progress.currentIndex)
        .sensoryFeedback(.success, trigger: progress.isComplete) { _, completed in completed }
        .sheet(item: $exportedImage) { item in
            ActivityShareView(items: [item.image])
        }
    }

    private var atlasHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(currentRoute.destination.name)
                .font(TurnCueTheme.atlasTitle(28))
                .fixedSize(horizontal: false, vertical: true)
            Label("\(currentRoute.transportMode.title) · \(currentRoute.totalDistanceText) · 约 \(currentRoute.durationMinutes) 分钟", systemImage: currentRoute.transportMode.symbolName)
                .font(.subheadline)
                .foregroundStyle(TurnCueTheme.secondaryInk)
                .padding(.top, 6)
            HStack {
                Text(progress.isComplete ? "已完成全部节点" : "共 \(currentRoute.legs.count) 个关键节点")
                    .font(.footnote)
                Spacer()
                Button("显示全程", systemImage: "arrow.up.left.and.arrow.down.right") { resetMap() }
                    .font(.footnote.weight(.semibold))
                    .frame(minHeight: 44)
            }
            .foregroundStyle(TurnCueTheme.accent)
        }
        .foregroundStyle(TurnCueTheme.ink)
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(TurnCueTheme.accent)
                    .accessibilityLabel("错误：\(errorMessage)")
            }
            if isExporting {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("正在生成路线图…").font(.footnote)
                }
            }
            Text(primarySubtitle)
                .font(.footnote)
                .foregroundStyle(TurnCueTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: primaryAction) {
                Text(primaryLabel)
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .foregroundStyle(.white)
                    .background(TurnCueTheme.ink)
            }
            .buttonStyle(PressButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TurnCueTheme.surface)
    }

    private var primaryLabel: String {
        if progress.isComplete { return "完成，返回搜索" }
        if !hasStarted { return "开始跟随" }
        if !isFollowing { return "继续跟随" }
        if isBrowsingAnotherNode { return "返回当前节点" }
        return progress.isOnFinalLeg ? "确认到达目的地" : "我已到达这个节点"
    }

    private var primarySubtitle: String {
        if progress.isComplete { return "已确认到达 \(currentRoute.destination.name)" }
        if !hasStarted { return "先到 \(progress.currentLeg.displayName) · 仅在前台更新位置" }
        if !isFollowing { return "已暂停 · 继续前往 \(progress.currentLeg.displayName)" }
        if isBrowsingAnotherNode { return "正在查看其他节点，当前目标仍是 \(progress.currentLeg.displayName)" }
        return "当前目标 \(progress.currentIndex + 1)/\(currentRoute.legs.count) · \(progress.currentLeg.displayName)"
    }

    private func nodeContext(for leg: RouteLeg) -> String {
        let number = sequence(of: leg)
        if progress.isComplete { return "路线回顾 · 节点 \(number)" }
        if !hasStarted { return "路线预览 · 节点 \(number)" }
        if leg.id == progress.currentLeg.id { return "\(isFollowing ? "当前目标" : "已暂停") · 节点 \(number)" }
        return "正在查看 · 节点 \(number)（不会改变进度）"
    }

    private func primaryAction() {
        if progress.isComplete { dismiss(); return }
        if !isFollowing {
            followPhase = .following
            detailScrollRequest += 1
            selectedLegID = progress.currentLeg.id
            locationService.startNavigationUpdates()
        } else if isBrowsingAnotherNode {
            selectedLegID = progress.currentLeg.id
            detailScrollRequest += 1
        } else {
            guard progress.confirmArrival(at: selectedLegID) else { return }
            selectedLegID = progress.currentLeg.id
            if progress.isComplete {
                followPhase = .paused
                locationService.stopNavigationUpdates()
            }
        }
    }

    private func resetMap() {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
            mapPosition = .region(Self.mapRegion(for: currentRoute))
        }
    }

    private func rowState(for index: Int) -> SketchRowState {
        if progress.isComplete { return .completed }
        guard hasStarted else { return .overview }
        if index < progress.currentIndex { return .completed }
        if index == progress.currentIndex { return .current }
        return .upcoming
    }

    private func updateFromLocation() {
        guard isFollowing, scenePhase == .active, let location = locationService.latestLocation,
              location.timestamp.timeIntervalSinceNow > -15 else { return }
        _ = progress.updateLocation(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude, horizontalAccuracy: location.horizontalAccuracy)
    }

    private var selectedLeg: RouteLeg? {
        currentRoute.legs.first { $0.id == selectedLegID }
    }

    private func sequence(of leg: RouteLeg) -> Int {
        (currentRoute.legs.firstIndex { $0.id == leg.id } ?? 0) + 1
    }

    private func exportRouteImage() {
        guard !isExporting else { return }
        isExporting = true
        errorMessage = nil
        exportTask = Task {
            defer { isExporting = false }
            do {
                let image = try await RouteImageExporter.render(route: currentRoute)
                try Task.checkCancellation()
                exportedImage = ExportedRouteImage(image: image)
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = "无法生成路线图。请检查网络，在右上角菜单中重新分享。"
            }
        }
    }

    private static func mapRegion(for route: RouteSketch) -> MKCoordinateRegion {
        let points = route.displayPath
        let latitudes = points.map(\.latitude)
        let longitudes = points.map(\.longitude)
        guard let minLatitude = latitudes.min(), let maxLatitude = latitudes.max(),
              let minLongitude = longitudes.min(), let maxLongitude = longitudes.max() else {
            return MKCoordinateRegion(center: route.source.coordinate, latitudinalMeters: 2_000, longitudinalMeters: 2_000)
        }
        let latitudeDelta = max(0.008, (maxLatitude - minLatitude) * 1.28)
        let longitudeDelta = max(0.008, (maxLongitude - minLongitude) * 1.28)
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: (minLatitude + maxLatitude) / 2, longitude: (minLongitude + maxLongitude) / 2),
            span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
        )
    }
}

private enum FollowPhase { case overview, following, paused }

private struct SimplifiedRouteMap: View {
    let route: RouteSketch
    let progress: RouteProgress
    let isFollowing: Bool
    @Binding var position: MapCameraPosition
    @Binding var selectedLegID: UUID?

    var body: some View {
        Map(position: $position, interactionModes: [.pan, .zoom]) {
            UserAnnotation()
            MapPolyline(coordinates: route.displayPath.map(\.coordinate))
                .stroke(TurnCueTheme.routeHalo, style: StrokeStyle(lineWidth: 12, lineCap: .round, lineJoin: .round))
            MapPolyline(coordinates: route.displayPath.map(\.coordinate))
                .stroke(TurnCueTheme.accent, style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))

            Annotation("起点", coordinate: route.source.coordinate, anchor: .center) {
                EndpointMarker(title: "起", color: TurnCueTheme.ink)
            }

            ForEach(Array(route.legs.enumerated()), id: \.element.id) { index, leg in
                Annotation(annotationTitle(for: leg, index: index), coordinate: leg.trigger.coordinate, anchor: .center) {
                    Button { selectedLegID = leg.id } label: {
                        MapNodeLabel(
                            name: leg.displayName,
                            sequence: index + 1,
                            action: leg.action,
                            isSelected: selectedLegID == leg.id,
                            isCurrent: isFollowing && index == progress.currentIndex,
                            isCompleted: isFollowing && index < progress.currentIndex
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("显示如何到达此节点以及到达后的方向")
                }
            }
        }
        .mapStyle(.standard(elevation: .flat))
        .frame(height: 320)
        .overlay(TurnCueTheme.background.opacity(0.10).allowsHitTesting(false))
        .overlay { Rectangle().stroke(Color.black.opacity(0.10), lineWidth: 1).allowsHitTesting(false) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("从当前位置到 \(route.destination.name) 的简化路线图，共 \(route.legs.count) 个关键节点")
    }

    private func annotationTitle(for leg: RouteLeg, index: Int) -> String {
        leg.action == .arrive ? "终点" : "节点 \(index + 1)：\(leg.action.title)"
    }
}

private struct MapNodeLabel: View {
    let name: String
    let sequence: Int
    let action: RouteAction
    let isSelected: Bool
    let isCurrent: Bool
    let isCompleted: Bool

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(TurnCueTheme.routeHalo)
                        .frame(width: 46, height: 46)
                        .overlay { Circle().stroke(TurnCueTheme.accent, lineWidth: 3) }
                }
                Circle()
                    .fill(action == .arrive || isSelected ? TurnCueTheme.accent : TurnCueTheme.ink)
                    .frame(width: isCurrent || isSelected ? 40 : 32, height: isCurrent || isSelected ? 40 : 32)
                if action == .arrive {
                    Image(systemName: "flag.fill").font(.caption.weight(.bold)).foregroundStyle(.white)
                } else {
                    Text("\(sequence)").font(.caption.weight(.bold)).foregroundStyle(.white)
                }
            }
            Text(name)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(TurnCueTheme.ink)
                .lineLimit(1)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(TurnCueTheme.surface.opacity(0.86))
        }
        .opacity(isCompleted ? 0.45 : 1)
        .contentShape(Rectangle())
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel(action == .arrive ? "终点，\(name)" : "第 \(sequence) 个关键节点，\(name)，\(action.title)")
    }
}

private struct SelectedNodeCard: View {
    let leg: RouteLeg
    let context: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(context)
                .font(.caption.weight(.semibold))
                .foregroundStyle(TurnCueTheme.secondaryInk)
            Text(leg.displayName)
                .font(TurnCueTheme.atlasTitle(25))
                .foregroundStyle(TurnCueTheme.ink)
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("怎么到这里").font(.caption2).frame(width: 78, alignment: .leading)
                Text(leg.approachSummary).font(.subheadline)
            }
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("到达以后").font(.caption2).frame(width: 78, alignment: .leading)
                Text(leg.decision)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(TurnCueTheme.accent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(TurnCueTheme.surface)
        .overlay(alignment: .top) { Rectangle().fill(TurnCueTheme.accent).frame(height: 4) }
        .accessibilityElement(children: .combine)
    }
}

private struct EndpointMarker: View {
    let title: String
    let color: Color
    var body: some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 32, height: 32)
            .background(color, in: Circle())
            .overlay { Circle().stroke(.white, lineWidth: 3) }
            .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
    }
}

private enum SketchRowState { case overview, completed, current, upcoming }

private struct RouteSketchRow: View {
    let leg: RouteLeg
    let index: Int
    let state: SketchRowState
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text("\(index + 1)")
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .frame(width: 30, height: 30)
                .background(TurnCueTheme.connector.opacity(0.25), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(leg.displayName).font(.body.weight(.medium))
                Text("\(leg.direction.title) · \(leg.approximateDistanceText) · \(leg.action.title)")
                    .font(.footnote)
                    .foregroundStyle(TurnCueTheme.secondaryInk)
            }
            Spacer(minLength: 4)
            if isSelected {
                Image(systemName: "eye").accessibilityHidden(true)
            } else if state == .completed {
                Image(systemName: "checkmark").accessibilityHidden(true)
            }
        }
        .foregroundStyle(state == .current || isSelected ? TurnCueTheme.accent : TurnCueTheme.ink)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) { Rectangle().fill(TurnCueTheme.connector).frame(height: 0.5) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("节点 \(index + 1)，\(leg.displayName)，\(leg.action.title)\(state == .current ? "，当前目标" : state == .completed ? "，已完成" : "")")
    }
}

#Preview { NavigationStack { RoutePreviewView(route: .sample, locationService: LocationService()) } }
